import Foundation

@Observable
class SettingsManager {
    static let shared = SettingsManager()

    var soundsEnabled: Bool {
        didSet { UserDefaults.standard.set(soundsEnabled, forKey: "soundsEnabled") }
    }

    /// Default OFF — user must opt in via Settings > Voice.
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

    /// 0.0 (lenient) ... 1.0 (strict). Maps to SoundAnalysis confidence threshold.
    var clapSensitivity: Double {
        didSet {
            UserDefaults.standard.set(clapSensitivity, forKey: "clapSensitivity")
            ClapDetector.shared.setSensitivity(clapSensitivity)
        }
    }

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "soundsEnabled") == nil { defaults.set(true, forKey: "soundsEnabled") }
        if defaults.object(forKey: "clapTriggerEnabled") == nil { defaults.set(false, forKey: "clapTriggerEnabled") }
        if defaults.object(forKey: "clapSensitivity") == nil { defaults.set(0.5, forKey: "clapSensitivity") }

        soundsEnabled = defaults.bool(forKey: "soundsEnabled")
        clapTriggerEnabled = defaults.bool(forKey: "clapTriggerEnabled")
        clapSensitivity = defaults.double(forKey: "clapSensitivity")
    }
}
