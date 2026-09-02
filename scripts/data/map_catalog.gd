class_name MapCatalog
extends RefCounted

# The Jade Divide uses the authored 40 x 32 layout below as a macro-grid. Each
# authored cell expands to a 2 x 2 gameplay block, producing an 80 x 64 map
# while preserving the terrain's rotational symmetry and strategic topology.
const AUTHORED_SIZE := Vector2i(40, 32)
const CELL_SCALE := 2
const SIZE := AUTHORED_SIZE * CELL_SCALE
const TERRAIN_ROWS: Array[String] = [
	"...~~~..................................",
	"....~~~.................................",
	".....~~~................++++++++++++....",
	"......~~~........+++++++................",
	".......~~~....+++..................+....",
	".......+===+++......................+...",
	"......+.+===+........#..............+...",
	"......+...~~~...................+...+...",
	".....+.....~~~.......................+..",
	".....+......~~~..............+.......+..",
	"....+........~~~............+........+..",
	".##.+.........~~~..........+.........+..",
	"...+...........~~~........+..........+..",
	"...+............~~~........#.........+..",
	"...+.............~~~....+..#.........+..",
	"...+.............+~~~+.+.............+..",
	"..+.............+.+~~~+.............+...",
	"..+.........#..+....~~~.............+...",
	"..+.........#........~~~............+...",
	"..+..........+........~~~...........+...",
	"..+.........+..........~~~.........+.##.",
	"..+........+............~~~........+....",
	"..+.......+..............~~~......+.....",
	"..+.......................~~~.....+.....",
	"...+...+...................~~~...+......",
	"...+..............#........+===+.+......",
	"...+......................+++===+.......",
	"....+..................+++....~~~.......",
	"................+++++++........~~~......",
	"....++++++++++++................~~~.....",
	".................................~~~....",
	"..................................~~~...",
]

const PLAYER_STRONGHOLD := Vector2i(5, 55)
const ENEMY_STRONGHOLD := Vector2i(73, 7)
const ENEMY_WAR_CAMP := Vector2i(67, 13)
const PLAYER_BUILD_TEST_SITE := Vector2i(10, 50)

const PLAYER_WORKERS: Array[Vector2i] = [
	Vector2i(8, 54),
	Vector2i(6, 52),
	Vector2i(4, 58),
]
const ENEMY_WORKERS: Array[Vector2i] = [
	Vector2i(71, 9),
	Vector2i(73, 11),
	Vector2i(75, 5),
]

# Two mirrored Yaoguai Dens create optional side objectives away from the three
# river crossings. Each two-cell footprint and its guardian pack has an exact
# 180-degree counterpart so neither starting position receives an easier hunt.
const CAVES: Array[Dictionary] = [
	{
		"cell": Vector2i(19, 21),
		"entrance": Vector2i(22, 22),
		"guardians": [Vector2i(22, 20), Vector2i(22, 24), Vector2i(24, 22)],
	},
	{
		"cell": Vector2i(59, 41),
		"entrance": Vector2i(57, 41),
		"guardians": [Vector2i(57, 43), Vector2i(57, 39), Vector2i(55, 41)],
	},
]

# Each side has a safe starting pair, two jungle expansions, and two river-side
# opportunities. Every definition has a 180-degree counterpart with the same
# resource kind and amount.
const RESOURCES: Array[Dictionary] = [
	{"kind": &"jade", "cell": Vector2i(12, 52), "amount": 1400.0},
	{"kind": &"essence", "cell": Vector2i(6, 60), "amount": 1000.0},
	{"kind": &"jade", "cell": Vector2i(67, 11), "amount": 1400.0},
	{"kind": &"essence", "cell": Vector2i(73, 3), "amount": 1000.0},
	{"kind": &"jade", "cell": Vector2i(18, 46), "amount": 1800.0},
	{"kind": &"essence", "cell": Vector2i(26, 52), "amount": 1400.0},
	{"kind": &"jade", "cell": Vector2i(61, 17), "amount": 1800.0},
	{"kind": &"essence", "cell": Vector2i(53, 11), "amount": 1400.0},
	{"kind": &"jade", "cell": Vector2i(28, 36), "amount": 2200.0},
	{"kind": &"essence", "cell": Vector2i(24, 28), "amount": 1700.0},
	{"kind": &"jade", "cell": Vector2i(51, 27), "amount": 2200.0},
	{"kind": &"essence", "cell": Vector2i(55, 35), "amount": 1700.0},
]

# Five wildlife species occupy mirrored herd territories. Centers are deliberately
# placed in tree-free glades; simulation-owned members wander inside each radius.
# Passive species flee from hunters, while boars and bears retaliate.
const WILDLIFE_HERDS: Array[Dictionary] = [
	{"kind": &"chicken", "center": Vector2i(12, 13), "count": 5, "radius": 3.0},
	{"kind": &"chicken", "center": Vector2i(67, 50), "count": 5, "radius": 3.0},
	{"kind": &"deer", "center": Vector2i(14, 47), "count": 4, "radius": 4.0},
	{"kind": &"deer", "center": Vector2i(65, 16), "count": 4, "radius": 4.0},
	{"kind": &"bison", "center": Vector2i(26, 10), "count": 3, "radius": 3.5},
	{"kind": &"bison", "center": Vector2i(53, 53), "count": 3, "radius": 3.5},
	{"kind": &"boar", "center": Vector2i(32, 34), "count": 3, "radius": 3.0},
	{"kind": &"boar", "center": Vector2i(47, 29), "count": 3, "radius": 3.0},
	{"kind": &"bear", "center": Vector2i(38, 20), "count": 2, "radius": 2.5},
	{"kind": &"bear", "center": Vector2i(41, 43), "count": 2, "radius": 2.5},
]

# The tree layer replaces painted, permanent forest walls with real Lumber
# entities. Adjacent letters form dense groves; dots keep roads, crossing
# approaches, bases, and expansion glades open. The layer is rotationally
# symmetric, and every tree can be cleared to reveal buildable meadow below.
const TREE_ROWS: Array[String] = [
	"PPP...CCFFFFJJJJPPPPFFFFCCCCPPPPJJJ...FF",
	"PPPP...CFFFFJJJJPPPPFFFFCCCCPPPPJJJ....F",
	"PPPPC...FFFFJJJ..PPPCCC................C",
	"CCCC.....JJJP.............PP....FP.....C",
	"CCC........J.......CC.......J..P.......C",
	"CC................PPFFFFP..............P",
	"FF..P..........CPPPPF.FFPP.PJJ........PP",
	"FFFC.............PPPFFFFPPPPJJ.......PPP",
	"FFFC....P............FFFFFFF.J......J.JJ",
	"JJJJP..CP............FFFFFF......J.PJ.JJ",
	"JJJJ...CP..............FFF......JJJ.J.JJ",
	"J.....CC......................PPJJJ...FF",
	"PP....CC.....................JJJPP....FF",
	"PP...CCCCC..................JJJJPPPP..FF",
	"PPP..CCCCC..................JJJJPPPP..CC",
	"CCC..CCCCCC...................JJPPP.C.CC",
	"CC.C.PPPJJ...................CCCCCC..CCC",
	"CC..PPPPJJJJ..................CCCCC..PPP",
	"FF..PPPPJJJJ..................CCCCC...PP",
	"FF....PPJJJ.....................CC....PP",
	"FF...JJJPP......................CC.....J",
	"JJ.J.JJJ......FFF..............PC...JJJJ",
	"JJ.JP.J......FFFFFF............PC..PJJJJ",
	"JJ.J......J.FFFFFFF............P....CFFF",
	"PPP.......JJPPPPFFFFPPP.............CFFF",
	"PP........JJP.PPFF.FPPPPC..........P..FF",
	"P..............PFFFFPP................CC",
	"C.......P..J.......CC.......J........CCC",
	"C.....PF....PP.............PJJJ.....CCCC",
	"C................CCCPPP..JJJFFFF...CPPPP",
	"F....JJJPPPPCCCCFFFFPPPPJJJJFFFFC...PPPP",
	"FF...JJJPPPPCCCCFFFFPPPPJJJJFFFFCC...PPP",
]
const TREE_YIELD := 300.0


static func terrain_at(cell: Vector2i) -> StringName:
	if not in_bounds(cell):
		return &"void"
	var authored_cell := Vector2i(
		floori(float(cell.x) / float(CELL_SCALE)),
		floori(float(cell.y) / float(CELL_SCALE)),
	)
	match TERRAIN_ROWS[authored_cell.y].substr(authored_cell.x, 1):
		"#":
			return &"ridge"
		"F":
			return &"forest"
		"~":
			return &"water"
		"=":
			return &"bridge"
		"+":
			return &"road"
		_:
			return &"meadow"


static func tree_definitions() -> Array[Dictionary]:
	var trees: Array[Dictionary] = []
	for y in range(TREE_ROWS.size()):
		for x in range(TREE_ROWS[y].length()):
			var variant := &""
			match TREE_ROWS[y].substr(x, 1):
				"P":
					variant = &"lumber_pine"
				"C":
					variant = &"lumber_cedar"
				"F":
					variant = &"lumber_fir"
				"J":
					variant = &"lumber_juniper"
				_:
					continue
			for offset_y in range(CELL_SCALE):
				for offset_x in range(CELL_SCALE):
					trees.append({
						"kind": &"lumber",
						"variant": variant,
						"cell": Vector2i(
							x * CELL_SCALE + offset_x,
							y * CELL_SCALE + offset_y,
						),
						"amount": TREE_YIELD,
					})
	return trees


static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE.x and cell.y < SIZE.y


static func is_static_walkable(cell: Vector2i) -> bool:
	return terrain_at(cell) in [&"meadow", &"road", &"bridge"]


static func is_buildable(cell: Vector2i) -> bool:
	return terrain_at(cell) == &"meadow"


static func footprint_cells(origin: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(footprint.y):
		for x in range(footprint.x):
			result.append(origin + Vector2i(x, y))
	return result
