---
phase: 3
title: OCR on Images
status: completed
priority: P1
effort: 2h
dependencies: []
---

# Phase 3: OCR on Images

## Overview

Right-click any image row → "Extract text" → Vision framework runs OCR, result added as a new text item (and lands on clipboard). Async, off-main, with progress feedback.

## Requirements

- **Functional:** Works on any captured image (text/code screenshots, photos of receipts, signs). Auto-detects language. Supports multi-line. Inserts result as new text history item with source `Stash · OCR`.
- **Non-functional:** ≤ 2 s for a typical 1080p screenshot. Runs on background queue; UI doesn't block. Failure surfaces a HUD toast.

## Architecture

```
HistoryRow context menu (image item only)
   ↓ "Extract text"
ClipboardStore.extractText(from item)
   ↓
OCRService.recognize(pngData) async -> Result<String, OCRError>
   ↓
Vision: VNImageRequestHandler + VNRecognizeTextRequest
   ↓
Domain/CapturedContent.text(extractedString) → repo.insert + clipboard write
```

## Related Code Files

- Create: `Stash/Infrastructure/OCR/OCRService.swift`
- Create: `Stash/Infrastructure/OCR/OCRError.swift`
- Modify: `Stash/Application/ClipboardStore.swift` — add `extractText(from item:)`
- Modify: `Stash/Presentation/Popover/ClipboardPopoverView.swift` — context menu entry for image items
- Create: `StashTests/OCRServiceTests.swift` (uses a small bundled fixture image)
- Create: `StashTests/Fixtures/ocr-sample.png` (small image with known text)

## Implementation Steps

1. **`OCRService`** is an `actor` (Infrastructure):
   ```swift
   actor OCRService {
       func recognize(pngData: Data) async -> Result<String, OCRError> {
           guard let image = CGImage.from(pngData: pngData) else { return .failure(.invalidImage) }
           let request = VNRecognizeTextRequest()
           request.recognitionLevel = .accurate
           request.usesLanguageCorrection = true
           let handler = VNImageRequestHandler(cgImage: image)
           do {
               try handler.perform([request])
               let lines = request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
               return .success(lines.joined(separator: "\n"))
           } catch {
               return .failure(.visionFailed(error.localizedDescription))
           }
       }
   }
   ```
2. **`ClipboardStore.extractText(from item:)`:**
   ```swift
   func extractText(from item: ClipboardItem) {
     guard case .image(let data, _) = item.content else { return }
     HUDToast.show("Extracting text…", duration: 1.5)
     Task {
       let result = await ocrService.recognize(pngData: data)
       await MainActor.run { self.handleOCR(result, source: item) }
     }
   }
   ```
3. **`handleOCR`:** on `.success` create new text item, insert, write to clipboard, toast "Extracted N chars". On `.failure` toast error.
4. **Context menu** in `ClipboardPopoverView` adds `Button("Extract text") { store.extractText(from: item) }` shown only when `item.kind == .image`.
5. **Composition root:** `AppDelegate` instantiates `OCRService` and passes to `ClipboardStore` via init (extend ClipboardStore init signature).
6. **Test fixture:** add a small `ocr-sample.png` (e.g., a 200×60 image of the text "Hello World") to `StashTests/Fixtures/`. Test asserts `recognize(...)` returns "Hello World" (allow ±2-char Levenshtein for Vision flakiness).

## Success Criteria

- [ ] Copy a code screenshot from VSCode → right-click → "Extract text" → new text item appears with recognized code within 2 s.
- [ ] Vietnamese text in screenshot is correctly extracted (Vision macOS 13+ supports vi).
- [ ] Test fixture round-trip passes (recognizes "Hello World" from `ocr-sample.png`).
- [ ] Right-click on a text or fileURL row does NOT show "Extract text".
- [ ] OCR running does not block popover UI (verify by scrolling list while recognising).

## Risk Assessment

- **Risk:** Vision OCR accuracy varies wildly with image quality. **Mitigation:** document as best-effort; provide "Try again" button via repeat from menu.
- **Risk:** Very large images (> 10 MP) slow. **Mitigation:** downscale to max 4000 px on long edge before recognize.
- **Risk:** Vision requires macOS 13+ — already our minimum. Confirmed in MVP.
