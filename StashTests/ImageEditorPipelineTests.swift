import XCTest
import AppKit
@testable import Stash

@MainActor
final class ImageEditorPipelineTests: XCTestCase {
    private func samplePNG(width: Int = 200, height: Int = 120) -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])!
    }

    func testInitDecodesPixelSize() {
        let vm = ImageEditorViewModel(pngData: samplePNG())
        XCTAssertNotNil(vm)
        XCTAssertEqual(vm?.imageSize, CGSize(width: 200, height: 120))
    }

    func testExportProducesValidPNG() {
        let vm = ImageEditorViewModel(pngData: samplePNG())!
        vm.tool = .rectangle
        vm.startDraft(at: CGPoint(x: 10, y: 10))
        vm.extendDraft(to: CGPoint(x: 80, y: 60))
        vm.commitDraft()
        let out = vm.exportPNG()
        XCTAssertNotNil(out, "exportPNG returned nil")
        XCTAssertNotNil(NSBitmapImageRep(data: out ?? Data()), "export is not a decodable image")
    }

    func testCropChangesOutputSize() {
        let vm = ImageEditorViewModel(pngData: samplePNG())!
        vm.tool = .crop
        vm.startDraft(at: CGPoint(x: 0, y: 0))
        vm.extendDraft(to: CGPoint(x: 100, y: 50))
        vm.commitDraft()
        XCTAssertNotNil(vm.cropRect)
        let out = vm.exportPNG()!
        let rep = NSBitmapImageRep(data: out)!
        XCTAssertEqual(rep.pixelsWide, 100)
        XCTAssertEqual(rep.pixelsHigh, 50)
    }

    func testEditTextReopensExistingLabel() {
        let vm = ImageEditorViewModel(pngData: samplePNG())!
        vm.tool = .text
        vm.editText(at: CGPoint(x: 20, y: 20))
        let firstID = vm.editingTextID
        XCTAssertNotNil(firstID)
        vm.updateText(firstID!, to: "hello")
        vm.finishTextEditing()
        vm.editText(at: CGPoint(x: 22, y: 24))
        XCTAssertEqual(vm.editingTextID, firstID, "tap on existing label should reopen it")
    }
}
