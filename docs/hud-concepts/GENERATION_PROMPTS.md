# HUD Concept Generation Prompts

All three final concepts were produced with GPT Image 2 through Codex's built-in image-generation workflow. They are reference mockups, not runtime assets. The supplied gameplay captures were edit targets; the prompts explicitly preserved the underlying battlefield and replaced only HUD overlays.

## Jade Command Altar — Worker State

**Input:** User-supplied 3426×1820 gameplay screenshot.

```text
Use case: precise-object-edit
Asset type: high-fidelity desktop-browser RTS game HUD concept mockup for Mandate of Myth
Input images: Image 1 is the edit target and authoritative gameplay reference.
Primary request: Replace only the existing HUD overlays with a polished, shippable “Jade Command Altar” interface. Preserve the isometric battlefield, terrain, fog of war, unit position, camera framing, and underlying game art from Image 1 unchanged.

Layout:
- A very slim top economy ribbon, about 5% of screen height, visually divided into stable resource capsules with small readable original pictograms: jade crystal, lumber log, violet spirit-flame essence, rice bowl food income, population silhouettes, captured-den crest, and clock. Put a compact pause button at the far right.
- Under the top-left ribbon, a compact collapsible objective tracker no wider than 22% of the screen: three short rows only, with icons and progress: “BUILD FOOD SUPPLY”, “CAPTURE A YAOGUAI DEN  0/2”, “DESTROY THE RIVAL STRONGHOLD”. No paragraph.
- A cohesive bottom command altar about 18% of screen height. Bottom-left: large readable diamond minimap with clear dark terrain, cyan friendly dots, red enemy dots, gold objective markers, camera outline, and three tiny utility controls for fog, ping, and map zoom. Bottom-center: selected Worker card with an elegant portrait medallion, name “WORKER”, green health bar “72 / 72”, current order “GATHERING LUMBER”, and cargo row with log icon “40 / 40”. Bottom-right: a tidy 3-by-3 square command card of large illustrated icons. First row is War Camp, Rice Farm, Hunter’s Lodge with costs shown compactly; second row contains Move, Attack-Move with “F”, and Stop with “X”. Empty slots should look intentional.
- Just above the bottom altar, show one small jade toast: “40 LUMBER DELIVERED”.
- Important information must be readable at a glance at 1280×720 and the central battlefield should remain unobstructed.

Style/medium: realistic shippable game UI mockup, crisp 2D interface rendering, not concept art; entirely original design.
Visual language: mythic ancient Chinese command table; dark green-black lacquer, carved jade edge pieces, aged bronze corner fittings, ivory parchment labels, restrained cinnabar player accent, subtle ink-wash cloud and meridian-line motifs. Decorative details stay on outer edges and never compete with data.
Typography: highly legible compact small-caps humanist sans-serif for values and labels; large numerals; consistent alignment.
Lighting/mood: controlled soft jade glow and warm gold highlights, premium but restrained.
Constraints: preserve the gameplay scene unchanged; all panels aligned to a coherent grid; no logos, no trademarks, no watermark; no imitation of Warcraft or StarCraft assets; no excessive bevels; no fantasy scroll clutter; no illegible tiny text; no overlapping panels; no extra windows; keep resource values exactly “JADE 320”, “LUMBER 130”, “ESSENCE 260”, “FOOD 160  +0.0/s”, “POP 3/24”, “DENS 0/2”, “01:16”.
```

## Floating Meridian — Worker State

**Input:** User-supplied 3426×1820 gameplay screenshot.

```text
Use case: precise-object-edit
Asset type: high-fidelity desktop-browser RTS game HUD concept mockup for Mandate of Myth
Input images: Image 1 is the edit target and authoritative gameplay reference.
Primary request: Replace only the existing HUD overlays with a polished, shippable alternative called “Floating Meridian”. Preserve the isometric battlefield, terrain, fog of war, unit position, camera framing, and underlying game art from Image 1 unchanged.

Design goal: maximize visible battlefield while keeping every high-frequency RTS decision one glance away. Create a restrained modern interface that still feels rooted in mythic ancient China.

Layout:
- At top-left, a compact player-versus-rival crest strip with a cinnabar Demon Host seal, a small “VS”, and a cyan Celestial Court seal. Do not use a long text bar.
- Across top-center, six separated floating economy chips with crisp original pictograms and large aligned numerals: jade crystal “320”, lumber log “130”, violet essence flame “260”, rice bowl “160 +0.0/s”, population “3/24”, den crest “0/2”. Put clock “01:16” and a small pause icon at top-right.
- Replace the long objective paragraph with a single slim mission chip under top-left: red fortress icon and “DESTROY THE RIVAL STRONGHOLD”; add a small expand chevron and a subtle “2 MORE” badge.
- Bottom-left floating selected-unit card: small circular Worker portrait, “WORKER”, green “72 / 72” health bar, order “MOVE”, and cargo log “40 LUMBER”. Include two tiny army-selection shortcuts above it: workers “Q” and army “E”.
- Bottom-center floating command dock with six large square illustrated buttons: War Camp, Rice Farm, Hunter’s Lodge, Move, Attack-Move “F”, Stop “X”. Make the first three buttons show compact cost chips using icon plus number, not letter abbreviations. The dock should occupy no more than half the screen width.
- Bottom-right, a large frameless diamond minimap. Use high-contrast dark terrain, cyan friendly dots, red enemy dots, gold objectives, a clear ivory camera outline, and tiny fog/ping/map-zoom icon buttons along its outside edge.
- Above the command dock, one small jade toast: “40 LUMBER DELIVERED”.
- Use soft translucent ink-black backplates so the world remains visible around and faintly beneath HUD islands. Maintain safe margins and consistent alignment.

Style/medium: realistic shippable game UI mockup, crisp 2D interface rendering, not concept art; entirely original design.
Visual language: understated Chinese ink-and-jade design; translucent smoked lacquer, hairline jade borders, ivory type, brushed gold separators, subtle cinnabar action accents, sparse cloud-line ornaments only in corners.
Typography: compact humanist sans-serif with tabular numerals; all essential values readable at 1280×720; no tiny prose.
Constraints: preserve gameplay scene unchanged; no full-width bottom frame; no logos, no trademarks, no watermark; no imitation of Warcraft or StarCraft assets; no oversized decoration; no overlapping panels; no extra windows; render the listed text exactly and do not add lorem ipsum.
```

## Jade Command Altar — Owned Den State

**Input:** `captures/captured-cave.png`.

```text
Use case: precise-object-edit
Asset type: high-fidelity desktop-browser RTS game HUD operational-state concept for Mandate of Myth
Input images: Image 1 is the edit target. It shows an owned Yaoguai Den and must remain the authoritative gameplay reference.
Primary request: Replace only the existing HUD overlays with the same cohesive “Jade Command Altar” interface described below, now in the owned Yaoguai Den production state. Preserve the isometric battlefield, forest, water, road, cave building, selected-unit ring, sprites, camera framing, and underlying game art from Image 1 unchanged.

Layout and exact information:
- Slim top economy ribbon with clear original pictograms and values: “JADE 455”, “LUMBER 120”, “ESSENCE 235”, “FOOD 160  +0.0/s”, “POP 5/24”, “DENS 1/2”, clock “00:01”, compact pause icon.
- Compact collapsed objective tracker at upper-left: “DESTROY THE RIVAL STRONGHOLD”, with small progress chips beneath it reading “DENS 1/2” and “GUARDIANS CLEARED”.
- Cohesive bottom command altar about 18% of screen height.
- Bottom-left: large readable diamond minimap with dark terrain, cyan friendly dots, red enemy dots, gold den/objective markers, ivory camera outline, and tiny fog, ping, and map-zoom controls.
- Bottom-center selected-structure card: elegant illustrated Yaoguai Den medallion, title “YAOGUAI DEN”, jade ownership seal “CONTROLLED”, strong green health bar “1200 / 1200”, status “JADECLAW PRODUCTION UNLOCKED”, and one concise hint “Right-click ground to set rally point”.
- Directly above or within the center card, a global production queue strip. First queue tile contains a Jadeclaw portrait, circular progress ring, “8.4s”, stack count “2”, and a small cancel “×”. Remaining slots are empty and clearly framed.
- Bottom-right command card: a large “CALL JADECLAW” illustrated button with compact icon costs “90” jade, “55” essence, “65” food; a rally-point flag button; a cancel-last-queue button; and intentional empty slots. Include a subtle hotkey badge only where a real hotkey is known.
- Above the altar show a small positive jade toast: “YAOGUAI DEN CAPTURED”.
- Essential values must remain legible at 1280×720.

Style/medium: realistic shippable game UI mockup, crisp 2D interface rendering, not concept art; original design.
Visual language: mythic ancient Chinese command table; dark green-black lacquer, carved jade edge pieces, aged bronze fittings, ivory labels, restrained cyan faction accent, subtle ink-wash cloud and meridian-line motifs. Ornament stays at outer edges.
Typography: highly legible compact small-caps humanist sans-serif, tabular numerals, consistent alignment.
Constraints: preserve gameplay scene unchanged; no long paragraphs; no logos, trademarks, watermark, or copied game assets; no excessive bevels or fantasy scroll clutter; no illegible tiny text; no overlapping panels; no extra windows; keep the UI clearly from the same design system as a premium game HUD.
```

The first den render invented unsupported `Q`, `R`, and `X` badges and omitted the clock. It was corrected with this targeted edit:

```text
Use case: precise-object-edit
Asset type: corrected high-fidelity RTS HUD concept mockup
Input images: Image 1 is the edit target.
Primary request: Make only two interface-accuracy corrections to Image 1.
1. Remove the small letter hotkey badges “Q”, “R”, and “X” from the CALL JADECLAW, SET RALLY POINT, and CANCEL LAST buttons. Keep those three buttons, their icons, labels, costs, positions, sizes, and surrounding command-card design otherwise unchanged.
2. Add the clock text “00:01” immediately to the left of the existing pause button in the top resource ribbon, matching the existing typography and spacing.
Constraints: preserve every other pixel-level aspect of the gameplay scene, HUD layout, text, values, icons, colors, queue, panels, ornament, and camera framing unchanged; no new text; no watermark.
```

Only the corrected den render is linked from the proposal. Final production art must display hotkey text dynamically from the game's actual input mapping rather than baking letters into generated assets.
