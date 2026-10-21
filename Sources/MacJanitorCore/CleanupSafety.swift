import Foundation

/// Locations MacJanitor must never treat as disposable cache.
///
/// Apple documents `~/Library/Caches` as purgeable, but a few folders under
/// that tree (and under app containers) hold iCloud, account, photo, music,
/// or message state. Matching is by path component so a similarly named
/// parent such as `Library` is not enough to skip a whole home directory.
enum CleanupSafety {
    /// Lowercased path-component identifiers. A component matches when it
    /// equals one of these, starts with `<name>.`, or contains `.<name>`.
    static let protectedNames: Set<String> = [
        "cloudkit",
        "familycircle",
        "com.apple.familycircled",
        "com.apple.homekit",
        "com.apple.homed",
        "com.apple.home",
        "com.apple.bird",
        "com.apple.clouddocs",
        "com.apple.icloud",
        "com.apple.iclouddrive",
        "com.apple.cloudphotod",
        "com.apple.protectedcloudstorage",
        "com.apple.fileprovider",
        "com.apple.passd",
        "com.apple.passwords",
        "com.apple.password-manager",
        "com.apple.security",
        "com.apple.keychain",
        "com.apple.akd",
        "com.apple.identityservicesd",
        "com.apple.appleaccountd",
        "com.apple.accountsd",
        "com.apple.itunes",
        "com.apple.applemediaservices",
        "com.apple.music",
        "com.apple.tv",
        "com.apple.podcasts",
        "com.apple.photos",
        "com.apple.photolibraryd",
        "com.apple.mediaanalysisd",
        "com.apple.photoanalysisd",
        "com.apple.siri",
        "com.apple.siriknowledged",
        "com.apple.messages",
        "com.apple.imagent",
        "com.apple.mobilesms",
        "com.apple.ichat",
        "com.apple.stickersd",
    ]

    static func isProtected(_ url: URL) -> Bool {
        url.pathComponents.contains { matches($0) }
    }

    static func matches(_ component: String) -> Bool {
        let name = component.lowercased()
        for protected in protectedNames {
            if name == protected { return true }
            if name.hasPrefix(protected + ".") { return true }
            if name.contains("." + protected + ".") || name.hasSuffix("." + protected) { return true }
        }
        return false
    }
}
