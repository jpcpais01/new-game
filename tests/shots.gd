extends Node
## Screenshot helper (run as a scene, not with -s):
## xvfb-run -s "-screen 0 1280x2400x24" godot --path . --resolution 720x1280 res://tests/shots.tscn -- /tmp/shots
## Captures the title, a mid-run moment, the level-up cards, the pause menu,
## the results panel and the Forge.

var out := "/tmp/shots"
var main: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	Save.data.missions = ["alchemist", "exterminator", "first_flight"]
	Save.data.ship = "strix"
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(2.5)
	await _shot("1_title")
	if args.has("daily"):
		await _daily_shots()
		get_tree().quit()
		return
	if args.has("threats"):
		await _threat_shots()
		get_tree().quit()
		return
	if args.has("arsenal"):
		await _arsenal_shots()
		get_tree().quit()
		return
	if args.has("radiance"):
		await _radiance_shots()
		get_tree().quit()
		return
	if args.has("rifts"):
		await _rift_shots()
		get_tree().quit()
		return
	if args.has("ricochet"):
		await _ricochet_shots()
		get_tree().quit()
		return
	if args.has("leviathan"):
		await _levi_shots()
		get_tree().quit()
		return
	if args.has("gauntlet"):
		await _gauntlet_shots()
		get_tree().quit()
		return
	if args.has("sectors"):
		await _sector_shots()
		get_tree().quit()
		return
	if args.has("resonance"):
		await _resonance_shots()
		get_tree().quit()
		return
	if args.has("shards"):
		await _shard_shots()
		get_tree().quit()
		return
	if args.has("traits"):
		await _trait_shots()
		get_tree().quit()
		return
	if args.has("report"):
		await _report_shots()
		get_tree().quit()
		return
	main.start_run()
	await _wait(1.0)
	var gs = main.screen
	# Fast-forward the run with the autopilot so the screen is busy.
	var s: Sim = gs.sim
	s.loadout = {"hull": 5}
	while s.seconds() < 150.0 and s.state != Sim.DEAD:
		if s.state == Sim.CHOOSING:
			s.choose(Autopilot.pick(s))
		else:
			var m := Autopilot.move(s)
			s.step(m.x, m.y)
		s.events.clear()
	main.arena.demo = true
	await _wait(1.6)
	main.arena.demo = false
	await _shot("2_run")
	# Overdrive: charged, then unleashed.
	s.od = s.od_need
	await _wait(0.6)
	await _shot("2a_od_ready")
	gs._od.trigger()
	await _wait(0.45)
	await _shot("2d_overdrive")
	# Evolved arsenal in action.
	s.weapons = [
		{"id": "pulse", "lvl": Defs.EVO_LEVEL, "t": 5, "k": 0, "a": 0},
		{"id": "orbit", "lvl": Defs.EVO_LEVEL, "t": 5, "k": 0, "a": 0},
		{"id": "nova", "lvl": Defs.EVO_LEVEL, "t": 5, "k": 0, "a": 0},
		{"id": "lance", "lvl": Defs.EVO_LEVEL, "t": 5, "k": 0, "a": 0},
	]
	s.hp = s.max_hp
	main.arena.demo = true
	await _wait(1.3)
	main.arena.demo = false
	await _shot("2b_evolved")
	# A Prism Cache that evolves the Seeker Swarm.
	s.weapons[3] = {"id": "seeker", "lvl": Defs.MAX_LEVEL, "t": 5, "k": 0, "a": 0}
	s.passives["fortune"] = 1
	s.passive_order.append("fortune")
	s.pickups.append({"k": "bigchest", "x": s.px, "y": s.py, "mag": true, "spd": 0.0})
	await _wait(3.4)
	await _shot("2c_cache")
	gs._chest.visible = false
	gs._on_chest_closed()
	await _wait(0.8)
	# The boss cache also holds a relic.
	if s.relic_choice:
		await _shot("2e_relic")
		gs._cards._pick(0)
		await _wait(0.8)
	s.xp = s.xp_need
	main.arena.demo = false
	await _wait(1.2)
	await _shot("3_levelup")
	gs._cards._pick(0)
	await _wait(0.8)
	gs.open_pause()
	await _wait(0.7)
	await _shot("4_pause")
	gs._pause.close()
	gs._resume()
	await _wait(0.3)
	s.state = Sim.DEAD
	s.warden_down = true
	gs._on_end(false)
	await _wait(1.6)
	await _shot("5_results")
	Save.data.flux = 900
	main.go_forge()
	await _wait(1.2)
	await _shot("6_forge")
	main.go_hangar()
	await _wait(1.2)
	await _shot("7_hangar")
	main.screen._show(1, 1)
	await _wait(0.8)
	await _shot("7b_hangar_vesper")
	main.screen._show(6, 1)
	await _wait(0.8)
	await _shot("7c_hangar_locked")
	main.go_missions()
	await _wait(1.4)
	await _shot("8_missions")
	get_tree().quit()


## The Daily Run, the dawn choice, the Afterdark, the results and the Codex.
func _daily_shots() -> void:
	Save.data.evolved = ["pulse", "nova"]
	Save.data.daily_log = [
		{"day": Save.today() - 1, "score": 84210, "time": 512.0, "kills": 6400, "dawn": false, "ship": "kestrel", "tries": 3},
		{"day": Save.today() - 2, "score": 131560, "time": 690.0, "kills": 9100, "dawn": true, "ship": "vesper", "tries": 1},
	]
	Save.data.daily_last = Save.today() - 1
	Save.data.daily_streak = 2
	Save.data.daily_streak_best = 2
	main.go_daily()
	await _wait(1.4)
	await _shot("d1_daily")
	main.start_daily()
	await _wait(1.6)
	await _shot("d2_daily_intro")
	var gs = main.screen
	var s: Sim = gs.sim
	while s.state != Sim.WON and s.state != Sim.DEAD and s.tick < 10 * 60 * Sim.TPS:
		if s.state == Sim.CHOOSING:
			s.choose(Autopilot.pick(s))
		else:
			var m := Autopilot.move(s)
			s.step(m.x, m.y, Autopilot.burst(s))
		s.events.clear()
	if s.state != Sim.WON:
		# Force the dawn so the screens below have something to show.
		s.state = Sim.RUNNING
		var i := s._spawn(Defs.ECLIPSE, s.px + 500.0, s.py, false, 0)
		s.e_hp[i] = 0.0
		s.step(0, 0)
		s.events.clear()
	gs._on_end(true)
	await _wait(1.4)
	await _shot("d3_dawn")
	var dp = gs._dawn
	dp.chose.emit(true)
	dp.close()
	await _wait(0.3)
	s.tick = s.night_next - 1
	main.arena.demo = true
	await _wait(3.5)
	main.arena.demo = false
	await _shot("d4_afterdark")
	s.state = Sim.DEAD
	gs._on_end(false)
	await _wait(2.5)
	await _shot("d5_results")
	main.go_codex()
	await _wait(1.4)
	await _shot("d6_codex")
	main.go_title()
	await _wait(2.0)
	await _shot("d7_title_after")


## The Sentinel, Phantom and Bastion, the Chain and the Seraph's three phases.
func _threat_shots() -> void:
	main.start_run()
	await _wait(1.0)
	var gs = main.screen
	var s: Sim = gs.sim
	Save.data.tutorial_done = true
	gs._hide_hint()
	while s.seconds() < 330.0 and s.state != Sim.DEAD:
		if s.state == Sim.CHOOSING:
			s.choose(Autopilot.pick(s))
		else:
			var m := Autopilot.move(s)
			s.iframes = 2
			s.step(m.x, m.y)
			var w := s.boss_index()
			if w >= 0 and s.e_type[w] == Defs.WARDEN:
				s.e_hp[w] = 0.0
		s.events.clear()
	s.hp = s.max_hp
	for k in 3:
		var e := s._spawn(Defs.SENTINEL, s.px + 260.0 * cos(k * 2.1), s.py + 260.0 * sin(k * 2.1), false, 0)
		s.e_t[e] = 0
	var b := s._spawn(Defs.BASTION, s.px - 200.0, s.py - 320.0, false, 0)
	for k in 6:
		s._spawn(Defs.DRIFTER, s.e_x[b] + 90.0 * cos(k), s.e_y[b] + 90.0 * sin(k), false, 0)
	var f := s._spawn(Defs.PHANTOM, s.px + 500.0, s.py + 300.0, false, 0)
	s.e_t[f] = 0
	main.arena.demo = true
	await _wait(1.2)
	main.arena.demo = false
	await _shot("t1_threats")
	s.chain = 312
	s.chain_t = Defs.CHAIN_TICKS
	await _wait(0.6)
	await _shot("t2_chain")
	while s.boss_index() < 0 and s.state != Sim.DEAD:
		if s.state == Sim.CHOOSING:
			s.choose(Autopilot.pick(s))
		else:
			var m := Autopilot.move(s)
			s.iframes = 2
			s.step(m.x, m.y)
		s.events.clear()
	s.e_hp[s.boss_index()] = s.e_maxhp[s.boss_index()] * 20.0
	s.e_maxhp[s.boss_index()] *= 20.0
	s.hp = s.max_hp
	for st in [2, 3, 5]:
		while s.state != Sim.DEAD and s.boss_index() >= 0 and s.e_state[s.boss_index()] != st:
			if s.state == Sim.CHOOSING:
				s.choose(Autopilot.pick(s))
			else:
				var m := Autopilot.move(s)
				s.step(m.x, m.y)
			s.iframes = 2
			s.events.clear()
		main.arena.demo = true
		await _wait(0.35)
		main.arena.demo = false
		await _shot("t3_seraph_%d" % st)
	main.go_codex()
	await _wait(1.2)
	var sc: Array = main.screen.find_children("*", "ScrollContainer", true, false)
	if not sc.is_empty():
		sc[0].scroll_vertical = 2400
	await _wait(0.5)
	await _shot("t4_codex")


## The warp-in, the Ion Scythe and Photon Mines, their evolutions, a relic
## offer and the relics in the pause menu and the Codex.
func _arsenal_shots() -> void:
	Save.data.tutorial_done = true
	main.start_run()
	await _wait(0.3)
	await _shot("a0_warp")
	await _wait(0.7)
	var gs = main.screen
	var s: Sim = gs.sim
	gs._hide_hint()
	while s.seconds() < 140.0 and s.state != Sim.DEAD:
		if s.state == Sim.CHOOSING:
			s.choose(Autopilot.pick(s))
		else:
			var m := Autopilot.move(s)
			s.iframes = 2
			s.step(m.x, m.y)
		s.events.clear()
	s.hp = s.max_hp
	s.weapons = [
		{"id": "pulse", "lvl": 4, "t": 5, "k": 0, "a": 0},
		{"id": "scythe", "lvl": 5, "t": 5, "k": 0, "a": 0},
		{"id": "mine", "lvl": 5, "t": 5, "k": 0, "a": 0},
	]
	for id in ["wake", "halo"]:
		s._take_relic(id)
	s.events.clear()
	gs._hud._rebuild_loadout()
	main.arena.demo = true
	await _wait(2.0)
	main.arena.demo = false
	await _shot("a1_arsenal")
	s.weapons[1].lvl = Defs.EVO_LEVEL
	s.weapons[2].lvl = Defs.EVO_LEVEL
	main.arena.demo = true
	await _wait(2.4)
	main.arena.demo = false
	await _shot("a2_evolved")
	s.pickups.append({"k": "chest", "x": s.px, "y": s.py, "mag": true, "spd": 0.0, "relic": true})
	main.arena.demo = false
	await _wait(3.4)
	gs._chest.visible = false
	gs._on_chest_closed()
	await _wait(1.0)
	await _shot("a3_relic")
	gs._cards._pick(0)
	await _wait(0.8)
	gs.open_pause()
	await _wait(0.7)
	await _shot("a4_pause")
	gs._pause.close()
	gs._resume()
	main.go_codex()
	await _wait(1.2)
	var sc: Array = main.screen.find_children("*", "ScrollContainer", true, false)
	if not sc.is_empty():
		sc[0].scroll_vertical = 1500
	await _wait(0.5)
	await _shot("a5_codex")


func _radiance_shots() -> void:
	Save.data.tutorial_done = true
	Save.data.radiance_cleared = 2
	Save.data.radiance = 3
	Save.data.tips = []
	Save.data.ship_best = {"strix": {"time": 540.0, "score": 182000, "dawn": true, "radiance": 2}}
	main.go_hangar()
	await _wait(1.2)
	await _shot("r0_hangar")
	main.start_run()
	await _wait(1.4)
	await _shot("r1_intro")
	var gs = main.screen
	var s: Sim = gs.sim
	gs._hide_hint()
	while s.seconds() < 70.0 and s.state != Sim.DEAD:
		if s.state == Sim.CHOOSING:
			s.choose(Autopilot.pick(s))
		else:
			var m := Autopilot.move(s)
			s.iframes = 2
			s.step(m.x, m.y)
		s.events.clear()
	s.xp = s.xp_need
	main.arena.demo = false
	await _wait(1.4)
	await _shot("r2_cards")
	gs._cards._toggle_banish()
	await _wait(0.3)
	await _shot("r3_banish_mode")
	gs._cards._on_card(gs._cards._cards[0])
	await _wait(0.8)
	await _shot("r4_banished")
	gs._cards._pick(1)
	await _wait(1.0)
	s.iframes = 0
	s._hurt(12.0)
	main.arena.handle_events()
	await _wait(0.06)
	await _shot("r5_hurt")
	gs._on_coach("elite")
	await _wait(0.8)
	await _shot("r6_tip")
	s.od = s.od_need
	await _wait(0.3)
	gs._od.trigger()
	await _wait(0.12)
	await _shot("r7_overdrive")
	s.dawn = true
	s.state = Sim.DEAD
	gs._on_end(false)
	await _wait(1.6)
	await _shot("r8_results")


## Round 8: a beacon from afar and charging, the wisp, an Umbral Trial, the
## Umbral relic offer and the Codex.
func _rift_shots() -> void:
	main.start_run()
	await _wait(1.0)
	var gs = main.screen
	var s: Sim = gs.sim
	gs._hide_hint()
	while s.seconds() < 47.0 and s.state != Sim.DEAD:
		if s.state == Sim.CHOOSING:
			s.choose(Autopilot.pick(s))
		else:
			s.iframes = 2
			s.step(0, 0)
		s.events.clear()
	await _wait(3.6)
	await _shot("k1_rift_opens")
	await _wait(2.5)
	s.px = float(s.rift.x) + 40.0
	s.py = float(s.rift.y) + 30.0
	s.ppx = s.px
	s.ppy = s.py
	main.arena.demo = true
	s.rift.prog = 180.0
	await _wait(1.0)
	main.arena.demo = false
	await _shot("k2_beacon")
	s.rift.prog = 299.0
	await _wait(1.6)
	await _shot("k3_beacon_lit")
	if gs._chest.visible:
		gs._chest.visible = false
		gs._on_chest_closed()
	await _wait(0.5)
	s.rift = {"kind": Defs.RIFT_WISP, "x": s.px + 300.0, "y": s.py - 200.0, "ox": s.px + 300.0, "oy": s.py - 200.0,
			"life": 1500, "on": false, "prog": 0.0, "k0": 0, "goal": 0}
	main.arena.demo = true
	await _wait(1.4)
	main.arena.demo = false
	await _shot("k4_wisp")
	s.rift = {"kind": Defs.RIFT_TRIAL, "x": s.px + 30.0, "y": s.py, "ox": s.px + 30.0, "oy": s.py,
			"life": 1500, "on": false, "prog": 0.0, "k0": 0, "goal": 0}
	await _wait(1.5)
	await _shot("k5_trial")
	s.kills += 9999
	await _wait(1.6)
	await _shot("k6_umbral_offer")
	gs._cards.decline_pressed.emit()
	await _wait(2.5)
	await _shot("k7_refused")
	if gs._chest.visible:
		gs._chest.visible = false
		gs._on_chest_closed()
	s._take_relic("u_crown")
	s._take_relic("u_sun")
	gs._hud._rebuild_loadout()
	await _wait(0.6)
	s.state = Sim.DEAD
	gs._on_end(false)
	await _wait(1.6)
	await _shot("k8_results")
	main.go_codex()
	await _wait(1.0)
	var sc: Array = main.screen.find_children("*", "ScrollContainer", true, false)
	if not sc.is_empty():
		sc[0].scroll_vertical = 2600
	await _wait(0.5)
	await _shot("k9_codex")


func _ricochet_shots() -> void:
	Save.data.missions = ["alchemist", "exterminator", "first_flight", "unbroken"]
	Save.data.ship = "echo"
	main.go_hangar()
	await _wait(1.2)
	await _shot("r0_hangar_echo")
	main.start_run()
	await _wait(1.0)
	var gs = main.screen
	var s: Sim = gs.sim
	gs._hide_hint()
	s.rift_next = 1 << 30
	while s.seconds() < 120.0 and s.state != Sim.DEAD:
		if s.state == Sim.CHOOSING:
			s.choose(Autopilot.pick(s))
		else:
			var m := Autopilot.move(s)
			s.iframes = 2
			s.step(m.x, m.y)
		s.events.clear()
	s.weapons[0].lvl = Defs.EVO_LEVEL
	gs._hud._rebuild_loadout()
	main.arena.demo = true
	await _wait(1.8)
	main.arena.demo = false
	await _shot("r1_ouroboros")
	s.od = s.od_need
	s.chain = 140
	s.chain_t = 600
	main.arena.burst_request = true
	await _wait(0.6)
	await _shot("r2_encore")
	await _wait(1.0)
	s.rift = {"kind": Defs.RIFT_STARFALL, "x": s.px + 60.0, "y": s.py - 40.0, "ox": s.px + 60.0, "oy": s.py - 40.0,
			"life": 1500, "on": false, "prog": 0.0, "k0": 0, "goal": 0, "mets": []}
	await _wait(0.4)
	await _shot("r3_starfall_ring")
	s.rift.prog = 240.0
	main.arena.demo = true
	await _wait(1.6)
	main.arena.demo = false
	await _shot("r4_starfall")
	await _wait(0.5)
	main.go_codex()
	await _wait(1.0)
	await _shot("r5_codex")


func _levi_shots() -> void:
	Save.data.ship_best["strix"] = {"time": 500.0, "score": 90000, "dawn": true, "radiance": 6}
	main.go_hangar()
	await _wait(1.2)
	await _shot("l0_hangar_helix")
	Save.data.ship_best["strix"].radiance = 10
	main.start_run()
	await _wait(1.0)
	var gs = main.screen
	var s: Sim = gs.sim
	gs._hide_hint()
	s.rift_next = 1 << 30
	while s.seconds() < 124.0 and s.state != Sim.DEAD:
		if s.state == Sim.CHOOSING:
			s.choose(Autopilot.pick(s))
		else:
			var m := Autopilot.move(s)
			s.iframes = 2
			s.step(m.x, m.y)
		s.events.clear()
	gs._hud._rebuild_loadout()
	var h := s.boss_index()
	if h >= 0:
		s.e_maxhp[h] = 1e6
		s.e_hp[h] = 0.8e6
	gs._hud._boss_intro(Defs.LEVIATHAN)
	main.arena.demo = true
	await _wait(0.9)
	await _shot("l0_intro")
	await _wait(1.7)
	await _shot("l1_arrival")
	for k in 3:
		while h >= 0 and s.e_state[h] != [1, 3, 4][k]:
			await _wait(0.05)
			s.hp = s.max_hp
			h = s.boss_index()
		if k == 0:
			await _wait(1.6)
		await _shot(["l2_coil", "l3_rear", "l4_lunge"][k])
	if h >= 0:
		s.e_hp[h] = s.e_maxhp[h] * 0.3
		await _wait(0.12)
		await _shot("l5_shed")
		s.e_hp[h] = 0.0
		await _wait(0.4)
		await _shot("l6_burst")
	await _wait(1.0)
	main.go_codex()
	await _wait(1.0)
	await _shot("l7_codex")


func _gauntlet_shots() -> void:
	Save.data.missions.append("warden")
	Save.data.gauntlet = {"runs": 3, "clears": 1, "best_clear": 13800, "best_felled": 5, "best_stage": 5,
			"best_score": 61000, "splits": [1500, 2100, 3300, 0]}
	main.go_title()
	await _wait(1.6)
	await _shot("g0_title")
	main.go_gauntlet()
	await _wait(1.2)
	await _shot("g1_screen")
	main.start_gauntlet()
	await _wait(1.6)
	await _shot("g2_draft")
	var gs = main.screen
	var s: Sim = gs.sim
	gs._hide_hint()
	gs._cards.close()
	main.arena.paused = false
	while s.g_stage < 1 or s.g_next < 0 or s.gauntlet_wait() > 4.0:
		if s.state == Sim.CHOOSING:
			s.choose(Autopilot.pick(s))
		elif s.state == Sim.RUNNING:
			var m := Autopilot.move(s)
			s.iframes = 2
			s.step(m.x, m.y, Autopilot.burst(s))
			if s.g_stage < 1 and s.boss_index() >= 0 and s.tick - s.g_boss_tick > 600:
				s.e_hp[s.boss_index()] = 1.0
		else:
			break
		s.events.clear()
	gs._hud._rebuild_loadout()
	main.arena.demo = true
	await _wait(0.6)
	main.arena.demo = false
	await _shot("g3_breather")
	gs._hud._on_split(0, 1320, true)
	await _wait(0.6)
	await _shot("g4_split")
	while s.boss_index() < 0 and s.state != Sim.DEAD:
		if s.state == Sim.CHOOSING:
			s.choose(Autopilot.pick(s))
		else:
			var m := Autopilot.move(s)
			s.iframes = 2
			s.step(m.x, m.y)
		s.events.clear()
	main.arena.demo = true
	await _wait(3.4)
	await _shot("g5_warden")
	main.arena.demo = false
	s.state = Sim.DEAD
	gs._on_end(false)
	await _wait(2.2)
	await _shot("g6_results")


## Fast-forwards the open run until `done` says stop, keeping the ship alive.
func _ff(s: Sim, done: Callable, limit: int) -> void:
	while not done.call() and s.tick < limit and s.state != Sim.DEAD:
		if s.state == Sim.CHOOSING:
			s.choose(Autopilot.pick(s))
		elif s.state == Sim.RUNNING:
			var m := Autopilot.move(s)
			s.iframes = 2
			s.step(m.x, m.y, Autopilot.burst(s))
		else:
			break
		s.events.clear()


func _sector_shots() -> void:
	Save.data.missions.append("warden")
	Save.data.missions.append("dawn")
	Save.data.sector = Defs.SECTOR_ABYSS
	Save.data.sector_best = {"abyss": {"time": 412.0, "score": 88210, "dawn": false}}
	main.go_title()
	await _wait(1.6)
	await _shot("s0_title")
	main.go_hangar()
	await _wait(1.4)
	await _shot("s1_hangar")
	main.start_run()
	await _wait(2.0)
	await _shot("s2_abyss_intro")
	var gs = main.screen
	var s: Sim = gs.sim
	gs._hide_hint()
	_ff(s, func(): return not s.maws.is_empty() and int(s.maws[0].t) > 400 and s.en > 60, 200 * Sim.TPS)
	if not s.maws.is_empty():
		s.px = float(s.maws[0].x) + 260.0
		s.py = float(s.maws[0].y) + 120.0
	gs._hud._rebuild_loadout()
	main.arena.demo = true
	await _wait(1.2)
	await _shot("s3_abyss")
	if not s.maws.is_empty():
		s.maws[0].t = int(s.maws[0].life) - 20
	await _wait(0.6)
	await _shot("s4_collapse")
	main.arena.demo = false
	s.state = Sim.DEAD
	gs._on_end(false)
	await _wait(2.4)
	await _shot("s5_results")
	Save.data.sector = Defs.SECTOR_CORONA
	main.start_run()
	await _wait(2.0)
	gs = main.screen
	s = gs.sim
	gs._hide_hint()
	_ff(s, func(): return not s.flare.is_empty() and int(s.flare.t) > 50 and s.tick > 100 * Sim.TPS, 200 * Sim.TPS)
	gs._hud._rebuild_loadout()
	main.arena.demo = true
	await _wait(0.5)
	await _shot("s6_corona_warn")
	_ff(s, func(): return not s.flare.is_empty() and float(s.flare.r) > 520.0, 220 * Sim.TPS)
	await _wait(0.1)
	await _shot("s7_flare")
	main.arena.demo = false


func _shard_shots() -> void:
	Save.data.missions.append("warden")
	Save.data.missions.append("dawn")
	Save.data.missions.append("seraphfall")
	Save.data.sector = Defs.SECTOR_SHARD
	main.go_hangar()
	await _wait(1.4)
	await _shot("c1_hangar")
	main.start_run()
	await _wait(2.0)
	await _shot("c2_intro")
	var gs = main.screen
	var s: Sim = gs.sim
	gs._hide_hint()
	_ff(s, func(): return s.tick > 215 * Sim.TPS and s.en > 80, 260 * Sim.TPS)
	# Stand beside the nearest crystal and charge it most of the way.
	var best := 0
	var bd := INF
	for k in s.shards.size():
		var c: Dictionary = s.shards[k]
		var d := Vector2(float(c.x) - s.px, float(c.y) - s.py).length()
		if d < bd and int(c.st) == 0:
			bd = d
			best = k
	var cb: Dictionary = s.shards[best]
	s.px = float(cb.x) + float(cb.r) + 90.0
	s.py = float(cb.y) + 40.0
	s.ppx = s.px
	s.ppy = s.py
	cb.charge = s.shard_full() * 0.8
	gs._hud._rebuild_loadout()
	main.arena.demo = true
	await _wait(1.0)
	await _shot("c3_field")
	cb.charge = s.shard_full() + 1.0
	s._shard_charge(best, 0.0)
	cb.st = 1
	cb.t = 12
	await _wait(0.12)
	await _shot("c4_resonate")
	await _wait(0.35)
	await _shot("c5_shatter")
	main.arena.demo = false
	s.state = Sim.DEAD
	gs._on_end(false)
	await _wait(2.4)
	await _shot("c6_results")
	main.go_codex()
	await _wait(1.2)
	await _shot("c7_codex")


func _trait_shots() -> void:
	Save.data.tutorial_done = true
	Save.data.trait_kills = {"brood": 3, "swift": 1}
	main.start_run()
	await _wait(1.0)
	var gs = main.screen
	var s: Sim = gs.sim
	gs._hide_hint()
	_ff(s, func(): return s.seconds() > 150.0, 170 * Sim.TPS)
	s.hp = s.max_hp
	s.xp = 0.0
	# Clear the field, then bring in a cast of trait elites around the ship.
	for i in s.en:
		s.e_hp[i] = 0.0
	s.step(0, 0)
	s.events.clear()
	var cast := [[Defs.BRUTE, 260.0, -300.0, ["shielded", "pulsar"]], [Defs.SPITTER, -280.0, -220.0, ["starcaller"]],
			[Defs.WEAVER, 300.0, 260.0, ["graviton", "leech", "swift"]], [Defs.SPLITTER, -260.0, 280.0, ["brood", "phasing"]]]
	for c in cast:
		var i := s._spawn(c[0], s.px + c[1], s.py + c[2], true, 0)
		var mask := 0
		for id in c[3]:
			mask |= Defs.trait_bit(id)
		s._give_traits(i, 0, false, mask)
	for k in 14:
		var a := k * Trig.STEPS / 14
		s._spawn(Defs.DRIFTER, s.px + Trig.cos_i(a) * 520.0, s.py + Trig.sin_i(a) * 520.0, false, 0)
	main.arena.elite_arrived.emit(Defs.WEAVER, Defs.trait_bit("graviton") | Defs.trait_bit("leech") |
			Defs.trait_bit("swift"))
	main.arena.demo = true
	for k in 20:
		s.step(0, 0)
	# A pulsar mid-swell, a barrier, stars on the way down.
	for i in s.en:
		var st := s.trait_state(i)
		if not st.is_empty():
			st.tt = Defs.PULSAR_EVERY - 20
	s.stars.append([s.px + 40.0, s.py + 10.0, 24, 0, 10.0])
	s.stars.append([s.px - 150.0, s.py + 120.0, 44, 0, 10.0])
	main.arena.demo = false
	await _wait(0.5)
	await _shot("t1_card")
	main.arena.demo = true
	await _wait(1.6)
	await _shot("t2_field")
	# A trophy: the exalted weaver falls.
	for i in s.en:
		if s.e_tr[i] == (Defs.trait_bit("graviton") | Defs.trait_bit("leech") | Defs.trait_bit("swift")):
			s.e_hp[i] = 1.0
			s._damage(i, 9999.0, 0.0, 0.0)
	main.arena.demo = false
	await _wait(0.5)
	await _shot("t3_trophy")
	s.state = Sim.DEAD
	gs._on_end(false)
	await _wait(2.4)
	await _shot("t4_results")
	main.go_codex()
	await _wait(1.0)
	var sc := _find_scroll(main.screen)
	if sc != null:
		sc.scroll_vertical = 5200
	await _wait(0.6)
	await _shot("t5_codex")


func _find_scroll(n: Node) -> ScrollContainer:
	if n is ScrollContainer:
		return n
	for c in n.get_children():
		var f := _find_scroll(c)
		if f != null:
			return f
	return null


func _resonance_shots() -> void:
	Save.data.tutorial_done = true
	Save.data.resonances = ["surge"]
	main.start_run()
	await _wait(1.0)
	var gs = main.screen
	var s: Sim = gs.sim
	gs._hide_hint()
	_ff(s, func(): return s.seconds() > 95.0, 120 * Sim.TPS)
	s.hp = s.max_hp
	s.weapons = [
		{"id": "pulse", "lvl": 1, "t": 5, "k": 0, "a": 0},
		{"id": "arc", "lvl": 2, "t": 5, "k": 0, "a": 0},
		{"id": "nova", "lvl": 2, "t": 5, "k": 0, "a": 0},
		{"id": "orbit", "lvl": 1, "t": 5, "k": 0, "a": 0},
	]
	s.events.clear()
	gs._hud._rebuild_loadout()
	s.state = Sim.CHOOSING
	s.pending_levels = 0
	s.choices = ["pulse", "orbit", "amplifier"]
	gs._open_cards()
	await _wait(1.2)
	await _shot("r1_cards")
	gs._cards._pick(0)
	await _wait(1.3)
	await _shot("r2_reveal")
	await _wait(2.6)
	s._apply_card("orbit")
	main.arena.handle_events()
	await _wait(3.4)
	main.arena.demo = true
	_ff(s, func(): return s.surge_t > 30, s.tick + 600)
	await _wait(0.05)
	await _shot("r3_surge")
	main.arena.demo = false
	# Bladestorm, Reap and Sow and Tesla Field together.
	s.weapons = [
		{"id": "orbit", "lvl": 4, "t": 5, "k": 0, "a": 0},
		{"id": "scythe", "lvl": 4, "t": 5, "k": 0, "a": 0},
		{"id": "mine", "lvl": 4, "t": 5, "k": 0, "a": 0},
		{"id": "arc", "lvl": 4, "t": 5, "k": 0, "a": 0},
	]
	s._check_resonances()
	s.events.clear()
	gs._hud._rebuild_loadout()
	main.arena.demo = true
	await _wait(2.0)
	await _shot("r4_bladestorm")
	main.arena.demo = false
	gs.open_pause()
	await _wait(0.7)
	await _shot("r5_pause")
	gs._pause.close()
	gs._resume()
	Save.data.resonances = ["surge", "conductor", "bladestorm", "sow", "tesla"]
	main.go_codex()
	await _wait(1.2)
	var sc: Array = main.screen.find_children("*", "ScrollContainer", true, false)
	if not sc.is_empty():
		sc[0].scroll_vertical = 1180
	await _wait(0.6)
	await _shot("r6_codex")
	if not sc.is_empty():
		sc[0].scroll_vertical = 1900
	await _wait(0.4)
	await _shot("r7_codex_list")


## The after-action report: a long autopiloted run, the results strip, the
## full report (scrolled to the timeline and highlights) and the live one in pause.
func _report_shots() -> void:
	main.start_run()
	await _wait(1.0)
	var gs = main.screen
	var s: Sim = gs.sim
	gs._hide_hint()
	# No i-frames here: the hull line should show the hits.
	while s.seconds() < 300.0 and s.state != Sim.DEAD:
		if s.state == Sim.CHOOSING:
			s.choose(Autopilot.pick(s))
		else:
			var m := Autopilot.move(s)
			s.step(m.x, m.y, Autopilot.burst(s))
		s.events.clear()
	s.state = Sim.RUNNING
	s.hp = maxf(s.hp, 1.0)
	gs._hud._rebuild_loadout()
	main.arena.demo = true
	await _wait(1.0)
	main.arena.demo = false
	gs.open_pause()
	await _wait(0.5)
	var rp := ReportPanel.new()
	rp.sim = s
	rp.live = true
	gs._pause.add_child(rp)
	await _wait(2.2)
	await _shot("x1_live_report")
	rp.close()
	gs._pause.close()
	gs._resume()
	await _wait(0.3)
	s.state = Sim.DEAD
	gs._on_end(false)
	await _wait(2.0)
	var sc: Array = gs.find_children("*", "ScrollContainer", true, false)
	if not sc.is_empty():
		sc[sc.size() - 1].scroll_vertical = 420
	await _wait(0.6)
	await _shot("x2_results")
	var full := ReportPanel.new()
	full.sim = s
	gs.add_child(full)
	await _wait(2.4)
	await _shot("x3_report")
	var sc2: Array = full.find_children("*", "ScrollContainer", true, false)
	if not sc2.is_empty():
		sc2[0].scroll_vertical = 1100
	await _wait(1.8)
	await _shot("x4_timeline")
	if not sc2.is_empty():
		sc2[0].scroll_vertical = 3000
	await _wait(0.8)
	await _shot("x5_highlights")


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("shot ", name)
