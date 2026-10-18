# ODM Overhaul Patch

This repository contains an ODM tuning patch plus a reusable controller module for Aot:Demolish.

## Existing source patch
- Hold right mouse button to auto-fire both grapple hooks.
- Release right mouse button to cut hooks while retaining character momentum.
- Increased hook speed, boost acceleration, and maximum ODM speed.
- Increased gas capacity and reduced gas drain while grappling/boosting.
- Updated the on-screen control hint.

The unified diff is in [`ODM_Overhaul.patch`](ODM_Overhaul.patch). It targets these files in the original project:
- `MATCH/StarterPlayerScripts/match_client.lua`
- `MATCH/ServerScriptService/match_server.lua`
- `BOTH/ReplicatedStorage/Scaling.lua`

## Controller module
[`ODM_Gear_Controller.lua`](ODM_Gear_Controller.lua) provides reusable ODM state, dual-hook input handling, cooldowns, gas drain/refill, boost, dash, slash callbacks, and cleanup. The controller was hardened to use independent left/right hook cooldowns and to reject actions unless their callbacks explicitly accept them.

Read [`ODM_Controller_Integration.md`](ODM_Controller_Integration.md) before installing it. The controller does not create hook physics, visuals, or server validation on its own. The original match source files are not included in this repository, so it is not yet wired into the live game scripts.

## Safety and testing
Keep server-side gas, hook range/line-of-sight, cooldowns, damage, and movement validation authoritative. Test in a separate Roblox Studio copy before replacing any live scripts. The patch and module have not yet been verified through Roblox Studio playtests.
