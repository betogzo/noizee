import AppKit
import Foundation

/// Keeps the Dock tile and Launch Services presentation aligned with bundled `noizee.icns`, which also
/// affects stale notification header icons until the daemon picks up refreshed registration.
@MainActor
enum ApplicationPresentationSync {
    private static let launchServicesSyncedSignatureKey = "ApplicationPresentationSync.launchServicesSignature"

    /// Loads `noizee.icns` from the packaged app Resources or SwiftPM `.bundle`, applies it as the Dock
    /// runtime icon, and re-registers this bundle when the icon artifact or bundle version changes.
    static func syncDockTileAndLaunchServicesRegistration() {
        self.applyBundledIcnsAsApplicationIcon()

        guard !UITestConfig.isRunningUnitTests else { return }

        guard Bundle.main.bundleURL.pathExtension == "app",
              Bundle.main.bundleIdentifier != nil else { return }
        guard self.currentSignature() != UserDefaults.standard.string(forKey: self.launchServicesSyncedSignatureKey) else {
            return
        }

        guard self.runLaunchServicesGarbageCollectThenRegisterOwnBundle() else { return }

        UserDefaults.standard.set(self.currentSignature(), forKey: self.launchServicesSyncedSignatureKey)
        DiagnosticsLogger.app.info("Launch Services refreshed for current bundle icon/version")
    }

    // MARK: - Icon

    private static func primaryIcnsURL() -> URL? {
        let main = Bundle.main
        if let direct = main.url(forResource: "noizee", withExtension: "icns") {
            return direct
        }
        if let name = main.object(forInfoDictionaryKey: "CFBundleName") as? String {
            let embedded = main.resourceURL?
                .appendingPathComponent("\(name)_Noizee.bundle", isDirectory: true)
                .appendingPathComponent("noizee.icns", isDirectory: false)
            if let embedded, FileManager.default.fileExists(atPath: embedded.path) {
                return embedded
            }
        }
        return nil
    }

    private static func applyBundledIcnsAsApplicationIcon() {
        guard let url = primaryIcnsURL(),
              let image = NSImage(contentsOf: url),
              image.isValid
        else {
            DiagnosticsLogger.app.debug("ApplicationPresentationSync: noizee.icns not found or invalid")
            return
        }
        NSApplication.shared.applicationIconImage = image
        DiagnosticsLogger.app.debug("ApplicationPresentationSync: applied noizee.icns to NSApplication.applicationIconImage")
    }

    // MARK: - Launch Services

    private static let lsregisterExecutable = URL(
        fileURLWithPath:
        "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
    )

    private static func currentSignature() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        guard let icns = Self.primaryIcnsURL(),
              let attrs = try? FileManager.default.attributesOfItem(atPath: icns.path),
              let sizeNum = attrs[.size] as? NSNumber,
              let modified = attrs[.modificationDate] as? Date
        else {
            return version
        }
        return "\(version)-\(sizeNum.uint64Value)-\(modified.timeIntervalSince1970)"
    }

    private static func runLaunchServicesGarbageCollectThenRegisterOwnBundle() -> Bool {
        let bundlePath = Bundle.main.bundleURL.path
        guard FileManager.default.fileExists(atPath: bundlePath) else { return false }

        Self.runLsRegister(arguments: ["-gc"], failuresAreFatal: false)

        guard Self.runLsRegister(arguments: ["-f", "-R", bundlePath], failuresAreFatal: true) else { return false }
        return true
    }

    @discardableResult
    private static func runLsRegister(arguments: [String], failuresAreFatal: Bool) -> Bool {
        let process = Process()
        process.executableURL = Self.lsregisterExecutable
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            DiagnosticsLogger.app.error(
                "ApplicationPresentationSync: lsregister \(arguments.joined(separator: " ")) failed: \(error.localizedDescription, privacy: .public)"
            )
            return !failuresAreFatal
        }
        guard process.terminationStatus == 0 else {
            DiagnosticsLogger.app.error(
                "ApplicationPresentationSync: lsregister \(arguments.joined(separator: " ")) exited \(process.terminationStatus, privacy: .public)"
            )
            return !failuresAreFatal
        }
        return true
    }
}
