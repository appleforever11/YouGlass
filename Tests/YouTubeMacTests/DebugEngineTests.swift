import Foundation
import XCTest
@testable import YouTubeMac

final class DebugEngineTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var defaults: UserDefaults!
    private var suiteName = ""
    private var additionalSuiteName = ""
    private var additionalDefaults: UserDefaults?

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("YouGlassDebugTests-" + UUID().uuidString, isDirectory: true)
        suiteName = "YouGlassDebugTests-" + UUID().uuidString
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        if !suiteName.isEmpty {
            defaults.removePersistentDomain(forName: suiteName)
        }
        if !additionalSuiteName.isEmpty {
            additionalDefaults?.removePersistentDomain(forName: additionalSuiteName)
        }
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        try super.tearDownWithError()
    }

    func testRedactsSecretsAndBoundsRecentEvents() throws {
        defaults.set(true, forKey: YouGlassDebugEngine.diagnosticsEnabledKey)

        let engine = YouGlassDebugEngine(
            userDefaults: defaults,
            directoryURL: temporaryDirectory
        )
        engine.startSession()

        for index in 0..<300 {
            engine.record(.debug, category: "test", message: "breadcrumb " + String(index))
        }

        engine.record(
            .error,
            category: "api",
            message: "request failed key=super-secret access_token=another-secret",
            metadata: ["authorization": "Bearer secret-value"]
        )

        let recentEvents = engine.recentEvents(limit: 500)
        XCTAssertEqual(recentEvents.count, 240)

        let report = engine.makeTextReport()
        XCTAssertTrue(report.contains("<redacted>"))
        XCTAssertFalse(report.contains("super-secret"))
        XCTAssertFalse(report.contains("another-secret"))
        XCTAssertFalse(report.contains("secret-value"))
    }

    func testExportContainsStructuredSnapshotAndSessionLog() throws {
        defaults.set(true, forKey: YouGlassDebugEngine.diagnosticsEnabledKey)
        defaults.set(true, forKey: YouGlassDebugEngine.verboseLoggingKey)

        let engine = YouGlassDebugEngine(
            userDefaults: defaults,
            directoryURL: temporaryDirectory
        )
        engine.startSession()
        engine.record(.notice, category: "test", message: "export check")

        let exportURL = temporaryDirectory.appendingPathComponent("diagnostics.json")
        try engine.exportDiagnostics(to: exportURL)

        let data = try Data(contentsOf: exportURL)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertEqual(object["schemaVersion"] as? Int, 2)
        XCTAssertEqual(object["verboseLoggingEnabled"] as? Bool, true)
        XCTAssertEqual(object["hiddenWebKitBridgesEnabled"] as? Bool, false)

        let events = try XCTUnwrap(object["recentEvents"] as? [[String: Any]])
        XCTAssertTrue(events.contains { ($0["message"] as? String) == "export check" })

        let files = try FileManager.default.contentsOfDirectory(
            at: temporaryDirectory,
            includingPropertiesForKeys: nil
        )
        XCTAssertTrue(files.contains { $0.pathExtension == "jsonl" })
    }

    func testHiddenWebKitBridgesAreOptIn() {
        XCTAssertFalse(YouGlassHiddenWebKitPolicy.isEnabled(defaults: defaults))

        YouGlassHiddenWebKitPolicy.setEnabled(true, defaults: defaults)
        XCTAssertTrue(YouGlassHiddenWebKitPolicy.isEnabled(defaults: defaults))

        YouGlassHiddenWebKitPolicy.setEnabled(false, defaults: defaults)
        XCTAssertFalse(YouGlassHiddenWebKitPolicy.isEnabled(defaults: defaults))
    }

    func testNewSessionReportsPreviousUncleanSession() throws {
        let firstEngine = YouGlassDebugEngine(
            userDefaults: defaults,
            directoryURL: temporaryDirectory
        )
        firstEngine.startSession()

        additionalSuiteName = "YouGlassDebugTests-" + UUID().uuidString
        let secondDefaults = try XCTUnwrap(UserDefaults(suiteName: additionalSuiteName))
        additionalDefaults = secondDefaults
        let secondEngine = YouGlassDebugEngine(
            userDefaults: secondDefaults,
            directoryURL: temporaryDirectory
        )
        secondEngine.startSession()

        XCTAssertTrue(secondEngine.makeSnapshot().previousSessionWasUnclean)
        XCTAssertTrue(secondEngine.makeTextReport().contains("Previous session unclean: true"))
    }

    func testExceptionHandlerWritesCrashArtifact() throws {
        let engine = YouGlassDebugEngine(
            userDefaults: defaults,
            directoryURL: temporaryDirectory
        )
        engine.startSession()

        let exception = NSException(
            name: NSExceptionName(rawValue: "YouGlassTestException"),
            reason: "synthetic failure",
            userInfo: nil
        )
        engine.handleUncaughtException(exception)

        let files = try FileManager.default.contentsOfDirectory(
            at: temporaryDirectory,
            includingPropertiesForKeys: nil
        )
        let crashURL = try XCTUnwrap(files.first { $0.lastPathComponent.hasPrefix("exception-") })
        let data = try Data(contentsOf: crashURL)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertEqual(object["exceptionName"] as? String, "YouGlassTestException")
        XCTAssertEqual(object["exceptionReason"] as? String, "synthetic failure")
    }
}
