# Panels

A native SwiftUI editor for Serge synthesizer panel prototypes, inspired by paperface panels.

Open `Panels.xcodeproj` in Xcode and run the **Panels** scheme. Requires macOS 14 or later.

Choose a **4 × 6** grid on a **4.25″ × 7″** panel or an **8 × 6** grid on an **8.5″ × 7″** panel. Control centers use 1″ spacing; the grid is centered horizontally with ½″ bands above and below it.

Click a cell and choose its control in the inspector:

- LEMO.1B.303 socket
- 4 mm Pomona 1581 banana jack
- SPDT NKK MN12 toggle
- SPDT NKK MBNF15 button
- LED with a VCC CLB-300 lens
- Bourns 51 potentiometer with a fluted knob

Add an optional control name, choose colors where applicable, and choose a rectangle, diamond, arch, or peak frame. Frames can rotate. The module name appears at the top of the panel.

**File → New Example Panel** opens a populated example. A copy is also in `Examples/Serge Prototype.panel`.

Save designs as `.panel` files with standard macOS document commands. The files contain versioned JSON, stable part identifiers, and all 48 cell slots. Switching to four columns hides the right-hand columns and keeps their contents.

**Export PNG** writes the artwork at 300 or 600 DPI, with physical resolution metadata. Guides, selection highlights, and the editor interface are excluded. At 300 DPI the two panel sizes produce 1275 × 2100 and 2550 × 2100 pixel images.

| Shortcut | Action |
|---|---|
| ⌘N / ⌘O / ⌘S | New / open / save |
| ⇧⌘N | New example panel |
| ⇧⌘E | Export PNG |
| ⌘Z / ⇧⌘Z | Undo / redo |
| ⌘C / ⌘V / ⌘X | Copy / paste / cut selected cell, or text while editing |
| Arrow keys | Select an adjacent cell when the canvas has focus |
| Delete | Clear the selected cell when the canvas has focus |
| Escape | Deselect |
| ⌘G | Toggle cell guides |
| ⌘+ / ⌘− / ⌘0 | Zoom in / out / fit |

The document model stores dimensions in integer micrometers with a lower-left origin. Physical cell geometry and decorative drawing are separate. Xcopper board export for 2 mm ENIG PCB panels and Mill Swift export for 7075 manufacturing can be added later; this version exports PNG only.

Build and run the focused test suite:

```sh
xcodebuild -project Panels.xcodeproj -scheme Panels -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/PanelsDerived \
  CODE_SIGNING_ALLOWED=NO test
```

Tests cover geometry, document round trips and validation, hidden-column retention, undo/redo, clipboard editing, and PNG output. Rendering checks write example PNGs to `/tmp/PanelsArtifacts` for visual inspection.

The same core tests can run without launching the app:

```sh
swift test
```

Clipboard tests use an in-memory adapter; the app uses the macOS clipboard. Native windows and save dialogs can be checked by running the app in Xcode.

`Examples/Serge Prototype.png` is a 300 DPI export of the included sample. Regenerate the example image and app icons with:

```sh
swiftc Panels/Model/PanelDesign.swift Panels/Rendering/PanelRenderer.swift \
  Panels/Rendering/PNGExporter.swift Tools/RenderAssets.swift -o /tmp/PanelsRenderAssets
/tmp/PanelsRenderAssets
```
