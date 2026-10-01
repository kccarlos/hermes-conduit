import Foundation
import XCTest

final class InterfaceOrientationTests: XCTestCase {
    private let appBundleIdentifier = "io.github.kccarlos.conduit"

    private func appInfoDictionary() throws -> [String: Any] {
        let bundle = try XCTUnwrap(Bundle(identifier: appBundleIdentifier))
        let infoData = try Data(contentsOf: bundle.bundleURL.appendingPathComponent("Info.plist"))
        return try XCTUnwrap(
            PropertyListSerialization.propertyList(from: infoData, options: [], format: nil) as? [String: Any]
        )
    }

    func testUniversalOrientationsRemainPortraitOnlyForIPhone() throws {
        let info = try appInfoDictionary()
        XCTAssertEqual(
            info["UISupportedInterfaceOrientations"] as? [String],
            ["UIInterfaceOrientationPortrait"]
        )
    }

    func testIPadOrientationsIncludeBothLandscapeDirections() throws {
        let info = try appInfoDictionary()
        XCTAssertEqual(
            info["UISupportedInterfaceOrientations~ipad"] as? [String],
            [
                "UIInterfaceOrientationPortrait",
                "UIInterfaceOrientationPortraitUpsideDown",
                "UIInterfaceOrientationLandscapeLeft",
                "UIInterfaceOrientationLandscapeRight"
            ]
        )
        XCTAssertNil(info["UIRequiresFullScreen"])
    }
}
