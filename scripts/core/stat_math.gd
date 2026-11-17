class_name StatMath
extends RefCounted
## Natural energy concentrations and artificial technology fields modify machine stats.
##
## mult(stat) = clamp(1 + sum_e influence[e][stat] * dev(e) * affinity[e])   (elements)
##            x temperature class multiplier                                   (independent heat and moisture)
##            x machine temperature tolerance (speed only)
##            x bound effect multipliers
##            x parcel attributes (richness / fertility / stability / conductivity)
## Natural energy deviation = (value - 50) / 50; technology strength = value / 100.

static func machine_stats(machine_id: String, parcel: Dictionary) -> Dictionary:
	var def: Dictionary = Data.machines.get(machine_id, {})
	var result: Dictionary = {"breakdown": {}}
	if def.is_empty() or parcel.is_empty():
		for s: String in Data.stat_ids: result[s] = 1.0
		return result
	var affinity: Dictionary = def.get("affinity", {})
	var temp: String = parcel.temperature
	var temp_def: Dictionary = Data.temperatures.get(temp, {})
	for s: String in Data.stat_ids:
		var lines: Array = []
		var m: float = 1.0
		for e: String in Data.element_ids:
			var natural: bool = e in ["life", "ember"]
			var dev: float = (float(parcel.elements[e]) - 50.0) / 50.0 if natural else float(parcel.elements[e]) / 100.0
			var inf: float = float(Data.stat_influence.get(e, {}).get(s, 0.0))
			var aff: float = float(affinity.get(e, 1.0))
			var part: float = inf * dev * aff
			if absf(part) >= 0.005:
				lines.append(["%s %d" % [Data.elements[e].name, int(parcel.elements[e])], part, true])
			m += part
		var lim: Array = Data.stat_limits.get(s, [0.2, 3.0])
		m = clampf(m, float(lim[0]), float(lim[1]))
		var tm: float = float(temp_def.get("stats", {}).get(s, 1.0))
		if not is_equal_approx(tm, 1.0): lines.append([str(temp_def.get("name", temp)), tm, false])
		m *= tm
		if s == "speed":
			var tol: float = float(def.get("temperature", {}).get(temp, 1.0))
			if not is_equal_approx(tol, 1.0): lines.append([TranslationServer.translate("Tolerance (%s)") % temp_def.get("name", temp), tol, false])
			m *= tol
		var em: float = float(parcel.stat_mults.get(s, 1.0))
		if not is_equal_approx(em, 1.0): lines.append([TranslationServer.translate("Bound effects"), em, false])
		m *= em
		match s:
			"yield":
				if def.kind == "extractor":
					lines.append([TranslationServer.translate("Richness"), parcel.richness, false])
					m *= float(parcel.richness)
				if def.get("living", false):
					var f: float = 0.6 + 0.6 * float(parcel.fertility)
					lines.append([TranslationServer.translate("Fertility (living)"), f, false])
					m *= f
			"wear":
				var st: float = 1.6 - float(parcel.stability)
				lines.append([TranslationServer.translate("Stability"), st, false])
				m *= st
			"energy":
				var c: float = 1.0 / float(parcel.conductivity)
				if not is_equal_approx(c, 1.0): lines.append([TranslationServer.translate("Conductivity"), c, false])
				m *= c
		result[s] = maxf(m, 0.0)
		result.breakdown[s] = lines
	return result

## A single 0..1 score of how well a machine suits a plot (used by the build preview).
static func suitability(stats: Dictionary) -> float:
	var s: float = float(stats.speed) * float(stats["yield"]) / (0.5 + 0.5 * float(stats.wear))
	return clampf(s / 2.0, 0.0, 1.0)
