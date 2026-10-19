class_name Daily
extends RefCounted
## The Daily Run: one seeded run per UTC day, the same for every player. The
## day number (days since 1970-01-01 UTC) is the only input, so this stays a
## pure function; the view reads the calendar and passes the day in.

## Day numbers are mixed with this so day 1 and seed 1 are unrelated runs.
const SALT := 0x5EED_D41

## Everything that defines a day's run: seed, ship and mutators. Daily runs
## ignore the Forge so every pilot starts equal.
static func for_day(day: int) -> Dictionary:
	var h := GlowRng.mix32((day * 2654435761 + SALT) & GlowRng.MASK)
	var r := GlowRng.new(h)
	var ship: String = Defs.SHIPS[r.range_i(Defs.SHIPS.size())].id
	var boons: Array = Defs.BOONS.duplicate()
	var banes: Array = Defs.BANES.duplicate()
	var mods: Array = [boons[r.range_i(boons.size())]]
	for k in 2:
		var j := r.range_i(banes.size())
		mods.append(banes[j])
		banes.remove_at(j)
	return {
		"day": day, "seed": r.next_u32(), "ship": ship, "mods": mods,
		"loadout": {"ship": ship, "mods": mods, "daily": day},
	}


## Score multiplier for a set of mutators (each bane adds its share).
static func multiplier(mods: Array) -> float:
	var m := 1.0
	for id in mods:
		m += float(Defs.MUTATORS.get(id, {}).get("score", 0.0))
	return m


## Calendar date for a day number, as {year, month, day} (proleptic Gregorian).
static func date_of(day: int) -> Dictionary:
	# Howard Hinnant's days-to-civil algorithm, integer only.
	var z := day + 719468
	var era := (z if z >= 0 else z - 146096) / 146097
	var doe := z - era * 146097
	var yoe := (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
	var y := yoe + era * 400
	var doy := doe - (365 * yoe + yoe / 4 - yoe / 100)
	var mp := (5 * doy + 2) / 153
	var d := doy - (153 * mp + 2) / 5 + 1
	var m := mp + 3 if mp < 10 else mp - 9
	return {"year": y + (1 if m <= 2 else 0), "month": m, "day": d}


const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]


static func label(day: int) -> String:
	var d := date_of(day)
	return "%s %d" % [MONTHS[int(d.month) - 1], int(d.day)]
