# ODM Controller Integration Guide

The controller is a reusable **state/resource layer**, not a drop-in replacement for the existing match movement code. The original match scripts are not present in this repository, so automatic integration would risk breaking the current game.

## Install

1. In Roblox Studio, add a `ModuleScript` named `ODM_Gear_Controller` in a location accessible to the script that owns ODM movement.
2. Paste the contents of [ODM_Gear_Controller.lua](ODM_Gear_Controller.lua).
3. Require the module and supply callbacks that connect to your existing hook, boost, dash, slash, and UI implementations.
4. Call `controller:Equip()` when ODM is equipped, `controller:Update(dt, grounded)` from one Heartbeat loop, and `controller:Unequip()` when the gear is removed.
5. Connect input events to `FireHook`, `FireDualHooks`, `ReleaseGrapple`, `StartBoost`, `StopBoost`, `Dash`, and `Slash`.

## Callback contract

Callbacks are supplied in `config.Actions`. Action callbacks must return `true` only when the action was actually accepted; return `false` (or no value) to reject it. For example:

- `FireHook(side, targetPosition, maxRange)`: request a hook; return true only after your hook system accepts it.
- `CutHook(side)`: remove that side's rope/constraints. Do not zero character velocity when cutting, so momentum is preserved.
- `Boost(force, maxSpeed)`: start the existing boost behavior and return true on success.
- `StopBoost()`: stop the boost force/actuator.
- `Dash(directionUnit, maxSpeed)`: perform a dash and return true on success.
- `Slash(target)`: request a slash; validate the target and damage on the server, then return true if accepted.
- `GasChanged(currentGas, maxGas)`: update your gas UI.
- `OnEquipped()` / `OnUnequipped()`: optional lifecycle hooks.

## Security and integration requirements

- The server must own gas, hook range/line-of-sight checks, cooldowns, slash hit validation, and movement limits. Do not trust client-provided targets, damage, gas values, or speed.
- Rate-limit RemoteEvents on the server and reject malformed vectors, stale characters, dead players, mounted/cutscene states, and requests when ODM is not equipped.
- Destroy hook attachments, ropes, forces, and connections when a hook is cut, the character respawns, or the player leaves.
- Test in a separate place first. The controller uses the Aot:Demolish tuning defaults (125 gas, 800 range, 430 max speed), but it does not create the game's hook visuals or physics by itself.

## Important

The module has been hardened for state handling, separate left/right hook cooldowns, callback rejection, finite tuning values, gas drain/refill, and cleanup. It still requires integration with the real match scripts and Roblox Studio playtests before it can be called finished.
