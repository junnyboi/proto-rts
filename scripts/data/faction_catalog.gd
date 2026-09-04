class_name FactionCatalog
extends RefCounted

const ORDER: Array[StringName] = [&"celestial", &"demon", &"beast", &"human"]
const WILDLIFE_KINDS: Array[StringName] = [&"deer", &"bison", &"chicken", &"boar", &"bear"]

const DATA := {
	&"celestial": {
		"name_key": &"faction.celestial.name",
		"epithet_key": &"faction.celestial.epithet",
		"identity_key": &"faction.celestial.identity",
		"passive_key": &"faction.celestial.passive",
		"accent": Color("74d7d0"),
		"dark": Color("17383d"),
	},
	&"demon": {
		"name_key": &"faction.demon.name",
		"epithet_key": &"faction.demon.epithet",
		"identity_key": &"faction.demon.identity",
		"passive_key": &"faction.demon.passive",
		"accent": Color("f05a47"),
		"dark": Color("451b22"),
	},
	&"beast": {
		"name_key": &"faction.beast.name",
		"epithet_key": &"faction.beast.epithet",
		"identity_key": &"faction.beast.identity",
		"passive_key": &"faction.beast.passive",
		"accent": Color("e5b85c"),
		"dark": Color("3c3822"),
	},
	&"human": {
		"name_key": &"faction.human.name",
		"epithet_key": &"faction.human.epithet",
		"identity_key": &"faction.human.identity",
		"passive_key": &"faction.human.passive",
		"accent": Color("e36b50"),
		"dark": Color("3b2021"),
	},
}

const BASE_STATS := {
	&"worker": {
		"name_key": &"entity.worker.name",
		"role_key": &"entity.worker.role",
		"max_hp": 72.0,
		"speed": 1.30,
		"damage": 5.0,
		"range": 0.75,
		"attack_period": 1.1,
		"acquire_range": 3.0,
		"population": 1,
		"train_time": 6.0,
		"jade_cost": 55,
		"essence_cost": 0,
		"food_cost": 30,
	},
	&"hunter": {
		"name_key": &"entity.hunter.name",
		"role_key": &"entity.hunter.role",
		"max_hp": 88.0,
		"speed": 2.0,
		"damage": 8.0,
		"range": 4.5,
		"attack_period": 1.1,
		"acquire_range": 7.0,
		"population": 1,
		"train_time": 6.5,
		"jade_cost": 45,
		"essence_cost": 0,
		"food_cost": 25,
	},
	&"vanguard": {
		"name_key": &"entity.vanguard.name",
		"role_key": &"entity.vanguard.role",
		"max_hp": 165.0,
		"speed": 1.85,
		"damage": 19.0,
		"range": 0.82,
		"attack_period": 0.9,
		"acquire_range": 6.5,
		"population": 2,
		"train_time": 7.5,
		"jade_cost": 75,
		"essence_cost": 0,
		"food_cost": 40,
	},
	&"mystic": {
		"name_key": &"entity.mystic.name",
		"role_key": &"entity.mystic.role",
		"max_hp": 92.0,
		"speed": 1.75,
		"damage": 27.0,
		"range": 4.0,
		"attack_period": 1.35,
		"acquire_range": 7.5,
		"population": 3,
		"train_time": 10.0,
		"jade_cost": 50,
		"essence_cost": 65,
		"food_cost": 50,
	},
	&"jadeclaw": {
		"name_key": &"entity.jadeclaw.name",
		"role_key": &"entity.jadeclaw.role",
		"max_hp": 280.0,
		"speed": 1.65,
		"damage": 24.0,
		"range": 0.9,
		"attack_period": 1.05,
		"acquire_range": 6.0,
		"population": 3,
		"train_time": 12.0,
		"jade_cost": 90,
		"essence_cost": 55,
		"food_cost": 65,
	},
	&"shenlong": {
		"name_key": &"entity.shenlong.name",
		"role_key": &"entity.shenlong.role",
		"max_hp": 1200.0,
		"speed": 2.05,
		"damage": 58.0,
		"range": 1.4,
		"attack_period": 1.15,
		"acquire_range": 9.0,
		"population": 8,
		"train_time": 0.0,
		"jade_cost": 0,
		"essence_cost": 0,
		"food_cost": 0,
	},
	&"shenlong_egg": {
		"name_key": &"entity.shenlong_egg.name",
		"role_key": &"entity.shenlong_egg.role",
		"max_hp": 1.0,
		"population": 0,
		"train_time": 0.0,
		"jade_cost": 0,
		"essence_cost": 0,
		"food_cost": 0,
	},
	&"chicken": {
		"name_key": &"entity.chicken.name",
		"role_key": &"entity.chicken.role",
		"max_hp": 18.0,
		"speed": 1.45,
		"damage": 0.0,
		"range": 0.65,
		"attack_period": 1.2,
		"acquire_range": 0.0,
		"population": 0,
		"train_time": 0.0,
		"jade_cost": 0,
		"essence_cost": 0,
		"food_cost": 0,
		"food_bounty": 8,
		"retaliates": false,
	},
	&"deer": {
		"name_key": &"entity.deer.name",
		"role_key": &"entity.deer.role",
		"max_hp": 55.0,
		"speed": 2.05,
		"damage": 0.0,
		"range": 0.65,
		"attack_period": 1.2,
		"acquire_range": 0.0,
		"population": 0,
		"train_time": 0.0,
		"jade_cost": 0,
		"essence_cost": 0,
		"food_cost": 0,
		"food_bounty": 19,
		"retaliates": false,
	},
	&"bison": {
		"name_key": &"entity.bison.name",
		"role_key": &"entity.bison.role",
		"max_hp": 150.0,
		"speed": 1.25,
		"damage": 0.0,
		"range": 0.75,
		"attack_period": 1.2,
		"acquire_range": 0.0,
		"population": 0,
		"train_time": 0.0,
		"jade_cost": 0,
		"essence_cost": 0,
		"food_cost": 0,
		"food_bounty": 45,
		"retaliates": false,
	},
	&"boar": {
		"name_key": &"entity.boar.name",
		"role_key": &"entity.boar.role",
		"max_hp": 100.0,
		"speed": 1.65,
		"damage": 13.0,
		"range": 0.8,
		"attack_period": 1.05,
		"acquire_range": 0.0,
		"population": 0,
		"train_time": 0.0,
		"jade_cost": 0,
		"essence_cost": 0,
		"food_cost": 0,
		"food_bounty": 31,
		"retaliates": true,
	},
	&"bear": {
		"name_key": &"entity.bear.name",
		"role_key": &"entity.bear.role",
		"max_hp": 230.0,
		"speed": 1.4,
		"damage": 22.0,
		"range": 0.9,
		"attack_period": 1.25,
		"acquire_range": 0.0,
		"population": 0,
		"train_time": 0.0,
		"jade_cost": 0,
		"essence_cost": 0,
		"food_cost": 0,
		"food_bounty": 60,
		"retaliates": true,
	},
	&"stronghold": {
		"name_key": &"entity.stronghold.name",
		"role_key": &"entity.stronghold.role",
		"max_hp": 1500.0,
		"population": 0,
		"train_time": 0.0,
		"jade_cost": 0,
		"essence_cost": 0,
		"footprint": Vector2i(2, 2),
	},
	&"war_camp": {
		"name_key": &"entity.war_camp.name",
		"role_key": &"entity.war_camp.role",
		"max_hp": 850.0,
		"population": 0,
		"train_time": 8.0,
		"jade_cost": 150,
		"lumber_cost": 80,
		"essence_cost": 25,
		"footprint": Vector2i(1, 1),
	},
	&"rice_farm": {
		"name_key": &"entity.rice_farm.name",
		"role_key": &"entity.rice_farm.role",
		"max_hp": 650.0,
		"population": 0,
		"train_time": 0.0,
		"jade_cost": 55,
		"lumber_cost": 45,
		"essence_cost": 0,
		"food_yield": 8,
		"food_interval": 40.0,
		"footprint": Vector2i(2, 2),
	},
	&"hunters_lodge": {
		"name_key": &"entity.hunters_lodge.name",
		"role_key": &"entity.hunters_lodge.role",
		"max_hp": 600.0,
		"population": 0,
		"train_time": 0.0,
		"jade_cost": 90,
		"lumber_cost": 75,
		"essence_cost": 15,
		"food_yield": 18,
		"food_interval": 50.0,
		"footprint": Vector2i(1, 1),
	},
	&"wall": {
		"name_key": &"entity.wall.name",
		"role_key": &"entity.wall.role",
		"max_hp": 300.0,
		"population": 0,
		"train_time": 0.0,
		"jade_cost": 0,
		"lumber_cost": 8,
		"essence_cost": 0,
		"footprint": Vector2i.ONE,
	},
	&"gate": {
		"name_key": &"entity.gate.name",
		"role_key": &"entity.gate.role",
		"max_hp": 700.0,
		"population": 0,
		"train_time": 0.0,
		"jade_cost": 0,
		"lumber_cost": 32,
		"essence_cost": 0,
		"footprint": Vector2i(2, 4),
	},
	&"sentry_tower": {
		"name_key": &"entity.sentry_tower.name",
		"role_key": &"entity.sentry_tower.role",
		"max_hp": 900.0,
		"population": 0,
		"train_time": 0.0,
		"jade_cost": 0,
		"lumber_cost": 60,
		"essence_cost": 0,
		"footprint": Vector2i(2, 2),
		"garrison_capacity": 2,
	},
	&"yaoguai_den": {
		"name_key": &"entity.yaoguai_den.name",
		"role_key": &"entity.yaoguai_den.role",
		"max_hp": 1200.0,
		"population": 0,
		"train_time": 0.0,
		"jade_cost": 0,
		"essence_cost": 0,
		"footprint": Vector2i(2, 2),
	},
}


static func definition(faction_id: StringName) -> Dictionary:
	return (DATA.get(faction_id, DATA[&"human"]) as Dictionary).duplicate(true)


static func faction_text_key(faction_id: StringName, field: StringName) -> StringName:
	var definition_value := DATA.get(faction_id, DATA[&"human"]) as Dictionary
	return definition_value.get("%s_key" % field, &"faction.human.name") as StringName


static func entity_text_key(kind: StringName, field: StringName = &"name") -> StringName:
	var stats_value := BASE_STATS.get(kind, BASE_STATS[&"worker"]) as Dictionary
	return stats_value.get("%s_key" % field, &"entity.worker.name") as StringName


static func stats(kind: StringName, faction_id: StringName) -> Dictionary:
	var result := (BASE_STATS.get(kind, BASE_STATS[&"worker"]) as Dictionary).duplicate(true)
	if faction_id == &"celestial" and kind == &"mystic":
		result["range"] = float(result["range"]) + 0.8
	if faction_id == &"beast":
		if kind in [&"worker", &"hunter", &"vanguard", &"mystic"]:
			result["speed"] = float(result["speed"]) * 1.18
		if kind == &"vanguard":
			result["jade_cost"] = maxi(0, int(result["jade_cost"]) - 15)
	if faction_id == &"human" and kind == &"war_camp":
		for cost_key in ["jade_cost", "lumber_cost", "essence_cost"]:
			result[cost_key] = int(round(float(result.get(cost_key, 0)) * 0.85))
	return result


static func portrait_path(faction_id: StringName) -> String:
	return "res://assets/runtime/portraits/%s.webp" % String(faction_id)


static func entity_art_path(faction_id: StringName, kind: StringName) -> String:
	if kind in WILDLIFE_KINDS:
		return "res://assets/runtime/wildlife/%s.png" % String(kind)
	if kind == &"jadeclaw":
		return "res://assets/runtime/units/neutral_jadeclaw.png"
	if kind == &"shenlong":
		return "res://assets/runtime/units/neutral_shenlong.png"
	if kind == &"shenlong_egg":
		return "res://assets/runtime/objectives/shenlong_egg.png"
	if kind == &"yaoguai_den":
		return "res://assets/runtime/buildings/neutral_yaoguai_den.png"
	if kind in [&"rice_farm", &"hunters_lodge"]:
		return "res://assets/runtime/buildings/%s.png" % String(kind)
	var folder := "buildings" if kind in [&"stronghold", &"war_camp", &"wall", &"gate", &"sentry_tower"] else "units"
	return "res://assets/runtime/%s/%s_%s.png" % [folder, String(faction_id), String(kind)]


static func can_farm(faction_id: StringName) -> bool:
	return faction_id in [&"celestial", &"human"]


static func can_hunt(faction_id: StringName) -> bool:
	return faction_id in [&"demon", &"beast", &"human"]


static func can_build_structure(faction_id: StringName, kind: StringName) -> bool:
	if kind == &"rice_farm":
		return can_farm(faction_id)
	if kind == &"hunters_lodge":
		return can_hunt(faction_id)
	return true


static func can_train_unit(faction_id: StringName, kind: StringName) -> bool:
	return kind != &"hunter" or can_hunt(faction_id)


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


static func opposing_factions(player_faction: StringName) -> Array[StringName]:
	# Keep the original one-on-one matchup in slot 1 so existing balance and
	# tutorial expectations remain stable, then fill the other two corners.
	var result: Array[StringName] = [opposing_faction(player_faction)]
	for faction in ORDER:
		if faction != player_faction and faction not in result:
			result.append(faction)
	return result
