# Working on Prisma

Prisma is a Godot 4.7 (GDScript only, Mobile renderer) block puzzle for
Android. It is improved in rounds; read `README.md` first for the layout.

## Hard rules

- **Determinism.** Everything in `src/core/` must stay a pure function of
  `(seed, moves)`: use `PrismRng` only (never `randi`/`randf`/`RandomNumberGenerator`),
  integer maths for anything that affects state or score, no `Time`/`OS`
  calls, no nodes. Views may use `randf()` for cosmetic effects only.
- If you change rules in a way that alters existing replays, bump
  `PrismGame.RULES_VERSION` and handle older saved runs (drop or migrate).
- **Patch notes.** Every merge to `main` adds a player-facing entry to
  `PATCH_NOTES.md` under an hour heading `## Mon DD, YYYY · HH:00 UTC`,
  newest first, at most 5 entries per group. The newest group becomes the
  release notes and the in-game "What's new".
- `tests/run_tests.gd` must pass (CI blocks otherwise). Add checks for new
  rules. `tests/run_tests.gd` runs with `-s`, so it must not reference
  autoloads (`Save`, `Sfx`); anything that needs them runs as a scene.
- Don't name members after built-in Node properties/signals (e.g. `hidden`).

## Handy commands

```sh
godot --headless --path . --import
godot --headless --path . -s tests/run_tests.gd
xvfb-run -s "-screen 0 1280x2400x24" godot --path . --rendering-driver opengl3 \
  --resolution 720x1280 res://tests/shots.tscn -- /tmp/shots   # screenshots
```

Assets are generated: edit `tools/gen_art.py` / `tools/gen_audio.py` and rerun
them instead of hand-editing PNG/WAV files. Keep `.import` files committed
(tiles/icons have mipmaps on; music has loop on).
