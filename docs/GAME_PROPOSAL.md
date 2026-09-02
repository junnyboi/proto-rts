# Mandate of Myth — Game Proposal

**Author:** Manus AI  
**Date:** 2 September 2026  
**Target:** Godot 4.7.2, desktop browsers, keyboard and mouse

## Executive Proposal

**Mandate of Myth** is a browser-playable real-time strategy game set in a mythic interpretation of ancient China. The player commands one of four asymmetric factions—**Celestial, Demon, Beast, or Human**—on a hand-authored isometric battlefield. The playable release will be a complete skirmish vertical slice rather than a broad but shallow prototype. It will include faction selection, resource harvesting, structure construction, unit production, group selection, pathfinding, real-time combat, an opposing commander, victory and defeat states, and replay.

The game will combine the legible economic and territorial rhythm associated with *Age of Mythology* with the responsive unit control, compact match duration, and faction readability associated with *StarCraft*. These references define design goals only. The factions, mythology, visual language, balance, interface, and implementation will be original.

> **Product promise:** Select a mythic host, establish an economy, raise an army, and destroy the rival stronghold in a polished 10–15 minute browser skirmish.

## Player Experience

A match begins at the **Jade Meridian**, a contested valley where spiritual ley lines cross beneath an abandoned imperial causeway. The player starts with a stronghold, three workers, and enough resources to make an immediate strategic choice. Workers gather **Jade**, used primarily for structures and martial troops, and **Essence**, used for ranged mystics and advanced production. A barracks unlocks combat units. The player can expand production, contest central resources, or stage an early assault.

The control model follows established desktop RTS conventions. Left click selects one unit or structure. Dragging creates a selection box. Right click issues contextual move, harvest, or attack commands. Worker and production commands appear in a bottom command panel. The keyboard supports control shortcuts for selecting workers, selecting the army, centering the stronghold, attack-moving, pausing, and camera movement.

The battlefield uses a 2:1 diamond projection derived from explicit grid-to-screen and screen-to-grid transforms. This approach preserves exact input picking and painter-order depth while avoiding dependence on a large authored TileSet. It follows the strongest architectural idea in `junnyboi/proto-td`: treat simulation coordinates as authoritative and make isometric projection a view concern.[1]

## Factions

Each faction shares the same essential production graph so that a first match remains understandable. Identity comes from a passive, cost profile, movement or range modifier, and coherent generated art direction.

| Faction | Strategic Identity | Passive | Visual Language |
| --- | --- | --- | --- |
| **Celestial Court** | Ranged control and spiritual economy | Essence income is increased; ranged units gain additional reach | Jade, ivory, cloud silk, gold filigree, disciplined divine silhouettes |
| **Demon Host** | Attrition and aggressive momentum | Kills restore health and grant a small Essence bounty | Obsidian, ember red, bronze masks, smoke, asymmetrical armor |
| **Beast Clans** | Mobility and map pressure | Units move faster and martial troops train for less Jade | Amber, moss, bone, fur, carved totems, powerful animal silhouettes |
| **Human Dynasty** | Efficient construction and balanced armies | Buildings cost less; Jade income is increased | Cinnabar, dark lacquer, lamellar armor, banners, practical engineering |

The playable roster is intentionally compact. **Workers** harvest and construct. **Vanguard** units provide inexpensive melee pressure. **Mystic** units provide slower, ranged damage. The **Stronghold** trains workers, while the **War Camp** trains both military types. This roster is enough to support economy, production, composition, focus fire, retreat, reinforcement, and counter-pressure without introducing an unreadable technology tree.

## Match Structure and Win Condition

The first playable mode is a one-versus-one skirmish against a scripted computer commander. Both armies occupy opposite corners of a symmetrical but tactically uneven 20 × 16 grid. Water and stone ridges constrain movement, central resource clusters create conflict, and side routes permit flanking.

Victory occurs when the opposing stronghold is destroyed. Defeat occurs when the player stronghold is destroyed. The simulation continues in real time except when the player explicitly pauses or the result overlay is active. The opposing commander receives no hidden combat bonuses. It uses a modest passive income supplement so that it can maintain pressure even if its simplified worker behavior is disrupted.

## Visual Direction and Asset Strategy

The art direction is **painterly 2D isometric strategy illustration** with crisp silhouettes, controlled detail, and a unified upper-left light source. GPT Image 2 will generate the title key art, four faction portraits, faction-specific workers, melee units, ranged units, strongholds, war camps, three terrain materials, and two resource-node illustrations. Source images will be retained separately from optimized runtime derivatives.

The runtime will use generated artwork for every representational world object. Godot custom drawing will be limited to functional geometry: selection rings, health bars, movement destinations, fog-neutral grid feedback, selection rectangles, and panel styling. Those elements require deterministic dimensions and state-dependent colors and are therefore interface primitives rather than substitute game art.

The terrain renderer will texture custom-drawn isometric diamonds using generated meadow, stone, and water materials. Static terrain can be redrawn from authored map data, while units and buildings are depth-sorted using projected cell depth. Godot’s `CanvasItem` custom drawing API supports textured polygons and controlled draw order for this presentation model.[2]

## Technical Shape

The implementation will use GDScript and the Godot Compatibility renderer because Godot web exports target WebGL 2.0 through that renderer.[3] `AStarGrid2D` will provide four-directional movement over the authored grid. Buildings and impassable terrain will be marked solid, and command execution will request a path to the nearest walkable destination.[4]

The codebase will separate the following responsibilities:

| Layer | Responsibility |
| --- | --- |
| **Data** | Faction definitions, costs, statistics, map layout, color tokens, and asset paths |
| **Simulation** | Resources, entities, orders, pathfinding, gathering, production, combat, computer strategy, and match state |
| **Projection** | Grid-to-screen transforms, inverse picking, diamond geometry, and depth keys |
| **Battlefield view** | Textured terrain, sprite presentation, health bars, selection feedback, camera transform, and input interpretation |
| **Interface** | Title screen, faction selection, top economy bar, selection details, command buttons, tutorial hints, pause, and result overlays |

The browser bundle will use a single-threaded web preset to avoid cross-origin isolation requirements. The exported directory must contain non-empty HTML, JavaScript, WebAssembly, and PCK files. It will be tested from an HTTP server rather than opened directly from the filesystem, consistent with Godot’s web-export guidance.[3]

## Scope Boundary

The release will implement a complete skirmish loop, not a campaign, multiplayer networking, save system, replay serialization, extensive technology tree, naval movement, aerial units, hero abilities, voice acting, or mobile touch interface. The architecture will leave clean seams for those systems, but adding them now would reduce the quality and testability of the core RTS loop.

## Acceptance Criteria

| Area | Acceptance criterion |
| --- | --- |
| **Start flow** | The player can launch the game, select any of four factions, read its passive, and start a skirmish |
| **Economy** | Workers can harvest Jade and Essence, return resources, and display current task state |
| **Construction** | A worker can place a War Camp on a valid tile and invalid placement is rejected visibly |
| **Production** | The stronghold trains workers and the War Camp trains two military unit classes with queue feedback |
| **Command** | Click selection, box selection, contextual right-click, attack-move, and keyboard group shortcuts function |
| **Combat** | Units acquire targets, pursue, attack by range and cooldown, take damage, die, and trigger faction passives |
| **Computer opponent** | The opponent produces mixed forces and launches recurring attacks capable of winning |
| **Match result** | Destroying a stronghold produces the correct victory or defeat overlay and permits a rematch |
| **Browser build** | The exported game loads from HTTP in a modern desktop browser with no fatal console or engine errors |
| **Repository** | Source, generated-asset provenance, tests, export instructions, and the web bundle are committed to `junnyboi/proto-rts` |

## Risks and Mitigations

The largest production risk is inconsistent sprite isolation from generated images. Every source prompt will require a centered, complete subject on a flat chroma background. A deterministic derivative pipeline will remove only edge-connected chroma pixels, trim transparent padding, and resize without changing the source master. The second risk is input ambiguity under isometric projection. The inverse projection will be unit tested at centers, corners, and map boundaries. The third risk is browser performance. The map and unit cap will remain intentionally small, terrain will use a single custom-drawn node, and expensive path recalculation will occur only when orders or occupancy change.

## References

[1]: https://github.com/junnyboi/proto-td/blob/master/scripts/view/iso_projection.gd "proto-td isometric projection implementation"
[2]: https://docs.godotengine.org/en/4.7/classes/class_canvasitem.html "Godot 4.7 CanvasItem class reference"
[3]: https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html "Godot documentation: Exporting for the Web"
[4]: https://docs.godotengine.org/en/4.7/classes/class_astargrid2d.html "Godot 4.7 AStarGrid2D class reference"
