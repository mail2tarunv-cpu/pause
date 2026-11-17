# PAUSE / Editorial visual identity

## Reference direction
- The physical split-flap board is the product's dark, tactile anchor.
- The supplied high-energy type composition inspires bold Space Grotesk headings and tiny supporting geometric accents.
- Do **not** place high-saturation blocks behind long paragraphs or UI form labels. The colored shapes create rhythm around typography, while the actual interface remains accessible and focused.

## Primary visual reference: physical split-flap board

The attached hardware photograph is the **source of truth** for the board's appearance. The earlier bold-typography poster remains inspiration for PAUSE's interface typography, but **not** for the board object itself.

- Wide, approximately **1.865:1** charcoal-black framed object, with a very thin border and recessed interior.
- **Exactly 6 rows × 22 columns (132 flaps)**. The tile matrix is centered with consistent top and bottom margins.
- Each tile has a narrow well, slightly different upper/lower flap shade, a mechanical horizontal seam, and legible white mono lettering.
- Colored tiles are actual flap faces—not separate decorative circles, confetti, stickers or overlays.
- A subtle shadow and a nearly-white wall/gallery background keep the physical board as the focal point.
- The PAUSE wordmark is a small embossed detail on the frame's bottom bezel.
- On the default idle scene, chromatic rows surround a simple two-line message; custom messages and real-time screen-time nudges still replace that scene.
- The web board, cloud preview, local controller preview, iPhone preview and Mac preview share the hardware proportions; do not redesign them independently.

Implementation: [`board-hardware.css`](board-hardware.css) and [`test_board_hardware.cjs`](../tests/test_board_hardware.cjs). The decorative `pause-shape-strip` is intentionally **removed from the board display page**, while it can remain on supporting control screens.

### Visual QA before release

Compare an actual desktop browser screenshot at **1200 × 675** to the attached reference: the physical frame should occupy roughly 786 × 421 pixels and the inner flap grid should be approximately 673 × 308 pixels. Verify that the exact 132 cells are present, the grid is centered, all text is legible across the seam, and tablet/mobile layouts preserve the aspect ratio. Run color/preset transitions and confirm the board remains functional. Native compilation is separate from rendered visual QA.

## Typography

**Platform distinction:** The typography below governs PAUSE's website, browser extension, and physical split-flap display. Native Mac and iPhone navigation, forms, headings, buttons, and Screen Time reports use the platform's San Francisco system fonts. Keep DM Mono only for physical board glyphs and the engraved hardware wordmark.

| Role | Font | Weight | Detail |
|---|---|---|---|
| Display / page title | Space Grotesk | 700 | Tight tracking and confident hierarchy |
| Section title / card title | Space Grotesk | 500–700 | Never monospaced |
| Body copy, forms, buttons | DM Mono | 400 | 14–15px minimum at normal density |
| Labels / strong body | DM Mono | 500 | No fake bold synthesizing |
| Board tile glyphs | DM Mono | 500 | Six rows, 22 columns |
| Metadata | DM Mono | 400–500 | Keep readable and avoid ultra-small labels |

Fonts are SIL OFL open source, sourced from pinned commits in `scripts/prepare_fonts.sh`.
- Space Grotesk: https://github.com/floriankarsten/space-grotesk
- DM Mono: https://github.com/googlefonts/dm-mono

Native apps bundle the actual assets using XcodeGen after `bash scripts/prepare_fonts.sh`.
iOS: the app and protected Screen Time report each include fonts in `UIAppFonts`.
macOS: fonts register in-process using CoreText, not as globally installed fonts.
Chromium extension: local font files are used because Manifest V3 CSP restricts remote font imports.
Web pages: Google Fonts stylesheets with system fallback.

## Color palette

| Name | Hex | Usage |
|---|---|---|
| Paper | `#F7F7F5` | Light canvas |
| Ink | `#101012` | Dark text, hardware |
| White | `#FFFFFF` | Controls and content surfaces |
| Orange | `#FF5E16` | Geometric accent |
| Yellow | `#FFE208` | Dot / small graphic |
| Pink | `#F350E7` | Triangle graphic |
| Cyan | `#13D1E2` | Waves, signal / tile accent |
| Purple | `#5951F9` | Graphic punctuation / tile |
| Lime | `#A4F45F` | Small secondary accent |
| Green | `#078B75` | Positive accent and hardware tile |
| Interactive dark teal | `#08796D` | Focus, primary interaction on light paper |

**Use dark ink on yellow/cyan/lime/orange surfaces, never white by default.**
Palette values inspired by the uploaded reference, not a pixel-for-pixel reproduction. On Mac/iPhone, native semantic labels, states, and SF Symbols remain legible in Dark Mode.

## Shapes
The `pause-shape-strip` contains original CSS-drawn blocks:
- quarter-rounded orange tile
- yellow disc
- magenta triangle
- cyan wave
- violet dot

The shapes are reserved for web editorial surfaces and physical display accents. Native Mac and iPhone screens do not use the decorative stamps in their primary UI; they rely on system hierarchy, spacing, and SF Symbols.

## QA
- Run `node tests/test_brand.cjs`.
- Run `python3 -m unittest discover -s tests` and the repository's full validation workflow.
- Run native iPhone and Mac CI builds. Font preparation must complete before `xcodegen generate`.
- Test custom fonts loaded via actual PostScript names on physical devices; neither compiler success nor available font files guarantee the rendered UI.
- Test darkest and brightest contrast pairs, small-screen mono readability and board tile width.
- Check system accessibility font scaling and Reduce Motion. Keep headings out of tiny clipped cards.
- Confirm the Vercel site actually deployed the latest commit; GitHub changes alone are not deployment proof.

This is the PAUSE design system, not a claim that every view has been manually pixel-reviewed.
