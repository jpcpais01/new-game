class_name Sim
extends RefCounted
## The whole game as a pure function of (seed, loadout, inputs).
##
## Fixed 60 Hz ticks. No nodes, no clock, no engine randomness, no Vector2
## maths and no sin/cos/atan2 (see Trig), so a run replays bit-for-bit on any
## device. Entities live in parallel packed arrays (struct of arrays) for
## speed. Views read the arrays and drain `events` after every call.

const RULES_VERSION := 6
const TPS := 60
const DT := 1.0 / 60.0
const ARENA_R := 1500.0
const PLAYER_R := 22.0
const MAX_E := 300
const MAX_B := 400
const MAX_Q := 320
const MAX_G := 360
const BOSS_R := 50.0
const OVERLOAD_TICKS := 120 * 60
const WELL_TICKS := 80
const CELL := 100.0
const GRID_N := 32
const GRID_HALF := 1600.0
const SENTINEL_LEN := 950.0
const SENTINEL_W := 12.0
const SERAPH_ARM := 780.0
const SERAPH_LANCE := 1300.0
const BASTION_R := 230.0
const MINE_ARM := 24
const MINE_LIFE := 720
const MINE_TRIGGER := 64.0
const MINE_PULL := 190.0
const WAKE_R := 34.0

enum { RUNNING, CHOOSING, DEAD, WON }

# Events: [code, ...payload]. Views drain `events` after each call.
const EV_HIT := 1         # x, y, dmg, crit, type
const EV_KILL := 2        # x, y, type, elite, r
const EV_GEM := 3         # x, y, value
const EV_HURT := 4        # dmg
const EV_LEVEL := 5       # level
const EV_SHOT := 6        # weapon id, x, y, angle
const EV_NOVA := 7        # x, y, r
const EV_ARC := 8         # PackedVector2Array of points
const EV_LANCE := 9       # x1, y1, x2, y2, width
const EV_BLAST := 10      # x, y, r, hostile
const EV_BOSS := 11       # type
const EV_BOSS_DOWN := 12  # type, x, y
const EV_PICKUP := 13     # kind, x, y
const EV_REVIVE := 14
const EV_WAVE := 15       # text
const EV_ORB := 16        # x, y
const EV_WIN := 17
const EV_DEAD := 18
const EV_ELITE := 19      # type
const EV_TELEGRAPH := 20  # x, y, angle, length (dash warning)
const EV_PICK := 21       # card id, new level
const EV_CHEST := 22      # rewards [[card id, new level], ...], big, x, y
const EV_EVOLVE := 23     # weapon id
const EV_WELL := 24       # x, y, r (a singularity opens)
const EV_IMPLODE := 25    # x, y, r (a singularity detonates)
const EV_OVERDRIVE := 26  # ship id, x, y
const EV_OD_READY := 27
const EV_AEGIS := 28      # x, y, r (shield pulse)
const EV_NIGHT := 29      # night number (a run pushes on into the Afterdark)
const EV_LASER := 30      # x, y, angle, length, half width, phase (0 charging, 1 firing), type
const EV_BLINK := 31      # x0, y0, x1, y1, type, phase (0 marked, 1 arrived)
const EV_CHAIN := 32      # chain, tier name (a Chain milestone)
const EV_CHAIN_LOST := 33 # chain, broken by a hit
const EV_SLASH := 34      # x, y, angle, radius, half arc, evolved, sweep
const EV_MINE := 35       # x, y (mines dropped)
const EV_RELIC := 36      # relic id (taken)
const EV_HALO := 37       # x, y (the Guardian Halo blocks a hit)
const EV_RELIC_OFFER := 38

const BURST_BIT := 1 << 16  # set in a logged move code when Overdrive was pressed

## Director schedule: [second, kind, type, count]
const SCHEDULE := [
	[70, "ring", Defs.DRIFTER, 14],
	[120, "elite", Defs.BRUTE, 1],
	[150, "ring", Defs.PHANTOM, 8],
	[175, "squad", Defs.DART, 10],
	[205, "grid", Defs.SENTINEL, 5],
	[240, "boss", Defs.WARDEN, 1],
	[315, "ring", Defs.WEAVER, 18],
	[360, "boss", Defs.SERAPH, 1],
	[420, "surge", 0, 0],
	[425, "ring", Defs.BOMBER, 12],
	[480, "boss", Defs.ECLIPSE, 1],
]

var seed_value := 0
var loadout := {}
var rng: GlowRng
var tick := 0
var state := RUNNING
var events: Array = []

# --- player -------------------------------------------------------------------
var px := 0.0
var py := 0.0
var ppx := 0.0
var ppy := 0.0
var mvx := 0.0
var mvy := 0.0
var facing := 768
var hp := 100.0
var max_hp := 100.0
var iframes := 0
var level := 1
var xp := 0.0
var xp_need := 10.0
var kills := 0
var bosses_killed := 0
var flux_bonus := 0
var revives := 0
var rerolls := 0
var pending_levels := 0
var damage_dealt := 0.0
var choices: Array = []
var weapons: Array = []      # [{id, lvl, t}]
var passives := {}           # id -> level
var passive_order: Array = []

var st_speed := 300.0
var st_magnet := 125.0
var st_might := 1.0
var st_haste := 1.0
var st_area := 1.0
var st_crit := 0.05
var st_xp := 1.0
var st_armor := 0.0
var st_regen := 0.0

var orbit_ang := 0
var novas: Array = []        # {x, y, r, max, step, dmg, hit: {uid: true}}
var wells: Array = []        # {x, y, r, t, dmg} singularities
var pickups: Array = []      # {k, x, y, mag, spd}
var evolutions := 0
var mines: Array = []        # {x, y, t (arming), life, dmg, blast} Photon Mines

# --- ship and Overdrive ------------------------------------------------------------
var ship_id := "lumen"
var ship_stats := {}
var od := 0.0                # charge, full at od_need
var od_need := Defs.OD_BASE
var od_uses := 0
var od_t := 0                # ticks left of an active Overdrive
var od_k := 0                # pulses fired by the active Overdrive
var shield := 0              # Aegis: ticks of invulnerability
var freeze := 0              # Eclipse: ticks of stopped time
var curse := 1.0             # enemy HP multiplier (Nyx)
var caches_opened := 0
var warden_down := false
var first_hurt := -1         # tick of the first damage taken, -1 if none
var elite_kills := 0

# --- mutators and the Afterdark --------------------------------------------------
var mods := {}               # mutator id -> true (from loadout.mods)
var sched_scale := 1.0       # Short Night runs the schedule faster
var dawn := false            # the Eclipse fell: the run counts as a win
var dawn_tick := -1
var endless := false         # flying on into the Afterdark
var night := 0               # Afterdark bosses summoned so far
var night_next := 0          # tick of the next Afterdark boss
var boss_mult := 1.0         # HP multiplier for bosses (grows each night)
var _arc_cd := 0
var _in_arc := false

# --- the Chain ---------------------------------------------------------------------
var chain := 0               # kills in a row (taking damage breaks it)
var chain_t := 0             # ticks before the Chain fades
var chain_best := 0
var chain_score := 0         # score earned on top by the Chain multiplier
var seraph_down := false
var _shielded := false       # any enemy currently under a Bastion's aegis

# --- relics ---------------------------------------------------------------------------
var relics: Array = []       # relic ids in the order taken
var pending_relics := 0
var relic_choice := false    # the open choice offers relics, not level-up cards
var halo_t := 0              # ticks until the Guardian Halo is back
var trail: Array = []        # Ion Wake: [x, y, ticks left]
var r_halo := false
var r_wake := false
var r_star := false
var r_supercrit := false
var r_over := false
var r_midas := false
var r_wrath := false

# --- director -------------------------------------------------------------------
var spawn_acc := 0.0
var sched_i := 0
var surge_until := 0
var elite_next := 200 * TPS
var uid_next := 1

# --- enemies (struct of arrays) -----------------------------------------------
var en := 0
var e_type := PackedInt32Array()
var e_x := PackedFloat64Array()
var e_y := PackedFloat64Array()
var e_ox := PackedFloat64Array()
var e_oy := PackedFloat64Array()
var e_vx := PackedFloat64Array()
var e_vy := PackedFloat64Array()
var e_hp := PackedFloat64Array()
var e_maxhp := PackedFloat64Array()
var e_r := PackedFloat64Array()
var e_speed := PackedFloat64Array()
var e_dmg := PackedFloat64Array()
var e_kb := PackedFloat64Array()
var e_t := PackedInt32Array()
var e_state := PackedInt32Array()
var e_k := PackedInt32Array()
var e_ang := PackedInt32Array()
var e_flash := PackedInt32Array()
var e_spawn := PackedInt32Array()
var e_hitcd := PackedInt32Array()
var e_elite := PackedInt32Array()
var e_uid := PackedInt32Array()
var e_ax := PackedFloat64Array()   # a point an enemy is heading for (blinks)
var e_ay := PackedFloat64Array()
var e_shd := PackedInt32Array()    # 1 while inside a Bastion's aegis

# --- player projectiles ---------------------------------------------------------
var bn := 0
var b_x := PackedFloat64Array()
var b_y := PackedFloat64Array()
var b_ox := PackedFloat64Array()
var b_oy := PackedFloat64Array()
var b_vx := PackedFloat64Array()
var b_vy := PackedFloat64Array()
var b_dmg := PackedFloat64Array()
var b_r := PackedFloat64Array()
var b_tx := PackedFloat64Array()
var b_ty := PackedFloat64Array()
var b_blast := PackedFloat64Array()
var b_life := PackedInt32Array()
var b_pierce := PackedInt32Array()
var b_kind := PackedInt32Array()   # 0 bolt, 1 missile
var b_last := PackedInt32Array()

# --- enemy projectiles ------------------------------------------------------------
var qn := 0
var q_x := PackedFloat64Array()
var q_y := PackedFloat64Array()
var q_ox := PackedFloat64Array()
var q_oy := PackedFloat64Array()
var q_vx := PackedFloat64Array()
var q_vy := PackedFloat64Array()
var q_dmg := PackedFloat64Array()
var q_life := PackedInt32Array()

# --- xp gems ------------------------------------------------------------------------
var gn := 0
var g_x := PackedFloat64Array()
var g_y := PackedFloat64Array()
var g_ox := PackedFloat64Array()
var g_oy := PackedFloat64Array()
var g_val := PackedFloat64Array()
var g_spd := PackedFloat64Array()
var g_mag := PackedInt32Array()

# --- spatial hash -----------------------------------------------------------------
var _head := PackedInt32Array()
var _next := PackedInt32Array()
var _bigs := PackedInt32Array()
var _qbuf := PackedInt32Array()
var _qn := 0
var _blasts: Array = []

# --- replay log ---------------------------------------------------------------------
var log_moves := PackedInt32Array()    # RLE pairs: code, count
var log_actions := PackedInt32Array()  # pairs: tick, action (0..2 pick, 9 reroll)


func _init(seed_in: int = 1, loadout_in: Dictionary = {}) -> void:
	seed_value = seed_in & GlowRng.MASK
	loadout = loadout_in.duplicate()
	rng = GlowRng.new(seed_value)
	_alloc()
	var sd := Defs.ship(String(loadout.get("ship", "lumen")))
	ship_id = sd.id
	ship_stats = sd.stats
	if ship_id == "nyx":
		curse = 1.4
	for id in loadout.get("mods", []):
		if Defs.MUTATORS.has(id):
			mods[id] = true
	if mods.has("dusk"):
		sched_scale = 0.75
	if mods.has("gilded"):
		elite_next = 60 * TPS
	revives = int(loadout.get("revive", 0))
	rerolls = int(loadout.get("reroll", 0)) + int(ship_stats.get("reroll", 0))
	weapons.append({"id": sd.weapon, "lvl": int(ship_stats.get("wlvl", 1)), "t": 20, "k": 0, "a": 0})
	_recompute()
	hp = max_hp
	xp_need = need_for(level)


func _alloc() -> void:
	e_type.resize(MAX_E); e_x.resize(MAX_E); e_y.resize(MAX_E); e_ox.resize(MAX_E); e_oy.resize(MAX_E)
	e_vx.resize(MAX_E); e_vy.resize(MAX_E); e_hp.resize(MAX_E); e_maxhp.resize(MAX_E); e_r.resize(MAX_E)
	e_speed.resize(MAX_E); e_dmg.resize(MAX_E); e_kb.resize(MAX_E); e_t.resize(MAX_E); e_state.resize(MAX_E)
	e_k.resize(MAX_E); e_ang.resize(MAX_E); e_flash.resize(MAX_E); e_spawn.resize(MAX_E); e_hitcd.resize(MAX_E)
	e_elite.resize(MAX_E); e_uid.resize(MAX_E); e_ax.resize(MAX_E); e_ay.resize(MAX_E); e_shd.resize(MAX_E)
	b_x.resize(MAX_B); b_y.resize(MAX_B); b_ox.resize(MAX_B); b_oy.resize(MAX_B); b_vx.resize(MAX_B)
	b_vy.resize(MAX_B); b_dmg.resize(MAX_B); b_r.resize(MAX_B); b_tx.resize(MAX_B); b_ty.resize(MAX_B)
	b_blast.resize(MAX_B); b_life.resize(MAX_B); b_pierce.resize(MAX_B); b_kind.resize(MAX_B); b_last.resize(MAX_B)
	q_x.resize(MAX_Q); q_y.resize(MAX_Q); q_ox.resize(MAX_Q); q_oy.resize(MAX_Q); q_vx.resize(MAX_Q)
	q_vy.resize(MAX_Q); q_dmg.resize(MAX_Q); q_life.resize(MAX_Q)
	g_x.resize(MAX_G); g_y.resize(MAX_G); g_ox.resize(MAX_G); g_oy.resize(MAX_G); g_val.resize(MAX_G)
	g_spd.resize(MAX_G); g_mag.resize(MAX_G)
	_head.resize(GRID_N * GRID_N)
	_next.resize(MAX_E)
	_qbuf.resize(MAX_E)


static func need_for(lvl: int) -> float:
	return float(5 + 6 * lvl + (lvl * lvl) / 4)


func seconds() -> float:
	return float(tick) / float(TPS)


# =============================================================================
# Public API
# =============================================================================

## Advance one tick with a move input in [-100, 100] per axis. `burst` fires
## the Overdrive if it is charged.
func step(ix: int, iy: int, burst := false) -> void:
	if state != RUNNING:
		return
	ix = clampi(ix, -100, 100)
	iy = clampi(iy, -100, 100)
	_log_move(ix, iy, burst)
	events.clear()
	tick += 1
	_snapshot()
	_move_player(ix, iy)
	_director()
	_update_enemies()
	_grid_build()
	_separate()
	_aegis_aura()
	_update_chain()
	_update_wake_trail()
	if burst and od_ready():
		_overdrive()
	_update_overdrive()
	_weapons()
	_update_novas()
	_update_wells()
	_update_mines()
	_update_bullets()
	_update_orbs()
	_contact()
	_reap()
	_update_gems()
	_update_pickups()
	if state == RUNNING:
		if pending_relics > 0:
			_start_relic()
		elif pending_levels > 0:
			_start_choice()


## Pick card k (0..2) while choosing.
func choose(k: int) -> void:
	if state != CHOOSING or k < 0 or k >= choices.size():
		return
	events.clear()
	log_actions.append(tick)
	log_actions.append(k)
	var id: String = choices[k]
	if relic_choice:
		_take_relic(id)
		pending_relics -= 1
	else:
		_apply_card(id)
		pending_levels -= 1
	if pending_relics > 0:
		choices = _roll_relics()
		events.append([EV_RELIC_OFFER])
	elif pending_levels > 0:
		relic_choice = false
		choices = _roll_choices()
		events.append([EV_LEVEL, level])
	else:
		relic_choice = false
		choices = []
		state = RUNNING


## After the dawn: keep flying into the Afterdark. The run stays a win; the
## swarm keeps growing and the bosses return, stronger every night.
func continue_night() -> void:
	if state != WON or endless:
		return
	events.clear()
	log_actions.append(tick)
	log_actions.append(8)
	endless = true
	state = RUNNING
	night_next = tick + 20 * TPS
	events.append([EV_WAVE, "AFTERDARK"])


func reroll() -> void:
	if state != CHOOSING or rerolls <= 0:
		return
	events.clear()
	log_actions.append(tick)
	log_actions.append(9)
	rerolls -= 1
	choices = _roll_relics() if relic_choice else _roll_choices()


func weapon_level(id: String) -> int:
	for w in weapons:
		if w.id == id:
			return w.lvl
	return 0


## True once a weapon has evolved.
func is_evolved(id: String) -> bool:
	return weapon_level(id) >= Defs.EVO_LEVEL


## Icon/name id for a slot: evolved weapons show as "<id>_evo".
func display_id(id: String) -> String:
	return id + "_evo" if is_evolved(id) else id


## A Lv5 weapon whose catalyst is owned: the next Prism Cache evolves it.
func evolution_ready(id: String) -> bool:
	if not Defs.EVOLUTIONS.has(id) or weapon_level(id) != Defs.MAX_LEVEL:
		return false
	return passives.has(Defs.EVOLUTIONS[id].needs)


## True when the Overdrive meter is full and nothing is already running.
func od_ready() -> bool:
	return od >= od_need and od_t <= 0


## Meter fill 0..1 (1 while an Overdrive is running, draining with it).
func od_frac() -> float:
	if od_t > 0:
		return 1.0
	return clampf(od / od_need, 0.0, 1.0)


func card_level(id: String) -> int:
	if Defs.is_weapon(id):
		return weapon_level(id)
	return int(passives.get(id, 0))


func has_relic(id: String) -> bool:
	return relics.has(id)


## Guardian Halo charge 0..1 (1 = ready to block), or -1 without the relic.
func halo_frac() -> float:
	if not r_halo:
		return -1.0
	return 1.0 - float(halo_t) / float(Defs.HALO_TICKS)


## Index of the living boss, or -1.
func boss_index() -> int:
	for i in en:
		if e_type[i] >= Defs.WARDEN:
			return i
	return -1


func flux_earned() -> int:
	var base := kills / 6 + tick / (TPS * 3) + (level - 1) * 4 + bosses_killed * 80 + flux_bonus
	if dawn:
		base += 300
	var mult := 1.0 + 0.12 * float(loadout.get("greed", 0))
	if ship_id == "nyx":
		mult *= 1.5
	return int(float(base) * mult)


## The run's score: what the Daily Run ranks by. Banes multiply it.
func score() -> int:
	var base := kills * 10 + elite_kills * 250 + bosses_killed * 2500 + (tick / TPS) * 10 + level * 50 + chain_score
	if dawn:
		base += 10000
	return int(float(base) * score_mult())


func score_mult() -> float:
	return Daily.multiplier(mods.keys())


## Seconds survived past the dawn (0 before it).
func afterdark_seconds() -> int:
	return 0 if dawn_tick < 0 else (tick - dawn_tick) / TPS


func checksum() -> int:
	var h := GlowRng.mix32(tick ^ (kills << 12) ^ (level << 24))
	h = GlowRng.mix32(h ^ (int(px * 1000.0) & GlowRng.MASK))
	h = GlowRng.mix32(h ^ (int(py * 1000.0) & GlowRng.MASK))
	h = GlowRng.mix32(h ^ (int(hp * 1000.0) & GlowRng.MASK))
	h = GlowRng.mix32(h ^ (int(xp * 1000.0) & GlowRng.MASK))
	for i in en:
		h = GlowRng.mix32(h ^ (int(e_x[i] * 100.0) & GlowRng.MASK) ^ ((int(e_hp[i] * 100.0) & 0xFFFF) << 8))
	for i in gn:
		h = GlowRng.mix32(h ^ (int(g_y[i] * 100.0) & GlowRng.MASK))
	h = GlowRng.mix32(h ^ int(rng.state()[0]))
	return h


func to_replay() -> Dictionary:
	return {
		"v": RULES_VERSION, "seed": seed_value, "loadout": loadout.duplicate(),
		"moves": Array(log_moves), "actions": Array(log_actions),
	}


## Rebuild a run from a replay dict. Stops at `upto_tick` if >= 0.
static func from_replay(data: Dictionary, upto_tick: int = -1) -> Sim:
	var s := Sim.new(int(data.get("seed", 1)), data.get("loadout", {}))
	var moves: Array = data.get("moves", [])
	var actions: Array = data.get("actions", [])
	var ai := 0
	var mi := 0
	var left := 0
	var code := 0
	while true:
		if upto_tick >= 0 and s.tick >= upto_tick and s.state == RUNNING:
			break
		if s.state == CHOOSING:
			if ai + 1 >= actions.size():
				break
			var act := int(actions[ai + 1])
			ai += 2
			if act == 9:
				s.reroll()
			else:
				s.choose(act)
			continue
		if s.state == WON:
			if ai + 1 < actions.size() and int(actions[ai + 1]) == 8:
				ai += 2
				s.continue_night()
				continue
			break
		if s.state != RUNNING:
			break
		if left <= 0:
			if mi + 1 >= moves.size():
				break
			code = int(moves[mi])
			left = int(moves[mi + 1])
			mi += 2
		left -= 1
		s.step(((code >> 8) & 0xFF) - 128, (code & 0xFF) - 128, (code & BURST_BIT) != 0)
	return s


# =============================================================================
# Tick internals
# =============================================================================

func _log_move(ix: int, iy: int, burst: bool) -> void:
	var code := ((ix + 128) << 8) | (iy + 128)
	if burst:
		code |= BURST_BIT
	var n := log_moves.size()
	if n >= 2 and log_moves[n - 2] == code:
		log_moves[n - 1] += 1
	else:
		log_moves.append(code)
		log_moves.append(1)


func _snapshot() -> void:
	ppx = px
	ppy = py
	for i in en:
		e_ox[i] = e_x[i]
		e_oy[i] = e_y[i]
	for i in bn:
		b_ox[i] = b_x[i]
		b_oy[i] = b_y[i]
	for i in qn:
		q_ox[i] = q_x[i]
		q_oy[i] = q_y[i]
	for i in gn:
		g_ox[i] = g_x[i]
		g_oy[i] = g_y[i]


func _move_player(ix: int, iy: int) -> void:
	var mx := float(ix) / 100.0
	var my := float(iy) / 100.0
	var l := sqrt(mx * mx + my * my)
	if l > 1.0:
		mx /= l
		my /= l
		l = 1.0
	mvx = mx
	mvy = my
	var spd := st_speed
	if r_wrath and hp < max_hp * 0.5:
		spd *= 1.15
	px += mx * spd * DT
	py += my * spd * DT
	var d := sqrt(px * px + py * py)
	var lim := ARENA_R - PLAYER_R
	if d > lim:
		px = px / d * lim
		py = py / d * lim
	if l > 0.2:
		facing = Trig.angle_of(mx, my)
	if st_regen > 0.0 and hp < max_hp:
		hp = minf(max_hp, hp + st_regen * DT)
	if iframes > 0:
		iframes -= 1


# --- director --------------------------------------------------------------------

func _director() -> void:
	var t := seconds()
	var tm := t / 60.0
	while sched_i < SCHEDULE.size() and tick >= int(float(SCHEDULE[sched_i][0]) * sched_scale) * TPS:
		_scheduled(SCHEDULE[sched_i])
		sched_i += 1
	if endless and tick >= night_next and boss_index() < 0:
		_night_boss()
	var rate := 1.7 + 1.3 * tm + 0.16 * tm * tm
	if mods.has("horde"):
		rate *= 2.0
	if boss_index() >= 0:
		rate *= 0.55
	if tick < surge_until:
		rate *= 1.8
	if endless:
		rate *= 1.0 + Defs.NIGHT_SWARM * float(night)
	if tick >= elite_next:
		elite_next = tick + ((35 + rng.range_i(15)) if mods.has("gilded") else (55 + rng.range_i(25))) * TPS
		if boss_index() < 0:
			var kinds := [Defs.DRIFTER, Defs.DART, Defs.WEAVER, Defs.SPLITTER, Defs.SPITTER, Defs.BRUTE,
					Defs.SENTINEL, Defs.BASTION]
			var type: int = kinds[rng.range_i(mini(kinds.size(), 2 + int(tm)))]
			var a := rng.range_i(Trig.STEPS)
			_spawn_at_safe(type, px + Trig.cos_i(a) * 700.0, py + Trig.sin_i(a) * 700.0, true, 70)
			events.append([EV_ELITE, type])
	var cap := mini(MAX_E - 40, 90 + int(tm * 36.0) + (60 if mods.has("horde") else 0) + 25 * night)
	if en < cap:
		spawn_acc += rate * DT
	while spawn_acc >= 1.0:
		spawn_acc -= 1.0
		_spawn_random(tm)


## The Afterdark: every night a boss returns, alternating Warden and Eclipse,
## each one tougher than the last.
func _night_boss() -> void:
	night += 1
	night_next = tick + Defs.NIGHT_BOSS_EVERY * TPS
	boss_mult = 1.0 + Defs.NIGHT_BOSS_GROWTH * float(night)
	var type: int = Defs.NIGHT_BOSSES[(night - 1) % Defs.NIGHT_BOSSES.size()]
	var a := rng.range_i(Trig.STEPS)
	_spawn_at_safe(type, px + Trig.cos_i(a) * 620.0, py + Trig.sin_i(a) * 620.0, false, 150)
	events.append([EV_NIGHT, night])
	events.append([EV_BOSS, type])
	# The swarm surges with them.
	surge_until = tick + 20 * TPS


func _spawn_random(tm: float) -> void:
	var w := [10.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	if tm >= 0.6:
		w[Defs.DART] = 3.5 + tm * 0.4
	if tm >= 1.4:
		w[Defs.WEAVER] = 4.0
	if tm >= 2.1:
		w[Defs.SPLITTER] = 2.6
	if tm >= 3.0:
		w[Defs.SPITTER] = 2.0
	if tm >= 3.5:
		w[Defs.BOMBER] = 2.4
	if tm >= 4.5:
		w[Defs.BRUTE] = 1.2 + (tm - 4.5) * 0.5
	if tm >= 2.6:
		w[Defs.PHANTOM] = 2.0
	if tm >= 3.4:
		w[Defs.SENTINEL] = 0.6 + minf(0.6, (tm - 3.4) * 0.2)
	if tm >= 4.2:
		w[Defs.BASTION] = 0.8 + minf(0.6, (tm - 4.2) * 0.2)
	var total := 0.0
	for v in w:
		total += v
	var r := rng.unit() * total
	var type := 0
	for k in w.size():
		r -= w[k]
		if r < 0.0:
			type = k
			break
	var a := rng.range_i(Trig.STEPS)
	var dist := rng.range_f(820.0, 1100.0)
	_spawn_at_safe(type, px + Trig.cos_i(a) * dist, py + Trig.sin_i(a) * dist, false, 36)


func _scheduled(ev: Array) -> void:
	var kind: String = ev[1]
	var type: int = ev[2]
	var count: int = ev[3]
	match kind:
		"ring":
			var base := rng.range_i(Trig.STEPS)
			for k in count:
				var a := base + k * Trig.STEPS / count
				_spawn_at_safe(type, px + Trig.cos_i(a) * 560.0, py + Trig.sin_i(a) * 560.0, false, 60)
			events.append([EV_WAVE, "SURROUNDED"])
		"squad":
			var a := rng.range_i(Trig.STEPS)
			var cx := px + Trig.cos_i(a) * 900.0
			var cy := py + Trig.sin_i(a) * 900.0
			var perp := a + Trig.QUARTER
			for k in count:
				var off := (float(k) - float(count - 1) * 0.5) * 52.0
				_spawn_at_safe(type, cx + Trig.cos_i(perp) * off, cy + Trig.sin_i(perp) * off, false, 40)
			events.append([EV_WAVE, "DART SQUADRON"])
		"grid":
			# Sentinels in a ring around you, firing one after another like a clock.
			var base := rng.range_i(Trig.STEPS)
			for k in count:
				var a := base + k * Trig.STEPS / count
				var e := _spawn_at_safe(type, px + Trig.cos_i(a) * 520.0, py + Trig.sin_i(a) * 520.0, false, 60)
				if e >= 0:
					e_t[e] = 50 + k * 22
			events.append([EV_WAVE, "LASER GRID"])
		"elite":
			var a := rng.range_i(Trig.STEPS)
			_spawn_at_safe(type, px + Trig.cos_i(a) * 700.0, py + Trig.sin_i(a) * 700.0, true, 70)
			events.append([EV_ELITE, type])
		"surge":
			surge_until = tick + 30 * TPS
			events.append([EV_WAVE, "SURGE"])
		"boss":
			var a := rng.range_i(Trig.STEPS)
			_spawn_at_safe(type, px + Trig.cos_i(a) * 620.0, py + Trig.sin_i(a) * 620.0, false, 150)
			events.append([EV_BOSS, type])


func _spawn_at_safe(type: int, x: float, y: float, elite: bool, warm: int) -> int:
	var d := sqrt(x * x + y * y)
	var lim := ARENA_R - 50.0
	if d > lim:
		x = x / d * lim
		y = y / d * lim
	return _spawn(type, x, y, elite, warm)


func _spawn(type: int, x: float, y: float, elite: bool, warm: int) -> int:
	if en >= MAX_E:
		return -1
	var def: Dictionary = Defs.ENEMY[type]
	var tm := seconds() / 60.0
	var hpm := 1.0 + 0.35 * tm + 0.08 * tm * tm
	var spm := 1.0 + minf(0.3, 0.04 * tm)
	var dmm := 1.0 + 0.14 * tm
	if type >= Defs.WARDEN:
		hpm = boss_mult
		spm = 1.0
		dmm = 1.0 + 0.15 * float(night)
	else:
		if mods.has("horde"):
			hpm *= 0.67
		if mods.has("giants"):
			hpm *= 2.0
		if mods.has("frenzy"):
			spm *= 1.2
		if endless:
			hpm *= 1.0 + Defs.NIGHT_TOUGH * float(night)
	var i := en
	en += 1
	e_type[i] = type
	e_x[i] = x
	e_y[i] = y
	e_ox[i] = x
	e_oy[i] = y
	e_vx[i] = 0.0
	e_vy[i] = 0.0
	var hpv: float = def.hp * hpm * curse
	var r: float = def.r
	if mods.has("giants") and type < Defs.WARDEN:
		r *= 1.3
	var dmg: float = def.dmg * dmm
	var kb: float = def.kb
	if elite:
		hpv *= 9.0
		r *= 1.4
		dmg *= 1.4
		kb *= 0.3
	e_hp[i] = hpv
	e_maxhp[i] = hpv
	e_r[i] = r
	e_speed[i] = def.speed * spm * (1.0 + rng.range_f(-0.08, 0.08))
	e_dmg[i] = dmg
	e_kb[i] = kb
	e_t[i] = 60 + rng.range_i(120)
	e_state[i] = 0
	e_k[i] = 0
	e_ang[i] = Trig.angle_of(px - x, py - y)
	e_flash[i] = 0
	e_spawn[i] = warm
	e_hitcd[i] = 0
	e_elite[i] = 1 if elite else 0
	e_ax[i] = x
	e_ay[i] = y
	e_shd[i] = 0
	e_uid[i] = uid_next
	uid_next += 1
	return i


func _e_remove(i: int) -> void:
	var l := en - 1
	if i != l:
		e_type[i] = e_type[l]; e_x[i] = e_x[l]; e_y[i] = e_y[l]; e_ox[i] = e_ox[l]; e_oy[i] = e_oy[l]
		e_vx[i] = e_vx[l]; e_vy[i] = e_vy[l]; e_hp[i] = e_hp[l]; e_maxhp[i] = e_maxhp[l]; e_r[i] = e_r[l]
		e_speed[i] = e_speed[l]; e_dmg[i] = e_dmg[l]; e_kb[i] = e_kb[l]; e_t[i] = e_t[l]; e_state[i] = e_state[l]
		e_k[i] = e_k[l]; e_ang[i] = e_ang[l]; e_flash[i] = e_flash[l]; e_spawn[i] = e_spawn[l]
		e_hitcd[i] = e_hitcd[l]; e_elite[i] = e_elite[l]; e_uid[i] = e_uid[l]; e_ax[i] = e_ax[l]
		e_ay[i] = e_ay[l]; e_shd[i] = e_shd[l]
	en = l


# --- enemies ------------------------------------------------------------------------

func _update_enemies() -> void:
	var i := 0
	while i < en:
		if e_spawn[i] > 0:
			e_spawn[i] -= 1
			i += 1
			continue
		if e_flash[i] > 0:
			e_flash[i] -= 1
		if e_hitcd[i] > 0:
			e_hitcd[i] -= 1
		if freeze > 0:
			# Stopped time: only knockback moves them.
			e_x[i] += e_vx[i] * DT
			e_y[i] += e_vy[i] * DT
			e_vx[i] *= 0.86
			e_vy[i] *= 0.86
			i += 1
			continue
		var type := e_type[i]
		var dx := px - e_x[i]
		var dy := py - e_y[i]
		var d := sqrt(dx * dx + dy * dy) + 0.0001
		var ux := dx / d
		var uy := dy / d
		var sp := e_speed[i]
		var vx := ux * sp
		var vy := uy * sp
		match type:
			Defs.DART:
				var st := e_state[i]
				if st == 0:
					e_t[i] -= 1
					if e_t[i] <= 0 and d < 620.0:
						e_state[i] = 1
						e_t[i] = 34
						e_ang[i] = Trig.angle_of(dx, dy)
						events.append([EV_TELEGRAPH, e_x[i], e_y[i], e_ang[i], 560.0 * 24.0 / 60.0])
				elif st == 1:
					vx = 0.0
					vy = 0.0
					e_t[i] -= 1
					if e_t[i] <= 0:
						e_state[i] = 2
						e_t[i] = 24
				else:
					vx = Trig.cos_i(e_ang[i]) * 560.0
					vy = Trig.sin_i(e_ang[i]) * 560.0
					e_t[i] -= 1
					if e_t[i] <= 0:
						e_state[i] = 0
						e_t[i] = 100 + rng.range_i(90)
			Defs.WEAVER:
				var s := Trig.sin_i(tick * 7 + e_uid[i] * 131) * 0.9
				vx += -uy * sp * s
				vy += ux * sp * s
			Defs.SPITTER:
				if d < 290.0:
					vx = -ux * sp * 0.8
					vy = -uy * sp * 0.8
				elif d < 400.0:
					var side := 1.0 if (e_uid[i] & 1) == 0 else -1.0
					vx = -uy * sp * 0.6 * side
					vy = ux * sp * 0.6 * side
				e_t[i] -= 1
				if e_t[i] <= 0:
					if d < 720.0:
						_fire_orb(e_x[i], e_y[i], Trig.angle_of(dx, dy), 230.0, e_dmg[i])
					e_t[i] = 150 + rng.range_i(70)
			Defs.BOMBER:
				if e_state[i] == 0:
					if d < 70.0 + e_r[i]:
						e_state[i] = 1
						e_t[i] = 36
				elif e_state[i] == 1:
					vx *= 0.35
					vy *= 0.35
					e_t[i] -= 1
					if e_t[i] <= 0:
						e_state[i] = 9
						e_hp[i] = 0.0
						events.append([EV_BLAST, e_x[i], e_y[i], 125.0, true])
						if d < 125.0 + PLAYER_R:
							_hurt(e_dmg[i] * 2.5)
			Defs.PHANTOM:
				var v3 := _phantom(i, d)
				vx *= v3
				vy *= v3
			Defs.SENTINEL:
				var v4 := _sentinel(i, dx, dy, d)
				vx *= v4
				vy *= v4
			Defs.BASTION:
				# Hangs back behind the swarm so its aegis covers the front line.
				if d < 300.0:
					vx = -ux * sp * 0.6
					vy = -uy * sp * 0.6
				elif d < 400.0:
					var side2 := 1.0 if (e_uid[i] & 1) == 0 else -1.0
					vx = -uy * sp * 0.4 * side2
					vy = ux * sp * 0.4 * side2
			Defs.SERAPH:
				var v5 := _seraph(i, dx, dy, d)
				vx = ux * sp * v5
				vy = uy * sp * v5
			Defs.WARDEN:
				var v := _warden(i, dx, dy, d)
				vx = ux * sp * v
				vy = uy * sp * v
			Defs.ECLIPSE:
				var v2 := _eclipse(i, dx, dy, d)
				if e_state[i] == 2:
					vx = Trig.cos_i(e_ang[i]) * 760.0
					vy = Trig.sin_i(e_ang[i]) * 760.0
				else:
					vx = ux * sp * v2
					vy = uy * sp * v2
		e_x[i] += (vx + e_vx[i]) * DT
		e_y[i] += (vy + e_vy[i]) * DT
		e_vx[i] *= 0.86
		e_vy[i] *= 0.86
		if type != Defs.DART or e_state[i] == 0:
			if vx != 0.0 or vy != 0.0:
				e_ang[i] = Trig.angle_of(vx, vy)
		var r2 := e_x[i] * e_x[i] + e_y[i] * e_y[i]
		var lim := ARENA_R - e_r[i]
		if r2 > lim * lim:
			var rd := sqrt(r2)
			e_x[i] = e_x[i] / rd * lim
			e_y[i] = e_y[i] / rd * lim
		i += 1


## Phantom: fades out, marks a spot beside you, then blinks there.
## Returns a speed factor.
func _phantom(i: int, d: float) -> float:
	if e_state[i] == 0:
		e_t[i] -= 1
		if e_t[i] <= 0 and d > 240.0 and d < 900.0:
			var a := rng.range_i(Trig.STEPS)
			var tx := px + Trig.cos_i(a) * 200.0
			var ty := py + Trig.sin_i(a) * 200.0
			var td := sqrt(tx * tx + ty * ty)
			var lim := ARENA_R - 60.0
			if td > lim:
				tx = tx / td * lim
				ty = ty / td * lim
			e_ax[i] = tx
			e_ay[i] = ty
			e_state[i] = 1
			e_t[i] = 48
			events.append([EV_BLINK, e_x[i], e_y[i], tx, ty, Defs.PHANTOM, 0])
		return 1.0
	e_t[i] -= 1
	if e_t[i] <= 0:
		events.append([EV_BLINK, e_x[i], e_y[i], e_ax[i], e_ay[i], Defs.PHANTOM, 1])
		e_x[i] = e_ax[i]
		e_y[i] = e_ay[i]
		e_ox[i] = e_x[i]
		e_oy[i] = e_y[i]
		e_state[i] = 0
		e_t[i] = 210 + rng.range_i(150)
		return 0.0
	return 0.0


## Sentinel: anchors in range, tracks you with a warning line, locks on and
## fires a long beam. Returns a speed factor.
func _sentinel(i: int, dx: float, dy: float, d: float) -> float:
	match e_state[i]:
		0:
			if e_t[i] > 0:
				e_t[i] -= 1
			elif d < 560.0:
				e_state[i] = 1
				e_t[i] = 80
				e_ang[i] = Trig.angle_of(dx, dy)
				events.append([EV_LASER, e_x[i], e_y[i], e_ang[i], SENTINEL_LEN, SENTINEL_W, 0, Defs.SENTINEL])
			return 1.0
		1:
			e_t[i] -= 1
			if e_t[i] > 30:
				e_ang[i] = Trig.angle_of(dx, dy)
			if e_t[i] <= 0:
				e_state[i] = 2
				e_t[i] = 16
				events.append([EV_LASER, e_x[i], e_y[i], e_ang[i], SENTINEL_LEN, SENTINEL_W, 1, Defs.SENTINEL])
			return 0.0
		2:
			e_t[i] -= 1
			if _beam_hit(e_x[i], e_y[i], e_ang[i], SENTINEL_LEN, SENTINEL_W):
				_hurt(e_dmg[i])
			if e_t[i] <= 0:
				e_state[i] = 3
				e_t[i] = 160 + rng.range_i(100)
			return 0.0
	e_t[i] -= 1
	if e_t[i] <= 0:
		e_state[i] = 0
	return 0.5


## True if the player is inside a beam from (x, y) at angle a.
func _beam_hit(x: float, y: float, a: int, length: float, half_w: float) -> bool:
	var ux := Trig.cos_i(a)
	var uy := Trig.sin_i(a)
	var rx := px - x
	var ry := py - y
	var along := rx * ux + ry * uy
	if along < 0.0 or along > length:
		return false
	return absf(rx * uy - ry * ux) < half_w + PLAYER_R * 0.6


## Seraph: a wheel of turning lasers, then three aimed lances, then it
## vanishes and reappears beside you in a ring of light. Returns a speed factor.
func _seraph(i: int, dx: float, dy: float, d: float) -> float:
	e_t[i] += 1
	var t := e_t[i]
	var overload := t > OVERLOAD_TICKS
	var enraged := e_hp[i] < e_maxhp[i] * 0.5 or overload
	if t == OVERLOAD_TICKS:
		events.append([EV_WAVE, "OVERLOAD"])
	if t % 1200 == 420:
		for k in 6:
			var a := k * Trig.STEPS / 6
			_spawn_at_safe(Defs.PHANTOM, px + Trig.cos_i(a) * 460.0, py + Trig.sin_i(a) * 460.0, false, 40)
	var c := t % 600
	if c < 330:
		# The wheel: the first second is a warning, then the arms burn.
		e_state[i] = 1 if c < 60 else 2
		e_k[i] += 3 if overload else 2
		if c == 0:
			events.append([EV_LASER, e_x[i], e_y[i], e_k[i], SERAPH_ARM, 16.0, 0, Defs.SERAPH])
		elif c == 60:
			events.append([EV_LASER, e_x[i], e_y[i], e_k[i], SERAPH_ARM, 16.0, 1, Defs.SERAPH])
		if e_state[i] == 2:
			var arms := seraph_arms(i)
			for k in arms:
				if _beam_hit(e_x[i], e_y[i], e_k[i] + k * Trig.STEPS / arms, SERAPH_ARM, 16.0):
					_hurt(e_dmg[i])
					break
		return 0.45
	if c < 480:
		# Judgement: three lances aimed where you are going.
		var sub := (c - 330) % 50
		if sub == 0:
			e_state[i] = 3
			e_ang[i] = Trig.angle_of(dx + mvx * st_speed * 0.4, dy + mvy * st_speed * 0.4)
			events.append([EV_LASER, e_x[i], e_y[i], e_ang[i], SERAPH_LANCE, 26.0, 0, Defs.SERAPH])
		elif sub == 30:
			e_state[i] = 4
			events.append([EV_LASER, e_x[i], e_y[i], e_ang[i], SERAPH_LANCE, 26.0, 1, Defs.SERAPH])
		elif sub == 42:
			e_state[i] = 0
		if e_state[i] == 4:
			for k in seraph_lances(i):
				if _beam_hit(e_x[i], e_y[i], e_ang[i] + k, SERAPH_LANCE, 26.0):
					_hurt(e_dmg[i] * 1.2)
					break
		return 0.0 if e_state[i] >= 3 else 0.3
	if c == 480:
		var a := rng.range_i(Trig.STEPS)
		var tx := px + Trig.cos_i(a) * 380.0
		var ty := py + Trig.sin_i(a) * 380.0
		var td := sqrt(tx * tx + ty * ty)
		var lim := ARENA_R - e_r[i] - 20.0
		if td > lim:
			tx = tx / td * lim
			ty = ty / td * lim
		e_ax[i] = tx
		e_ay[i] = ty
		e_state[i] = 5
		events.append([EV_BLINK, e_x[i], e_y[i], tx, ty, Defs.SERAPH, 0])
	if c < 540:
		return 0.0
	if c == 540:
		events.append([EV_BLINK, e_x[i], e_y[i], e_ax[i], e_ay[i], Defs.SERAPH, 1])
		e_x[i] = e_ax[i]
		e_y[i] = e_ay[i]
		e_ox[i] = e_x[i]
		e_oy[i] = e_y[i]
		e_state[i] = 0
		var n := 30 if enraged else 22
		for k in n:
			_fire_orb(e_x[i], e_y[i], k * Trig.STEPS / n + (t & 31), 165.0, 15.0)
	elif c == 575 and enraged:
		for k in 22:
			_fire_orb(e_x[i], e_y[i], k * Trig.STEPS / 22 + Trig.STEPS / 44, 130.0, 15.0)
	return 0.9 if d > 200.0 else 0.3


## The Seraph's wheel has three arms, four once it is wounded.
func seraph_arms(i: int) -> int:
	return 4 if e_hp[i] < e_maxhp[i] * 0.5 or e_t[i] > OVERLOAD_TICKS else 3


## Angle offsets of the Seraph's aimed lances (side lances once wounded).
func seraph_lances(i: int) -> Array:
	if e_hp[i] < e_maxhp[i] * 0.5 or e_t[i] > OVERLOAD_TICKS:
		return [0, Trig.STEPS / 10, -Trig.STEPS / 10]
	return [0]


## Every laser on the field for the views and the autopilot:
## [x, y, angle, length, half width, live, type, charge 0..1].
func lasers() -> Array:
	var out: Array = []
	for i in en:
		var type := e_type[i]
		if e_spawn[i] > 0:
			continue
		var st := e_state[i]
		if type == Defs.SENTINEL and (st == 1 or st == 2):
			var kc := 1.0 if st == 2 else 1.0 - float(e_t[i]) / 80.0
			out.append([e_x[i], e_y[i], e_ang[i], SENTINEL_LEN, SENTINEL_W, st == 2, type, kc])
		elif type == Defs.SERAPH:
			var c := e_t[i] % 600
			if st == 1 or st == 2:
				var arms := seraph_arms(i)
				var ka := 1.0 if st == 2 else float(c) / 60.0
				for k in arms:
					out.append([e_x[i], e_y[i], e_k[i] + k * Trig.STEPS / arms, SERAPH_ARM, 16.0, st == 2, type, ka])
			elif st == 3 or st == 4:
				var kl := 1.0 if st == 4 else float((c - 330) % 50) / 30.0
				for off in seraph_lances(i):
					out.append([e_x[i], e_y[i], e_ang[i] + int(off), SERAPH_LANCE, 26.0, st == 4, type, kl])
	return out


## Bastions shield every enemy near them: shielded enemies take half damage.
func _aegis_aura() -> void:
	if tick % 6 != 0:
		return
	var bastions := PackedInt32Array()
	for i in en:
		if e_type[i] == Defs.BASTION and e_spawn[i] <= 0 and e_hp[i] > 0.0:
			bastions.append(i)
	if _shielded:
		for i in en:
			e_shd[i] = 0
		_shielded = false
	var rad := BASTION_R
	for b in bastions:
		var bx := e_x[b]
		var by := e_y[b]
		var br := rad * (1.3 if e_elite[b] == 1 else 1.0)
		_query(bx, by, br)
		for q in _qn:
			var j := _qbuf[q]
			if j == b or e_type[j] >= Defs.WARDEN or e_type[j] == Defs.BASTION:
				continue
			var dx := e_x[j] - bx
			var dy := e_y[j] - by
			if dx * dx + dy * dy < br * br:
				e_shd[j] = 1
				_shielded = true


## The Chain fades if you stop killing.
func _update_chain() -> void:
	if chain <= 0:
		return
	chain_t -= 1
	if chain_t <= 0:
		chain = 0


## Warden: radial bursts and summons. Returns a speed factor.
func _warden(i: int, dx: float, dy: float, d: float) -> float:
	e_t[i] += 1
	var t := e_t[i]
	var enraged := e_hp[i] < e_maxhp[i] * 0.5
	# Overload: a Warden left alive too long fights twice as hard.
	if e_state[i] == 0 and t > OVERLOAD_TICKS:
		e_state[i] = 5
		events.append([EV_WAVE, "OVERLOAD"])
	var overload := e_state[i] == 5
	if overload:
		enraged = true
	var every := (90 if overload else 140) if enraged else 200
	if t % every == 0:
		e_k[i] += 1
		var n := 18
		var off := (e_k[i] & 1) * (Trig.STEPS / n / 2)
		for k in n:
			_fire_orb(e_x[i], e_y[i], off + k * Trig.STEPS / n, 190.0, 14.0)
		if enraged:
			for k in 12:
				_fire_orb(e_x[i], e_y[i], off + k * Trig.STEPS / 12 + 20, 135.0, 14.0)
	if t % 480 == 240:
		for k in 6:
			var a := k * Trig.STEPS / 6
			_spawn(Defs.DRIFTER, e_x[i] + Trig.cos_i(a) * 110.0, e_y[i] + Trig.sin_i(a) * 110.0, false, 24)
	if overload:
		return 1.7 if d > 160.0 else 0.6
	return 1.0 if d > 160.0 else 0.4


## Eclipse: spiral streams, telegraphed dashes, orb rings, mite swarms.
func _eclipse(i: int, dx: float, dy: float, d: float) -> float:
	e_t[i] += 1
	var t := e_t[i]
	var c := t % 760
	var enraged := e_hp[i] < e_maxhp[i] * 0.4 or t > OVERLOAD_TICKS
	if t == OVERLOAD_TICKS:
		events.append([EV_WAVE, "OVERLOAD"])
	if c < 220:
		e_state[i] = 0
		if t % 6 == 0:
			var arms := (4 if t > OVERLOAD_TICKS * 2 else 3) if enraged else 2
			e_k[i] += 29
			for k in arms:
				_fire_orb(e_x[i], e_y[i], e_k[i] + k * Trig.STEPS / arms, 170.0, 15.0)
		return 0.6
	if c >= 280 and c < 330:
		if c == 280:
			e_state[i] = 1
			e_ang[i] = Trig.angle_of(dx, dy)
			events.append([EV_TELEGRAPH, e_x[i], e_y[i], e_ang[i], 760.0 * 34.0 / 60.0])
		return 0.0
	if c >= 330 and c < 364:
		e_state[i] = 2
		return 0.0
	e_state[i] = 0
	if c == 420 or c == 600 or (enraged and c == 510):
		var n := 26
		for k in n:
			_fire_orb(e_x[i], e_y[i], k * Trig.STEPS / n + (t & 15), 160.0, 15.0)
	if t % 900 == 700:
		for k in 10:
			var a := k * Trig.STEPS / 10
			_spawn_at_safe(Defs.MITE, px + Trig.cos_i(a) * 420.0, py + Trig.sin_i(a) * 420.0, false, 40)
		events.append([EV_WAVE, "SWARM"])
	return 1.0


func _fire_orb(x: float, y: float, a: int, speed: float, dmg: float) -> void:
	if qn >= MAX_Q:
		return
	var i := qn
	qn += 1
	q_x[i] = x
	q_y[i] = y
	q_ox[i] = x
	q_oy[i] = y
	q_vx[i] = Trig.cos_i(a) * speed
	q_vy[i] = Trig.sin_i(a) * speed
	q_dmg[i] = dmg
	q_life[i] = 600
	events.append([EV_ORB, x, y])


# --- spatial hash -----------------------------------------------------------------

func _cell(x: float, y: float) -> int:
	var cx := clampi(int((x + GRID_HALF) / CELL), 0, GRID_N - 1)
	var cy := clampi(int((y + GRID_HALF) / CELL), 0, GRID_N - 1)
	return cy * GRID_N + cx


func _grid_build() -> void:
	_head.fill(-1)
	_bigs.clear()
	for i in en:
		if e_spawn[i] > 0 or e_hp[i] <= 0.0:
			continue
		if e_r[i] > BOSS_R:
			_bigs.append(i)
			continue
		var c := _cell(e_x[i], e_y[i])
		_next[i] = _head[c]
		_head[c] = i


## Fills _qbuf/_qn with live enemies that may touch a circle at (x, y) of
## radius `rad` (plus any enemy radius). Never call while iterating _qbuf.
func _query(x: float, y: float, rad: float) -> void:
	_qn = 0
	var reach := rad + BOSS_R
	var x0 := clampi(int((x - reach + GRID_HALF) / CELL), 0, GRID_N - 1)
	var x1 := clampi(int((x + reach + GRID_HALF) / CELL), 0, GRID_N - 1)
	var y0 := clampi(int((y - reach + GRID_HALF) / CELL), 0, GRID_N - 1)
	var y1 := clampi(int((y + reach + GRID_HALF) / CELL), 0, GRID_N - 1)
	for cy in range(y0, y1 + 1):
		var row := cy * GRID_N
		for cx in range(x0, x1 + 1):
			var j := _head[row + cx]
			while j >= 0:
				_qbuf[_qn] = j
				_qn += 1
				j = _next[j]
	for b in _bigs:
		_qbuf[_qn] = b
		_qn += 1


func _separate() -> void:
	for cy in GRID_N:
		for cx in GRID_N:
			var i := _head[cy * GRID_N + cx]
			while i >= 0:
				var checks := 0
				var x0 := maxi(cx - 1, 0)
				var x1 := mini(cx + 1, GRID_N - 1)
				var y0 := maxi(cy - 1, 0)
				var y1 := mini(cy + 1, GRID_N - 1)
				for ny in range(y0, y1 + 1):
					for nx in range(x0, x1 + 1):
						var j := _head[ny * GRID_N + nx]
						while j >= 0 and checks < 12:
							if j > i:
								checks += 1
								var dx := e_x[j] - e_x[i]
								var dy := e_y[j] - e_y[i]
								var rr := e_r[i] + e_r[j]
								var d2 := dx * dx + dy * dy
								if d2 < rr * rr and d2 > 0.0001:
									var d := sqrt(d2)
									var push := (rr - d) * 0.3 / d
									var wi := e_r[j] / rr
									var wj := e_r[i] / rr
									e_x[i] -= dx * push * wi
									e_y[i] -= dy * push * wi
									e_x[j] += dx * push * wj
									e_y[j] += dy * push * wj
							j = _next[j]
				i = _next[i]
	# Bosses shove small enemies aside.
	for b in _bigs:
		for i in en:
			if i == b or e_spawn[i] > 0 or e_r[i] > BOSS_R:
				continue
			var dx := e_x[i] - e_x[b]
			var dy := e_y[i] - e_y[b]
			var rr := e_r[i] + e_r[b]
			var d2 := dx * dx + dy * dy
			if d2 < rr * rr and d2 > 0.0001:
				var d := sqrt(d2)
				e_x[i] += dx / d * (rr - d) * 0.5
				e_y[i] += dy / d * (rr - d) * 0.5


# --- weapons ----------------------------------------------------------------------

func _weapons() -> void:
	for w in weapons:
		var spec: Dictionary = Defs.WEAPONS[w.id].levels[w.lvl - 1]
		if w.id == "orbit":
			_orbit(spec)
			continue
		w.t -= 1
		if w.t > 0:
			continue
		var fired := false
		match w.id:
			"pulse":
				fired = _fire_pulse(spec, w)
			"arc":
				fired = _fire_arc(spec)
			"nova":
				fired = _fire_nova(spec)
			"seeker":
				fired = _fire_seeker(spec)
			"lance":
				fired = _fire_lance(spec, w)
			"scythe":
				fired = _fire_scythe(spec, w)
			"mine":
				fired = _fire_mine(spec)
		if fired:
			var haste := st_haste
			# Kestrel's slipstream: faster recharge while moving.
			if ship_id == "kestrel" and mvx * mvx + mvy * mvy > 0.25:
				haste *= 0.8
			w.t = maxi(6, int(float(spec.cd) * haste))
			# Spectrum and Lunar Reaper: quick follow-ups before the real cooldown.
			if spec.has("sweeps"):
				w.k += 1
				if w.k < int(spec.sweeps):
					w.t = 8
				else:
					w.k = 0
		else:
			w.t = 6


func _nearest(x: float, y: float, maxd: float, skip: Dictionary = {}) -> int:
	var best := -1
	var bd := maxd * maxd
	for i in en:
		if e_spawn[i] > 0 or e_hp[i] <= 0.0:
			continue
		if not skip.is_empty() and skip.has(e_uid[i]):
			continue
		var dx := e_x[i] - x
		var dy := e_y[i] - y
		var d2 := dx * dx + dy * dy
		if d2 < bd:
			bd = d2
			best = i
	return best


func _fire_pulse(spec: Dictionary, w: Dictionary) -> bool:
	var t := _nearest(px, py, 680.0)
	if t < 0:
		return false
	var a := Trig.angle_of(e_x[t] - px, e_y[t] - py)
	var n: int = spec.n
	var evo: bool = spec.get("evo", false)
	var kind := 3 if evo else 0
	var r := (14.0 if evo else 9.0) * sqrt(st_area)
	for k in n:
		var off := int((float(k) - float(n - 1) * 0.5) * (16.0 if evo else 20.0))
		_add_bullet(kind, px, py, a + off, 980.0, spec.dmg, r, spec.pierce, 52, 0.0)
	events.append([EV_SHOT, "pulse_evo" if evo else "pulse", px, py, a])
	if evo:
		w.k += 1
		if w.k >= int(spec.ring):
			w.k = 0
			for k in 16:
				_add_bullet(kind, px, py, a + k * Trig.STEPS / 16 + Trig.STEPS / 32, 760.0, spec.dmg, r,
						spec.pierce, 60, 0.0)
			events.append([EV_SHOT, "supernova", px, py, a])
	return true


func _add_bullet(kind: int, x: float, y: float, a: int, speed: float, dmg: float, r: float, pierce: int,
		life: int, blast: float) -> int:
	if bn >= MAX_B:
		return -1
	var i := bn
	bn += 1
	b_kind[i] = kind
	b_x[i] = x
	b_y[i] = y
	b_ox[i] = x
	b_oy[i] = y
	b_vx[i] = Trig.cos_i(a) * speed
	b_vy[i] = Trig.sin_i(a) * speed
	b_dmg[i] = dmg
	b_r[i] = r
	b_pierce[i] = pierce
	b_life[i] = life
	b_last[i] = 0
	b_blast[i] = blast
	b_tx[i] = x + b_vx[i]
	b_ty[i] = y + b_vy[i]
	return i


func _b_remove(i: int) -> void:
	var l := bn - 1
	if i != l:
		b_kind[i] = b_kind[l]; b_x[i] = b_x[l]; b_y[i] = b_y[l]; b_ox[i] = b_ox[l]; b_oy[i] = b_oy[l]
		b_vx[i] = b_vx[l]; b_vy[i] = b_vy[l]; b_dmg[i] = b_dmg[l]; b_r[i] = b_r[l]; b_pierce[i] = b_pierce[l]
		b_life[i] = b_life[l]; b_last[i] = b_last[l]; b_blast[i] = b_blast[l]; b_tx[i] = b_tx[l]
		b_ty[i] = b_ty[l]
	bn = l


func _orbit(spec: Dictionary) -> void:
	orbit_ang = (orbit_ang + int(spec.spin)) & Trig.MASK
	var n: int = spec.n
	var rad := orbit_radius()
	var evo: bool = spec.get("evo", false)
	var br := (28.0 if evo else 20.0) * st_area
	var push := 520.0 if evo else 220.0
	for k in n:
		var a := orbit_ang + k * Trig.STEPS / n
		var bx := px + Trig.cos_i(a) * rad
		var by := py + Trig.sin_i(a) * rad
		_query(bx, by, br)
		for q in _qn:
			var i := _qbuf[q]
			if e_hitcd[i] > 0 or e_hp[i] <= 0.0:
				continue
			var dx := e_x[i] - bx
			var dy := e_y[i] - by
			var rr := br + e_r[i]
			if dx * dx + dy * dy < rr * rr:
				e_hitcd[i] = 18
				var ox := e_x[i] - px
				var oy := e_y[i] - py
				var od := sqrt(ox * ox + oy * oy) + 0.001
				_damage(i, spec.dmg, ox / od * push, oy / od * push)


func orbit_spec() -> Dictionary:
	var l := weapon_level("orbit")
	if l == 0:
		return {}
	return Defs.WEAPONS.orbit.levels[l - 1]


## Current blade orbit radius (Event Horizon breathes between r and r2).
func orbit_radius() -> float:
	var spec := orbit_spec()
	if spec.is_empty():
		return 0.0
	if spec.has("r2"):
		var k := 0.5 + 0.5 * Trig.sin_i(tick * 5)
		return (float(spec.r) + (float(spec.r2) - float(spec.r)) * k) * st_area
	return float(spec.r) * st_area


func _fire_arc(spec: Dictionary) -> bool:
	var first := _nearest(px, py, 560.0)
	if first < 0:
		return false
	var hit := {}
	var reach: float = spec.get("reach", 230.0)
	var blast: float = spec.get("blast", 0.0)
	for s in int(spec.strikes):
		var cur := first if s == 0 else _nearest(px, py, 560.0, hit)
		if cur < 0:
			break
		var pts := PackedVector2Array([Vector2(px, py)])
		var lx := px
		var ly := py
		for c in int(spec.chain):
			hit[e_uid[cur]] = true
			pts.append(Vector2(e_x[cur], e_y[cur]))
			lx = e_x[cur]
			ly = e_y[cur]
			_damage(cur, spec.dmg, 0.0, 0.0)
			var nxt := _nearest(e_x[cur], e_y[cur], reach * st_area, hit)
			if nxt < 0:
				break
			cur = nxt
		events.append([EV_ARC, pts, blast > 0.0])
		if blast > 0.0:
			_explode(lx, ly, blast * st_area, spec.dmg)
	return true


func _fire_nova(spec: Dictionary) -> bool:
	var mr: float = spec.r * st_area
	novas.append({"x": px, "y": py, "r": 0.0, "max": mr, "step": mr / 16.0, "dmg": spec.dmg, "hit": {}})
	events.append([EV_NOVA, px, py, mr])
	if spec.has("well"):
		# Singularity: open a black hole on the nearest enemy, or ahead of the ship.
		var t := _nearest(px, py, 620.0)
		var wx := px + Trig.cos_i(facing) * 260.0
		var wy := py + Trig.sin_i(facing) * 260.0
		if t >= 0:
			wx = e_x[t]
			wy = e_y[t]
		var wr: float = spec.well * st_area
		wells.append({"x": wx, "y": wy, "r": wr, "t": WELL_TICKS, "max": WELL_TICKS, "dmg": spec.well_dmg})
		events.append([EV_WELL, wx, wy, wr])
	return true


## Singularities pull everything nearby inwards, grind it, then detonate.
func _update_wells() -> void:
	var k := wells.size() - 1
	while k >= 0:
		var w: Dictionary = wells[k]
		w.t -= 1
		var wx: float = w.x
		var wy: float = w.y
		var wr: float = w.r
		_query(wx, wy, wr)
		var grind: bool = int(w.t) % 12 == 0
		for q in _qn:
			var i := _qbuf[q]
			if e_hp[i] <= 0.0:
				continue
			var dx := wx - e_x[i]
			var dy := wy - e_y[i]
			var d2 := dx * dx + dy * dy
			if d2 < wr * wr:
				var d := sqrt(d2) + 0.001
				var pull := 95.0 * (0.35 + 0.65 * (1.0 - d / wr)) * e_kb[i]
				e_vx[i] += dx / d * pull
				e_vy[i] += dy / d * pull
				if grind and d < wr * 0.55:
					_damage(i, w.get("grind", 6.0), 0.0, 0.0)
		if w.t <= 0:
			wells.remove_at(k)
			events.append([EV_IMPLODE, wx, wy, wr * 0.65])
			_explode(wx, wy, wr * 0.65, w.dmg)
		k -= 1


func _update_novas() -> void:
	var k := novas.size() - 1
	while k >= 0:
		var n: Dictionary = novas[k]
		n.r += n.step
		var hit: Dictionary = n.hit
		var nx: float = n.x
		var ny: float = n.y
		var nr: float = n.r
		_query(nx, ny, nr)
		for q in _qn:
			var i := _qbuf[q]
			if hit.has(e_uid[i]) or e_hp[i] <= 0.0:
				continue
			var dx := e_x[i] - nx
			var dy := e_y[i] - ny
			var rr: float = nr + e_r[i]
			var d2 := dx * dx + dy * dy
			if d2 < rr * rr:
				hit[e_uid[i]] = true
				var d := sqrt(d2) + 0.001
				_damage(i, n.dmg, dx / d * 420.0, dy / d * 420.0)
		if n.r >= n.max:
			novas.remove_at(k)
		k -= 1


func _fire_seeker(spec: Dictionary) -> bool:
	var t := _nearest(px, py, 750.0)
	if t < 0:
		return false
	var a := Trig.angle_of(e_x[t] - px, e_y[t] - py)
	var n: int = spec.n
	var split: int = spec.get("split", 0)
	for k in n:
		var off := (100 + k * 30) * (1 if k % 2 == 0 else -1)
		var i := _add_bullet(1, px, py, a + off, 360.0, spec.dmg, 12.0, split, 150, spec.blast * st_area)
		if i >= 0:
			b_tx[i] = e_x[t]
			b_ty[i] = e_y[t]
	events.append([EV_SHOT, "seeker", px, py, a])
	return true


## Hydra Swarm: a missile's blast releases smaller hunters.
func _split_missile(x: float, y: float, n: int, dmg: float, blast: float) -> void:
	var a := tick * 37
	for k in n:
		var i := _add_bullet(2, x, y, a + k * Trig.STEPS / n, 420.0, dmg * 0.5, 9.0, 0, 90, blast * 0.6)
		if i >= 0:
			b_tx[i] = x + Trig.cos_i(a + k * Trig.STEPS / n) * 300.0
			b_ty[i] = y + Trig.sin_i(a + k * Trig.STEPS / n) * 300.0


func _fire_lance(spec: Dictionary, w: Dictionary) -> bool:
	var a: int = w.a
	if w.k == 0:
		var t := _nearest(px, py, 900.0)
		if t < 0:
			return false
		a = Trig.angle_of(e_x[t] - px, e_y[t] - py)
		w.a = a
	var evo: bool = spec.get("evo", false)
	if evo:
		a += int(w.k) * Trig.STEPS / 18
	var dirs: int = spec.dirs
	var wd: float = spec.w * st_area
	for k in dirs:
		var da := a + k * Trig.STEPS / dirs
		var ux := Trig.cos_i(da)
		var uy := Trig.sin_i(da)
		var length := 1000.0
		for i in en:
			if e_spawn[i] > 0 or e_hp[i] <= 0.0:
				continue
			var rx := e_x[i] - px
			var ry := e_y[i] - py
			var along := rx * ux + ry * uy
			if along < -e_r[i] or along > length + e_r[i]:
				continue
			var perp := absf(rx * uy - ry * ux)
			if perp < wd * 0.5 + e_r[i]:
				_damage(i, spec.dmg, ux * 160.0, uy * 160.0)
		events.append([EV_LANCE, px, py, px + ux * length, py + uy * length, wd,
				float(k) / float(dirs) if evo else -1.0])
	return true


## Ion Scythe: a crescent sweep towards the nearest enemy (behind you too at
## Lv4). Lunar Reaper sweeps full circles and heals on every kill.
func _fire_scythe(spec: Dictionary, w: Dictionary) -> bool:
	var r: float = float(spec.r) * st_area
	var a: int = w.a
	if w.k == 0:
		var t := _nearest(px, py, r * 1.5)
		if t < 0:
			return false
		a = Trig.angle_of(e_x[t] - px, e_y[t] - py)
		w.a = a
	var half: int = spec.half
	var full := half >= Trig.HALF
	var cosh := Trig.cos_i(half)
	var dirs: int = spec.dirs
	var leech: float = spec.get("leech", 0.0)
	var healed := 0.0
	var evo: bool = spec.get("evo", false)
	for k in dirs:
		var da := a + k * Trig.STEPS / dirs
		var ux := Trig.cos_i(da)
		var uy := Trig.sin_i(da)
		_query(px, py, r)
		for q in _qn:
			var i := _qbuf[q]
			if e_hp[i] <= 0.0:
				continue
			var rx := e_x[i] - px
			var ry := e_y[i] - py
			var d := sqrt(rx * rx + ry * ry) + 0.001
			if d > r + e_r[i]:
				continue
			if not full and rx * ux + ry * uy < d * cosh - e_r[i]:
				continue
			_damage(i, spec.dmg, rx / d * 380.0, ry / d * 380.0)
			if leech > 0.0 and e_hp[i] <= 0.0 and healed < 4.0:
				healed += leech
				hp = minf(max_hp, hp + leech)
		events.append([EV_SLASH, px, py, da, r, half, evo, int(w.k)])
	return true


## Photon Mines: dropped behind the ship, armed after a moment, triggered by
## the swarm. The oldest mine detonates when the field is full.
func _fire_mine(spec: Dictionary) -> bool:
	if _nearest(px, py, 900.0) < 0:
		return false
	var n: int = spec.n
	var bx := px - Trig.cos_i(facing) * 30.0
	var by := py - Trig.sin_i(facing) * 30.0
	var sx := -Trig.sin_i(facing)
	var sy := Trig.cos_i(facing)
	for k in n:
		while mines.size() >= int(spec.max):
			var old: Dictionary = mines.pop_front()
			_explode(old.x, old.y, old.blast, old.dmg)
		var off := 0.0 if n == 1 else (44.0 if k == 0 else -44.0)
		mines.append({"x": bx + sx * off, "y": by + sy * off, "t": MINE_ARM, "life": MINE_LIFE,
				"dmg": float(spec.dmg), "blast": float(spec.blast) * st_area})
	events.append([EV_MINE, bx, by])
	return true


func mine_spec() -> Dictionary:
	var l := weapon_level("mine")
	if l == 0:
		return {}
	return Defs.WEAPONS.mine.levels[l - 1]


## Constellation tripwires: consecutive armed mines close enough to link,
## as [x0, y0, x1, y1] segments.
func mine_links() -> Array:
	var out: Array = []
	var spec := mine_spec()
	if not spec.has("link"):
		return out
	var lim: float = spec.link
	for k in range(1, mines.size()):
		var m0: Dictionary = mines[k - 1]
		var m1: Dictionary = mines[k]
		if int(m0.t) > 0 or int(m1.t) > 0:
			continue
		var dx: float = m1.x - m0.x
		var dy: float = m1.y - m0.y
		if dx * dx + dy * dy < lim * lim:
			out.append([m0.x, m0.y, m1.x, m1.y])
	return out


func _update_mines() -> void:
	if mines.is_empty():
		return
	var spec := mine_spec()
	var evo := spec.has("link")
	var k := mines.size() - 1
	while k >= 0:
		var m: Dictionary = mines[k]
		m.life -= 1
		if m.t > 0:
			m.t -= 1
		var boom: bool = m.life <= 0
		if not boom and m.t <= 0 and (tick + k) % 2 == 0:
			var mx: float = m.x
			var my: float = m.y
			_query(mx, my, MINE_PULL if evo else MINE_TRIGGER)
			for q in _qn:
				var i := _qbuf[q]
				if e_hp[i] <= 0.0:
					continue
				var dx := mx - e_x[i]
				var dy := my - e_y[i]
				var d := sqrt(dx * dx + dy * dy) + 0.001
				if d < MINE_TRIGGER + e_r[i]:
					boom = true
					break
				if evo and d < MINE_PULL:
					e_vx[i] += dx / d * 26.0 * e_kb[i]
					e_vy[i] += dy / d * 26.0 * e_kb[i]
		if boom:
			mines.remove_at(k)
			_explode(m.x, m.y, m.blast, m.dmg)
		k -= 1
	if evo and tick % 8 == 0:
		var hw := 14.0
		for l in mine_links():
			var ax: float = l[0]
			var ay: float = l[1]
			var lx: float = l[2] - ax
			var ly: float = l[3] - ay
			var l2 := lx * lx + ly * ly + 0.001
			for i in en:
				if e_spawn[i] > 0 or e_hp[i] <= 0.0:
					continue
				var rx := e_x[i] - ax
				var ry := e_y[i] - ay
				var tt := clampf((rx * lx + ry * ly) / l2, 0.0, 1.0)
				var qx := rx - lx * tt
				var qy := ry - ly * tt
				var rr := hw + e_r[i]
				if qx * qx + qy * qy < rr * rr:
					_damage(i, spec.link_dmg, 0.0, 0.0)


# --- relics -------------------------------------------------------------------------

func _start_relic() -> void:
	state = CHOOSING
	relic_choice = true
	choices = _roll_relics()
	events.append([EV_RELIC_OFFER])


func _roll_relics() -> Array:
	var pool: Array = []
	for id in Defs.RELIC_ORDER:
		if not relics.has(id):
			pool.append(id)
	var out: Array = []
	while out.size() < 3 and not pool.is_empty():
		var k := rng.range_i(pool.size())
		out.append(pool[k])
		pool.remove_at(k)
	return out


func _take_relic(id: String) -> void:
	if relics.has(id) or not Defs.is_relic(id):
		return
	relics.append(id)
	match id:
		"phoenix":
			revives += 1
		"midas":
			rerolls += 1
		"halo":
			halo_t = 0
	r_halo = relics.has("halo")
	r_wake = relics.has("wake")
	r_star = relics.has("starbreaker")
	r_supercrit = relics.has("supercrit")
	r_over = relics.has("overcharge")
	r_midas = relics.has("midas")
	r_wrath = relics.has("wrath")
	_recompute()
	events.append([EV_RELIC, id])
	events.append([EV_PICK, id, 1])


## Ion Wake: the ship lays burning light that scorches whatever crosses it.
func _update_wake_trail() -> void:
	if r_halo and halo_t > 0:
		halo_t -= 1
	if not r_wake:
		return
	if tick % 4 == 0 and mvx * mvx + mvy * mvy > 0.04:
		trail.append([px, py, Defs.WAKE_TICKS])
	for p in trail:
		p[2] -= 1
	while not trail.is_empty() and int(trail[0][2]) <= 0:
		trail.pop_front()
	if tick % 10 != 0 or trail.is_empty():
		return
	var dmg := 6.0 * _od_scale()
	var hit := {}
	for p in trail:
		var tx: float = p[0]
		var ty: float = p[1]
		_query(tx, ty, WAKE_R)
		for q in _qn:
			var i := _qbuf[q]
			if e_hp[i] <= 0.0 or hit.has(e_uid[i]):
				continue
			var dx := e_x[i] - tx
			var dy := e_y[i] - ty
			var rr := WAKE_R + e_r[i]
			if dx * dx + dy * dy < rr * rr:
				hit[e_uid[i]] = true
				_damage(i, dmg, 0.0, 0.0)


# --- Overdrive --------------------------------------------------------------------

## Overdrive damage grows with the swarm's toughness so it never goes stale.
func _od_scale() -> float:
	var tm := seconds() / 60.0
	return 1.0 + 0.35 * tm + 0.08 * tm * tm


func _overdrive() -> void:
	od -= od_need
	od_uses += 1
	od_need = Defs.OD_BASE * (1.0 + Defs.OD_GROWTH * float(od_uses))
	od_k = 0
	iframes = maxi(iframes, 30)
	if r_over:
		hp = minf(max_hp, hp + 25.0)
	var sc := _od_scale()
	events.append([EV_OVERDRIVE, ship_id, px, py])
	match ship_id:
		"vesper":
			od_t = 360
			shield = 360
		"kestrel":
			od_t = 90
		"strix":
			od_t = 300
		"halcyon":
			od_t = 150
			var r := 650.0 * st_area
			wells.append({"x": px, "y": py, "r": r, "t": 150, "max": 150, "dmg": 160.0 * sc, "grind": 10.0 * sc})
			events.append([EV_WELL, px, py, r])
			for g in gn:
				g_mag[g] = 1
			for p in pickups:
				p.mag = true
		"aurora":
			od_t = 240
		"nyx":
			od_t = 300
			freeze = 300
		_:
			# Flare: scorch everything nearby and erase enemy fire.
			od_t = 30
			qn = 0
			var fr := 1000.0
			for i in en:
				if e_spawn[i] > 0 or e_hp[i] <= 0.0:
					continue
				var dx := e_x[i] - px
				var dy := e_y[i] - py
				var d2 := dx * dx + dy * dy
				if d2 < fr * fr:
					var d := sqrt(d2) + 0.001
					_damage(i, 55.0 * sc, dx / d * 700.0, dy / d * 700.0)


func _update_overdrive() -> void:
	if _arc_cd > 0:
		_arc_cd -= 1
	if shield > 0:
		shield -= 1
	if freeze > 0:
		freeze -= 1
	if od_t <= 0:
		return
	od_t -= 1
	var sc := _od_scale()
	match ship_id:
		"vesper":
			# Aegis: the shield burns and repels whatever it touches.
			if od_t % 10 == 0:
				var r := 210.0 * st_area
				events.append([EV_AEGIS, px, py, r])
				_query(px, py, r)
				for q in _qn:
					var i := _qbuf[q]
					if e_hp[i] <= 0.0:
						continue
					var dx := e_x[i] - px
					var dy := e_y[i] - py
					var rr := r + e_r[i]
					var d2 := dx * dx + dy * dy
					if d2 < rr * rr:
						var d := sqrt(d2) + 0.001
						_damage(i, 12.0 * sc, dx / d * 320.0, dy / d * 320.0)
		"kestrel":
			# Barrage: a missile every third tick, fanning around the ship.
			if od_t % 3 == 0:
				od_k += 1
				var t := _nearest(px, py, 900.0)
				var a := od_k * 97
				var i := _add_bullet(1, px, py, a, 520.0, 24.0 * sc, 12.0, 0, 150, 92.0 * st_area)
				if i >= 0 and t >= 0:
					b_tx[i] = e_x[t]
					b_ty[i] = e_y[t]
				if od_k % 3 == 1:
					events.append([EV_SHOT, "seeker", px, py, a])
		"strix":
			# Tempest: lightning falls on random enemies around you.
			if od_t % 5 == 0:
				var a := rng.range_i(Trig.STEPS)
				var dist := rng.range_f(80.0, 520.0)
				var cur := _nearest(px + Trig.cos_i(a) * dist, py + Trig.sin_i(a) * dist, 360.0)
				if cur >= 0:
					var hit := {}
					var pts := PackedVector2Array([Vector2(e_x[cur], e_y[cur] - 900.0)])
					for c in 4:
						hit[e_uid[cur]] = true
						pts.append(Vector2(e_x[cur], e_y[cur]))
						_damage(cur, 30.0 * sc, 0.0, 0.0)
						var nxt := _nearest(e_x[cur], e_y[cur], 260.0, hit)
						if nxt < 0:
							break
						cur = nxt
					events.append([EV_ARC, pts, true])
		"aurora":
			# Prism Storm: eight beams turning like a lighthouse.
			if od_t % 12 == 0:
				od_k += 1
				var base := od_k * Trig.STEPS / 40
				var wd := 54.0 * st_area
				for k in 8:
					var da := base + k * Trig.STEPS / 8
					var ux := Trig.cos_i(da)
					var uy := Trig.sin_i(da)
					var length := 1100.0
					for i in en:
						if e_spawn[i] > 0 or e_hp[i] <= 0.0:
							continue
						var rx := e_x[i] - px
						var ry := e_y[i] - py
						var along := rx * ux + ry * uy
						if along < -e_r[i] or along > length + e_r[i]:
							continue
						if absf(rx * uy - ry * ux) < wd * 0.5 + e_r[i]:
							_damage(i, 30.0 * sc, ux * 160.0, uy * 160.0)
					events.append([EV_LANCE, px, py, px + ux * length, py + uy * length, wd, float(k) / 8.0])


# --- projectiles ------------------------------------------------------------------

func _update_bullets() -> void:
	var i := bn - 1
	while i >= 0:
		b_life[i] -= 1
		var kind := b_kind[i]
		var homing := kind == 1 or kind == 2
		if homing:
			if (tick + i) % 8 == 0:
				var t := _nearest(b_x[i], b_y[i], 650.0)
				if t >= 0:
					b_tx[i] = e_x[t]
					b_ty[i] = e_y[t]
			var dx := b_tx[i] - b_x[i]
			var dy := b_ty[i] - b_y[i]
			var d := sqrt(dx * dx + dy * dy) + 0.001
			b_vx[i] += (dx / d * 640.0 - b_vx[i]) * 0.09
			b_vy[i] += (dy / d * 640.0 - b_vy[i]) * 0.09
		b_x[i] += b_vx[i] * DT
		b_y[i] += b_vy[i] * DT
		var x := b_x[i]
		var y := b_y[i]
		var r := b_r[i]
		var dead := b_life[i] <= 0
		var boom := dead and homing
		if not dead:
			_query(x, y, r)
			for q in _qn:
				var e := _qbuf[q]
				if e_hp[e] <= 0.0 or e_uid[e] == b_last[i]:
					continue
				var dx2 := e_x[e] - x
				var dy2 := e_y[e] - y
				var rr := r + e_r[e]
				if dx2 * dx2 + dy2 * dy2 < rr * rr:
					if homing:
						boom = true
						dead = true
						break
					var sp := sqrt(b_vx[i] * b_vx[i] + b_vy[i] * b_vy[i]) + 0.001
					_damage(e, b_dmg[i], b_vx[i] / sp * 130.0, b_vy[i] / sp * 130.0)
					b_last[i] = e_uid[e]
					b_pierce[i] -= 1
					if b_pierce[i] < 0:
						dead = true
						break
		if x * x + y * y > (ARENA_R + 300.0) * (ARENA_R + 300.0):
			dead = true
		if boom:
			_explode(x, y, b_blast[i], b_dmg[i])
			if kind == 1 and b_pierce[i] > 0:
				_split_missile(x, y, b_pierce[i], b_dmg[i], b_blast[i])
		if dead:
			_b_remove(i)
		i -= 1


func _explode(x: float, y: float, r: float, dmg: float) -> void:
	events.append([EV_BLAST, x, y, r, false])
	_query(x, y, r)
	for q in _qn:
		var e := _qbuf[q]
		if e_hp[e] <= 0.0:
			continue
		var dx := e_x[e] - x
		var dy := e_y[e] - y
		var rr := r + e_r[e]
		var d2 := dx * dx + dy * dy
		if d2 < rr * rr:
			var d := sqrt(d2) + 0.001
			_damage(e, dmg, dx / d * 260.0, dy / d * 260.0)


func _update_orbs() -> void:
	if freeze > 0:
		return
	var i := qn - 1
	var hr := 9.0 + PLAYER_R * 0.75
	while i >= 0:
		if i >= qn:
			i -= 1
			continue
		q_life[i] -= 1
		q_x[i] += q_vx[i] * DT
		q_y[i] += q_vy[i] * DT
		var dx := q_x[i] - px
		var dy := q_y[i] - py
		var dead := q_life[i] <= 0
		if dx * dx + dy * dy < hr * hr:
			dead = true
			_hurt(q_dmg[i])
		elif q_x[i] * q_x[i] + q_y[i] * q_y[i] > (ARENA_R + 40.0) * (ARENA_R + 40.0):
			dead = true
		if dead:
			var l := qn - 1
			if i != l:
				q_x[i] = q_x[l]; q_y[i] = q_y[l]; q_ox[i] = q_ox[l]; q_oy[i] = q_oy[l]
				q_vx[i] = q_vx[l]; q_vy[i] = q_vy[l]; q_dmg[i] = q_dmg[l]; q_life[i] = q_life[l]
			qn = l
		i -= 1


# --- damage -----------------------------------------------------------------------

func _damage(i: int, dmg: float, kx: float, ky: float) -> void:
	if e_hp[i] <= 0.0:
		return
	var crit := rng.unit() < st_crit
	var dd := dmg * st_might
	if crit:
		dd *= (3.0 if ship_id == "aurora" else 2.0) + (1.0 if r_supercrit else 0.0)
	if r_star and (e_elite[i] == 1 or e_type[i] >= Defs.WARDEN):
		dd *= 1.6
	if r_wrath and hp < max_hp * 0.5:
		dd *= 1.5
	if freeze > 0:
		dd *= 1.5
	if e_shd[i] == 1:
		dd *= 0.5
	e_hp[i] -= dd
	damage_dealt += dd
	e_flash[i] = 5
	e_vx[i] += kx * e_kb[i]
	e_vy[i] += ky * e_kb[i]
	events.append([EV_HIT, e_x[i], e_y[i], dd, crit, e_type[i]])
	# Strix: critical hits leap to a nearby enemy (never recursively).
	if crit and ship_id == "strix" and not _in_arc and _arc_cd <= 0:
		var skip := {e_uid[i]: true}
		var j := _nearest(e_x[i], e_y[i], 240.0, skip)
		if j >= 0:
			_arc_cd = 4
			_in_arc = true
			events.append([EV_ARC, PackedVector2Array([Vector2(e_x[i], e_y[i]), Vector2(e_x[j], e_y[j])]), false])
			_damage(j, dmg * 0.6, 0.0, 0.0)
			_in_arc = false


func _contact() -> void:
	if iframes > 0 or shield > 0 or freeze > 0 or state != RUNNING:
		return
	_query(px, py, PLAYER_R)
	for q in _qn:
		var i := _qbuf[q]
		if e_hp[i] <= 0.0:
			continue
		var dx := e_x[i] - px
		var dy := e_y[i] - py
		var rr := e_r[i] + PLAYER_R * 0.8
		if dx * dx + dy * dy < rr * rr:
			_hurt(e_dmg[i])
			return


func _hurt(dmg: float) -> void:
	if iframes > 0 or shield > 0 or state != RUNNING:
		return
	if r_halo and halo_t <= 0:
		# Guardian Halo: the hit shatters the halo instead. The Chain holds.
		halo_t = Defs.HALO_TICKS
		iframes = 42
		events.append([EV_HALO, px, py])
		_shove(px, py, 170.0, 420.0)
		return
	var d := maxf(1.0, dmg - st_armor)
	hp -= d
	iframes = 42
	if first_hurt < 0:
		first_hurt = tick
	events.append([EV_HURT, d])
	if chain >= 10:
		events.append([EV_CHAIN_LOST, chain])
	chain = 0
	# Repulse: give the player room to breathe.
	_shove(px, py, 170.0, 420.0)
	# Vesper's bulwark answers every hit with a shockwave.
	if ship_id == "vesper":
		var vr := 260.0 * st_area
		novas.append({"x": px, "y": py, "r": 0.0, "max": vr, "step": vr / 14.0, "dmg": 18.0 * _od_scale() * 0.5,
				"hit": {}})
		events.append([EV_NOVA, px, py, vr])
	if hp <= 0.0:
		if revives > 0:
			revives -= 1
			hp = max_hp * 0.6
			iframes = 150
			events.append([EV_REVIVE])
			for i in en:
				var dx := e_x[i] - px
				var dy := e_y[i] - py
				if dx * dx + dy * dy < 450.0 * 450.0 and e_type[i] < Defs.WARDEN:
					if e_elite[i] == 1:
						e_hp[i] *= 0.5
					else:
						e_hp[i] = 0.0
			_shove(px, py, 600.0, 900.0)
			qn = 0
		else:
			hp = 0.0
			state = DEAD
			events.append([EV_DEAD])


func _shove(x: float, y: float, rad: float, force: float) -> void:
	for i in en:
		var dx := e_x[i] - x
		var dy := e_y[i] - y
		var d2 := dx * dx + dy * dy
		if d2 < rad * rad:
			var d := sqrt(d2) + 0.001
			e_vx[i] += dx / d * force * e_kb[i]
			e_vy[i] += dy / d * force * e_kb[i]


func _reap() -> void:
	for pass_i in 6:
		var any := false
		var i := en - 1
		while i >= 0:
			if i < en and e_hp[i] <= 0.0:
				_on_death(i)
				_e_remove(i)
				any = true
			i -= 1
		if _blasts.is_empty():
			if not any:
				break
		else:
			_grid_build()
			var bl := _blasts
			_blasts = []
			for b in bl:
				_explode(b[0], b[1], b[2], b[3])


func _on_death(i: int) -> void:
	var type := e_type[i]
	var x := e_x[i]
	var y := e_y[i]
	var elite := e_elite[i] == 1
	if e_state[i] == 9 and type == Defs.BOMBER:
		events.append([EV_KILL, x, y, type, false, e_r[i]])
		return
	kills += 1
	if elite:
		elite_kills += 1
	events.append([EV_KILL, x, y, type, elite, e_r[i]])
	chain += 1
	chain_t = Defs.CHAIN_TICKS
	chain_best = maxi(chain_best, chain)
	var worth := 10.0 + (250.0 if elite else 0.0) + (2500.0 if type >= Defs.WARDEN else 0.0)
	chain_score += int(worth * (Defs.chain_mult(chain) - 1.0) + 0.5)
	for tier in Defs.CHAIN_TIERS:
		if chain == int(tier[0]):
			events.append([EV_CHAIN, chain, tier[1]])
	if mods.has("bloodlight"):
		hp = minf(max_hp, hp + 0.25)
	if mods.has("volatile") and type < Defs.WARDEN and rng.unit() < 0.25:
		_blasts.append([x, y, 95.0, 16.0 * _od_scale()])
	if od_t <= 0:
		var was_ready := od >= od_need
		var gain := 40.0 if type >= Defs.WARDEN else (12.0 if elite else 1.0)
		if mods.has("overcharged"):
			gain *= 2.0
		if r_over:
			gain *= 1.75
		od = minf(od_need, od + gain)
		if not was_ready and od >= od_need:
			events.append([EV_OD_READY])
	var xpv: int = Defs.ENEMY[type].xp
	if elite:
		xpv = xpv * 8 + 10
	if mods.has("giants"):
		xpv *= 2
	if xpv > 0:
		_drop_gem(x, y, float(xpv))
	match type:
		Defs.SPLITTER:
			for k in 3:
				var a := e_ang[i] + k * Trig.STEPS / 3
				_spawn(Defs.MITE, x + Trig.cos_i(a) * 18.0, y + Trig.sin_i(a) * 18.0, false, 0)
		Defs.BOMBER:
			_blasts.append([x, y, 110.0, 30.0])
		Defs.WARDEN:
			bosses_killed += 1
			warden_down = true
			events.append([EV_BOSS_DOWN, type, x, y])
			_drop_pickup("bigchest", x, y)
			_drop_pickup("core", x + 70.0, y)
			_drop_pickup("heart", x - 70.0, y)
			for k in 12:
				var a2 := k * Trig.STEPS / 12
				_drop_gem(x + Trig.cos_i(a2) * 90.0, y + Trig.sin_i(a2) * 90.0, 10.0)
		Defs.SERAPH:
			bosses_killed += 1
			seraph_down = true
			events.append([EV_BOSS_DOWN, type, x, y])
			_drop_pickup("bigchest", x, y)
			_drop_pickup("core", x + 70.0, y)
			_drop_pickup("heart", x - 70.0, y)
			for k in 14:
				var a4 := k * Trig.STEPS / 14
				_drop_gem(x + Trig.cos_i(a4) * 100.0, y + Trig.sin_i(a4) * 100.0, 12.0)
		Defs.ECLIPSE:
			bosses_killed += 1
			events.append([EV_BOSS_DOWN, type, x, y])
			if endless:
				_drop_pickup("bigchest", x, y)
				_drop_pickup("heart", x - 70.0, y)
				for k in 16:
					var a3 := k * Trig.STEPS / 16
					_drop_gem(x + Trig.cos_i(a3) * 110.0, y + Trig.sin_i(a3) * 110.0, 14.0)
			else:
				dawn = true
				dawn_tick = tick
				state = WON
				events.append([EV_WIN])
	if elite:
		_drop_pickup("chest", x, y)
		# The first elite of a run guards a relic.
		if elite_kills == 1:
			pickups[pickups.size() - 1].relic = true
	elif type < Defs.WARDEN:
		var roll := rng.unit()
		if roll < 0.004:
			if not mods.has("bloodlight"):
				_drop_pickup("heart", x, y)
		elif roll < 0.0055:
			_drop_pickup("magnet", x, y)


# --- pickups ----------------------------------------------------------------------

func _drop_gem(x: float, y: float, v: float) -> void:
	if gn >= MAX_G:
		var k := rng.range_i(gn)
		g_val[k] += v
		return
	var i := gn
	gn += 1
	g_x[i] = x
	g_y[i] = y
	g_ox[i] = x
	g_oy[i] = y
	g_val[i] = v
	g_spd[i] = 0.0
	g_mag[i] = 0


func _drop_pickup(kind: String, x: float, y: float) -> void:
	pickups.append({"k": kind, "x": x, "y": y, "mag": false, "spd": 0.0})


func _update_gems() -> void:
	var m2 := st_magnet * st_magnet
	var i := gn - 1
	while i >= 0:
		var dx := px - g_x[i]
		var dy := py - g_y[i]
		var d2 := dx * dx + dy * dy
		if g_mag[i] == 0 and d2 < m2:
			g_mag[i] = 1
			g_spd[i] = -160.0
		var take := false
		if g_mag[i] == 1:
			g_spd[i] = minf(g_spd[i] + 48.0, 1600.0)
			var d := sqrt(d2) + 0.001
			var stepd := g_spd[i] * DT
			if d < 30.0 or stepd >= d:
				take = true
			else:
				g_x[i] += dx / d * stepd
				g_y[i] += dy / d * stepd
		if take:
			var v := g_val[i]
			xp += v * st_xp
			if ship_id == "halcyon":
				hp = minf(max_hp, hp + v * 0.08)
			events.append([EV_GEM, g_x[i], g_y[i], v])
			var l := gn - 1
			if i != l:
				g_x[i] = g_x[l]; g_y[i] = g_y[l]; g_ox[i] = g_ox[l]; g_oy[i] = g_oy[l]
				g_val[i] = g_val[l]; g_spd[i] = g_spd[l]; g_mag[i] = g_mag[l]
			gn = l
		i -= 1
	while xp >= xp_need:
		xp -= xp_need
		level += 1
		xp_need = need_for(level)
		pending_levels += 1


func _update_pickups() -> void:
	var k := pickups.size() - 1
	var m2 := st_magnet * st_magnet
	while k >= 0:
		var p: Dictionary = pickups[k]
		var dx: float = px - p.x
		var dy: float = py - p.y
		var d2 := dx * dx + dy * dy
		if not p.mag and d2 < m2:
			p.mag = true
			p.spd = -140.0
		var take := false
		if p.mag:
			p.spd = minf(p.spd + 40.0, 1400.0)
			var d := sqrt(d2) + 0.001
			var stepd: float = p.spd * DT
			if d < 34.0 or stepd >= d:
				take = true
			else:
				p.x += dx / d * stepd
				p.y += dy / d * stepd
		if take:
			match p.k:
				"heart":
					hp = minf(max_hp, hp + 30.0)
				"magnet":
					for g in gn:
						g_mag[g] = 1
				"core":
					xp += xp_need - xp + 0.001
					hp = minf(max_hp, hp + 15.0)
				"chest", "bigchest":
					_open_chest(p.k == "bigchest", p.x, p.y, p.get("relic", false))
			events.append([EV_PICKUP, p.k, p.x, p.y])
			pickups.remove_at(k)
		k -= 1
	while xp >= xp_need:
		xp -= xp_need
		level += 1
		xp_need = need_for(level)
		pending_levels += 1


## Prism Cache: evolves the first ready weapon, otherwise upgrades what you
## own (one item, or three from a boss). Always some Flux on top, and a relic
## choice from bosses and the first elite.
func _open_chest(big: bool, x: float, y: float, relic := false) -> void:
	caches_opened += 1
	var rewards: Array = []
	for w in weapons:
		if evolution_ready(w.id):
			w.lvl = Defs.EVO_LEVEL
			w.k = 0
			evolutions += 1
			rewards.append([w.id, Defs.EVO_LEVEL])
			events.append([EV_EVOLVE, w.id])
			events.append([EV_PICK, w.id, Defs.EVO_LEVEL])
			break
	var want := 3 if big else 1
	while rewards.size() < want:
		var pool: Array = []
		for w in weapons:
			if w.lvl < Defs.MAX_LEVEL:
				pool.append(w.id)
		for id in passive_order:
			if int(passives[id]) < Defs.MAX_LEVEL:
				pool.append(id)
		if pool.is_empty():
			break
		var id: String = pool[rng.range_i(pool.size())]
		_apply_card(id)
		rewards.append([id, card_level(id)])
	if rewards.is_empty():
		hp = minf(max_hp, hp + max_hp * 0.5)
		rewards.append(["heal", 0])
	var fl := 30 if big else 10
	if mods.has("lucky"):
		fl *= 2
	if r_midas:
		fl *= 3
	# Boss caches (and the first elite's) also hold a relic.
	if (big or relic) and relics.size() + pending_relics < Defs.RELIC_ORDER.size():
		pending_relics += 1
	flux_bonus += fl
	rewards.append(["flux", fl])
	events.append([EV_CHEST, rewards, big, x, y])


# --- level-up cards ---------------------------------------------------------------

func _start_choice() -> void:
	state = CHOOSING
	choices = _roll_choices()
	events.append([EV_LEVEL, level])


func _roll_choices() -> Array:
	var pool: Array = []
	var wts: Array = []
	for id in Defs.WEAPON_ORDER:
		var l := weapon_level(id)
		if l > 0 and l < Defs.MAX_LEVEL:
			pool.append(id)
			wts.append(3.0)
		elif l == 0 and weapons.size() < Defs.MAX_WEAPONS:
			# Eight weapons share the pool, so each new one is offered a little less.
			pool.append(id)
			wts.append(1.6)
	for id in Defs.PASSIVE_ORDER:
		if id == "renewal" and mods.has("bloodlight"):
			continue
		var l := int(passives.get(id, 0))
		if l > 0 and l < Defs.MAX_LEVEL:
			pool.append(id)
			wts.append(2.4)
		elif l == 0 and passives.size() < Defs.MAX_PASSIVES:
			pool.append(id)
			wts.append(1.4)
	var out: Array = []
	while out.size() < 3 and not pool.is_empty():
		var total := 0.0
		for w in wts:
			total += w
		var r := rng.unit() * total
		var pick := pool.size() - 1
		for k in pool.size():
			r -= wts[k]
			if r < 0.0:
				pick = k
				break
		out.append(pool[pick])
		pool.remove_at(pick)
		wts.remove_at(pick)
	if out.size() < 3:
		out.append("heal")
	if out.size() < 3:
		out.append("flux")
	return out


func _apply_card(id: String) -> void:
	if Defs.is_weapon(id):
		var found := false
		for w in weapons:
			if w.id == id:
				w.lvl = mini(w.lvl + 1, Defs.MAX_LEVEL)
				found = true
		if not found:
			weapons.append({"id": id, "lvl": 1, "t": 10, "k": 0, "a": 0})
		events.append([EV_PICK, id, weapon_level(id)])
	elif Defs.PASSIVES.has(id):
		if not passives.has(id):
			passive_order.append(id)
		passives[id] = int(passives.get(id, 0)) + 1
		_recompute()
		if id == "vitality":
			hp = minf(max_hp, hp + 20.0)
		events.append([EV_PICK, id, passives[id]])
	elif id == "heal":
		hp = minf(max_hp, hp + max_hp * 0.4)
		events.append([EV_PICK, id, 0])
	elif id == "flux":
		flux_bonus += 25
		events.append([EV_PICK, id, 0])


func _recompute() -> void:
	var lv := func(p: String) -> float: return float(passives.get(p, 0))
	var fl := func(f: String) -> float: return float(loadout.get(f, 0))
	var sh := func(k: String, d: float) -> float: return float(ship_stats.get(k, d))
	var new_max: float = 100.0 + sh.call("hp", 0.0) + 20.0 * lv.call("vitality") + 12.0 * fl.call("hull")
	if mods.has("glass"):
		new_max *= 0.5
	if new_max > max_hp:
		hp += new_max - max_hp
	max_hp = new_max
	hp = minf(hp, max_hp)
	st_speed = 300.0 * sh.call("speed", 1.0) * (1.0 + 0.08 * lv.call("thrusters") + 0.04 * fl.call("engine"))
	st_magnet = 125.0 * (1.0 + sh.call("magnet", 0.0) + 0.35 * lv.call("magnet") + 0.12 * fl.call("magnet"))
	if mods.has("gravity"):
		st_magnet *= 3.0
	st_haste = 1.0 - 0.08 * lv.call("overclock")
	st_might = 1.0 + sh.call("might", 0.0) + 0.12 * lv.call("amplifier") + 0.06 * fl.call("power")
	if mods.has("glass"):
		st_might += 0.4
	st_area = 1.0 + 0.12 * lv.call("lens")
	st_armor = sh.call("armor", 0.0) + 2.0 * lv.call("plating")
	st_crit = 0.05 + sh.call("crit", 0.0) + 0.07 * lv.call("fortune")
	if mods.has("lucky"):
		st_crit += 0.15
	if relics.has("supercrit"):
		st_crit += 0.1
	st_xp = 1.0 + sh.call("xp", 0.0) + 0.12 * lv.call("scholar") + (0.25 if relics.has("midas") else 0.0)
	st_regen = 0.4 * lv.call("renewal")
