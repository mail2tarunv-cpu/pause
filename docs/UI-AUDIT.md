# PAUSE — Apple-native interface audit
Last review: November 16, 2026

**Design intent:** PAUSE should feel at home on an iPhone and Mac, without falsely imitating Apple's own apps. We use SwiftUI-native patterns for navigation, content density, type, form controls, semantic colors and accessibility. The physical split-flap display is the intentional custom component.

## Decisions implemented

### iPhone (iOS 17+)

| Screen | System-first implementation | Manual checks still required |
|---|---|---|
| Today | NavigationStack tab; large native title; inset grouped List; protected DeviceActivityReport; ContentUnavailableView for permission denial; system labels | Screen Time report height, narrow devices, real Screen Time permission |
| Rules | Form with Apple FamilyActivityPicker, Stepper, Picker, native buttons and footers | Picker sheet and monitoring/permission edge cases |
| Board | Native TextEditor and keyboard Done control; split-flap 6×22 preview; clear error when text overflows; cloud/local connection sections | Long multiline messages, VoiceOver preview, phone sizes |
| Settings | System grouped Form, toggles, labeled values, secure password field, destructive-action confirmations | Dynamic Type, sign-in messages, permission toggles |

- Removed forced `.preferredColorScheme(.light)`.
- Changed iPhone colors to `Color.primary`, `Color.secondary`, iOS grouped backgrounds and separators.
- Preserved a single muted PAUSE accent for interactive controls; don't tint every piece of decoration.
- Reduced tiny monospaced uppercase text to only the split-flap content.
- Each tab has its own navigation stack, preserving native navigation state.
- Updated the DeviceActivityReport extension to semantic type/colors and native progress indicators.
- Screen Time data stays in Apple's protected extension.

### Mac (macOS 14+)

| Area | System-first implementation | Manual checks still required |
|---|---|---|
| Overview | NavigationSplitView sidebar, overview heading, native GroupBox summaries, category ProgressView | Min-width window resizing, VoiceOver |
| Activity | App/site records, semantic labels, native progress bars and destructive confirmation | Real app idle timing and long names |
| Browser | Connection state, localhost listener, obscured pairing token, native Copy/Rotate actions | Extension pairing, focus behavior |
| Cloud | Grouped Form, native TextField/SecureField/Toggle, signed-in/offline states | Hosted Supabase provisioned and authenticated |
| Board | Neutral dark physical board preview inside native GroupBox | Message fit and display refresh |
| Menu bar | Native MenuBarExtra commands, window activation, Pause/Resume | Launch/close/window focus behavior |

- Removed the hard-coded beige page background and custom website-like cards.
- Used native sidebar + title toolbar rather than turning macOS into a wide iPhone app.
- Kept browser/cloud connectivity and monitoring independent of the UI overhaul.

### Browser popup (Chromium)

- Uses system type and control sizing, accessible keyboard focus, `prefers-color-scheme: dark`, and Reduced Motion.
- It remains an extension popup, not a SwiftUI app; this is an approximate system-consistent web design.

## UI quality test pass

Structural regression checks run in CI:
`node tests/test_ui_contract.cjs`

Xcode compilation workflows:
- `Build PAUSE for iPhone` — SwiftUI app, monitor and report extensions (simulator compile)
- `Build PAUSE for Mac` — native macOS SwiftUI app

**Not claimed:** visual pixel-perfect approval, actual iPhone/macOS device screenshots, verified VoiceOver or full end-to-end cloud deployment. CI compilation proves syntax/type correctness, not screen quality.

## Manual visual review (required before shipping)

On **each iPhone screen**, inspect at system default text and at the largest Accessibility text size, in Light and Dark Mode. Use the smallest supported iPhone and a large iPhone. Check safe areas, tab bar, title collapse, focus, keyboard overlap, labels, VoiceOver traversal, and Reduce Motion.

On **Mac**, inspect sidebar at minimum and maximum window sizes, resizing, keyboard tab traversal, VoiceOver, Dark Mode, system accent colors, menu bar, and long app names.

Check the **Board** in both platforms at various screen widths: precisely 132 tiles, centered lines, no clipped characters, readable error for overflow, and no accidental loss of typed messages.

Use screenshots from actual devices to refine padding and visual rhythm. Avoid making static screenshots or simulated runtime data appear as proven functional features.

## Relevant references

- [Apple HIG — Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)
- [Apple HIG — Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars)
- [Apple HIG — Typography](https://developer.apple.com/design/human-interface-guidelines/typography)
- [Apple HIG — Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)
- [Apple HIG — Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos)
