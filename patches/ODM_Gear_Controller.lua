-- ODM Gear Controller prototype for Aot:Demolish
-- Place this ModuleScript in ReplicatedStorage or StarterPlayerScripts.
-- Integration note: this is an adapter-based controller because the repository currently
-- contains patch files, not the game's original match_client.lua / match_server.lua.
-- Pass the existing project's hook, boost, dash, slash, and gas functions in config.

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

function ODMGearController.new(config)
    assert(type(config) == "table", "ODM config table is required")
    local self = setmetatable({}, ODMGearController)
    self.Config = table.clone(DEFAULTS)
    for key, value in pairs(config.Tuning or {}) do
        if self.Config[key] ~= nil then self.Config[key] = value end
    end

    self.Actions = config.Actions or {}
    self.Gas = self.Config.MaxGas
    self.Hooks = { Left = false, Right = false }
    self.LastAction = { Hook = 0, Boost = 0, Dash = 0, Slash = 0 }
    self.Equipped = false
    self.Boosting = false
    self.Destroyed = false
    return self
end

function ODMGearController:_call(actionName, ...)
    local callback = self.Actions[actionName]
    if callback then
        return callback(...)
    end
    warn(("ODM action '%s' has no callback configured"):format(actionName))
    return nil
end

function ODMGearController:Equip()
    if self.Destroyed then return false end
    self.Equipped = true
    self:_call("OnEquipped")
    return true
end

function ODMGearController:Unequip()
    self:ReleaseGrapple()
    self.Boosting = false
    self.Equipped = false
    self:_call("OnUnequipped")
end

function ODMGearController:FireHook(side, targetPosition)
    if not self.Equipped or self.Destroyed or self.Gas <= 0 then return false end
    if side ~= "Left" and side ~= "Right" then return false end

    local now = os.clock()
    if now - self.LastAction.Hook < self.Config.HookCooldown then return false end
    self.LastAction.Hook = now

    local accepted = self:_call("FireHook", side, targetPosition, self.Config.HookRange)
    if accepted == false then return false end
    self.Hooks[side] = true
    return true
end

function ODMGearController:FireDualHooks(leftTarget, rightTarget)
    local left = self:FireHook("Left", leftTarget)
    local right = self:FireHook("Right", rightTarget)
    return left or right
end

function ODMGearController:ReleaseGrapple(side)
    if side then
        if not self.Hooks[side] then return end
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
    -- Deliberately do not zero velocity here; the movement system keeps momentum.
end

function ODMGearController:StartBoost()
    if not self.Equipped or self.Destroyed or self.Gas <= 0 then return false end
    local now = os.clock()
    if now - self.LastAction.Boost < self.Config.BoostCooldown then return false end
    self.LastAction.Boost = now
    self.Boosting = true
    self:_call("Boost", self.Config.BoostForce, self.Config.MaxSpeed)
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
    local now = os.clock()
    if now - self.LastAction.Dash < self.Config.DashCooldown then return false end
    self.LastAction.Dash = now
    self.Gas -= self.Config.GasPerDash
    self:_call("Dash", direction, self.Config.MaxSpeed)
    self:_call("GasChanged", self.Gas, self.Config.MaxGas)
    return true
end

function ODMGearController:Slash(target)
    if not self.Equipped or self.Destroyed then return false end
    local now = os.clock()
    if now - self.LastAction.Slash < self.Config.SlashCooldown then return false end
    self.LastAction.Slash = now
    self:_call("Slash", target)
    return true
end

-- Call once per frame/Heartbeat with delta time. Server-side validation should remain
-- authoritative for gas, damage, hook range, and movement limits.
function ODMGearController:Update(deltaTime, grounded)
    if self.Destroyed or not self.Equipped or deltaTime <= 0 then return end

    local hookCount = (self.Hooks.Left and 1 or 0) + (self.Hooks.Right and 1 or 0)
    local drain = hookCount * self.Config.GasPerHookSecond
    if self.Boosting then drain += self.Config.GasPerBoostSecond end

    if drain > 0 then
        self.Gas = math.max(0, self.Gas - drain * deltaTime)
        if self.Gas <= 0 then
            self:ReleaseGrapple()
            self:StopBoost()
        end
    elseif grounded then
        self.Gas = math.min(
            self.Config.MaxGas,
            self.Gas + self.Config.GasRefillPerSecond * deltaTime
        )
    end

    self:_call("GasChanged", self.Gas, self.Config.MaxGas)
end

function ODMGearController:Destroy()
    if self.Destroyed then return end
    self:Unequip()
    self.Destroyed = true
    table.clear(self.Hooks)
    table.clear(self.LastAction)
end

return ODMGearController
