import SwiftUI
import AppKit

// MARK: - Language (English + Turkish)

/// "system" follows the Mac's language; "en" / "tr" force one.
func isTurkish() -> Bool {
    switch UserDefaults.standard.string(forKey: "lang") ?? "system" {
    case "tr": return true
    case "en": return false
    default: return Locale.preferredLanguages.first?.hasPrefix("tr") ?? false
    }
}

let strings: [String: (en: String, tr: String)] = [
    "checking": ("Checking…", "Kontrol ediliyor…"),
    "updates": ("%d updates available", "%d güncelleme var"),
    "update1": ("1 update available", "1 güncelleme var"),
    "allUpToDate": ("All up to date", "Hepsi güncel"),
    "updating": ("Updating %d/%d", "Güncelleniyor %d/%d"),
    "check": ("Check", "Kontrol Et"),
    "updateAll": ("Update All", "Hepsini Güncelle"),
    "update": ("Update", "Güncelle"),
    "preparing": ("Preparing…", "Hazırlanıyor…"),
    "updated": ("Updated", "Güncellendi"),
    "inAppStore": ("In App Store", "App Store'da"),
    "inApp": ("Update in app", "Uygulamada güncelle"),
    "unknown": ("Unknown", "Bilinmiyor"),
    "appFeed": ("App", "Uygulama"),
    "confirmTitle": ("Update %d apps?", "%d uygulama güncellensin mi?"),
    "confirmMsg": ("Open apps are closed, updated and reopened. Save any unsaved work first.",
                   "Açık olan uygulamalar kapatılıp güncellendikten sonra yeniden açılır. Kaydedilmemiş işin varsa önce kaydet."),
    "needsAdmin": ("Needs your Mac password", "Mac şifren gerekiyor"),
    "tryPassword": ("Try with Password", "Şifreyle Dene"),
    "couldNotQuit": ("Couldn't quit the app. Close it and retry.", "Uygulama kapatılamadı. Kapatıp tekrar dene."),
    "network": ("No internet connection", "İnternet bağlantısı yok"),
    "cancelled": ("Password was not entered", "Şifre girilmedi"),
    "failed": ("Update failed", "Güncellenemedi"),
    "retry": ("Retry", "Tekrar Dene"),
    "hide": ("Hide from List", "Listeden Kaldır"),
    "hideShort": ("Hide", "Kaldır"),
    "hideHelp": ("Stops checking this app. Turn it back on in Settings.", "Bu uygulama artık kontrol edilmez. Ayarlar'dan tekrar açabilirsin."),
    "openSite": ("Website", "Siteyi Aç"),
    "askpass": ("Check Updates needs your Mac password to update %@.", "Check Updates, %@ güncellemesi için Mac şifreni istiyor."),
    "settings": ("Settings", "Ayarlar"),
    "whatToCheck": ("What to check", "Neler kontrol edilsin"),
    "masApps": ("Apps from the App Store", "App Store'dan yüklenen uygulamalar"),
    "webApps": ("Apps downloaded from the web (DMG, ZIP)", "İnternetten indirilen uygulamalar (DMG, ZIP)"),
    "showUnknown": ("Show apps whose latest version can't be found", "En son sürümü bulunamayan uygulamaları da göster"),
    "apps": ("Apps", "Uygulamalar"),
    "appsHint": ("Turn off apps you don't want checked.", "Kontrol edilmesini istemediğin uygulamaları kapat."),
    "language": ("Language", "Dil"),
    "system": ("System", "Sistem"),
    "about": ("About", "Hakkında"),
    "done": ("Done", "Bitti"),
]

func L(_ key: String) -> String {
    guard let s = strings[key] else { return key }
    return isTurkish() ? s.tr : s.en
}
func L(_ key: String, _ args: CVarArg...) -> String { String(format: L(key), arguments: args) }
func pctText(_ p: Double) -> String { isTurkish() ? "%\(Int(p))" : "\(Int(p))%" }

let repoURL = URL(string: "https://github.com/armanalis/check-updates")!

// MARK: - Model

enum Source { case appStore, web, sparkle, unknown
    var label: String {
        switch self { case .appStore: "App Store"; case .web: "Web"; case .sparkle: L("appFeed"); case .unknown: L("unknown") }
    }
}

struct AppInfo: Identifiable {
    let id = UUID()
    let name: String, url: URL, bundleID: String
    let version: String, build: String
    let isMAS: Bool, feedURL: String?
    var latest: String? = nil
    var source = Source.unknown
    var link: URL? = nil
    var caskURL: URL? = nil
    var cask: String? = nil // Homebrew token, lets "Update" install the new version itself
    var sources: [String: String] = [:] // every version found, by source name (for --audit)

    // shortcut: an app whose short version lacks a patch number (e.g. "1.2" + build "500") can hide a "1.2.1" update; fine for real-world apps.
    var hasUpdate: Bool {
        guard let l = latest else { return false }
        var installed = [version, "\(version).\(build)"]
        // some apps keep the full version only in the build number (Opera: "140.0" + "140.0.6074.36")
        if build.contains("."), versionParts(build).first == versionParts(version).first { installed.append(build) }
        return installed.allSatisfy { isNewer(l, than: $0) }
    }
}

/// "26.46.21" > "26.46.17". Ignores suffixes like ",hash", " (123)", ".g1a2b".
func versionParts(_ s: String) -> [Int] {
    let head = s.split(separator: ",").first.map(String.init) ?? s
    let core = head.split(separator: " ").first.map(String.init) ?? head
    var out: [Int] = []
    for comp in core.split(separator: ".") {
        let digits = comp.prefix { $0.isNumber }
        guard let n = Int(digits) else { break }
        out.append(n)
        if digits.count != comp.count { break }
    }
    return out
}

func isNewer(_ a: String, than b: String) -> Bool {
    let x = versionParts(a), y = versionParts(b)
    guard !x.isEmpty, !y.isEmpty else { return false }
    for i in 0..<max(x.count, y.count) {
        let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
        if p != q { return p > q }
    }
    return false
}

// MARK: - Scanning

func scanApps() -> [AppInfo] {
    let fm = FileManager.default
    let roots = [URL(fileURLWithPath: "/Applications"), fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
    var bundles: [URL] = []
    for root in roots {
        for item in (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [] {
            if item.pathExtension == "app" { bundles.append(item); continue }
            // one level deeper, e.g. "/Applications/Corsair iCUE5 Software/iCUE.app"
            for sub in (try? fm.contentsOfDirectory(at: item, includingPropertiesForKeys: nil)) ?? [] where sub.pathExtension == "app" {
                bundles.append(sub)
            }
        }
    }
    return bundles.compactMap { url in
        // read the plist from disk: Bundle(url:) caches it, so a just-updated app would still show its old version
        guard let info = NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist")) as? [String: Any],
              let id = info["CFBundleIdentifier"] as? String else { return nil }
        let isMAS = fm.fileExists(atPath: url.appendingPathComponent("Contents/_MASReceipt").path)
        if id.hasPrefix("com.apple.") && !isMAS { return nil } // system apps update with macOS
        if id == Bundle.main.bundleIdentifier { return nil } // not ourselves
        return AppInfo(
            name: url.deletingPathExtension().lastPathComponent, url: url, bundleID: id,
            version: info["CFBundleShortVersionString"] as? String ?? "?",
            build: info["CFBundleVersion"] as? String ?? "0",
            isMAS: isMAS, feedURL: info["SUFeedURL"] as? String)
    }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
}

// MARK: - Update sources

struct Cask { let token: String, version: String, homepage: URL?, url: URL? }

/// Homebrew's public cask index knows the latest version of ~7000 Mac apps, keyed here by "WhatsApp.app".
// shortcut: downloads the ~20 MB index on every check; cache it on disk if checks become frequent.
func loadCasks() async -> [String: Cask] {
    guard let (data, _) = try? await URLSession.shared.data(from: URL(string: "https://formulae.brew.sh/api/cask.json")!),
          let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [:] }
    var out: [String: Cask] = [:], fromPkg: [String: Cask] = [:]
    for c in list {
        guard let token = c["token"] as? String, let version = c["version"] as? String, version != "latest" else { continue }
        let isVariant = token.contains("@") // "whatsapp@beta" must not override "whatsapp"
        let cask = Cask(token: token, version: version, homepage: (c["homepage"] as? String).flatMap(URL.init(string:)), url: (c["url"] as? String).flatMap(URL.init(string:)))
        for art in c["artifacts"] as? [[String: Any]] ?? [] {
            for app in art["app"] as? [Any] ?? [] {
                guard let name = app as? String else { continue }
                if !isVariant || out[name] == nil { out[name] = cask }
            }
            // pkg installers (Zoom, Teams) have no "app" entry, but their uninstall step names the app they put in /Applications
            for key in ["uninstall", "zap"] {
                for step in art[key] as? [[String: Any]] ?? [] {
                    let deletes = (step["delete"] as? [String]) ?? (step["delete"] as? String).map { [$0] } ?? []
                    for path in deletes where path.hasPrefix("/Applications/") && path.hasSuffix(".app") && !path.contains("*") {
                        let name = String(path.dropFirst("/Applications/".count))
                        if !name.contains("/"), !isVariant || fromPkg[name] == nil { fromPkg[name] = cask }
                    }
                }
            }
        }
    }
    return out.merging(fromPkg) { app, _ in app } // a real "app" entry wins over an uninstall path
}

func appStoreLatest(_ bundleID: String) async -> (String, URL?)? {
    let country = Locale.current.region?.identifier ?? "US"
    var comps = URLComponents(string: "https://itunes.apple.com/lookup")!
    comps.queryItems = [.init(name: "bundleId", value: bundleID), .init(name: "country", value: country)]
    guard let (data, _) = try? await URLSession.shared.data(from: comps.url!),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let r = (json["results"] as? [[String: Any]])?.first,
          let v = r["version"] as? String else { return nil }
    let link = (r["trackViewUrl"] as? String).flatMap(URL.init(string:))
    // Universal (iPhone + Mac) apps: lookup returns the newest version on ANY platform, and the Mac build can lag
    // (Prime Video: 10.158 on iPhone, 10.157 on Mac). Ask the Mac store page instead.
    let devices = r["supportedDevices"] as? [String] ?? []
    if devices.contains(where: { !$0.hasPrefix("Mac") }), let id = r["trackId"] as? Int,
       let mac = await macStoreVersion(id: id, country: country) {
        return (mac, link)
    }
    return (v, link)
}

// shortcut: reads the version history on the App Store web page; if Apple changes that HTML we fall back to the lookup version.
func macStoreVersion(id: Int, country: String) async -> String? {
    guard let url = URL(string: "https://apps.apple.com/\(country.lowercased())/app/id\(id)?platform=mac"),
          let (data, _) = try? await URLSession.shared.data(from: url),
          let html = String(data: data, encoding: .utf8) else { return nil }
    let re = try! NSRegularExpression(pattern: #">(?:Version |Sürüm )?(\d+(?:\.\d+)+)</span>\s*<time"#)
    let found = re.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap {
        Range($0.range(at: 1), in: html).map { String(html[$0]) }
    }
    return found.max { isNewer($1, than: $0) }
}

/// Sparkle is the updater most non-App-Store Mac apps use; its feed lists released versions.
// shortcut: ignores Sparkle beta channels, so an app might report a beta as "latest".
func sparkleLatest(_ feed: String) async -> String? {
    guard let url = URL(string: feed), let (data, _) = try? await URLSession.shared.data(from: url),
          let text = String(data: data, encoding: .utf8) else { return nil }
    return sparkleLatest(xml: text)
}

/// Newest release in a Sparkle feed, ignoring beta/nightly items (they carry <sparkle:channel>).
func sparkleLatest(xml text: String) -> String? {
    guard text.contains("<rss") || text.contains("sparkle") else { return nil }
    let re = try! NSRegularExpression(pattern: #"shortVersionString(?:="|>)([^"<]+)"#)
    let looksLikeVersion = try! NSRegularExpression(pattern: #"^\d+(\.\d+)+"#) // skips nightlies like "663205b5 (2024-12-20)"
    let found = text.components(separatedBy: "<item").dropFirst()
        .filter { !$0.contains("<sparkle:channel>") && !$0.contains("sparkle:channel=") }
        .flatMap { item in
            re.matches(in: item, range: NSRange(item.startIndex..., in: item)).compactMap {
                Range($0.range(at: 1), in: item).map { String(item[$0]).trimmingCharacters(in: .whitespaces) }
            }
        }
        .filter { looksLikeVersion.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) != nil }
    return found.max { isNewer($1, than: $0) }
}

// MARK: - Finding an app's own update feed

/// Every "https://..." string inside a binary file.
func httpsURLs(in data: Data) -> Set<String> {
    let needle = Array("https://".utf8)
    let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~:/?#@!$&'()*+,;=%".utf8)
    var out = Set<String>()
    data.withUnsafeBytes { (buf: UnsafeRawBufferPointer) in
        guard let base = buf.baseAddress else { return }
        let n = buf.count
        var i = 0
        while i + needle.count < n {
            guard let hit = memchr(base + i, Int32(needle[0]), n - i - needle.count) else { break }
            i = base.distance(to: UnsafeRawPointer(hit))
            if memcmp(base + i, needle, needle.count) == 0 {
                var j = i + needle.count
                while j < n, allowed.contains(buf[j]) { j += 1 }
                if (12...300).contains(j - i) { out.insert(String(decoding: buf[i..<j], as: UTF8.self)) }
                i = j
            } else { i += 1 }
        }
    }
    return out
}

/// URLs in the app's binaries that look like update feeds, best guesses first.
func feedCandidates(in appURL: URL) -> [String] {
    let contents = appURL.appendingPathComponent("Contents")
    var files: [URL] = []
    if let exe = NSDictionary(contentsOf: contents.appendingPathComponent("Info.plist"))?["CFBundleExecutable"] as? String {
        files.append(contents.appendingPathComponent("MacOS/" + exe))
    }
    let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
    if let e = FileManager.default.enumerator(at: contents.appendingPathComponent("Frameworks"), includingPropertiesForKeys: keys) {
        for case let f as URL in e where files.count < 60 {
            if e.level > 5 { e.skipDescendants(); continue }
            guard let v = try? f.resourceValues(forKeys: Set(keys)), v.isRegularFile == true,
                  let size = v.fileSize, (100_000...400_000_000).contains(size) else { continue }
            files.append(f)
        }
    }
    var urls = Set<String>()
    for f in files {
        if let d = try? Data(contentsOf: f, options: .alwaysMapped) { urls.formUnion(httpsURLs(in: d)) }
    }
    func score(_ u: String) -> Int {
        let l = u.lowercased()
        return (l.contains("appcast") ? 4 : 0) + (l.contains("update") ? 2 : 0) + (l.hasSuffix(".xml") ? 1 : 0) + (l.contains("feed") ? 1 : 0)
    }
    return urls
        .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:)'")) }
        .filter { score($0) > 0 && !$0.contains("sparkle-project.org") && !$0.contains("apple.com/DTDs") && !$0.contains("%") }
        .sorted { (score($0), $1) > (score($1), $0) }
}

/// Finds a Sparkle feed even when the app keeps it out of Info.plist (WhatsApp, Ghostty) and remembers the answer
/// per app version, so each app's files are only read once.
func discoverFeed(_ app: AppInfo) async -> String? {
    let key = "feed2.\(app.bundleID).\(app.version)"
    if let cached = UserDefaults.standard.string(forKey: key) { return cached.isEmpty ? nil : cached }
    let candidates = await Task.detached(priority: .utility) { feedCandidates(in: app.url) }.value
    var found: String?
    for url in candidates.prefix(6) {
        // must answer like a feed AND be about this app: same major version family, not some bundled library's feed
        if let v = await sparkleLatest(url), let new = versionParts(v).first, let old = versionParts(app.version).first,
           (old...old + 2).contains(new) { found = url; break }
    }
    UserDefaults.standard.set(found ?? "", forKey: key)
    return found
}

/// Electron apps built with electron-builder ship app-update.yml, which says where their releases live.
func electronFeedURL(yml: String) -> URL? {
    func val(_ k: String) -> String? {
        yml.split(whereSeparator: \.isNewline).first { $0.hasPrefix(k + ":") }
            .map { $0.dropFirst(k.count + 1).trimmingCharacters(in: CharacterSet(charactersIn: " '\"")) }
    }
    let file = (val("channel") ?? "latest") + "-mac.yml"
    switch val("provider") {
    case "generic": return val("url").flatMap { URL(string: $0.hasSuffix("/") ? $0 + file : $0 + "/" + file) }
    case "github":
        guard let o = val("owner"), let r = val("repo") else { return nil }
        return URL(string: "https://github.com/\(o)/\(r)/releases/latest/download/\(file)")
    default: return nil
    }
}

func electronLatest(_ app: AppInfo) async -> String? {
    guard let yml = try? String(contentsOf: app.url.appendingPathComponent("Contents/Resources/app-update.yml"), encoding: .utf8),
          let url = electronFeedURL(yml: yml),
          let (data, resp) = try? await URLSession.shared.data(from: url), (resp as? HTTPURLResponse)?.statusCode == 200,
          let text = String(data: data, encoding: .utf8),
          let line = text.split(whereSeparator: \.isNewline).first(where: { $0.hasPrefix("version:") }) else { return nil }
    return line.dropFirst("version:".count).trimmingCharacters(in: CharacterSet(charactersIn: " '\""))
}

func check(_ app: AppInfo, casks: [String: Cask]) async -> AppInfo {
    var a = app
    if a.isMAS {
        if let (v, link) = await appStoreLatest(a.bundleID) {
            (a.latest, a.source, a.link) = (v, .appStore, link)
            a.sources["App Store"] = v
        }
        return a
    }
    if let c = casks[a.url.lastPathComponent] {
        (a.latest, a.source, a.link, a.cask, a.caskURL) = (c.version.split(separator: ",").first.map(String.init), .web, c.homepage, c.token, c.url)
        a.sources["Homebrew"] = a.latest
    }
    // Homebrew's catalog can lag an app's own updater by days (WhatsApp: brew 26.46.21, app 26.47.12),
    // so also ask the app itself and keep whichever is newer.
    var own: String?
    if let feed = a.feedURL, let v = await sparkleLatest(feed) { own = v; a.sources["Sparkle (Info.plist)"] = v }
    else if let feed = await discoverFeed(a), let v = await sparkleLatest(feed) { own = v; a.sources["Sparkle (found in app)"] = v }
    if own == nil, let v = await electronLatest(a) { own = v; a.sources["Electron app-update.yml"] = v }
    if let v = own, a.latest.map({ isNewer(v, than: $0) }) ?? true {
        a.latest = v
        a.source = .sparkle
        a.cask = nil // brew would install its older version; the app's own updater gets the new one
    }
    return a
}

// MARK: - Settings

enum Pref {
    static var d: UserDefaults { .standard }
    // bool(forKey:) also understands "YES"/"NO" strings (e.g. from command-line arguments); default is on
    static func flag(_ k: String) -> Bool { d.object(forKey: k) == nil ? true : d.bool(forKey: k) }
    static var checkMAS: Bool { flag("checkMAS") }
    static var checkWeb: Bool { flag("checkWeb") }
    static var showUnknown: Bool { flag("showUnknown") }
    static var ignored: Set<String> { Set((d.string(forKey: "ignored") ?? "").split(separator: "\n").map(String.init)) }
}

// MARK: - Updating

func brewPath() -> String? {
    ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first { FileManager.default.isExecutableFile(atPath: $0) }
}

final class LogBox: @unchecked Sendable {
    private let lock = NSLock(); private var buf = ""
    func append(_ s: String) { lock.lock(); buf += s; lock.unlock() }
    var text: String { lock.lock(); defer { lock.unlock() }; return buf }
}

func runBrew(_ args: [String], askpass: String? = nil) async -> (ok: Bool, log: String) {
    guard let brew = brewPath() else { return (false, "Homebrew not found") }
    return await withCheckedContinuation { cont in
        let p = Process()
        p.executableURL = URL(fileURLWithPath: brew)
        p.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["HOMEBREW_NO_AUTO_UPDATE"] = "1"; env["HOMEBREW_NO_ENV_HINTS"] = "1"; env["NONINTERACTIVE"] = "1"
        if let askpass { env["SUDO_ASKPASS"] = askpass } // brew then runs `sudo -A`, which asks via this helper
        p.environment = env
        let pipe = Pipe(), log = LogBox()
        p.standardOutput = pipe; p.standardError = pipe; p.standardInput = FileHandle.nullDevice
        // drain continuously so a chatty brew can't block on a full pipe
        pipe.fileHandleForReading.readabilityHandler = { log.append(String(decoding: $0.availableData, as: UTF8.self)) }
        p.terminationHandler = { p in
            pipe.fileHandleForReading.readabilityHandler = nil
            cont.resume(returning: (p.terminationStatus == 0, log.text))
        }
        do { try p.run() } catch { cont.resume(returning: (false, error.localizedDescription)) }
    }
}

func downloadSize(_ url: URL?) async -> Double? {
    guard let url else { return nil }
    var req = URLRequest(url: url); req.httpMethod = "HEAD"
    guard let (_, resp) = try? await URLSession.shared.data(for: req), resp.expectedContentLength > 0 else { return nil }
    return Double(resp.expectedContentLength)
}

func fileSize(_ path: String) -> Double? {
    (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.doubleValue
}

/// Download % = size of brew's "<cache>.incomplete" file / server-reported size.
func percent(cache: String, total: Double?) -> Double? {
    guard let total else { return nil }
    if let part = fileSize(cache + ".incomplete") { return min(99, part / total * 100) }
    return fileSize(cache) != nil ? 100 : nil
}

/// Politely quits an app (it can still ask to save). Never force-kills, to avoid losing unsaved work.
func quitApp(_ bundleID: String) async -> (wasRunning: Bool, ok: Bool) {
    let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    if running.isEmpty { return (false, true) }
    running.forEach { $0.terminate() }
    for _ in 0..<60 {
        if running.allSatisfy(\.isTerminated) { return (true, true) }
        try? await Task.sleep(for: .milliseconds(250))
    }
    return (true, false)
}

/// A tiny helper sudo runs to ask for the password with a standard macOS dialog. The password goes
/// straight from the dialog to sudo; this app never sees or stores it.
func makeAskpass(appName: String) -> String? {
    let safe = appName.filter { $0 != "\"" && $0 != "\\" && $0 != "'" }
    let prompt = L("askpass", safe).filter { $0 != "\"" && $0 != "\\" && $0 != "'" }
    let script = """
    #!/bin/sh
    exec /usr/bin/osascript -e 'text returned of (display dialog "\(prompt)" default answer "" with hidden answer with title "Check Updates" with icon caution)'
    """
    let path = NSTemporaryDirectory() + "check-updates-askpass.sh"
    guard FileManager.default.createFile(atPath: path, contents: Data(script.utf8), attributes: [.posixPermissions: 0o700]) else { return nil }
    return path
}

enum Failure: Equatable {
    case needsAdmin, couldNotQuit, network, cancelled, other(String)
    var message: String {
        switch self {
        case .needsAdmin: L("needsAdmin")
        case .couldNotQuit: L("couldNotQuit")
        case .network: L("network")
        case .cancelled: L("cancelled")
        case .other(let s): s.isEmpty ? L("failed") : L("failed") + ": " + s
        }
    }
}

/// Turns brew's log into a reason the user can act on.
func classify(_ log: String, usedPassword: Bool) -> Failure {
    let l = log.lowercased()
    if usedPassword && (l.contains("user canceled") || l.contains("no password was provided") || l.contains("-128")) { return .cancelled }
    if l.contains("a terminal is required") || l.contains("password is required") || l.contains("permission denied") { return .needsAdmin }
    if l.contains("could not resolve host") || l.contains("curl: (6)") || l.contains("curl: (7)") || l.contains("network is unreachable") { return .network }
    let err = log.split(whereSeparator: \.isNewline).last { $0.contains("Error:") }
    return .other(err.map { String($0).replacingOccurrences(of: "Error: ", with: "") } ?? "")
}

enum UpdateState { case working(Double?), updated, inAppStore, inApp, failed(Failure) }

// MARK: - UI

@MainActor final class Checker: ObservableObject {
    @Published var installed: [AppInfo] = [] // everything found, for Settings
    @Published var apps: [AppInfo] = []      // what the main list shows
    @Published var busy = false
    @Published var state: [String: UpdateState] = [:] // by bundle ID, so it survives a re-check
    @Published var updating: (done: Int, total: Int)?

    func run() async {
        busy = true
        let scanned = scanApps()
        installed = scanned
        let ignored = Pref.ignored
        let wanted = scanned.filter { !ignored.contains($0.bundleID) && ($0.isMAS ? Pref.checkMAS : Pref.checkWeb) }
        apps = wanted
        let casks = Pref.checkWeb ? await loadCasks() : [:]
        let showUnknown = Pref.showUnknown
        apps = await withTaskGroup(of: AppInfo.self) { group in
            for app in wanted { group.addTask { await check(app, casks: casks) } }
            var done: [AppInfo] = []
            for await a in group { done.append(a) }
            return done
        }
        .filter { showUnknown || $0.latest != nil }
        .sorted { ($0.hasUpdate ? 0 : 1, $0.name.lowercased()) < ($1.hasUpdate ? 0 : 1, $1.name.lowercased()) }
        busy = false
    }

    func updateAll() async { await updateList(apps.filter(\.hasUpdate)) }

    /// Same list Settings → Apps edits, so the user can bring it back there.
    func hide(_ app: AppInfo) {
        let d = UserDefaults.standard
        var set = Pref.ignored
        set.insert(app.bundleID)
        d.set(set.sorted().joined(separator: "\n"), forKey: "ignored")
        apps.removeAll { $0.bundleID == app.bundleID }
        state[app.bundleID] = nil
    }

    func updateList(_ list: [AppInfo], withPassword: Bool = false) async {
        guard updating == nil else { return }
        list.forEach { state[$0.bundleID] = nil }
        updating = (0, list.count)
        var openedStore = false
        for (i, app) in list.enumerated() {
            if app.source == .appStore {
                // App Store apps can only be updated by the App Store itself
                if !openedStore { NSWorkspace.shared.open(URL(string: "macappstore://showUpdatesPage")!); openedStore = true }
                state[app.bundleID] = .inAppStore
            } else if let cask = app.cask, brewPath() != nil {
                await brewUpdate(app, cask: cask, withPassword: withPassword)
            } else {
                NSWorkspace.shared.open(app.url) // the app's own updater takes over
                if let link = app.link { NSWorkspace.shared.open(link) }
                state[app.bundleID] = .inApp
            }
            updating = (i + 1, list.count)
        }
        updating = nil
        await run()
    }

    private func brewUpdate(_ app: AppInfo, cask: String, withPassword: Bool) async {
        let id = app.bundleID
        state[id] = .working(nil)
        let q = await quitApp(id)
        guard q.ok else { state[id] = .failed(.couldNotQuit); return }
        let cache = (await runBrew(["--cache", "--cask", cask])).log.trimmingCharacters(in: .whitespacesAndNewlines)
        let total = await downloadSize(app.caskURL)
        let poller = Task { @MainActor in
            while !Task.isCancelled {
                if let pct = percent(cache: cache, total: total) { state[id] = .working(pct) }
                try? await Task.sleep(for: .milliseconds(300))
            }
        }
        // Apps owned by root (pkg installs like Zoom, Teams, Shottr) always need the password, so ask right away
        // instead of failing first and making the user press "Try with Password".
        let owner = (try? FileManager.default.attributesOfItem(atPath: app.url.path)[.ownerAccountID] as? NSNumber)?.uint32Value
        let needsPassword = withPassword || (owner != nil && owner != getuid())
        // --force replaces the existing app even if it was installed by hand; settings in ~/Library are kept.
        let askpass = needsPassword ? makeAskpass(appName: app.name) : nil
        let (ok, log) = await runBrew(["install", "--cask", "--force", cask], askpass: askpass)
        poller.cancel()
        if let askpass { try? FileManager.default.removeItem(atPath: askpass) }
        state[id] = ok ? .updated : .failed(classify(log, usedPassword: needsPassword))
        if q.wasRunning { NSWorkspace.shared.open(app.url) }
    }
}

struct ContentView: View {
    @StateObject var checker = Checker()
    @State var confirmAll = false
    @State var showSettings = false
    @AppStorage("lang") var lang = "system"

    var body: some View {
        let pending = checker.apps.filter(\.hasUpdate)
        let locked = checker.busy || checker.updating != nil
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if let u = checker.updating {
                    ProgressView().controlSize(.small)
                    Text(L("updating", u.done, u.total)).font(.title2.bold())
                } else {
                    Text(checker.busy ? L("checking")
                         : pending.isEmpty ? L("allUpToDate")
                         : pending.count == 1 ? L("update1") : L("updates", pending.count)).font(.title2.bold())
                    if checker.busy { ProgressView().controlSize(.small) }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    // small repo link above the buttons, not a button of its own
                    Link("github.com/armanalis/check-updates", destination: repoURL)
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(L("check")) { Task { await checker.run() } }
                            .keyboardShortcut("r").disabled(locked)
                        Button(L("updateAll")) { confirmAll = true }
                            .buttonStyle(.borderedProminent).disabled(locked || pending.isEmpty)
                        Button { showSettings = true } label: { Image(systemName: "gearshape") }
                            .keyboardShortcut(",").help(L("settings")).disabled(locked)
                    }
                }
            }.padding()
            List(checker.apps) { app in
                HStack(spacing: 10) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path)).resizable().frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name).font(.headline)
                        Text("\(app.version)  →  \(app.latest ?? "—")  ·  \(app.source.label)")
                            .font(.caption).foregroundStyle(.secondary)
                        if case .failed(let f) = checker.state[app.bundleID] {
                            Label(f.message, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption).foregroundStyle(.orange).lineLimit(2)
                        }
                    }
                    Spacer()
                    status(app, locked: locked)
                }
                .padding(.vertical, 2)
                .contextMenu {
                    Button(L("hide")) { checker.hide(app) }.disabled(locked)
                }
            }
        }
        .id(lang) // redraw every string when the language changes
        .frame(minWidth: 600, minHeight: 560)
        .task {
            await checker.run()
            await snapshotIfAsked()
        }
        .sheet(isPresented: $showSettings, onDismiss: { Task { await checker.run() } }) {
            SettingsView(checker: checker)
        }
        .confirmationDialog(L("confirmTitle", pending.count), isPresented: $confirmAll) {
            Button(L("updateAll")) { Task { await checker.updateAll() } }
        } message: {
            Text(L("confirmMsg"))
        }
    }

    /// For README screenshots: `--snapshot-dir=/path` saves main.png and settings.png there and quits.
    /// The app draws its own windows, so no screen-recording permission is needed.
    /// (One dash-prefixed argument on purpose: macOS treats a bare path argument as a document to open
    /// and then skips creating the main window.)
    func snapshotIfAsked() async {
        guard let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--snapshot-dir=") }) else { return }
        let dir = String(arg.dropFirst("--snapshot-dir=".count))
        try? await Task.sleep(for: .seconds(1))
        guard let win = NSApp.windows.first(where: { $0.isVisible }) else { exit(1) }
        NSApp.activate(ignoringOtherApps: true) // inactive windows draw gray buttons
        win.makeKeyAndOrderFront(nil)
        try? await Task.sleep(for: .seconds(0.5))
        savePNG(win, to: dir + "/main.png")
        showSettings = true
        try? await Task.sleep(for: .seconds(1.5))
        if let sheet = win.attachedSheet { savePNG(sheet, to: dir + "/settings.png") }
        exit(0)
    }

    @ViewBuilder func status(_ app: AppInfo, locked: Bool) -> some View {
        switch checker.state[app.bundleID] {
        case .working(let pct):
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(pct.map(pctText) ?? L("preparing")).monospacedDigit().frame(minWidth: 44, alignment: .trailing)
            }
        case .updated where app.hasUpdate:
            Label(L("updated"), systemImage: "checkmark").foregroundStyle(.secondary)
        case .inAppStore where app.hasUpdate:
            Label(L("inAppStore"), systemImage: "arrow.up.forward.app").foregroundStyle(.secondary)
        case .inApp where app.hasUpdate:
            Label(L("inApp"), systemImage: "arrow.up.forward.app").foregroundStyle(.secondary)
        case .failed(let f):
            HStack(spacing: 6) {
                Button(L("hideShort")) { checker.hide(app) }
                    .help(L("hideHelp")).disabled(locked)
                if let link = app.link, f != .needsAdmin {
                    Button(L("openSite")) { NSWorkspace.shared.open(link) }
                }
                Button(f == .needsAdmin || f == .cancelled ? L("tryPassword") : L("retry")) {
                    Task { await checker.updateList([app], withPassword: f == .needsAdmin || f == .cancelled) }
                }
                .buttonStyle(.borderedProminent).disabled(locked)
            }
        default:
            if app.hasUpdate {
                Button(L("update")) { Task { await checker.updateList([app]) } }
                    .buttonStyle(.borderedProminent).disabled(locked)
            } else if app.latest != nil {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var checker: Checker
    @AppStorage("checkMAS") var checkMAS = true
    @AppStorage("checkWeb") var checkWeb = true
    @AppStorage("showUnknown") var showUnknown = true
    @AppStorage("ignored") var ignoredRaw = ""
    @AppStorage("lang") var lang = "system"
    @Environment(\.dismiss) var dismiss

    func isOn(_ id: String) -> Binding<Bool> {
        Binding(
            get: { !ignoredRaw.split(separator: "\n").contains(Substring(id)) },
            set: { on in
                var set = Set(ignoredRaw.split(separator: "\n").map(String.init))
                if on { set.remove(id) } else { set.insert(id) }
                ignoredRaw = set.sorted().joined(separator: "\n")
            })
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section(L("whatToCheck")) {
                    Toggle(L("masApps"), isOn: $checkMAS)
                    Toggle(L("webApps"), isOn: $checkWeb)
                    Toggle(L("showUnknown"), isOn: $showUnknown)
                }
                Section(L("language")) {
                    Picker(L("language"), selection: $lang) {
                        Text(L("system")).tag("system")
                        Text("English").tag("en")
                        Text("Türkçe").tag("tr")
                    }.labelsHidden().pickerStyle(.segmented)
                }
                Section {
                    ForEach(checker.installed) { app in
                        Toggle(isOn: isOn(app.bundleID)) {
                            HStack(spacing: 8) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path)).resizable().frame(width: 20, height: 20)
                                Text(app.name)
                                Text(app.isMAS ? "App Store" : "Web").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .disabled(app.isMAS ? !checkMAS : !checkWeb)
                    }
                } header: { Text(L("apps")) } footer: { Text(L("appsHint")) }
                Section(L("about")) {
                    LabeledContent("Check Updates", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                    Link("github.com/armanalis/check-updates", destination: repoURL)
                }
            }
            .formStyle(.grouped)
            HStack { Spacer(); Button(L("done")) { dismiss() }.keyboardShortcut(.defaultAction) }.padding()
        }
        .id(lang)
        .frame(width: 480, height: 620)
    }
}

@main struct CheckUpdatesApp: App {
    init() {
        if CommandLine.arguments.contains("--selftest") { selfTest(); exit(0) }
        if CommandLine.arguments.contains("--audit") { // which sources answered for each app, and where they disagree
            Task { @MainActor in
                let c = Checker(); await c.run()
                for a in c.apps.sorted(by: { $0.name < $1.name }) {
                    let vals = Set(a.sources.values.map { versionParts($0) })
                    let flag = a.sources.isEmpty ? "NONE    " : vals.count > 1 ? "DIFFER  " : a.sources.count == 1 ? "1 source" : "agree   "
                    let detail = a.sources.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "  ")
                    print(flag, a.hasUpdate ? "⬆️" : "  ", a.name, a.version, "→", a.latest ?? "-", " |", detail)
                }
                exit(0)
            }
            RunLoop.main.run()
        }
        if CommandLine.arguments.contains("--list") { // terminal output, for debugging
            Task { @MainActor in
                let c = Checker(); await c.run()
                for a in c.apps { print(a.hasUpdate ? "⬆️" : "  ", a.name, a.version, "->", a.latest ?? "-", "(\(a.source.label))") }
                exit(0)
            }
            RunLoop.main.run()
        }
        if let i = CommandLine.arguments.firstIndex(of: "--update"), i + 1 < CommandLine.arguments.count { // debug: update one app
            let name = CommandLine.arguments[i + 1]
            Task { @MainActor in
                let c = Checker(); await c.run()
                guard let app = c.apps.first(where: { $0.name == name }) else { print("not found"); exit(1) }
                let watcher = Task { while !Task.isCancelled { print(c.state[app.bundleID] as Any); try? await Task.sleep(for: .seconds(2)) } }
                await c.updateList([app]); watcher.cancel()
                let now = c.apps.first { $0.bundleID == app.bundleID }
                print("result:", c.state[app.bundleID] as Any, "version now:", now?.version ?? "?", "hasUpdate:", now?.hasUpdate ?? false)
                exit(0)
            }
            RunLoop.main.run()
        }
    }
    var body: some Scene {
        WindowGroup("Check Updates") { ContentView() }
    }
}

func selfTest() {
    precondition(isNewer("26.46.21", than: "26.46.17"))
    precondition(!isNewer("0.40.17", than: "0.40.17"))
    precondition(isNewer("1.10", than: "1.9"))
    precondition(!isNewer("1.3.10.2586,abc", than: "1.3.10.2586.g1a2b"))
    precondition(!isNewer("16.103.25111410", than: "16.103.25111410"))
    var a = AppInfo(name: "W", url: URL(fileURLWithPath: "/x"), bundleID: "x", version: "16.103", build: "25111410", isMAS: false, feedURL: nil)
    a.latest = "16.103.25111410"; precondition(!a.hasUpdate)
    a.latest = "16.104.1"; precondition(a.hasUpdate)
    var o = AppInfo(name: "Opera", url: URL(fileURLWithPath: "/x"), bundleID: "o", version: "140.0", build: "140.0.6074.36", isMAS: false, feedURL: nil)
    o.latest = "140.0.6074.36"; precondition(!o.hasUpdate)
    o.latest = "141.0.1"; precondition(o.hasUpdate)
    var sh = AppInfo(name: "Shottr", url: URL(fileURLWithPath: "/x"), bundleID: "s", version: "1.9.3", build: "137", isMAS: false, feedURL: nil)
    sh.latest = "1.10.0"; precondition(sh.hasUpdate)
    precondition(classify("sudo: a terminal is required to read the password", usedPassword: false) == .needsAdmin)
    precondition(classify("curl: (6) Could not resolve host: github.com", usedPassword: false) == .network)
    precondition(classify("Error: shottr: something odd", usedPassword: false) == .other("shottr: something odd"))
    precondition(httpsURLs(in: Data("xx\0https://web.whatsapp.com/desktop/mac_native/updates\0yy https://a.b/c".utf8))
                 == ["https://web.whatsapp.com/desktop/mac_native/updates", "https://a.b/c"])
    let feedXML = """
    <rss><channel><item><sparkle:shortVersionString>2.0</sparkle:shortVersionString></item>
    <item><sparkle:channel>beta</sparkle:channel><sparkle:shortVersionString>3.0-beta</sparkle:shortVersionString></item>
    <item><enclosure sparkle:shortVersionString="1.9"/></item></channel></rss>
    """
    precondition(sparkleLatest(xml: feedXML) == "2.0")
    precondition(sparkleLatest(xml: "<rss><item><sparkle:shortVersionString>663205b5 (2024-12-20)</sparkle:shortVersionString></item><item><sparkle:shortVersionString>1.4.0</sparkle:shortVersionString></item></rss>") == "1.4.0")
    precondition(electronFeedURL(yml: "provider: generic\nurl: 'https://desktop-release.notion-static.com'\nchannel: arm64\n")?.absoluteString
                 == "https://desktop-release.notion-static.com/arm64-mac.yml")
    precondition(electronFeedURL(yml: "owner: acme\nrepo: app\nprovider: github\n")?.absoluteString
                 == "https://github.com/acme/app/releases/latest/download/latest-mac.yml")
    let tmp = NSTemporaryDirectory() + "cu-selftest"
    FileManager.default.createFile(atPath: tmp + ".incomplete", contents: Data(count: 250))
    precondition(percent(cache: tmp, total: 1000) == 25)
    try? FileManager.default.removeItem(atPath: tmp + ".incomplete")
    precondition(percent(cache: tmp, total: 1000) == nil)
    print("selftest ok")
}

/// Renders a window (title bar included) into a PNG file.
func savePNG(_ window: NSWindow, to path: String) {
    guard let view = window.contentView?.superview ?? window.contentView,
          let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
    view.cacheDisplay(in: view.bounds, to: rep)
    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
}
