# Afterglow

**Survive the swarm. Become the light.** A neon arena survivor for Android:
drag to steer a ship of light, your weapons fire on their own, every level-up
offers three upgrade cards, and four bosses (the Leviathan, a serpent of light
that coils around you, then the Warden, the Seraph and the Eclipse) stand
between you and the dawn at 8:00. Kill without getting hit to
build a Chain that multiplies your score. Elites and bosses drop Prism Caches: max a weapon, carry its catalyst
system, and a cache evolves it into one of nine evolved forms. Every boss also guards a
relic: pick one of three rule-bending powers that last the whole run. Pick one of eight
ships in the Hangar, each with its own starting weapon, quirk and an
Overdrive you charge with kills and unleash with a tap. Missions unlock new
ships and pay Flux, and every run earns Flux for permanent upgrades in the
Forge. The Daily Run gives every pilot the same seeded run each day (fixed ship,
one boon and two bane mutators, no Forge) with a bounty and a streak, and after
the dawn you can fly on into the Afterdark, where the bosses return stronger
every night and everything counts towards your score. Reach the dawn and
Radiance unlocks: ten ascension levels, each adding a rule and raising the
score, and every ship remembers the highest Radiance it has cleared. Any
level-up card can be banished from the run. About once a minute a rift opens
somewhere in the arena: light a Beacon, catch a fleeing Prism Wisp, weather a
Starfall of meteors or win an Umbral Trial for an Umbral relic, power at a price. Every ship streams a
light trail that grows from an ember to a prismatic ribbon as you master it. Felled the Warden? The Gauntlet
throws all four bosses at you back to back, then again, stronger, and times every
fight: race your best splits, clear it under four minutes, see how many cycles you last.
Nine pairs of weapons resonate: hold both at level 2 and a bonus effect switches on (Pulse bolts
that leap on as lightning, glaives that refract beams, mines that sow from Scythe kills...), mapped
as a ring of weapons in the Codex. Three sectors to fly: the Neon Grid, the Abyss (black holes that drag in the swarm, your
gems and you, then burst with everything they ate) and Corona (a sun at the centre whose
flares race outwards as walls of fire with gaps to slip through).
Built with Godot 4.7 (GDScript, Mobile renderer).

**Download:** grab the latest `Afterglow-v*.apk` from
[Releases](../../releases/latest). Every merge to `main` builds, signs and
publishes a new release automatically.

## Layout

| Path | What lives there |
| --- | --- |
| `src/core/` | The deterministic game: `sim.gd` (all rules, struct-of-arrays entities, spatial hash, director, weapons, bosses, replays), `defs.gd` (data: enemies, weapons, ships, missions, the Chain), `missions.gd` (mission progress), `daily.gd` (the day's seed, ship and mutators), `rng.gd` (xoshiro128**), `trig.gd` (table trig), `autopilot.gd` (bot for the title demo and tests). Sector hazards (the Abyss's black holes, Corona's sun and flares) and weapon resonances live in `sim.gd` too. |
| `src/view/` | Drawing only: `arena.gd` (runs the sim in real time, camera, shake, slow-mo, events → effects/sound), `entities.gd`, `fx.gd` (particles, rings, beams, lightning, damage numbers), `background.gdshader` (warping grid). |
| `src/ui/` | Screens: title (live autopilot demo behind it), the Gauntlet, game (joystick, HUD, Overdrive button, level-up cards, Prism Cache reveal, pause, results), Hangar, Missions, Daily Run, Codex (with the resonance web), Forge, settings. |
| `src/autoload/` | `Save` (local JSON) and `Sfx` (pooled sounds, layered music, haptics). |
| `assets/` | Generated sprites/icons/audio (see `tools/`) and fonts (Orbitron, Rajdhani; OFL). |
| `tests/` | `run_tests.gd` (CI logic checks + replay determinism), `tune.gd` (balance timeline), `weapon_probe.gd` (damage per second of every weapon level), `hurt_probe.gd` (what damages the bot, by source), `daily_probe.gd` (bot plays Daily Runs), `levi_probe.gd` (how the bot fares against the Leviathan), `gauntlet_probe.gd` (the bot in the Gauntlet), `shots.tscn` (screenshots). |

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
