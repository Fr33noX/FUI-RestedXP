# FUI-RestedXP

Standalone **RestedXP Guides** (RXP) dressing (no EllesmereUI)
for World of Warcraft **Forever** and **Midnight 12.1+**: theme, guide-window
reskin, navigation arrow and map route, all adjustable in its own options
window (`/fuirxp`).

Author: **Fr33noX**. The guide-window reskin engine (layouts,
arrows, animations) is adapted from the RestedXP module of **LiteTweaks 1.46**
by Jo, with his explicit permission. If LiteTweaks is installed with
its RestedXP reskin active, FUI-RestedXP reports it at login with a
**three-choice popup** (disable LiteTweaks' reskin / this addon's one /
keep both); equivalent clickable links remain in the chat.

The **RestedXP arrow frame** can also be held transparent
by something living next to it: ours is drawn inside it, so it
disappears along with it. FUI-RestedXP reports it at login — once, without
naming anyone and without offering to disable anything — and
`/fuirxp status` shows its state ("arrow frame: ok"). As long as the frame
is held this way, both arrows cannot coexist.

## What the addon does

1. **"Fr33noX-UI" RXP theme**: a RestedXP theme whose colors
   (backgrounds, borders, map pins, tooltip) follow **the accent picked on the
   Theme page**: fire orange by default (taken from EllesmereUI
   automatically if installed), or the *Custom Color* (*Follow
   Accent* off).
2. **Guide window reskin**: flat dark panels, thin accent
   borders, accent-tinted banners, tinted navigation arrow. The
   reskin is re-applied after every RXP repaint (hooks on
   `UpdateVisuals` / `UpdateFrame` / `UpdateText`, debounced to once per
   frame), and steps aside when you pick another RXP theme.
3. **Standalone options window**: Reskin / Map / Theme / Changelog pages,
   global settings search, window scale (Scale
   slider, 60–130%), resizable window — with no dependency
   beyond RestedXP Guides.

## Installation

1. Copy the `FUI-RestedXP` folder into your WoW client's `Interface\AddOns`
   folder (the one that already contains the `RXPGuides` folder).
2. Restart the game or run `/reload`.
3. Select the **"Fr33noX-UI by FUI-RestedXP"** theme in
   `RXP Settings > Guide Window > Theme` — or simply click
   **Activate in RestedXP** on the options *Theme* page (a button that
   makes the selection for you). A status indicator shows whether the
   theme is properly active.
   > The *Theme* page drives **all** of the addon's colors (RXP theme,
   Classic reskin, arrow tint) from a single source: the accent
   (*Follow Accent*, default) or the *Custom Color*.
4. **Settings**: `/fuirxp` opens the options window, with the
   Reskin / Map / Theme / Changelog pages and a global search field.
   > The module's tab bar only shows the appearance page of the
   > **active layout** (Timeline selected → only the Timeline tab;
   > stock RestedXP or disabled engine → none). Changing layout
   > or toggling "Reskin RestedXP" rebuilds the bar immediately.

## Commands

- `/fuirxp`: opens the options window
- `/fuirxp status`: addon state and detected accent color
- `/fuirxp reset`: restore default settings

## Reset

The **Reset to Defaults** button (*Reskin* page) restores **all** of the
 addon's configuration:
 layout, arrow style and its colors, window opacity, theme
 color source, step numbers, listed steps, sizes, fonts,
 distance unit — and puts the RXP window scale back to 100%.
 RestedXP's own settings (window position, followed guides) are
 left untouched.

## Settings (FUIRestedXPCache, editable in WTF)

- `rxpLayout`: the guide window look —
  `FRAMELESS` (outlined text
  over the world), `TIMELINE` (numbered-line window), `COMPACT`
  ("‹ 2/189 ›" title bar, per-line RXP icons, progress
  bar), `ZYGOR` (Zygor style: tab, objectives on a red band,
  green bar), `BIT8` (pixel-art quest log: Silkscreen/VT323, CRT scanlines,
  ◀ B / A ▶ buttons) or `DEFAULT` (RXP window untouched).
- **In every layout**: left-click a current step =
  skip it (green "Skipped" animation), right-click = go back to the previous
  step (animated "Back"); mouse wheel = scroll the list;
  double-click a listed step = jump to it. Each layout has its own
  appearance page in the options window (fonts, sizes, fade,
  colors).
- `rxpArrowStyle`: the navigation arrow, **the full set** —
  `LAYOUT` (the layout's own), `CHEVRON`, `CARD`, `CLASSIC`
  (shaded 3D arrow: green when facing the point, yellow from the side, red from behind),
  `ZYGOR` (Zygor-style arrow + time remaining), `RAIL` (bent needle head,
  dark half = relief; default of the Rail layout) or `RAILC` (the same
  idea inside a ring, two-facet needle). Card is tinted by
  distance (red > 100, yellow, green < 30).
- `rxpMeters`: arrow distance in "m" (1 yd = 1 m in WoW: only
  the label changes). Works with the engine arrow (Custom Arrow on)
  **and** with RXP's stock arrow (Custom Arrow off — live
  rewrite of RXP's "177yd" text).
- `rxpBoxLock` (default: true): **objective icons pinned to the window**.
  RestedXP's target and item boxes stay under the guide
  window and follow it in every layout. When unchecked, drag them with
  left-drag anywhere on screen and they stay there — in every
  layout and across sessions (position saved in `rxpBoxFree`).
- `rxpArrowETA` (default: true): remaining time ("1:23" / "45s", in
  yellow) on **all** custom arrows (Chevron, Card, Classic,
  Zygor-style, Rail, Rail Compass). Off = distance only.
- Fonts: the `uiFont` key (*Theme* page, **Default Font** row, default:
  **Overpass**) is the font of the whole addon UI. Looks
  (`rxpFlFont`/`rxpCpFont`/`rxpZgFont`/`rxpTlFont`...) follow that same
  font by default via the **FUI Global Font** choice (the renamed
  entry of the old "EUI Global Font"; a font explicitly picked on
  a look page stays pinned). 8-Bit keeps its pixel
  fonts (Silkscreen / VT323).
- `skinForceClassic` (default: true): keeps RXP's **classic guide window**
  available. ⚠️ RXP's **"Guide Window v2"** option (V2 UI, Beta)
  **fully hides** the classic window (window, steps,
  scrollbar): the Classic reskin and the other layouts then have nothing left
  to dress or read. With this option, the addon detects
  v2, disables it and shows a message (a `/reload` completes the
  restore); set it to false to let v2 run.
- `rxpHideNums`: hides step numbers and the vertical line
- `rxpUpcoming`: number of upcoming steps listed — **0** hides them
  entirely (the "Step X of Y" header and % remain)
- The **only custom skin** is the **theme** (*Theme* page):
  "Fr33noX-UI by FUI-RestedXP", whose colors follow the accent
  (*Follow Accent*, default) or the *Custom Color*. Everything else
  in the window is the reskin engine, unchanged. When this theme is
  selected in RXP and the custom arrow is disabled
  (or stock RestedXP layout), RXP's readable **Blue theme arrow**
  (v2 file) is used and tinted with the same color (live
  accent or custom) instead of the DarkMode texture set's dark arrow.
- `themeFollowAccent`: the theme follows the accent (default: true)
- `themeR/G/B`: custom color when `themeFollowAccent` is false

## Troubleshooting

- The **Activate in RestedXP** button (Theme page) should answer
  "theme activated". If it says RXP is not loaded, open
  RestedXP's settings once (to initialize its profile), then retry.
- The theme shows up in RXP's dropdown as
  **"Fr33noX-UI by FUI-RestedXP"**. If missing: check that RXPGuides
  is installed in the same game instance as FUI-RestedXP.

## Version

**Latest version: 1.1.0** — first release of the **standalone
version**: no dependency beyond RestedXP Guides, its own options
window (Reskin / Map / Theme / Changelog, global search, 60–130 %
scale, resizable), `/fuirxp` commands. Content matches
1.1.0: the **world map route** (MAP page, disabled by default)
— a straight line from you to the current objective, in the accent color,
with optionally the next six objectives chained behind — and **the same
route on the minimap**; **guide overlays** (farm circuits,
patrols, search zones) with their own colors and a shared
opacity; **tooltips on map markers** (step,
distance, direction, ETA, quest); the arrow's **blurred shadow** in the
Arrow block (spread and color, disabled by default); the **corpse-recovery
line**; the warning when the arrow frame is held
transparent from the outside; and fixes: duplicated objective
counter, and ETA beyond one hour ("1:01:01" instead
of "61:01"). Details are in the Changelog tab (`/fuirxp`).

## Compatibility

- **RestedXP Guides** must be installed (the addon only dresses it up).
- No other dependency: EllesmereUI is neither required nor used — if
  present, its accent is reused as the default accent.
- Clients: Forever (16001) and Midnight (120000-120100).
- The code never touches RXP's files: everything goes through its public
  APIs (`RegisterTheme`, `RXPGuides_Themes` global) and hooks.

## License

See [LICENSE.txt](LICENSE.txt). Addon provided "as is", all rights
reserved (Fr33noX), with attribution: reskin engine adapted from
LiteTweaks 1.46 by Jo, with his explicit permission; theme arrow
rebuilt from RestedXP Guides art; third-party fonts under their
own licenses (OFL for Silkscreen, VT323 and Overpass).

## History (3.4.x series)

3.4.17 — arrow tint follows the live EUI accent again
(re-registered with EUI's skin API after the engine change), and is
re-applied as soon as the theme is activated.

3.4.16 — the theme-tinted arrow uses the v2 file (Blue theme,
readable) instead of DarkMode's dark arrow.

3.4.15 — "Reskin RestedXP" is at the top of the Reskin page: when it is
disabled, the Layout and Arrow blocks disappear from the page. The
Guide Window toggle now warns that a /reload is needed both ways
(RXP's v2 destroys the classic window's scripts).

3.4.14 — the Reskin page groups arrow settings in their own
"ARROW" block (Custom Arrow, Arrow Style, Meters, Time to Waypoint).

3.4.13 — the theme status ("Color source") also updates when
toggling "Follow Accent".

3.4.12 — Activate / Deactivate buttons side by side on the Theme page, and
the theme status refreshes on click.

3.4.11 — "Deactivate in RestedXP" button on the Theme page: hands the
window back to RXP's stock theme (RXP Blue) without opening its settings.

3.4.10 — RXP's stock arrow follows the Theme page color
(live EUI accent or custom color) instead of staying black.

3.4.9 — the EUI options tab bar only shows the appearance page
of the active layout (one at a time).

3.4.8 — "Time to Waypoint" extended to **all** custom
arrows (Chevron, Card, Classic 3D, Zygor-style).

3.4.7 — "Time to Waypoint" option to show or hide the
Zygor-style arrow's remaining time.

3.4.6 — distance/time text is back on **all** arrows
(the 3.4.5 pattern only accepted a single-letter unit and rejected "yd").

3.4.5 — fixed the Zygor-style arrow's remaining time ("1:23" / "45s"):
the engine parser accepts both units again and the
arrow label is rewritten both ways (yd ↔ m), loop-free.

3.4.4 — "Meters (m) on the Arrow" works again when
"Custom Arrow" is disabled (live rewrite of RXP's arrow text,
no conflict with the engine map).

## Files

- `Core.lua` - DB, accent, RXP load detection, slash,
  embedded fonts (Overpass / Expressway)
- `Theme.lua` - RXP theme derived from the accent (official channels)
- `Skin.lua` - Guide Window v2 guard, distance-unit rewrite,
  theme enable/disable, arrow tint
- `Reskin.lua` - full reskin engine (adapted from LiteTweaks 1.46, see
  above): five in-house
  layouts (**Frameless**, **Timeline**, **Compact**, **Zygor-style**,
  **8-Bit**, **Rail**), card animations
  (skip/back), per-line RXP icons, progress bars, Active
  Targets/Items boxes, RXP announcement muting, universal
  navigation arrows (including real TomTom and Zygor Stealth ones), enemy/item
  name colors
- `MapRoute.lua` - world map route: straight line from the player to
  the guide's current objective, then the following steps chained, all
  in the accent color. Each step is ringed with a circle (eight
  points on the circumference plus one at the center), chevrons
  (`rxp-chevron.png`) run along the line to carry direction, each
  segment carries a dark halo and its thickness follows zoom. Coordinates are
  read from RestedXP data (never written) and drawing happens
  on the map canvas, so it follows zoom and pan.
  Lines only sample the flat interior of a white game texture, so
  its edge is never stretched across the map. Disabled by default
  (options MAP page)
- `Textures/` - engine textures (chevron, card /
  classic / zygor arrows, check, back, prev, next, tri, HQ theme arrow)
- `Options.lua` - standalone settings window (search, scale,
  resizing)
- `OptionsView.lua` / `Controls.lua` - window engine: rows
  (toggles, stretchable-rail sliders, lists, colors) and widgets
- `FUIOptions.lua` - settings pages: Reskin, Map (world
  map route + minimap), Theme (accent, font), Changelog, plus one
  appearance page per active layout
- `About.lua` - options window home page
