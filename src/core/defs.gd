class_name Defs
extends RefCounted
## Static game data: enemies, weapons, passives, the director's schedule and
## the Forge (permanent upgrades). Pure data, shared by the sim and the views.

enum { DRIFTER, DART, SPLITTER, MITE, WEAVER, BRUTE, SPITTER, BOMBER, PHANTOM, SENTINEL, BASTION,
		WARDEN, ECLIPSE, SERAPH, LEVIATHAN }

## hp, speed (px/s), r (px), dmg (contact), xp, kb (knockback taken 0..1)
const ENEMY := [
	{"name": "drifter", "hp": 12.0, "speed": 92.0, "r": 20.0, "dmg": 8.0, "xp": 1, "kb": 1.0},
	{"name": "dart", "hp": 10.0, "speed": 74.0, "r": 17.0, "dmg": 10.0, "xp": 1, "kb": 1.0},
	{"name": "splitter", "hp": 32.0, "speed": 70.0, "r": 26.0, "dmg": 10.0, "xp": 2, "kb": 0.8},
	{"name": "mite", "hp": 6.0, "speed": 150.0, "r": 11.0, "dmg": 5.0, "xp": 0, "kb": 1.2},
	{"name": "weaver", "hp": 18.0, "speed": 118.0, "r": 19.0, "dmg": 9.0, "xp": 2, "kb": 1.0},
	{"name": "brute", "hp": 120.0, "speed": 54.0, "r": 38.0, "dmg": 18.0, "xp": 8, "kb": 0.25},
	{"name": "spitter", "hp": 30.0, "speed": 84.0, "r": 22.0, "dmg": 10.0, "xp": 3, "kb": 0.9},
	{"name": "bomber", "hp": 22.0, "speed": 128.0, "r": 20.0, "dmg": 8.0, "xp": 2, "kb": 1.0},
	{"name": "phantom", "hp": 16.0, "speed": 96.0, "r": 18.0, "dmg": 9.0, "xp": 2, "kb": 1.0},
	{"name": "sentinel", "hp": 46.0, "speed": 66.0, "r": 24.0, "dmg": 12.0, "xp": 4, "kb": 0.5},
	{"name": "bastion", "hp": 80.0, "speed": 62.0, "r": 30.0, "dmg": 12.0, "xp": 6, "kb": 0.35},
	{"name": "warden", "hp": 1700.0, "speed": 70.0, "r": 74.0, "dmg": 24.0, "xp": 60, "kb": 0.0},
	{"name": "eclipse", "hp": 8500.0, "speed": 48.0, "r": 92.0, "dmg": 30.0, "xp": 0, "kb": 0.0},
	{"name": "seraph", "hp": 6000.0, "speed": 60.0, "r": 82.0, "dmg": 26.0, "xp": 0, "kb": 0.0},
	{"name": "leviathan", "hp": 2400.0, "speed": 265.0, "r": 54.0, "dmg": 18.0, "xp": 0, "kb": 0.0},
]

const ENEMY_COLOR := [
	Color(1.0, 0.3, 0.65), Color(1.0, 0.84, 0.22), Color(0.35, 1.0, 0.45), Color(0.72, 1.0, 0.3),
	Color(0.6, 0.48, 1.0), Color(1.0, 0.55, 0.18), Color(0.88, 0.35, 1.0), Color(1.0, 0.24, 0.24),
	Color(0.55, 0.95, 1.0), Color(1.0, 0.42, 0.2), Color(0.35, 0.6, 1.0),
	Color(1.0, 0.8, 0.35), Color(1.0, 0.3, 0.88), Color(0.4, 1.0, 0.85), Color(0.52, 0.46, 1.0),
]

## Weapons: one spec per level (index 0 = level 1). cd in ticks (60/s).
const WEAPONS := {
	"pulse": {
		"name": "Pulse Cannon", "color": Color(0.35, 0.95, 1.0),
		"blurb": "Fires bolts at the nearest enemy.",
		"levels": [
			{"cd": 32, "dmg": 10.0, "n": 1, "pierce": 0, "text": "Fires bolts at the nearest enemy."},
			{"cd": 32, "dmg": 10.0, "n": 2, "pierce": 0, "text": "+1 bolt."},
			{"cd": 28, "dmg": 15.0, "n": 2, "pierce": 0, "text": "+50% damage, faster fire."},
			{"cd": 28, "dmg": 15.0, "n": 3, "pierce": 1, "text": "+1 bolt. Bolts pierce an enemy."},
			{"cd": 22, "dmg": 19.0, "n": 4, "pierce": 2, "text": "+1 bolt, more pierce, much faster fire."},
			{"cd": 16, "dmg": 24.0, "n": 5, "pierce": 3, "ring": 3, "evo": true,
				"text": "Five piercing star-bolts per volley, and every third volley erupts in a full ring."},
		],
	},
	"orbit": {
		"name": "Halo Blades", "color": Color(0.55, 1.0, 1.0),
		"blurb": "Blades of light circle around you.",
		"levels": [
			{"n": 2, "r": 108.0, "spin": 9, "dmg": 9.0, "text": "Two blades orbit you, cutting what they touch."},
			{"n": 3, "r": 108.0, "spin": 9, "dmg": 9.0, "text": "+1 blade."},
			{"n": 3, "r": 118.0, "spin": 11, "dmg": 15.0, "text": "+65% damage, faster spin."},
			{"n": 4, "r": 132.0, "spin": 11, "dmg": 15.0, "text": "+1 blade, wider orbit."},
			{"n": 6, "r": 140.0, "spin": 14, "dmg": 21.0, "text": "+2 blades, +40% damage."},
			{"n": 8, "r": 140.0, "r2": 270.0, "spin": 16, "dmg": 30.0, "evo": true,
				"text": "Eight void blades whose orbit breathes in and out, flinging enemies away."},
		],
	},
	"arc": {
		"name": "Arc Coil", "color": Color(0.75, 0.7, 1.0),
		"blurb": "Lightning that leaps between enemies.",
		"levels": [
			{"cd": 80, "dmg": 16.0, "chain": 3, "strikes": 1, "text": "Lightning strikes and jumps to 2 more enemies."},
			{"cd": 80, "dmg": 16.0, "chain": 5, "strikes": 1, "text": "Jumps to 2 more enemies."},
			{"cd": 70, "dmg": 25.0, "chain": 5, "strikes": 1, "text": "+55% damage, faster."},
			{"cd": 70, "dmg": 25.0, "chain": 7, "strikes": 2, "text": "Two bolts at once, longer chains."},
			{"cd": 56, "dmg": 34.0, "chain": 9, "strikes": 2, "text": "+35% damage, much faster, longer chains."},
			{"cd": 34, "dmg": 40.0, "chain": 10, "strikes": 3, "reach": 320.0, "blast": 90.0, "evo": true,
				"text": "Three storms at once. Every chain ends in a thunderclap."},
		],
	},
	"nova": {
		"name": "Nova Ring", "color": Color(1.0, 0.55, 0.9),
		"blurb": "A shockwave that blasts enemies away.",
		"levels": [
			{"cd": 170, "dmg": 14.0, "r": 230.0, "text": "Releases a shockwave that hurts and repels."},
			{"cd": 170, "dmg": 14.0, "r": 280.0, "text": "+22% radius."},
			{"cd": 150, "dmg": 24.0, "r": 280.0, "text": "+70% damage, faster."},
			{"cd": 125, "dmg": 24.0, "r": 320.0, "text": "Wider and faster."},
			{"cd": 110, "dmg": 36.0, "r": 360.0, "text": "+50% damage, wider, faster."},
			{"cd": 105, "dmg": 40.0, "r": 400.0, "well": 380.0, "well_dmg": 120.0, "evo": true,
				"text": "Each shockwave also opens a black hole that drags the swarm in, then detonates."},
		],
	},
	"seeker": {
		"name": "Seeker Swarm", "color": Color(1.0, 0.72, 0.3),
		"blurb": "Homing missiles that explode on impact.",
		"levels": [
			{"cd": 78, "dmg": 20.0, "n": 1, "blast": 70.0, "text": "Launches a homing missile that explodes."},
			{"cd": 78, "dmg": 20.0, "n": 2, "blast": 70.0, "text": "+1 missile."},
			{"cd": 70, "dmg": 30.0, "n": 2, "blast": 82.0, "text": "+50% damage, bigger blasts."},
			{"cd": 70, "dmg": 30.0, "n": 3, "blast": 96.0, "text": "+1 missile, bigger blasts."},
			{"cd": 54, "dmg": 40.0, "n": 4, "blast": 104.0, "text": "+1 missile, +33% damage, faster."},
			{"cd": 46, "dmg": 46.0, "n": 5, "blast": 120.0, "split": 3, "evo": true,
				"text": "Five missiles. Every blast spawns three more hunters."},
		],
	},
	"lance": {
		"name": "Prism Lance", "color": Color(1.0, 0.95, 0.6),
		"blurb": "A piercing beam that cuts through everything.",
		"levels": [
			{"cd": 120, "dmg": 32.0, "w": 26.0, "dirs": 1, "text": "Fires a beam that pierces every enemy in line."},
			{"cd": 120, "dmg": 46.0, "w": 30.0, "dirs": 1, "text": "+45% damage."},
			{"cd": 110, "dmg": 46.0, "w": 40.0, "dirs": 2, "text": "Fires backwards too. Wider beam."},
			{"cd": 92, "dmg": 58.0, "w": 44.0, "dirs": 2, "text": "+25% damage, faster."},
			{"cd": 84, "dmg": 72.0, "w": 52.0, "dirs": 4, "text": "Four beams in a cross. +25% damage."},
			{"cd": 64, "dmg": 80.0, "w": 58.0, "dirs": 6, "sweeps": 3, "evo": true,
				"text": "Six rainbow beams that sweep around you three times."},
		],
	},
	"scythe": {
		"name": "Ion Scythe", "color": Color(0.5, 1.0, 0.8),
		"blurb": "A crescent of light that cleaves the swarm in front of you.",
		"levels": [
			{"cd": 72, "dmg": 20.0, "r": 175.0, "half": 150, "dirs": 1,
				"text": "Sweeps a crescent blade through everything in front of you."},
			{"cd": 72, "dmg": 20.0, "r": 200.0, "half": 170, "dirs": 1, "text": "Longer, wider sweep."},
			{"cd": 64, "dmg": 32.0, "r": 200.0, "half": 170, "dirs": 1, "text": "+60% damage, faster."},
			{"cd": 64, "dmg": 32.0, "r": 215.0, "half": 170, "dirs": 2, "text": "Sweeps behind you too."},
			{"cd": 52, "dmg": 44.0, "r": 235.0, "half": 190, "dirs": 2, "text": "+35% damage, wider, faster."},
			{"cd": 50, "dmg": 44.0, "r": 280.0, "half": 512, "dirs": 1, "sweeps": 2, "leech": 0.5, "evo": true,
				"text": "Two full-circle crescents in quick succession. Every enemy they cut down heals you."},
		],
	},
	"mine": {
		"name": "Photon Mines", "color": Color(1.0, 0.45, 0.55),
		"blurb": "Drops mines that detonate when the swarm steps on them.",
		"levels": [
			{"cd": 84, "dmg": 28.0, "blast": 100.0, "max": 3, "n": 1,
				"text": "Drops a mine that detonates when an enemy comes close."},
			{"cd": 76, "dmg": 28.0, "blast": 100.0, "max": 4, "n": 1, "text": "Faster, +1 mine on the field."},
			{"cd": 76, "dmg": 50.0, "blast": 115.0, "max": 5, "n": 1, "text": "+50% damage, bigger blasts."},
			{"cd": 70, "dmg": 50.0, "blast": 115.0, "max": 7, "n": 2, "text": "Drops two mines at a time."},
			{"cd": 60, "dmg": 66.0, "blast": 130.0, "max": 8, "n": 2, "text": "+30% damage, faster, bigger blasts."},
			{"cd": 50, "dmg": 76.0, "blast": 145.0, "max": 10, "n": 2, "link": 520.0, "link_dmg": 14.0,
				"evo": true, "text": "Mines link into a constellation of burning tripwires and pull the swarm in."},
		],
	},
	"glaive": {
		"name": "Ricochet Glaive", "color": Color(0.72, 1.0, 0.4),
		"blurb": "A spinning glaive that ricochets through the swarm and flies home.",
		"levels": [
			{"cd": 60, "dmg": 10.0, "n": 1, "bounce": 2, "r": 16.0,
				"text": "Throws a glaive that ricochets between enemies, then returns to you."},
			{"cd": 60, "dmg": 10.0, "n": 1, "bounce": 4, "r": 16.0, "text": "+2 ricochets."},
			{"cd": 54, "dmg": 17.0, "n": 1, "bounce": 4, "r": 18.0, "text": "+70% damage, faster."},
			{"cd": 54, "dmg": 17.0, "n": 2, "bounce": 5, "r": 18.0, "text": "+1 glaive, +1 ricochet."},
			{"cd": 46, "dmg": 24.0, "n": 3, "bounce": 7, "r": 20.0, "text": "+1 glaive, +2 ricochets, +40% damage."},
			{"cd": 40, "dmg": 30.0, "n": 4, "bounce": 9, "r": 24.0, "grow": 0.2, "evo": true,
				"text": "Four serpent glaives that grow stronger with every ricochet, and leap back out the moment they come home."},
		],
	},
}

const WEAPON_ORDER := ["pulse", "orbit", "arc", "nova", "seeker", "lance", "scythe", "mine", "glaive"]

## Evolutions: a Lv5 weapon plus its catalyst system (any level) evolves when
## you open a Prism Cache. The evolved spec is the weapon's sixth level.
const EVOLUTIONS := {
	"pulse": {"name": "Supernova Cannon", "needs": "amplifier", "color": Color(1.0, 0.82, 0.4)},
	"orbit": {"name": "Event Horizon", "needs": "lens", "color": Color(0.78, 0.5, 1.0)},
	"arc": {"name": "Storm Crown", "needs": "overclock", "color": Color(1.0, 0.92, 0.45)},
	"nova": {"name": "Singularity", "needs": "plating", "color": Color(0.7, 0.38, 1.0)},
	"seeker": {"name": "Hydra Swarm", "needs": "fortune", "color": Color(0.45, 1.0, 0.5)},
	"lance": {"name": "Spectrum", "needs": "thrusters", "color": Color(1.0, 0.6, 0.85)},
	"scythe": {"name": "Lunar Reaper", "needs": "vitality", "color": Color(0.6, 1.0, 0.9)},
	"mine": {"name": "Constellation", "needs": "magnet", "color": Color(1.0, 0.6, 0.4)},
	"glaive": {"name": "Ouroboros", "needs": "renewal", "color": Color(0.9, 1.0, 0.3)},
}
const EVO_LEVEL := 6

const PASSIVES := {
	"vitality": {"name": "Vitality Core", "color": Color(1.0, 0.35, 0.45), "text": "+20 max HP and heal 20."},
	"thrusters": {"name": "Thrusters", "color": Color(0.4, 1.0, 0.7), "text": "+8% move speed."},
	"magnet": {"name": "Attractor", "color": Color(0.4, 0.8, 1.0), "text": "+35% pickup range."},
	"overclock": {"name": "Overclock", "color": Color(1.0, 0.85, 0.3), "text": "Weapons recharge 8% faster."},
	"amplifier": {"name": "Amplifier", "color": Color(1.0, 0.45, 0.35), "text": "+12% damage."},
	"lens": {"name": "Wide Lens", "color": Color(0.6, 0.9, 1.0), "text": "+12% weapon area."},
	"plating": {"name": "Plating", "color": Color(0.6, 0.75, 1.0), "text": "Take 2 less damage per hit."},
	"fortune": {"name": "Fortune", "color": Color(1.0, 0.85, 0.35), "text": "+7% critical chance (crits hit x2)."},
	"scholar": {"name": "Scholar", "color": Color(0.5, 1.0, 0.65), "text": "+12% experience."},
	"renewal": {"name": "Renewal", "color": Color(0.4, 1.0, 0.55), "text": "Regenerate 0.4 HP per second."},
}

const PASSIVE_ORDER := ["vitality", "thrusters", "magnet", "overclock", "amplifier", "lens", "plating",
		"fortune", "scholar", "renewal"]

const MAX_LEVEL := 5
const MAX_WEAPONS := 4
const MAX_PASSIVES := 4

## Fallback cards when everything is maxed.
const EXTRAS := {
	"heal": {"name": "Repair", "color": Color(0.4, 1.0, 0.6), "text": "Restore 40% of your HP."},
	"flux": {"name": "Flux Cache", "color": Color(1.0, 0.5, 1.0), "text": "+25 Flux for the Forge."},
}

## Relics: one of three is offered when you open the first elite's Prism Cache
## and every boss's.
## Each bends the rules for the rest of the run. Applied inside Sim.
const RELICS := {
	"halo": {"name": "Guardian Halo", "color": Color(1.0, 0.92, 0.55),
		"text": "A halo blocks one hit every 15 seconds. A blocked hit never breaks your Chain."},
	"wake": {"name": "Ion Wake", "color": Color(0.4, 0.95, 1.0),
		"text": "Your ship leaves a trail of burning light behind it."},
	"starbreaker": {"name": "Starbreaker", "color": Color(1.0, 0.5, 0.3),
		"text": "+60% damage to elites and bosses."},
	"supercrit": {"name": "Supercritical", "color": Color(1.0, 0.85, 0.35),
		"text": "+10% critical chance, and critical hits strike one time harder."},
	"overcharge": {"name": "Overcharge", "color": Color(0.35, 0.95, 1.0),
		"text": "Overdrive charges 75% faster, and every Overdrive heals 25 HP."},
	"phoenix": {"name": "Phoenix Plume", "color": Color(1.0, 0.45, 0.3),
		"text": "Rise once more when you fall, in a blast that clears the swarm."},
	"midas": {"name": "Midas Core", "color": Color(1.0, 0.78, 0.3),
		"text": "+25% experience, +1 reroll, and every Prism Cache pays triple Flux."},
	"wrath": {"name": "Wrath of Dawn", "color": Color(1.0, 0.3, 0.45),
		"text": "Below half health you deal +50% damage and fly 15% faster."},
}
const RELIC_ORDER := ["halo", "wake", "starbreaker", "supercrit", "overcharge", "phoenix", "midas", "wrath"]
## Umbral relics: power at a price. Only a won Umbral Trial offers them, and
## the offer can be refused for a Prism Cache instead.
const UMBRALS := {
	"u_sun": {"name": "Shattered Sun", "color": Color(1.0, 0.36, 0.5), "umbral": true,
		"text": "+50% damage. Your hull holds 30% less."},
	"u_hunger": {"name": "Hunger", "color": Color(0.85, 0.3, 1.0), "umbral": true,
		"text": "+40% experience. The swarm has +25% HP."},
	"u_frenzy": {"name": "Frenzy Engine", "color": Color(1.0, 0.42, 0.25), "umbral": true,
		"text": "Weapons recharge 25% faster. You take 35% more damage."},
	"u_gambit": {"name": "Gambler's Prism", "color": Color(1.0, 0.75, 0.3), "umbral": true,
		"text": "+20% critical chance and critical hits strike one time harder. Every other hit deals 30% less."},
	"u_crown": {"name": "Chain Crown", "color": Color(1.0, 0.85, 0.45), "umbral": true,
		"text": "Your Chain's score multiplier climbs twice as fast, up to x6. A hit that breaks a Chain of 25 or more costs 15 more HP."},
}
const UMBRAL_ORDER := ["u_sun", "u_hunger", "u_frenzy", "u_gambit", "u_crown"]
const UMBRAL_COLOR := Color(0.78, 0.32, 1.0)
const HALO_TICKS := 15 * 60
const WAKE_TICKS := 80


static func is_relic(id: String) -> bool:
	return RELICS.has(id) or UMBRALS.has(id)


static func is_umbral(id: String) -> bool:
	return UMBRALS.has(id)


## Rifts: every minute or so a rift opens somewhere in the arena with a
## challenge and a prize. Kinds are indices into RIFTS.
enum { RIFT_BEACON, RIFT_WISP, RIFT_TRIAL, RIFT_STARFALL }
const RIFTS := [
	{"id": "beacon", "name": "Light Beacon", "goal": "LIGHT THE BEACON", "color": Color(1.0, 0.82, 0.38),
		"text": "Hold your ground inside its ring until it blazes, while the swarm closes in. Lit, it pays a Prism Cache."},
	{"id": "wisp", "name": "Prism Wisp", "goal": "CATCH THE WISP", "color": Color(0.55, 1.0, 0.92),
		"text": "A spark of pure light that flees and scatters gems as it runs. Catch it for a full Overdrive, repairs and a shower of light."},
	{"id": "trial", "name": "Umbral Rift", "goal": "UMBRAL TRIAL", "color": Color(0.78, 0.32, 1.0),
		"text": "Touch it to open a trial: destroy the swarm it releases before time runs out to claim an Umbral relic, power at a price."},
	{"id": "starfall", "name": "Starfall", "goal": "WEATHER THE STARFALL", "color": Color(0.55, 0.78, 1.0),
		"text": "Step into its ring to call down a meteor shower. Stay inside until it passes without being struck and the last star falls as a Star Core. The meteors crush the swarm too."},
]
const RIFT_FIRST := 50         # seconds until the first rift (always a beacon)
const RIFT_GAP := 55           # seconds between one rift closing and the next opening...
const RIFT_GAP_RANGE := 30     # ...plus up to this many more
const RIFT_LIFE := [40, 30, 35, 35]  # seconds a rift waits to be taken, per kind
const TRIAL_FROM := 120        # Umbral Trials open from 2:00
const BEACON_R := 160.0
const BEACON_TICKS := 300      # ticks inside the ring to light a beacon
const WISP_R := 30.0
const WISP_SIGHT := 560.0      # the wisp bolts once you come this close
const TRIAL_R := 100.0
const TRIAL_TICKS := 15 * 60
const RIFT_SCORE := 750
const STARFALL_FROM := 90      # Starfalls open from 1:30
const STARFALL_R := 300.0
const STARFALL_TICKS := 12 * 60     # ticks inside the ring to weather the storm
const STARFALL_WINDOW := 22 * 60    # ...within this long once it starts
const METEOR_R := 95.0
const METEOR_FALL := 60             # ticks from the warning mark to impact
const METEOR_EVERY := 15


## The Forge: permanent upgrades bought with Flux between runs.
const FORGE := [
	{"id": "hull", "name": "Hull", "text": "+12 max HP", "max": 5, "cost": [30, 70, 140, 240, 380]},
	{"id": "power", "name": "Power", "text": "+6% damage", "max": 5, "cost": [40, 90, 170, 280, 440]},
	{"id": "engine", "name": "Engine", "text": "+4% move speed", "max": 5, "cost": [30, 70, 130, 220, 340]},
	{"id": "magnet", "name": "Attractor", "text": "+12% pickup range", "max": 3, "cost": [25, 60, 120]},
	{"id": "greed", "name": "Greed", "text": "+12% Flux earned", "max": 5, "cost": [50, 110, 200, 330, 500]},
	{"id": "reroll", "name": "Reroll", "text": "+1 card reroll per run", "max": 3, "cost": [60, 150, 300]},
	{"id": "revive", "name": "Second Light", "text": "Revive once per run", "max": 1, "cost": [400]},
	{"id": "banish", "name": "Banish", "text": "+1 card banish per run", "max": 2, "cost": [90, 220]},
]

## Every run can banish one level-up card (more from the Forge): it is gone
## from the pool for the rest of the run and a new card takes its place.
const BASE_BANISHES := 1

## Radiance: ten ascension levels unlocked one by one by reaching the dawn.
## Each level keeps every rule below it and raises the score and Flux paid.
const RADIANCE := [
	{"name": "Kindled", "text": "The swarm has +15% HP."},
	{"name": "Restless", "text": "The swarm gathers 15% faster."},
	{"name": "Hunted", "text": "Elites hunt you from 2:30, every 40 to 60 seconds."},
	{"name": "Sharp", "text": "Enemies hit 20% harder."},
	{"name": "Titans", "text": "Bosses have +30% HP."},
	{"name": "Scarcity", "text": "All healing is 35% weaker."},
	{"name": "Swift", "text": "The swarm moves 10% faster."},
	{"name": "Legion", "text": "Forty more enemies at once, each with +15% HP."},
	{"name": "Impatient", "text": "Bosses overload after 75 seconds instead of 120."},
	{"name": "Eventide", "text": "The night runs 10% faster: every boss arrives sooner."},
]
const MAX_RADIANCE := 10
const RADIANCE_SCORE := 0.15
const RADIANCE_FLUX := 0.1
const RADIANCE_COLOR := Color(1.0, 0.62, 0.28)


static func radiance_score(r: int) -> float:
	return 1.0 + RADIANCE_SCORE * float(r)


static func radiance_flux(r: int) -> float:
	return 1.0 + RADIANCE_FLUX * float(r)


## A colour per Radiance level: warm gold rising to white-hot violet.
static func radiance_color(r: int) -> Color:
	if r <= 0:
		return Color(0.62, 0.6, 0.8)
	var t := float(r - 1) / float(MAX_RADIANCE - 1)
	return Color(1.0, 0.82, 0.35).lerp(Color(1.0, 0.36, 0.3), minf(1.0, t * 1.6)).lerp(Color(0.9, 0.5, 1.0),
			maxf(0.0, t * 2.0 - 1.0))


static func forge_def(id: String) -> Dictionary:
	for f in FORGE:
		if f.id == id:
			return f
	return {}


static func card_info(id: String) -> Dictionary:
	if id.ends_with("_evo"):
		var base := id.trim_suffix("_evo")
		var e: Dictionary = EVOLUTIONS[base].duplicate()
		e.text = WEAPONS[base].levels[EVO_LEVEL - 1].text
		return e
	if WEAPONS.has(id):
		return WEAPONS[id]
	if PASSIVES.has(id):
		return PASSIVES[id]
	if RELICS.has(id):
		return RELICS[id]
	if UMBRALS.has(id):
		return UMBRALS[id]
	return EXTRAS.get(id, {})


static func is_weapon(id: String) -> bool:
	return WEAPONS.has(id)


## The base weapon a catalyst system evolves, or "".
static func evolves(passive: String) -> String:
	for w in EVOLUTIONS:
		if EVOLUTIONS[w].needs == passive:
			return w
	return ""


## Ships: each starts with its own weapon, tweaks the base stats, has a quirk
## and a signature Overdrive (charged by kills, fired from the HUD button).
## Stat keys are multipliers or additions on top of the base ship.
const SHIPS := [
	{"id": "lumen", "name": "Lumen", "color": Color(0.35, 0.95, 1.0), "weapon": "pulse",
		"title": "The first light", "quirk": "Balanced. +1 card reroll every run.",
		"od": "Flare", "od_text": "A blinding nova that scorches everything on screen and erases enemy fire.",
		"stats": {"reroll": 1}},
	{"id": "vesper", "name": "Vesper", "color": Color(0.45, 1.0, 0.75), "weapon": "orbit",
		"title": "The bulwark",
		"quirk": "Starts with three blades. +40 max HP, 3 armour, 6% slower. Taking a hit releases a shockwave.",
		"od": "Aegis", "od_text": "Six seconds of invulnerability inside a searing shield that burns all it touches.",
		"stats": {"hp": 40.0, "armor": 3.0, "speed": 0.94, "wlvl": 2}},
	{"id": "kestrel", "name": "Kestrel", "color": Color(1.0, 0.68, 0.3), "weapon": "seeker",
		"title": "The hunter", "quirk": "15% faster, -15 max HP. Weapons recharge 20% faster while you move.",
		"od": "Barrage", "od_text": "Unloads a storm of thirty homing missiles.",
		"stats": {"hp": -15.0, "speed": 1.15}},
	{"id": "strix", "name": "Strix", "color": Color(0.78, 0.62, 1.0), "weapon": "arc",
		"title": "The glass cannon", "quirk": "+25% damage, -25 max HP. Critical hits arc to a nearby enemy.",
		"od": "Tempest", "od_text": "Five seconds of chain lightning raining on the swarm.",
		"stats": {"hp": -25.0, "might": 0.25}},
	{"id": "halcyon", "name": "Halcyon", "color": Color(1.0, 0.5, 0.88), "weapon": "nova",
		"title": "The harvester", "quirk": "+40% pickup range, +15% experience. Light you collect heals you.",
		"od": "Black Sun", "od_text": "Opens a colossal singularity that swallows the swarm, and pulls in every gem.",
		"stats": {"magnet": 0.4, "xp": 0.15}},
	{"id": "aurora", "name": "Aurora", "color": Color(1.0, 0.92, 0.55), "weapon": "lance",
		"title": "The prism", "quirk": "+10% critical chance. Critical hits deal triple damage.",
		"od": "Prism Storm", "od_text": "Eight rainbow lances wheel around you for four seconds.",
		"stats": {"crit": 0.1}},
	{"id": "nyx", "name": "Nyx", "color": Color(1.0, 0.3, 0.5), "weapon": "pulse",
		"title": "The eclipse-born", "quirk": "The swarm has +40% HP. You gain +50% experience and +50% Flux.",
		"od": "Eclipse", "od_text": "Stops time for five seconds. Frozen enemies are harmless and take +50% damage.",
		"stats": {"xp": 0.5}},
	{"id": "echo", "name": "Echo", "color": Color(0.72, 1.0, 0.4), "weapon": "glaive",
		"title": "The resonance",
		"quirk": "-10 max HP. Your Chain fades twice as slowly, and every 25 kills in it add +4% damage, up to +40%.",
		"od": "Encore", "od_text": "Six seconds in which your Chain cannot break and every kill throws a ricochet glaive.",
		"stats": {"hp": -10.0}},
]

## Overdrive: kills charge the meter; each use makes the next one costlier.
const OD_BASE := 140.0
const OD_GROWTH := 0.3


static func ship(id: String) -> Dictionary:
	for s in SHIPS:
		if s.id == id:
			return s
	return SHIPS[0]


## Missions: long-term goals. Some unlock ships; all pay Flux once.
## kind: what is measured (see Missions.progress), goal: the target.
const MISSIONS := [
	{"id": "first_flight", "name": "First Flight", "text": "Survive 2:00 in one run.", "kind": "time", "goal": 120,
		"flux": 40},
	{"id": "warden", "name": "Wardenfall", "text": "Defeat the Warden.", "kind": "warden", "goal": 1,
		"flux": 120, "ship": "vesper"},
	{"id": "long_haul", "name": "Long Haul", "text": "Survive 5:00 in one run.", "kind": "time", "goal": 300,
		"flux": 100, "ship": "kestrel"},
	{"id": "exterminator", "name": "Exterminator", "text": "Destroy 2,000 enemies in total.", "kind": "total_kills",
		"goal": 2000, "flux": 100, "ship": "strix"},
	{"id": "alchemist", "name": "Alchemist", "text": "Evolve a weapon.", "kind": "evolutions", "goal": 1,
		"flux": 100, "ship": "aurora"},
	{"id": "ascendant", "name": "Ascendant", "text": "Reach level 30 in one run.", "kind": "level", "goal": 30,
		"flux": 150, "ship": "halcyon"},
	{"id": "dawn", "name": "Dawnbringer", "text": "Reach the dawn.", "kind": "win", "goal": 1, "flux": 300,
		"ship": "nyx"},
	{"id": "overdrive", "name": "Redline", "text": "Use Overdrive 5 times in one run.", "kind": "overdrives",
		"goal": 5, "flux": 100},
	{"id": "swarm_breaker", "name": "Swarm Breaker", "text": "Destroy 1,500 enemies in one run.", "kind": "kills",
		"goal": 1500, "flux": 120},
	{"id": "hoarder", "name": "Hoarder", "text": "Open 6 Prism Caches in one run.", "kind": "caches", "goal": 6,
		"flux": 120},
	{"id": "untouchable", "name": "Untouchable", "text": "Survive 2:30 without taking damage.",
		"kind": "untouched", "goal": 150, "flux": 150},
	{"id": "twin_evo", "name": "Twin Stars", "text": "Evolve 2 weapons in one run.", "kind": "evolutions",
		"goal": 2, "flux": 200},
	{"id": "codex", "name": "Codex", "text": "Discover 6 evolutions.", "kind": "codex", "goal": 6, "flux": 500},
	{"id": "veteran", "name": "Veteran", "text": "Destroy 25,000 enemies in total.", "kind": "total_kills",
		"goal": 25000, "flux": 400},
	{"id": "fleet", "name": "Fleet Admiral", "text": "Reach the dawn with 3 different ships.", "kind": "fleet",
		"goal": 3, "flux": 500},
	{"id": "nightfall", "name": "Nightfall", "text": "Reach the dawn flying Nyx.", "kind": "win_nyx", "goal": 1,
		"flux": 800},
	{"id": "daybreaker", "name": "Daybreaker", "text": "Fly a Daily Run.", "kind": "dailies", "goal": 1,
		"flux": 60},
	{"id": "ritual", "name": "Ritual", "text": "Fly the Daily Run 3 days in a row.", "kind": "streak", "goal": 3,
		"flux": 250},
	{"id": "luminary", "name": "Luminary", "text": "Score 100,000 in one run.", "kind": "score", "goal": 100000,
		"flux": 250},
	{"id": "afterdark", "name": "Into the Afterdark", "text": "Survive 3:00 past the dawn.", "kind": "afterdark",
		"goal": 180, "flux": 300},
	{"id": "nightmare", "name": "Nightmare", "text": "Defeat 6 bosses in one run.", "kind": "bosses", "goal": 6,
		"flux": 400},
	{"id": "seraphfall", "name": "Seraphfall", "text": "Defeat the Seraph.", "kind": "seraph", "goal": 1,
		"flux": 180},
	{"id": "unbroken", "name": "Unbroken", "text": "Build a Chain of 300 kills.", "kind": "chain", "goal": 300,
		"flux": 200, "ship": "echo"},
	{"id": "radiant", "name": "Radiant", "text": "Build a Chain of 1,000 kills.", "kind": "chain", "goal": 1000,
		"flux": 450},
	{"id": "relic_keeper", "name": "Reliquary", "text": "Hold 4 relics in one run.", "kind": "relics", "goal": 4,
		"flux": 250},
	{"id": "grand_codex", "name": "Grand Codex", "text": "Discover all 9 evolutions.", "kind": "codex", "goal": 9,
		"flux": 700},
	{"id": "riftwalker", "name": "Riftwalker", "text": "Complete 3 rifts in one run.", "kind": "rifts", "goal": 3,
		"flux": 150},
	{"id": "pathfinder", "name": "Pathfinder", "text": "Complete 40 rifts in total.", "kind": "total_rifts",
		"goal": 40, "flux": 400},
	{"id": "umbral_pact", "name": "Umbral Pact", "text": "Hold 2 Umbral relics in one run.", "kind": "umbrals",
		"goal": 2, "flux": 300},
	{"id": "stargazer", "name": "Stargazer", "text": "Weather a Starfall without being struck.", "kind": "starfalls",
		"goal": 1, "flux": 150},
	{"id": "ricochet", "name": "Ricochet", "text": "Land 40 ricochets with one throw of a glaive.",
		"kind": "ricochet", "goal": 40, "flux": 250},
	{"id": "serpentfall", "name": "Serpentfall", "text": "Defeat the Leviathan.", "kind": "leviathan", "goal": 1,
		"flux": 120},
	{"id": "charmer", "name": "Snake Charmer", "text": "Defeat the Leviathan without it ever touching you.",
		"kind": "charmer", "goal": 1, "flux": 300},
	{"id": "kindled", "name": "Kindled", "text": "Reach the dawn at Radiance 1.", "kind": "radiance", "goal": 1,
		"flux": 300},
	{"id": "zenith", "name": "Zenith", "text": "Reach the dawn at Radiance 5.", "kind": "radiance", "goal": 5,
		"flux": 700},
	{"id": "eventide", "name": "Eventide", "text": "Reach the dawn at Radiance 10.", "kind": "radiance", "goal": 10,
		"flux": 1500},
]


## Mutators: rule twists. The Daily Run rolls one boon and two banes; each bane
## adds to the score multiplier. Applied inside Sim from `loadout.mods`.
const MUTATORS := {
	"volatile": {"name": "Volatile", "boon": true, "score": 0.0, "color": Color(1.0, 0.55, 0.2),
		"text": "One in four enemies detonates when it dies, scorching its neighbours."},
	"lucky": {"name": "Lucky Star", "boon": true, "score": 0.0, "color": Color(1.0, 0.85, 0.35),
		"text": "+15% critical chance. Prism Caches pay double Flux."},
	"overcharged": {"name": "Overcharged", "boon": true, "score": 0.0, "color": Color(0.35, 0.95, 1.0),
		"text": "Overdrive charges twice as fast."},
	"gravity": {"name": "Gravity", "boon": true, "score": 0.0, "color": Color(0.45, 0.8, 1.0),
		"text": "Pickup range is tripled."},
	"gilded": {"name": "Gilded", "boon": true, "score": 0.0, "color": Color(1.0, 0.75, 0.3),
		"text": "Elites hunt you from the first minute, every 35 seconds."},
	"glass": {"name": "Glass Heart", "boon": false, "score": 0.3, "color": Color(1.0, 0.35, 0.5),
		"text": "Half max HP. You deal +40% damage."},
	"horde": {"name": "Horde", "boon": false, "score": 0.25, "color": Color(1.0, 0.3, 0.65),
		"text": "Twice the swarm. Each enemy is a third frailer."},
	"frenzy": {"name": "Frenzy", "boon": false, "score": 0.25, "color": Color(1.0, 0.3, 0.3),
		"text": "The swarm moves 20% faster."},
	"giants": {"name": "Giants", "boon": false, "score": 0.3, "color": Color(0.4, 1.0, 0.5),
		"text": "Enemies are larger with double HP, and drop double experience."},
	"bloodlight": {"name": "Bloodlight", "boon": false, "score": 0.2, "color": Color(0.9, 0.15, 0.3),
		"text": "Hearts never drop and Renewal is gone. Every kill restores 0.25 HP."},
	"dusk": {"name": "Short Night", "boon": false, "score": 0.35, "color": Color(0.75, 0.45, 1.0),
		"text": "The night runs a quarter faster: the bosses arrive at 1:30, 3:00, 4:30 and 6:00."},
}
const BOONS := ["volatile", "lucky", "overcharged", "gravity", "gilded"]
const BANES := ["glass", "horde", "frenzy", "giants", "bloodlight", "dusk"]

## Afterdark: after the dawn you may fly on. Bosses return stronger.
const NIGHT_BOSS_EVERY := 90
const NIGHT_BOSS_GROWTH := 0.75
const NIGHT_BOSSES := [WARDEN, LEVIATHAN, SERAPH, ECLIPSE]
## Each night the swarm also grows denser and tougher.
const NIGHT_SWARM := 0.22
const NIGHT_TOUGH := 0.18

## The Leviathan: a serpent of light whose body trails its head. Only the
## head can be hurt; the body burns. It escapes if it lives too long.
const LEVI_SEGS := 26
const LEVI_GAP := 38.0
const LEVI_SHED := 4           # segments it sheds at 75%, 50% and 25% HP

## Chain: kills within CHAIN_TICKS of each other build it; taking damage
## breaks it. Every CHAIN_STEP kills add CHAIN_BONUS to each kill's score.
const CHAIN_TICKS := 150
const CHAIN_STEP := 25
const CHAIN_BONUS := 0.1
const CHAIN_MAX_MULT := 4.0
## Milestones announce themselves: [kills, name].
const CHAIN_TIERS := [[50, "ON FIRE"], [100, "RAMPAGE"], [250, "UNSTOPPABLE"], [500, "LUMINOUS"],
		[1000, "SUPERNOVA"], [2000, "AFTERGLOW"]]


static func chain_mult(chain: int, crown := false) -> float:
	if crown:
		return minf(CROWN_MAX_MULT, 1.0 + 2.0 * CHAIN_BONUS * float(chain / CHAIN_STEP))
	return minf(CHAIN_MAX_MULT, 1.0 + CHAIN_BONUS * float(chain / CHAIN_STEP))


## Chain Crown (an Umbral relic) raises the multiplier's ceiling.
const CROWN_MAX_MULT := 6.0


## The mission that unlocks a ship, or {} for ships you start with.
static func ship_mission(ship_id: String) -> Dictionary:
	for m in MISSIONS:
		if m.get("ship", "") == ship_id:
			return m
	return {}
