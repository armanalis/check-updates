// Language, settings and error reasons. No WinForms here, so tests can run on any OS.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;

public static class Lang
{
    /// "system" follows Windows' display language; "en" / "tr" force one.
    public static string Choice = "system";
    public static bool Turkish => Choice == "tr" || (Choice == "system" && CultureInfo.CurrentUICulture.TwoLetterISOLanguageName == "tr");

    static readonly Dictionary<string, (string en, string tr)> Strings = new Dictionary<string, (string, string)>
    {
        ["checking"] = ("Checking…", "Kontrol ediliyor…"),
        ["updates"] = ("{0} updates available", "{0} güncelleme var"),
        ["update1"] = ("1 update available", "1 güncelleme var"),
        ["allUpToDate"] = ("All up to date", "Hepsi güncel"),
        ["updating"] = ("Updating {0}/{1}", "Güncelleniyor {0}/{1}"),
        ["check"] = ("Check", "Kontrol Et"),
        ["updateAll"] = ("Update All", "Hepsini Güncelle"),
        ["updateSelected"] = ("Update Selected", "Seçileni Güncelle"),
        ["update"] = ("Update", "Güncelle"),
        ["settings"] = ("Settings", "Ayarlar"),
        ["colApp"] = ("App", "Uygulama"),
        ["colInstalled"] = ("Installed", "Yüklü"),
        ["colLatest"] = ("Latest", "Yeni"),
        ["colStatus"] = ("Status", "Durum"),
        ["preparing"] = ("Preparing…", "Hazırlanıyor…"),
        ["asAdmin"] = ("Installing as administrator…", "Yönetici olarak kuruluyor…"),
        ["updated"] = ("✓ Updated", "✓ Güncellendi"),
        ["doubleClick"] = ("Update (double-click)", "Güncelle (çift tık)"),
        ["truncated"] = ("Can't be updated alone", "Tek başına güncellenemiyor"),
        ["truncatedMsg"] = ("This app's ID is shortened by winget, so it can't be updated on its own. Use Update All.",
                            "Bu uygulamanın kimliği winget tarafından kısaltılmış, tek başına güncellenemiyor. Hepsini Güncelle'yi kullan."),
        ["confirmTitle"] = ("Update All", "Hepsini Güncelle"),
        ["confirmMsg"] = ("Update {0} apps?\n\nSome apps may close while updating. Save any unsaved work first.",
                          "{0} uygulama güncellensin mi?\n\nBazı uygulamalar güncellenirken kapanabilir; kaydedilmemiş işin varsa önce kaydet."),
        ["noWinget"] = ("winget not found", "winget bulunamadı"),
        ["noWingetMsg"] = ("Check Updates uses Windows' App Installer (winget). Install it from the Microsoft Store?",
                           "Bu uygulama Windows'un 'Uygulama Yükleyicisi' (winget) ile çalışır. Microsoft Store'dan yüklemek ister misin?"),
        ["menuUpdate"] = ("Update", "Güncelle"),
        ["menuAdmin"] = ("Retry as Administrator", "Yönetici Olarak Dene"),
        ["menuHide"] = ("Hide from List", "Listeden Kaldır"),
        ["hideHelp"] = ("Hidden apps can be turned back on in Settings.", "Kaldırılan uygulamaları Ayarlar'dan geri açabilirsin."),
        ["failAdmin"] = ("Needs administrator rights. Right-click → Retry as Administrator", "Yönetici izni gerekiyor. Sağ tık → Yönetici Olarak Dene"),
        ["failInUse"] = ("App is open. Close it and retry", "Uygulama açık. Kapatıp tekrar dene"),
        ["failNetwork"] = ("No internet connection", "İnternet bağlantısı yok"),
        ["failHash"] = ("Download didn't match. Try again later", "İndirilen dosya doğrulanamadı. Sonra tekrar dene"),
        ["failCancelled"] = ("Cancelled", "İptal edildi"),
        ["failReboot"] = ("Restart your PC to finish", "Bitirmek için bilgisayarı yeniden başlat"),
        ["failDisk"] = ("Not enough disk space", "Diskte yer yok"),
        ["failBusy"] = ("Another install is running. Retry in a minute", "Başka bir kurulum sürüyor. Biraz sonra tekrar dene"),
        ["failNoUpdate"] = ("winget has no installable update for this app", "winget bu uygulama için kurulabilir bir güncelleme bulamadı"),
        ["failOther"] = ("Update failed", "Güncellenemedi"),
        ["whatToCheck"] = ("What to check", "Neler kontrol edilsin"),
        ["storeApps"] = ("Apps from the Microsoft Store", "Microsoft Store'dan yüklenen uygulamalar"),
        ["otherApps"] = ("Other apps (winget catalog)", "Diğer uygulamalar (winget kataloğu)"),
        ["language"] = ("Language", "Dil"),
        ["system"] = ("System", "Sistem"),
        ["hiddenApps"] = ("Hidden apps (untick to show again)", "Kaldırılan uygulamalar (tekrar göstermek için işareti kaldır)"),
        ["none"] = ("None", "Yok"),
        ["about"] = ("About", "Hakkında"),
        ["ok"] = ("OK", "Tamam"),
        ["cancel"] = ("Cancel", "İptal"),
    };

    public static string L(string key, params object[] args)
    {
        if (!Strings.TryGetValue(key, out var s)) return key;
        var text = Turkish ? s.tr : s.en;
        return args.Length == 0 ? text : string.Format(text, args);
    }

    public static string Pct(double p) => Turkish ? $"%{(int)p}" : $"{(int)p}%";
}

/// Saved as simple "key=value" lines in %APPDATA%\CheckUpdates\settings.txt.
public class Settings
{
    public string Lang = "system";
    public bool StoreApps = true, OtherApps = true;
    public SortedSet<string> Hidden = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);

    public static string DefaultPath =>
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "CheckUpdates", "settings.txt");

    public static Settings Parse(string text)
    {
        var s = new Settings();
        foreach (var line in text.Replace("\r", "").Split('\n'))
        {
            var i = line.IndexOf('=');
            if (i <= 0) continue;
            string k = line.Substring(0, i).Trim(), v = line.Substring(i + 1).Trim();
            if (k == "lang" && (v == "system" || v == "en" || v == "tr")) s.Lang = v;
            else if (k == "store") s.StoreApps = v != "0";
            else if (k == "other") s.OtherApps = v != "0";
            else if (k == "hide" && v.Length > 0) s.Hidden.Add(v);
        }
        return s;
    }

    public string Serialize() =>
        $"lang={Lang}\nstore={(StoreApps ? 1 : 0)}\nother={(OtherApps ? 1 : 0)}\n" + string.Concat(Hidden.Select(h => $"hide={h}\n"));

    public static Settings Load(string path = null)
    {
        try { return Parse(File.ReadAllText(path ?? DefaultPath)); } catch { return new Settings(); }
    }

    public void Save(string path = null)
    {
        path = path ?? DefaultPath;
        Directory.CreateDirectory(Path.GetDirectoryName(path));
        File.WriteAllText(path, Serialize());
    }

    /// What the main list shows: not hidden, and its source is switched on.
    public bool Shows(Pkg p) =>
        !Hidden.Contains(p.Id) && (p.Source.Equals("msstore", StringComparison.OrdinalIgnoreCase) ? StoreApps : OtherApps);
}

public enum Failure { None, NeedsAdmin, InUse, Network, Hash, Cancelled, Reboot, Disk, Busy, NoUpdate, Other }

public static class Errors
{
    /// Maps winget's exit code (see winget's returnCodes docs) and output text to a reason the user can act on.
    public static Failure Classify(int code, string output)
    {
        switch ((uint)code)
        {
            case 0: return Failure.None;
            case 0x800704C7: return Failure.Cancelled;           // ERROR_CANCELLED, e.g. UAC prompt declined
            case 0x80070005: return Failure.NeedsAdmin;          // E_ACCESSDENIED
            case 0x8A150011: return Failure.Hash;                // installer hash mismatch
            case 0x8A15002B: return Failure.NoUpdate;            // no applicable upgrade
            case 0x8A150101: return Failure.InUse;               // package in use
            case 0x8A150102: return Failure.Busy;                // another install in progress
            case 0x8A150104: return Failure.Disk;                // disk full
            case 0x8A150106: return Failure.Network;             // no network
            case 0x8A150109: return Failure.Reboot;              // reboot required to finish
        }
        var o = (output ?? "").ToLowerInvariant();
        if (o.Contains("administrator") || o.Contains("access is denied") || o.Contains("elevation")) return Failure.NeedsAdmin;
        if (o.Contains("currently running") || o.Contains("in use")) return Failure.InUse;
        if (o.Contains("internet") || o.Contains("network") || o.Contains("could not resolve")) return Failure.Network;
        if (o.Contains("hash does not match")) return Failure.Hash;
        if (o.Contains("cancel")) return Failure.Cancelled;
        return Failure.Other;
    }

    public static string Message(Failure f, int code)
    {
        switch (f)
        {
            case Failure.NeedsAdmin: return Lang.L("failAdmin");
            case Failure.InUse: return Lang.L("failInUse");
            case Failure.Network: return Lang.L("failNetwork");
            case Failure.Hash: return Lang.L("failHash");
            case Failure.Cancelled: return Lang.L("failCancelled");
            case Failure.Reboot: return Lang.L("failReboot");
            case Failure.Disk: return Lang.L("failDisk");
            case Failure.Busy: return Lang.L("failBusy");
            case Failure.NoUpdate: return Lang.L("failNoUpdate");
            default: return Lang.L("failOther") + $" (0x{code:X8})";
        }
    }
}
