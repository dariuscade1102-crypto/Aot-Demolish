# ODM Overhaul Patch

This patch updates the existing AOT Demolish ODM scripts.

## Changes
- Hold right mouse button to auto-fire both grapple hooks.
- Release right mouse button to cut hooks while retaining character momentum.
- Increased hook speed, boost acceleration, and maximum ODM speed.
- Increased gas capacity and reduced gas drain while grappling/boosting.
- Updated the on-screen control hint.

## Files changed
- `MATCH/StarterPlayerScripts/match_client.lua`
- `MATCH/ServerScriptService/match_server.lua`
- `BOTH/ReplicatedStorage/Scaling.lua`

## Applying
The unified diff is in [`patches/ODM_Overhaul.patch`](ODM_Overhaul.patch). Apply it to the original project source after checking that the target paths match your local project layout.

## Important
This is a source patch, not a full Roblox place/project upload. It has not been tested in Roblox Studio, so test it in a separate copy before replacing the live game files.
