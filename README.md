# ExtraRV

A Lua mod for **RV There Yet?** that allows you to spawn extra Winnebago RVs into your game. Designed with multiplayer in mind, all spawned vehicles are fully replicated and synchronized across all players.

## Features

- **Multiplayer Replicated**: Spawned RVs are visible, driveable, and synchronized for everyone in a co-op session.
- **Easy Spawning**: Use the `F7` key or the `spawnrv` console command to create a new RV near you.
- **Customizable Placement**: Adjust the side offset and drop height via console parameters.
- **Actor Scanner**: Use `F6` or `scanrv` to list vehicle classes in the world (useful if spawning fails).

## Installation

This mod requires [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) (Unreal Engine 4 Scripting System).

1. Install **UE4SS** into your game's `Win64` folder.
2. Extract the `ExtraRV` folder into `.../Ride/Binaries/Win64/ue4ss/Mods/`.
3. Ensure the mod is enabled in your `mods.txt` or through the UE4SS UI.

## Usage

### Keybinds
- **F6**: Scan actors/world (Diagnostic).
- **F7**: Spawn an RV with default settings (300cm offset, 500cm height).

### Console Commands
Open the console with `~` or `` ` `` and use the following:

- `spawnrv` - Spawns an RV at the default position.
- `spawnrv [side] [height]` - Spawns an RV with a custom horizontal offset (side) and drop height.
  - *Example*: `spawnrv 500 100` (further away, lower drop).
- `scanrv` - Scans the world for relevant vehicle class names.

## Technical Details

ExtraRV uses a deferred spawning strategy (`BeginDeferredActorSpawnFromClass`) to ensure that replication properties like `bReplicates`, `bAlwaysRelevant`, and `bReplicateMovement` are set **before** the actor is finished spawning. This is the recommended pattern for Unreal Engine multiplayer mods to ensure the replication channel opens correctly.

## Credits

Created by **Lohith**.
