import Foundation

@Observable
class SettingsManager {
    static let shared = SettingsManager()

    var mascotVisible: Bool {
        didSet {
            UserDefaults.standard.set(mascotVisible, forKey: "mascotVisible")
            NotificationCenter.default.post(name: .WhiskyClaudeMascotVisibilityChanged, object: nil)
        }
    }

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

    /// Default OFF — user must opt in via Settings > Voice.
    var wakeWordEnabled: Bool {
        didSet {
            UserDefaults.standard.set(wakeWordEnabled, forKey: "wakeWordEnabled")
            if wakeWordEnabled {
                KeywordRecognizer.shared.start()
            } else {
                KeywordRecognizer.shared.stop()
            }
        }
    }

    /// When true, IOPMAssertion holds off system idle sleep while Whisky
    /// Claude is running. Default ON since users typically launch this for
    /// long-running Claude Code sessions.
    var preventSleep: Bool {
        didSet {
            UserDefaults.standard.set(preventSleep, forKey: "preventSleep")
            SleepBlocker.shared.applySetting(preventSleep)
        }
    }

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "mascotVisible") == nil { defaults.set(true, forKey: "mascotVisible") }
        if defaults.object(forKey: "soundsEnabled") == nil { defaults.set(true, forKey: "soundsEnabled") }
        if defaults.object(forKey: "clapTriggerEnabled") == nil { defaults.set(false, forKey: "clapTriggerEnabled") }
        if defaults.object(forKey: "clapSensitivity") == nil { defaults.set(0.5, forKey: "clapSensitivity") }
        if defaults.object(forKey: "wakeWordEnabled") == nil { defaults.set(false, forKey: "wakeWordEnabled") }
        if defaults.object(forKey: "preventSleep") == nil { defaults.set(true, forKey: "preventSleep") }

        mascotVisible = defaults.bool(forKey: "mascotVisible")
        soundsEnabled = defaults.bool(forKey: "soundsEnabled")
        clapTriggerEnabled = defaults.bool(forKey: "clapTriggerEnabled")
        clapSensitivity = defaults.double(forKey: "clapSensitivity")
        wakeWordEnabled = defaults.bool(forKey: "wakeWordEnabled")
        preventSleep = defaults.bool(forKey: "preventSleep")
    }
}
