# Screenshot: instant capture + basic image editor

## Problem
1. After `⇧⌘S` crop, the image does not show on the popover immediately — it only
   arrives on the next `ClipboardWatcher` poll (0.5s, 1.5s on battery).
2. No way to annotate a captured screenshot.

## Decisions (locked with user)
- Crop **saves immediately**; editing is **on demand** from the popover, not auto-opened.
- Editor tools: crop, arrow, rectangle, freehand pen, text, blur/pixelate. Color + width.

## Part A — Instant capture (bug)
- `ClipboardWatcher.captureNow()`: force one capture using the existing snapshot path.
  Guards on `changeCount` change so an Esc-cancelled crop is a no-op. Reuses hash dedup.
- `ScreenshotService.captureInteractiveCrop(onFinish:)`: keep `-i -c -x`, add
  `terminationHandler` → hop to main → `onFinish()`.
- `AppDelegate.handle(.captureScreenshotCrop)`: launch with `onFinish` calling
  `clipboardWatcher?.captureNow()`; show a confirm HUD toast.

Verify: crop → item appears in popover with no perceptible delay; Esc → nothing added.

## Part B — Image editor (on demand)
Reuse the capture path for the result: editor exports PNG → store writes PNG to
`NSPasteboard.general` → `captureNow()` rebuilds thumbnail + inserts + refreshes.
No new thumbnail code, no repo write in the editor path.

New `Stash/Presentation/ImageEditor/`:
- `EditorTool.swift` — `EditorTool` enum + `Annotation` value type.
- `ImageEditorViewModel.swift` — `@MainActor` state: base image, annotations,
  tool/color/width, cropRect, undo, `exportPNG()`.
- `ImageAnnotationRenderer.swift` — draw annotations + blur (CoreImage pixellate on
  rects) into an `NSImage`; produce cropped/flattened PNG.
- `ImageCanvasView.swift` — base image + live annotation overlay + drag gestures.
- `EditorToolbar.swift` — tool buttons, color, width.
- `ImageEditorView.swift` — toolbar + canvas + Done/Cancel.
- `ImageEditorPresenter.swift` — `ImageEditor.present(pngData:onSave:)` window controller.

Wiring:
- `ClipboardStore`: `requestImmediateCapture: (() -> Void)?` hook +
  `applyEditedImage(_ png: Data)` (clear pasteboard, `setData(png, .png)`,
  `requestImmediateCapture?()`).
- `AppDelegate`: `store.requestImmediateCapture = { [weak self] in self?.clipboardWatcher?.captureNow() }`.
- `ClipboardPopoverView.contextMenu`: for `.image`, add `Edit image…` →
  `ImageEditor.present(pngData:) { store.applyEditedImage($0) }`.

## Build
`xcodegen generate` after adding files, then `xcodebuild test -scheme Stash`.

## Open questions
- Text tool editing UX (inline field vs prompt) — going with click-to-place +
  double-click-to-edit inline. Revisit if clumsy.
