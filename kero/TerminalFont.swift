//
//  TerminalFont.swift
//  kero
//

import AppKit
import CoreText

/// Kero font handling, same approach as Otty: bundle JetBrains Mono
/// with the app so the default looks identical on every machine, and let
/// the OS cascade cover glyphs the primary font lacks (CJK, symbols).
enum TerminalFont {
    static let defaultSize: CGFloat = 13
    static let bundledFamily = "JetBrains Mono"
    private static let symbolsFontName = "SymbolsNFM"

    /// Registers the bundled JetBrains Mono faces (Regular/Bold/Italic/
    /// BoldItalic) and the Symbols Nerd Font for this process only, so
    /// nothing is installed system-wide. Must run before the first
    /// terminal view is created.
    static func registerBundledFonts() {
        // Xcode's synchronized groups flatten Fonts/ into Contents/Resources.
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        guard !urls.isEmpty else { return }
        CTFontManagerRegisterFontURLs(urls as CFArray, .process, true, nil)
    }

    /// The editor font for the current settings.
    @MainActor
    static func current() -> NSFont {
        let settings = AppSettings.shared
        return resolve(
            family: settings.fontFamily,
            fallbackFamily: settings.fontFallbackFamily,
            size: CGFloat(settings.fontSize)
        )
    }

    /// Resolves the selected primary and fallback families for the editor.
    /// Empty primary family means the bundled default; an unknown family
    /// falls back to it too.
    ///
    /// The bundled Symbols Nerd Font is attached as a CoreText cascade
    /// entry so PUA icon glyphs (file-type symbols, git glyphs, nf-md-*)
    /// render without a user-installed patched font. JetBrains Mono covers
    /// Powerline separators itself, so those never hit the fallback.
    static func resolve(
        family: String,
        fallbackFamily: String,
        size: CGFloat
    ) -> NSFont {
        let base: NSFont
        if !family.isEmpty, family != bundledFamily,
           let chosen = NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: size) {
            base = chosen
        } else if let bundled = NSFont(name: "JetBrainsMono-Regular", size: size) {
            base = bundled
        } else {
            return .monospacedSystemFont(ofSize: size, weight: .regular)
        }

        var cascade: [NSFontDescriptor] = []
        if !fallbackFamily.isEmpty,
           base.familyName != fallbackFamily,
           let fallback = NSFontManager.shared.font(
               withFamily: fallbackFamily,
               traits: [],
               weight: 5,
               size: size
           ) {
            cascade.append(fallback.fontDescriptor)
        }
        cascade.append(NSFontDescriptor(name: symbolsFontName, size: size))
        let descriptor = base.fontDescriptor.addingAttributes([
            .cascadeList: cascade
        ])
        return NSFont(descriptor: descriptor, size: size) ?? base
    }

    /// Font Book families available for the font picker, bundled default
    /// first. The symbols-only fallback font is not a usable text font.
    static func selectableFamilies() -> [String] {
        let families = NSFontManager.shared.availableFontFamilies
            .filter { family in
                guard !family.hasPrefix("Symbols Nerd Font"),
                      family != bundledFamily, !family.hasPrefix(".")
                else { return false }
                return true
            }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        return [bundledFamily] + families
    }
}
