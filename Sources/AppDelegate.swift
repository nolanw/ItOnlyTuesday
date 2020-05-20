import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadMenu()
        observeChanges()
        updateFormatters()
        updateTitles()
    }

    // MARK: -

    func loadMenu() {
        guard menu == nil else { return }

        Bundle(for: Self.self).loadNibNamed("Menu", owner: self, topLevelObjects: nil)
        statusItem.menu = menu

        // As of writing, it's `NSFont.menuBarFont(ofSize: 14)`, but this seems slightly more resilient?
        statusItem.button?.title = " "
        let menuBarFont = statusItem.button!.attributedTitle.attribute(.font, at: 0, effectiveRange: nil) as! NSFont
        font = NSFont(descriptor:
            menuBarFont
                .fontDescriptor
                .addingAttributes([
                    .featureSettings: [
                        [NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
                         .selectorIdentifier: kMonospacedNumbersSelector
                        ],
                        [NSFontDescriptor.FeatureKey.typeIdentifier: kStylisticAlternativesType,
                         .selectorIdentifier: kStylisticAltFiveOnSelector]], // smaller digits? narrower 0 for sure
                ]), size: 0)!
    }

    @IBOutlet var menu: NSMenu!
    @IBOutlet var fullDateTimeItem: NSMenuItem!
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    // MARK: -

    func observeChanges() {
        observers += [
            clockDefaults.observe(\.dateFormat, changeHandler: { [weak self] defaults, change in
                self?.updateFormatters()
                self?.updateTitles()
            }),
            clockDefaults.observe(\.flashDateSeparators, changeHandler: { [weak self] defaults, change in
                self?.updateTitles()
            }),
        ]

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(localeDidChange), name: NSLocale.currentLocaleDidChangeNotification, object: nil)

        nc.addObserver(self, selector: #selector(clockDidChange), name: .NSSystemClockDidChange, object: nil)
        nc.addObserver(self, selector: #selector(clockDidChange), name: .NSSystemTimeZoneDidChange, object: nil)
    }

    @objc private func localeDidChange(_ notification: Notification) {
        updateFormatters()
        updateTitles()
    }

    @objc private func clockDidChange(_ notification: Notification) {
        updateTitles()
    }

    var observers: [NSKeyValueObservation] = []

    // MARK: -

    func updateTitles() {
        let now = Date()

        let title = NSMutableAttributedString(
            string: titleFormatter.string(from: now),
            attributes: [
                .foregroundColor: NSColor.controlTextColor,
                .font: font!])
        if
            clockDefaults.flashDateSeparators,
            Int(now.timeIntervalSinceReferenceDate) % 2 == 0
        {
            var remainingRange = NSRange(location: 0, length: title.length)
            var separatorRange = NSRange(location: NSNotFound, length: 0)
            while true {
                separatorRange = title.mutableString.rangeOfCharacter(from: separators, options: .backwards, range: remainingRange)
                if separatorRange.location == NSNotFound { break }

                title.addAttribute(.foregroundColor, value: NSColor.clear, range: separatorRange)

                remainingRange.length = separatorRange.location
            }
        }
        statusItem.button?.attributedTitle = title

        fullDateTimeItem.title = fullDateFormatter.string(from: now)

        updateTimer?.invalidate()

        let untilNextSecond = 1 - now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)
        updateTimer = Timer.scheduledTimer(
            withTimeInterval: untilNextSecond,
            repeats: false,
            block: { [weak self] _ in self?.updateTitles() })
    }

    var font: NSFont!
    let clockDefaults = UserDefaults(suiteName: "com.apple.menuextra.clock")!
    let separators = CharacterSet.punctuationCharacters
    var updateTimer: Timer?

    // MARK: -

    func updateFormatters() {
        titleFormatter.locale = .current
        if let format = clockDefaults.dateFormat {
            titleFormatter.dateFormat = format
        } else {
            titleFormatter.setLocalizedDateFormatFromTemplate("EEEMMMdHHmm")
        }

        fullDateFormatter.locale = .current
    }

    let titleFormatter: DateFormatter = {
        let df = DateFormatter()
        df.setAlwaysTuesday()
        return df
    }()

    let fullDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.setAlwaysTuesday()
        df.dateStyle = .full
        df.timeStyle = .none
        return df
    }()
}

extension DateFormatter {
    func setAlwaysTuesday() {
        let weekdayKeyPaths = [
            \DateFormatter.weekdaySymbols,
            \.shortWeekdaySymbols,
            \.standaloneWeekdaySymbols,
            \.veryShortWeekdaySymbols,
            \.shortStandaloneWeekdaySymbols,
            \.veryShortStandaloneWeekdaySymbols,
        ]
        for kp in weekdayKeyPaths {
            guard let symbols = self[keyPath: kp] else { continue }
            let tuesday = symbols[2]
            self[keyPath: kp] = Array(repeating: tuesday, count: symbols.count)
        }
    }
}

// MARK: -

extension AppDelegate {
    @IBAction func openDateAndTimePreferences(_ sender: Any) {
        NSWorkspace.shared.openFile("/System/Library/PreferencePanes/DateAndTime.prefPane")
    }
}

// MARK: -

extension UserDefaults {
    @objc dynamic var analog: Bool {
        get { bool(forKey: "IsAnalog") }
        set { set(newValue, forKey: "IsAnalog") }
    }

    @objc dynamic var dateFormat: String? {
        get { string(forKey: "DateFormat") }
        set { set(newValue, forKey: "DateFormat") }
    }

    @objc dynamic var flashDateSeparators: Bool {
        get { bool(forKey: "FlashDateSeparators") }
        set { set(newValue, forKey: "FlashDateSeparators") }
    }

    open override class func keyPathsForValuesAffectingValue(
        forKey key: String
    ) -> Set<String> {
        var keyPaths = super.keyPathsForValuesAffectingValue(forKey: key)
        switch key {
        case #keyPath(UserDefaults.analog):
            keyPaths.insert("IsAnalog")
        case #keyPath(UserDefaults.dateFormat):
            keyPaths.insert("DateFormat")
        case #keyPath(UserDefaults.flashDateSeparators):
            keyPaths.insert("FlashDateSeparators")
        default:
            break
        }
        return keyPaths
    }
}
