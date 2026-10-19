class_name Defs
extends RefCounted
## Static game data: enemies, weapons, passives, the director's schedule and
## the Forge (permanent upgrades). Pure data, shared by the sim and the views.

enum { DRIFTER, DART, SPLITTER, MITE, WEAVER, BRUTE, SPITTER, BOMBER, WARDEN, ECLIPSE }

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
	{"name": "warden", "hp": 1700.0, "speed": 70.0, "r": 74.0, "dmg": 24.0, "xp": 60, "kb": 0.0},
	{"name": "eclipse", "hp": 8500.0, "speed": 48.0, "r": 92.0, "dmg": 30.0, "xp": 0, "kb": 0.0},
]

const ENEMY_COLOR := [
	Color(1.0, 0.3, 0.65), Color(1.0, 0.84, 0.22), Color(0.35, 1.0, 0.45), Color(0.72, 1.0, 0.3),
	Color(0.6, 0.48, 1.0), Color(1.0, 0.55, 0.18), Color(0.88, 0.35, 1.0), Color(1.0, 0.24, 0.24),
	Color(1.0, 0.8, 0.35), Color(1.0, 0.3, 0.88),
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
}

const WEAPON_ORDER := ["pulse", "orbit", "arc", "nova", "seeker", "lance"]

## Evolutions: a Lv5 weapon plus its catalyst system (any level) evolves when
## you open a Prism Cache. The evolved spec is the weapon's sixth level.
const EVOLUTIONS := {
	"pulse": {"name": "Supernova Cannon", "needs": "amplifier", "color": Color(1.0, 0.82, 0.4)},
	"orbit": {"name": "Event Horizon", "needs": "lens", "color": Color(0.78, 0.5, 1.0)},
	"arc": {"name": "Storm Crown", "needs": "overclock", "color": Color(1.0, 0.92, 0.45)},
	"nova": {"name": "Singularity", "needs": "plating", "color": Color(0.7, 0.38, 1.0)},
	"seeker": {"name": "Hydra Swarm", "needs": "fortune", "color": Color(0.45, 1.0, 0.5)},
	"lance": {"name": "Spectrum", "needs": "thrusters", "color": Color(1.0, 0.6, 0.85)},
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

## The Forge: permanent upgrades bought with Flux between runs.
const FORGE := [
	{"id": "hull", "name": "Hull", "text": "+12 max HP", "max": 5, "cost": [30, 70, 140, 240, 380]},
	{"id": "power", "name": "Power", "text": "+6% damage", "max": 5, "cost": [40, 90, 170, 280, 440]},
	{"id": "engine", "name": "Engine", "text": "+4% move speed", "max": 5, "cost": [30, 70, 130, 220, 340]},
	{"id": "magnet", "name": "Attractor", "text": "+12% pickup range", "max": 3, "cost": [25, 60, 120]},
	{"id": "greed", "name": "Greed", "text": "+12% Flux earned", "max": 5, "cost": [50, 110, 200, 330, 500]},
	{"id": "reroll", "name": "Reroll", "text": "+1 card reroll per run", "max": 3, "cost": [60, 150, 300]},
	{"id": "revive", "name": "Second Light", "text": "Revive once per run", "max": 1, "cost": [400]},
]


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
	{"id": "codex", "name": "Codex", "text": "Discover all 6 evolutions.", "kind": "codex", "goal": 6, "flux": 500},
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
	{"id": "nightmare", "name": "Nightmare", "text": "Defeat 4 bosses in one run.", "kind": "bosses", "goal": 4,
		"flux": 400},
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
		"text": "The night runs a quarter faster: the bosses arrive at 3:00 and 6:00."},
}
const BOONS := ["volatile", "lucky", "overcharged", "gravity", "gilded"]
const BANES := ["glass", "horde", "frenzy", "giants", "bloodlight", "dusk"]

## Afterdark: after the dawn you may fly on. Bosses return stronger.
const NIGHT_BOSS_EVERY := 90
const NIGHT_BOSS_GROWTH := 0.75


## The mission that unlocks a ship, or {} for ships you start with.
static func ship_mission(ship_id: String) -> Dictionary:
	for m in MISSIONS:
		if m.get("ship", "") == ship_id:
			return m
	return {}
