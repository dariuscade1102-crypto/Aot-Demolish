--!strict
-- Aot:Demolish | ODM Gear Controller
-- Adapter-based controller. Hook geometry, physics, and damage must be implemented
-- by the host game and validated on the server. This module is not a security boundary.

local ODMGearController = {}
ODMGearController.__index = ODMGearController

local DEFAULTS = {
    MaxGas = 125,
    HookRange = 800,
    HookCooldown = 0.18,
    BoostCooldown = 0.22,
    DashCooldown = 0.42,
    SlashCooldown = 0.28,
    GasPerHookSecond = 1.8,
    GasPerBoostSecond = 4.2,
    GasPerDash = 8,
    GasRefillPerSecond = 42,
    BoostForce = 310,
    MaxSpeed = 430,
}

local SIDES = { Left = true, Right = true }
local ACTION_NAMES = {
    "FireHook", "CutHook", "Boost", "StopBoost", "Dash", "Slash",
    "GasChanged", "OnEquipped", "OnUnequipped",
}

local function isFiniteNonNegative(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge and value >= 0
end

local function safeCall(callback, ...)
    local ok, result = pcall(callback, ...)
    if not ok then
        warn("[ODM] Callback failed: " .. tostring(result))
        return false, nil
    end
    return true, result
end

function ODMGearController.new(config)
    assert(type(config) == "table", "ODM config table is required")
    assert(config.Tuning == nil or type(config.Tuning) == "table", "Tuning must be a table")
    assert(config.Actions == nil or type(config.Actions) == "table", "Actions must be a table")

    local self = setmetatable({}, ODMGearController)
    self.Config = table.clone(DEFAULTS)

    for key, value in pairs(config.Tuning or {}) do
        if self.Config[key] ~= nil then
            assert(isFiniteNonNegative(value), ("Tuning.%s must be a finite non-negative number"):format(key))
            self.Config[key] = value
        end
    end
    assert(self.Config.MaxGas > 0, "MaxGas must be greater than zero")
    assert(self.Config.HookRange > 0, "HookRange must be greater than zero")

    self.Actions = config.Actions or {}
    for name, callback in pairs(self.Actions) do
        assert(table.find(ACTION_NAMES, name), ("Unknown ODM action: %s"):format(tostring(name)))
        assert(type(callback) == "function", ("Actions.%s must be a function"):format(name))
    end

    self.Gas = self.Config.MaxGas
    self.Hooks = { Left = false, Right = false }
    self.LastAction = {
        Hook = { Left = -math.huge, Right = -math.huge },
        Boost = -math.huge,
        Dash = -math.huge,
        Slash = -math.huge,
    }
    self.Equipped = false
    self.Boosting = false
    self.Destroyed = false
    return self
end

function ODMGearController:_call(name, ...)
    local callback = self.Actions[name]
    if not callback then
        return false, nil
    end
    return safeCall(callback, ...)
end

function ODMGearController:_emitGas()
    self:_call("GasChanged", self.Gas, self.Config.MaxGas)
end

function ODMGearController:Equip()
    if self.Destroyed or self.Equipped then return false end
    self.Equipped = true
    self:_call("OnEquipped")
    self:_emitGas()
    return true
end

function ODMGearController:Unequip()
    if self.Destroyed or not self.Equipped then return end
    self:ReleaseGrapple()
    self:StopBoost()
    self.Equipped = false
    self:_call("OnUnequipped")
end

function ODMGearController:FireHook(side, targetPosition)
    if not self.Equipped or self.Destroyed or self.Gas <= 0 then return false end
    if not SIDES[side] or self.Hooks[side] then return false end
    if targetPosition ~= nil and typeof(targetPosition) ~= "Vector3" then return false end

    local now = os.clock()
    if now - self.LastAction.Hook[side] < self.Config.HookCooldown then return false end
    local callback = self.Actions.FireHook
    if not callback then
        warn("[ODM] Actions.FireHook is required to fire a hook")
        return false
    end

    local ok, accepted = safeCall(callback, side, targetPosition, self.Config.HookRange)
    if not ok or accepted ~= true then return false end

    self.LastAction.Hook[side] = now
    self.Hooks[side] = true
    return true
end

function ODMGearController:FireDualHooks(leftTarget, rightTarget)
    -- Separate per-side cooldowns allow both hooks to fire in the same input frame.
    local left = self:FireHook("Left", leftTarget)
    local right = self:FireHook("Right", rightTarget)
    return left or right
end

function ODMGearController:ReleaseGrapple(side)
    if side ~= nil then
        if not SIDES[side] or not self.Hooks[side] then return end
        self.Hooks[side] = false
        self:_call("CutHook", side)
        return
    end

    for _, hookSide in ipairs({ "Left", "Right" }) do
        if self.Hooks[hookSide] then
            self.Hooks[hookSide] = false
            self:_call("CutHook", hookSide)
        end
    end
    -- Never zero AssemblyLinearVelocity here: preserve swing momentum.
end

function ODMGearController:StartBoost()
    if not self.Equipped or self.Destroyed or self.Gas <= 0 or self.Boosting then
        return false
    end
    local now = os.clock()
    if now - self.LastAction.Boost < self.Config.BoostCooldown then return false end
    local ok = self:_call("Boost", self.Config.BoostForce, self.Config.MaxSpeed)
    if not ok then return false end
    self.LastAction.Boost = now
    self.Boosting = true
    return true
end

function ODMGearController:StopBoost()
    if not self.Boosting then return end
    self.Boosting = false
    self:_call("StopBoost")
end

function ODMGearController:Dash(direction)
    if not self.Equipped or self.Destroyed or self.Gas < self.Config.GasPerDash then
        return false
    end
    if typeof(direction) ~= "Vector3" or direction.Magnitude < 1e-4 then return false end

    local now = os.clock()
    if now - self.LastAction.Dash < self.Config.DashCooldown then return false end
    local ok = self:_call("Dash", direction.Unit, self.Config.MaxSpeed)
    if not ok then return false end

    self.LastAction.Dash = now
    self.Gas = math.max(0, self.Gas - self.Config.GasPerDash)
    self:_emitGas()
    return true
end

function ODMGearController:Slash(target)
    if not self.Equipped or self.Destroyed then return false end
    local now = os.clock()
    if now - self.LastAction.Slash < self.Config.SlashCooldown then return false end
    local ok = self:_call("Slash", target)
    if not ok then return false end
    self.LastAction.Slash = now
    return true
end

-- Call from RunService.Heartbeat with deltaTime and whether the character is grounded.
-- In production, server-owned gas and movement validation must be authoritative.
function ODMGearController:Update(deltaTime, grounded)
    if self.Destroyed or not self.Equipped then return end
    if not isFiniteNonNegative(deltaTime) or deltaTime == 0 then return end

    local hookCount = (self.Hooks.Left and 1 or 0) + (self.Hooks.Right and 1 or 0)
    local drain = hookCount * self.Config.GasPerHookSecond
    if self.Boosting then drain += self.Config.GasPerBoostSecond end

    local oldGas = self.Gas
    if drain > 0 then
        self.Gas = math.max(0, self.Gas - drain * math.min(deltaTime, 0.25))
        if self.Gas <= 0 then
            self:ReleaseGrapple()
            self:StopBoost()
        end
    elseif grounded == true then
        self.Gas = math.min(
            self.Config.MaxGas,
            self.Gas + self.Config.GasRefillPerSecond * math.min(deltaTime, 0.25)
        )
    end

    if math.abs(self.Gas - oldGas) > 1e-4 then self:_emitGas() end
end

function ODMGearController:Destroy()
    if self.Destroyed then return end
    self:Unequip()
    self.Destroyed = true
    self.Hooks.Left = false
    self.Hooks.Right = false
end

return ODMGearController
