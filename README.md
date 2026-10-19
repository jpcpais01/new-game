# Afterglow

**Survive the swarm. Become the light.** A neon arena survivor for Android:
drag to steer a ship of light, your weapons fire on their own, every level-up
offers three upgrade cards, and two bosses stand between you and the dawn at
8:00. Elites and bosses drop Prism Caches: max a weapon, carry its catalyst
system, and a cache evolves it into one of six evolved forms. Pick one of seven
ships in the Hangar, each with its own starting weapon, quirk and an
Overdrive you charge with kills and unleash with a tap. Missions unlock new
ships and pay Flux, and every run earns Flux for permanent upgrades in the
Forge. The Daily Run gives every pilot the same seeded run each day (fixed ship,
one boon and two bane mutators, no Forge) with a bounty and a streak, and after
the dawn you can fly on into the Afterdark, where the bosses return stronger
every night and everything counts towards your score. Built with
Godot 4.7 (GDScript, Mobile renderer).

**Download:** grab the latest `Afterglow-v*.apk` from
[Releases](../../releases/latest). Every merge to `main` builds, signs and
publishes a new release automatically.

## Layout

| Path | What lives there |
| --- | --- |
| `src/core/` | The deterministic game: `sim.gd` (all rules, struct-of-arrays entities, spatial hash, director, weapons, bosses, replays), `defs.gd` (data: enemies, weapons, ships, missions), `missions.gd` (mission progress), `daily.gd` (the day's seed, ship and mutators), `rng.gd` (xoshiro128**), `trig.gd` (table trig), `autopilot.gd` (bot for the title demo and tests). |
| `src/view/` | Drawing only: `arena.gd` (runs the sim in real time, camera, shake, slow-mo, events → effects/sound), `entities.gd`, `fx.gd` (particles, rings, beams, lightning, damage numbers), `background.gdshader` (warping grid). |
| `src/ui/` | Screens: title (live autopilot demo behind it), game (joystick, HUD, Overdrive button, level-up cards, Prism Cache reveal, pause, results), Hangar, Missions, Daily Run, Codex, Forge, settings. |
| `src/autoload/` | `Save` (local JSON) and `Sfx` (pooled sounds, layered music, haptics). |
| `assets/` | Generated sprites/icons/audio (see `tools/`) and fonts (Orbitron, Rajdhani; OFL). |
| `tests/` | `run_tests.gd` (CI logic checks + replay determinism), `tune.gd` (balance timeline), `daily_probe.gd` (bot plays Daily Runs), `shots.tscn` (screenshots). |

```sh
godot --headless --path . --import
godot --headless --path . -s tests/run_tests.gd          # logic + determinism
godot --headless --path . -s tests/tune.gd -- 3          # balance timeline, 3 bot runs
python3 tools/gen_art.py && python3 tools/gen_audio.py   # regenerate assets
```

### Determinism

A run is a pure function of `(seed, loadout, inputs)`: fixed 60 Hz ticks,
`GlowRng` only, scalar float maths with no `Vector2` and no `sin/cos/atan2`
(the `Trig` table is built from sqrt and basic arithmetic, which IEEE 754
rounds identically everywhere). Inputs are logged as run-length-encoded stick
values plus card picks; `Sim.from_replay(sim.to_replay())` rebuilds a run
bit-for-bit, which the tests check. Overdrive presses ride in the same log as a
flag bit on the stick code. The wall clock is only read in `src/main.gd`
to pick a seed.

### Signing

CI signs with the repository secrets `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD` and `ANDROID_KEY_ALIAS` when they exist, otherwise
with the committed public fallback key in `android/`.
