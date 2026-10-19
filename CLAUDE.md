# Working on Afterglow

Afterglow is a Godot 4.7 (GDScript only, Mobile renderer) neon arena survivor
for Android, improved in rounds. Read `README.md` first for the layout.

## Hard rules

- **Determinism.** `src/core/` is a pure function of `(seed, loadout, inputs)`.
  Use `GlowRng` only (never `randi`/`randf`/`RandomNumberGenerator`), no
  `Time`/`OS`, no nodes, no `Vector2`/`Vector2i` maths, no `sin`/`cos`/`atan2`/
  `pow`/`exp` (use `Trig`). `+ - * /`, `sqrt`, `abs`, `min`, `max` are fine.
  Views may use `randf()` and any maths for cosmetics.
- Views never change sim state except through `step`, `choose`, `reroll`.
- If a change alters existing replays, bump `Sim.RULES_VERSION`.
- **Patch notes.** Every merge to `main` adds a player-facing entry to
  `PATCH_NOTES.md` under an hour heading `## Mon DD, YYYY · HH:00 UTC`,
  newest first, at most 5 entries per group. The newest group becomes the
  release notes.
- `tests/run_tests.gd` must pass (CI blocks otherwise) and runs with `-s`, so
  it must not reference autoloads (`Save`, `Sfx`). Add checks for new rules.
- After balance changes, run `tests/tune.gd` and keep the bot alive past 6:00
  without Forge upgrades on most seeds.
- Use `set_anchors_and_offsets_preset` (not `set_anchors_preset`) for
  full-rect controls built in code, or they end up zero-sized.
- Don't name members after built-in Node properties/signals.

## Handy commands

```sh
godot --headless --path . --import
godot --headless --path . -s tests/run_tests.gd
xvfb-run -a -s "-screen 0 1280x2400x24" godot --path . --resolution 720x1280 \
  res://tests/shots.tscn -- /tmp/shots   # screenshots (apt install mesa-vulkan-drivers for real glow)
```

Assets are generated: edit `tools/gen_art.py` / `tools/gen_audio.py` and rerun
them instead of hand-editing PNG/WAV/OGG files. Keep `.import` files committed.
