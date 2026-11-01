# Session Handoff Notes

## Workspace / paths
- VS Code workspace root: `/home/mx5ve/Projects/Palette` (NOT the repo root; sources live in `Nautilus/`).
- Xcode project: `Nautilus.xcodeproj` (sibling of the `Nautilus/` folder).
- Continue extension (VSCode-OSS): `~/.vscode-oss/extensions/continue.continue-2.0.0-linux-x64/`
  - GUI bundle: `gui/assets/index.css` and `gui/assets/index.js`
- Continue config: `~/.continue/config.yaml` (PROTECTED — cannot be read/edited by the agent; do not try).

## TASK A (DONE): iOS app "Nautilus" — SwiftUI LED strip controller (ELK-BLEDOM BLE)
Goal: fix protocol bytes to match a reference `CommandUtils.kt`, plus add a Settings tab.

Applied edits (all verified against `/home/mx5ve/Downloads/CommandUtils.kt` — the authoritative source):
1. `BluetoothManager.swift`
   - Fixed power frames (note: the `isOn` boolean appears TWICE — bytes 3 and 6):
     - turnOn:  `[7E,04,04,01,00,01,FF,00,EF]`
     - turnOff: `[7E,04,04,00,00,00,FF,00,EF]`
   - Fixed color frame: `[7E,07,05,03,RR,GG,BB,10,EF]` (8th byte was 0x00, now 0x10)
   - Added `IndexedColor` struct (Equatable, Sendable); used for lastColor/pendingColor/lastTransmittedColor
     (replaces tuples to satisfy Sendable under strict concurrency).
   - Added command methods mirroring CommandUtils.kt:
     - setBrightness(0...100): `[7E,04,01,v,FF,FF,FF,00,EF]`
     - setSpeed(0...100):      `[7E,04,02,v,FF,FF,FF,00,EF]`
     - setPattern(0...28):     `[7E,05,03,(p+128),03,FF,FF,00,EF]` (9 bytes — note extra 0xFF)
     - syncTime(date):         `[7E,07,83,HH,MM,SS,(weekday-1),FF,EF]`  (Calendar weekday 1..7 -> 0..6)
     - setTiming(h,m,s,weekdays[7 Bool, idx0=Sun], isOn, isSet):
         `[7E,08,82,HH,MM,SS,(isOn?0:1),(isSet?128:0)|packedWeekdays,EF]`
     - setWireOrder(firstWire,secondWire,thirdWire): `[7E,06,81,a,b,c,FF,00,EF]` (1=Red,2=Green,3=Blue)
   - Added `packWeekdays(_:)` static helper.
2. `NautilusApp.swift` — wrapped ContentView + SettingsView in a TabView (Dashboard / Settings).
3. NEW file `SettingsView.swift` — brightness, speed, pattern, clock sync, weekly schedule UI.
4. Registered `SettingsView.swift` in `project.pbxproj` (PBXBuildFile `...05`, PBXFileReference `...17`, group + Sources).

IMPORTANT corrections to the original handoff plan (found by diffing against CommandUtils.kt):
- turnOn originally planned `[7E,04,04,01,00,00,...]` is WRONG — byte 6 must be `01` (isOn used twice).
- setPattern originally planned 8 bytes `[7E,05,03,(p+128),03,FF,00,EF]` — the real frame is 9 bytes
  `[7E,05,03,(p+128),03,FF,FF,00,EF]` (extra 0xFF at index 6).

Validation: cannot build on Linux host (xcodebuild/swiftc unavailable; project targets iOS 17).
Static checks passed: no leftover tuple refs, pbxproj braces/parens balanced, IDs unique.

## TASK B (in progress): Continue extension CSS — sidebar content cut off & does not resize
Diagnosis:
- Continue's root layout writes an INLINE `height:100vh` on a grid (`grid-template-rows:1fr auto`),
  via a styled component minified as `mon`, wrapped by `pon {height:100%; overflow-x:hidden}`.
- In a VS Code webview, `100vh` maps to the iframe viewport and does NOT track panel resizes,
  so the `1fr/auto` grid clips and never reflows. Verified: policy claims about
  `body:not(.accent-full){width:0}` were a FALSE LEAD (actually scoped under `.katex .accent`).

Action taken:
- Backed up `gui/assets/index.css` -> `index.css.bak` (pristine original, 90300 bytes).
- Appended an override block to `gui/assets/index.css` (now ~91099 bytes) with:
  - `html, body, #root { height:100% !important; min-height:0 !important; }`
  - `#root [style*="100vh"] { height:100% !important; min-height:0 !important; }`
  - `#root > div, #root > div > div, #root > div > div > div { min-height:0 !important; }`
  (Justification: a stylesheet `!important` rule overrides a non-important inline style.)

Status: override appended, NOT yet verified live. Next steps:
1. Confirm brace balance of the appended CSS block (`tail -n 20 index.css`).
2. Reload VS Code window / restart extension to pick up CSS (webview caches; may need "Developer: Reload Window").
3. If still cut off, inspect actual DOM depth of the `100vh` element and tighten `#root [style*="100vh"]` selector.
4. To revert: `cp index.css.bak index.css`.

## TASK C (done, on user side): Continue "auto-apply"
- Policies live in GUI webview localStorage (`persist:root` -> `ui.toolSettings`), NOT in config.yaml/config.ts
  (config-yaml `toolSchema` only has name/description/defaultIcon — no `policies`).
- To enable auto-apply: Continue panel -> wrench/Tool Policies -> set
  `builtin_edit_existing_file` and `builtin_create_new_file` to "Automatic" (= `allowedWithoutPermission`).
  (Optional: `builtin_run_terminal_command`, `builtin_fetch_url_content`.)
- User asked for this; it is a UI toggle, not something the agent can persist via files.

## Gotchas learned
- Edit tools require workspace-RELATIVE paths (e.g. `Nautilus/BluetoothManager.swift`), not absolute.
- Multi-chunk `edit_existing_file` edits with lazy `// ... existing code ...` placeholders kept failing;
  use full rewrites or `single_find_and_replace` with exact original strings.
- The shell is stateless; `cd` fallbacks can drop you in `/usr/bin` — always set cwd explicitly per command.
