// winget = Windows' built-in package manager (Windows 10 1809+ / 11). It already knows which installed apps
// have updates, so this file only runs it and reads its output. No WinForms here, so it is testable on any OS.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

public class Pkg
{
    public string Name = "", Id = "", Version = "", Available = "", Source = "";
    // winget cuts long ids with "…" when the table is narrow; those can't be targeted one by one
    public bool IdTruncated => Id.EndsWith("…");
}

public static class Winget
{
    // --include-unknown: without it winget hides apps whose installed version it can't read (often Office and
    // Store apps), so they looked up to date while an update was out (same miss as Excel on the Mac)
    const string Quiet = "--accept-source-agreements --disable-interactivity --include-unknown";

    /// Parses every table in `winget upgrade` output. Headers are localized ("Name"/"Ad"), so columns
    /// are located by the positions of the header words, not their text.
    public static List<Pkg> ParseUpgradeTable(string output)
    {
        var lines = output.Replace("\r\n", "\n").Split('\n')
            .Select(l => l.Contains('\r') ? l.Substring(l.LastIndexOf('\r') + 1) : l) // drop spinner frames
            .ToList();
        var result = new List<Pkg>();
        for (int i = 1; i < lines.Count; i++)
        {
            if (!Regex.IsMatch(lines[i], @"^-{10,}\s*$")) continue;
            var starts = Regex.Matches(lines[i - 1], @"\S+").Cast<Match>().Select(m => m.Index).ToArray();
            if (starts.Length < 4) continue;
            for (int j = i + 1; j < lines.Count && lines[j].Trim().Length > 0; j++)
            {
                var row = lines[j];
                if (row.Length <= starts[2]) break; // footer like "2 upgrades available."
                string Col(int k) => k >= starts.Length || starts[k] >= row.Length ? ""
                    : row.Substring(starts[k], (k + 1 < starts.Length ? Math.Min(starts[k + 1], row.Length) : row.Length) - starts[k]).Trim();
                var p = new Pkg { Name = Col(0), Id = Col(1), Version = Col(2), Available = Col(3), Source = Col(4) };
                if (p.Id.Length > 0 && p.Available.Length > 0) result.Add(p);
            }
        }
        return result;
    }

    /// Latest download percentage in a chunk of winget output: "██████  45%" or "12.5 MB / 40.0 MB".
    public static double? LastPercent(string chunk)
    {
        double? best = null; int bestAt = -1;
        foreach (Match m in Regex.Matches(chunk, @"(\d{1,3})\s*%"))
            if (int.Parse(m.Groups[1].Value) <= 100) { best = int.Parse(m.Groups[1].Value); bestAt = m.Index; }
        foreach (Match m in Regex.Matches(chunk, @"([\d.,]+)\s*(KB|MB|GB)\s*/\s*([\d.,]+)\s*(KB|MB|GB)"))
        {
            double done = Bytes(m.Groups[1].Value, m.Groups[2].Value), total = Bytes(m.Groups[3].Value, m.Groups[4].Value);
            if (total > 0 && m.Index > bestAt) { best = Math.Min(100, done / total * 100); bestAt = m.Index; }
        }
        return best;
    }

    static double Bytes(string n, string unit) =>
        double.Parse(n.Replace(',', '.'), CultureInfo.InvariantCulture) * (unit == "GB" ? 1e9 : unit == "MB" ? 1e6 : 1e3);

    public static async Task<List<Pkg>> ListUpgrades()
    {
        var (_, output) = await Run("upgrade " + Quiet, null);
        return ParseUpgradeTable(output);
    }

    public static Task<(int code, string output)> Upgrade(Pkg p, Action<double> progress) =>
        Run($"upgrade --id \"{p.Id}\" --exact --silent --accept-package-agreements {Quiet}", chunk =>
        {
            var pct = LastPercent(chunk);
            if (pct.HasValue) progress(pct.Value);
        });

    /// Same upgrade, started through Windows' "Run as administrator" prompt (UAC). Elevated processes can't
    /// share their output with us, so there is no percentage here, only the exit code.
    public static Task<int> UpgradeElevated(Pkg p) => Task.Run(() =>
    {
        var psi = new ProcessStartInfo("winget", $"upgrade --id \"{p.Id}\" --exact --silent --accept-package-agreements {Quiet}")
        {
            UseShellExecute = true, Verb = "runas", WindowStyle = ProcessWindowStyle.Hidden,
        };
        try
        {
            using (var proc = Process.Start(psi)) { proc.WaitForExit(); return proc.ExitCode; }
        }
        catch (System.ComponentModel.Win32Exception e) when (e.NativeErrorCode == 1223) // user said No to UAC
        {
            return unchecked((int)0x800704C7);
        }
    });

    /// Runs winget and streams raw output (progress bars use \r, so line-based reading would miss them).
    static Task<(int, string)> Run(string args, Action<string> onChunk) => Task.Run(() =>
    {
        var psi = new ProcessStartInfo("winget", args)
        {
            UseShellExecute = false, CreateNoWindow = true,
            RedirectStandardOutput = true, RedirectStandardError = true,
            StandardOutputEncoding = Encoding.UTF8,
        };
        using (var proc = Process.Start(psi))
        {
            var all = new StringBuilder();
            var err = proc.StandardError.ReadToEndAsync();
            var buf = new char[4096];
            int n;
            while ((n = proc.StandardOutput.Read(buf, 0, buf.Length)) > 0)
            {
                var chunk = new string(buf, 0, n);
                all.Append(chunk);
                onChunk?.Invoke(chunk);
            }
            proc.WaitForExit();
            return (proc.ExitCode, all.ToString() + err.Result);
        }
    });
}
