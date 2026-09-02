class_name FactionCatalog
extends RefCounted

const ORDER: Array[StringName] = [&"celestial", &"demon", &"beast", &"human"]

const DATA := {
	&"celestial": {
		"name": "Celestial Court",
		"epithet": "Edicts of the High Sky",
		"identity": "Ranged control and spiritual economy",
		"passive": "Mandate of Heaven — +15% Essence income; Mystics gain +0.8 range.",
		"accent": Color("74d7d0"),
		"dark": Color("17383d"),
	},
	&"demon": {
		"name": "Demon Host",
		"epithet": "The Ten-Thousand Hungers",
		"identity": "Attrition and aggressive momentum",
		"passive": "Feast of Ash — kills heal the attacker and yield 3 Essence.",
		"accent": Color("f05a47"),
		"dark": Color("451b22"),
	},
	&"beast": {
		"name": "Beast Clans",
		"epithet": "Pacts of Fang and Feather",
		"identity": "Mobility and map pressure",
		"passive": "Wild Hunt — units move 18% faster; Vanguards cost 15 less Jade.",
		"accent": Color("e5b85c"),
		"dark": Color("3c3822"),
	},
	&"human": {
		"name": "Human Dynasty",
		"epithet": "Walls, Banners, Resolve",
		"identity": "Efficient construction and balanced armies",
		"passive": "Ordered Realm — +10% Jade income; War Camps cost 15% less.",
		"accent": Color("e36b50"),
		"dark": Color("3b2021"),
	},
}

const BASE_STATS := {
	&"worker": {
		"name": "Worker",
		"role": "Gathers Jade and Essence. Constructs War Camps.",
		"max_hp": 72.0,
		"speed": 1.95,
		"damage": 5.0,
		"range": 0.75,
		"attack_period": 1.1,
		"acquire_range": 3.0,
		"population": 1,
		"train_time": 6.0,
		"jade_cost": 55,
		"essence_cost": 0,
	},
	&"vanguard": {
		"name": "Vanguard",
		"role": "Durable melee infantry for direct assaults.",
		"max_hp": 165.0,
		"speed": 1.72,
		"damage": 19.0,
		"range": 0.82,
		"attack_period": 0.9,
		"acquire_range": 6.5,
		"population": 2,
		"train_time": 7.5,
		"jade_cost": 75,
		"essence_cost": 0,
	},
	&"mystic": {
		"name": "Mystic",
		"role": "Fragile ranged attacker empowered by Essence.",
		"max_hp": 92.0,
		"speed": 1.52,
		"damage": 27.0,
		"range": 4.0,
		"attack_period": 1.35,
		"acquire_range": 7.5,
		"population": 3,
		"train_time": 10.0,
		"jade_cost": 50,
		"essence_cost": 65,
	},
	&"stronghold": {
		"name": "Stronghold",
		"role": "Command center, resource drop-off, and worker production.",
		"max_hp": 1500.0,
		"population": 0,
		"train_time": 0.0,
		"jade_cost": 0,
		"essence_cost": 0,
		"footprint": Vector2i(2, 2),
	},
	&"war_camp": {
		"name": "War Camp",
		"role": "Trains Vanguards and Mystics.",
		"max_hp": 850.0,
		"population": 0,
		"train_time": 8.0,
		"jade_cost": 180,
		"essence_cost": 40,
		"footprint": Vector2i(1, 1),
	},
}


static func definition(faction_id: StringName) -> Dictionary:
	return (DATA.get(faction_id, DATA[&"human"]) as Dictionary).duplicate(true)


static func stats(kind: StringName, faction_id: StringName) -> Dictionary:
	var result := (BASE_STATS.get(kind, BASE_STATS[&"worker"]) as Dictionary).duplicate(true)
	if faction_id == &"celestial" and kind == &"mystic":
		result["range"] = float(result["range"]) + 0.8
	if faction_id == &"beast":
		if kind in [&"worker", &"vanguard", &"mystic"]:
			result["speed"] = float(result["speed"]) * 1.18
		if kind == &"vanguard":
			result["jade_cost"] = maxi(0, int(result["jade_cost"]) - 15)
	if faction_id == &"human" and kind == &"war_camp":
		result["jade_cost"] = int(round(float(result["jade_cost"]) * 0.85))
		result["essence_cost"] = int(round(float(result["essence_cost"]) * 0.85))
	return result


static func portrait_path(faction_id: StringName) -> String:
	return "res://assets/runtime/portraits/%s.webp" % String(faction_id)


static func entity_art_path(faction_id: StringName, kind: StringName) -> String:
	var folder := "buildings" if kind in [&"stronghold", &"war_camp"] else "units"
	return "res://assets/runtime/%s/%s_%s.png" % [folder, String(faction_id), String(kind)]


static func opposing_faction(player_faction: StringName) -> StringName:
	match player_faction:
		&"demon":
			return &"celestial"
		&"celestial":
			return &"demon"
		&"beast":
			return &"human"
		_:
			return &"beast"
