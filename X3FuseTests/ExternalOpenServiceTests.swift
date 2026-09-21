//
//  ExternalOpenServiceTests.swift
//  X3FuseTests
//
//  Parsing of the x3fuse:// URL scheme and plain file opens (Finder Quick Action, Open With).
//

import Foundation
import Testing

@testable import X3Fuse

struct ExternalOpenServiceTests {

  @Test func fileURLIsQueuedNotConverted() {
    let url = URL(fileURLWithPath: "/Users/me/Pictures/SDIM0001.X3F")
    let request = ExternalOpenService.request(from: url)
    #expect(request == .init(fileURLs: [url], convert: false, outputFormat: nil))
  }

  @Test func convertURLDecodesPathsAndFormat() {
    let url = URL(
      string:
        "x3fuse://convert?format=dng&path=%2FUsers%2Fme%2FMy%20Photos%2F%E6%97%A5%E6%9C%AC%20SDIM0001.X3F&path=%2Fx%2Fy.X3F"
    )!
    let request = ExternalOpenService.request(from: url)
    #expect(request?.convert == true)
    #expect(request?.outputFormat == .dng)
    #expect(
      request?.fileURLs.map(\.path) == ["/Users/me/My Photos/日本 SDIM0001.X3F", "/x/y.X3F"])
  }

  @Test func openURLOnlyQueues() {
    let url = URL(string: "x3fuse://open?path=%2Fa%2Fb.x3f")!
    let request = ExternalOpenService.request(from: url)
    #expect(request?.convert == false)
    #expect(request?.outputFormat == nil)
    #expect(request?.fileURLs.map(\.path) == ["/a/b.x3f"])
  }

  @Test func fileParameterAcceptsFileURLs() {
    let url = URL(string: "x3fuse://convert?file=file%3A%2F%2F%2Fa%2Fb%20c.X3F")!
    let request = ExternalOpenService.request(from: url)
    #expect(request?.fileURLs.map(\.path) == ["/a/b c.X3F"])
  }

  @Test func unknownActionsAndSchemesAreRejected() {
    #expect(ExternalOpenService.request(from: URL(string: "x3fuse://delete?path=%2Fa.x3f")!) == nil)
    #expect(ExternalOpenService.request(from: URL(string: "https://example.com/convert?path=%2Fa.x3f")!) == nil)
  }

  @Test func formatNames() {
    #expect(ExternalOpenService.outputFormat(named: "DNG") == .dng)
    #expect(ExternalOpenService.outputFormat(named: "tiff") == .tiff)
    #expect(ExternalOpenService.outputFormat(named: "tif") == .tiff)
    #expect(ExternalOpenService.outputFormat(named: "jpg") == .embeddedJpg)
    #expect(ExternalOpenService.outputFormat(named: "jpeg") == .embeddedJpg)
    #expect(ExternalOpenService.outputFormat(named: "png") == nil)
  }
}
