# Immersive Field Moves

A `content` gen1recomp mod.

## Layout

- `manifest.json` - identity, version range, load order
- `main.lua` - the entry chunk; receives the `mod` object

## Loop

1. `POKEPORT_DEV=1 love .` once, leave it running
2. edit, press F5 to hot-reload, backtick for the dev console
3. `python3 tools/modkit.py validate testmod` before sharing
4. `python3 tools/modkit.py pack mods/testmod` to ship
