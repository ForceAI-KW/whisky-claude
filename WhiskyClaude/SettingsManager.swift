import Foundation

@Observable
class SettingsManager {
    static let shared = SettingsManager()

    var showNotch: Bool {
        didSet { UserDefaults.standard.set(showNotch, forKey: "replaceNotch") }
    }

    var soundsEnabled: Bool {
        didSet { UserDefaults.standard.set(soundsEnabled, forKey: "soundsEnabled") }
    }

    var claudeIntegrationEnabled: Bool {
        didSet { UserDefaults.standard.set(claudeIntegrationEnabled, forKey: "claudeIntegrationEnabled") }
    }

    /// Whether the clap detector is active. Default OFF — user must opt in.
    var clapTriggerEnabled: Bool {
        didSet {
            UserDefaults.standard.set(clapTriggerEnabled, forKey: "clapTriggerEnabled")
            if clapTriggerEnabled {
                ClapDetector.shared.start()
            } else {
                ClapDetector.shared.stop()
            }
        }
    }

    /// 0.0 (lenient — louder background OK) ... 1.0 (strict — only loud claps).
    var clapSensitivity: Double {
        didSet {
            UserDefaults.standard.set(clapSensitivity, forKey: "clapSensitivity")
            ClapDetector.shared.setSensitivity(clapSensitivity)
        }
    }

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "replaceNotch") == nil { defaults.set(true, forKey: "replaceNotch") }
        if defaults.object(forKey: "soundsEnabled") == nil { defaults.set(true, forKey: "soundsEnabled") }
        if defaults.object(forKey: "claudeIntegrationEnabled") == nil { defaults.set(true, forKey: "claudeIntegrationEnabled") }
        if defaults.object(forKey: "clapTriggerEnabled") == nil { defaults.set(false, forKey: "clapTriggerEnabled") }
        if defaults.object(forKey: "clapSensitivity") == nil { defaults.set(0.5, forKey: "clapSensitivity") }

        showNotch = defaults.bool(forKey: "replaceNotch")
        soundsEnabled = defaults.bool(forKey: "soundsEnabled")
        claudeIntegrationEnabled = defaults.bool(forKey: "claudeIntegrationEnabled")
        clapTriggerEnabled = defaults.bool(forKey: "clapTriggerEnabled")
        clapSensitivity = defaults.double(forKey: "clapSensitivity")
    }
}
