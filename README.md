# Prisma

**A block puzzle of light.** Drag glowing gem pieces onto an 8×8 board, fill
rows and columns to shatter them, chain clears into combos, and line up a
single colour for a PRISM. Native Android, built with Godot 4 (GDScript,
Mobile renderer).

**Download:** grab the latest `Prisma-v*.apk` from
[Releases](../../releases/latest) and open it on your phone. Every merge to
`main` builds, signs and publishes a new release automatically.

## How to play

- Drag one of the three pieces under the board onto it. Pieces can't rotate.
- Fill a whole row or column to clear it. Clearing several at once pays a lot more.
- **Combo:** clear again within 3 placements to keep your streak; each step raises the multiplier (×1, ×1.5, ×2 … up to ×10).
- **Prism line:** a cleared line made of a single colour is worth a big bonus.
- **Perfect clear:** empty the whole board for a huge bonus.
- The game ends when none of your pieces fit.
- **Daily Prism:** everyone gets the same puzzle each day (UTC).

## Development

| Path | What lives there |
| --- | --- |
| `src/core/` | Deterministic game rules: RNG, pieces, board, dealer, scoring, replays. No nodes, no clock, no rendering. |
| `src/view/` | Drawing only: board, tray, drag, effects, logo, background shader. |
| `src/ui/` | Screens and dialogs (title, game, modals, buttons). |
| `src/autoload/` | `Save` (local JSON save) and `Sfx` (audio + haptics). |
| `assets/` | Generated art/audio (see `tools/`) and the Fredoka font (OFL). |
| `tests/` | `run_tests.gd` logic checks (run in CI), `shots.tscn` screenshot helper. |
| `tools/` | `gen_art.py` and `gen_audio.py` regenerate every bitmap and sound. |

```sh
godot --headless --path . --import             # first time / after asset changes
godot --headless --path . -s tests/run_tests.gd  # deterministic logic checks
python3 tools/gen_art.py && python3 tools/gen_audio.py  # regenerate assets
```

### Determinism

`PrismGame` is a pure function of `(seed, moves)`. It uses its own
xoshiro128** RNG (`PrismRng`) with integer-only maths, never reads the clock,
and never touches nodes. A run is saved as `{seed, moves}` and resumed by
replaying it; the same data enables replays, verification and future online
play. The clock is only read in `src/main.gd` to pick a seed or today's date.

### Signing

CI signs with a private key when the repository secrets
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD` and `ANDROID_KEY_ALIAS`
exist. Otherwise it uses the committed fallback key in `android/`, which is
public, so add the secrets before distributing widely. Changing keys means
players must uninstall once before updating.

Font: [Fredoka](https://fonts.google.com/specimen/Fredoka), SIL Open Font License (`assets/fonts/OFL.txt`).
