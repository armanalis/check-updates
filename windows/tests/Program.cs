using System;
using System.Linq;

static void Check(bool ok, string what) { if (!ok) throw new Exception("FAIL: " + what); }

// English output with spinner frames before the header, a footer, and a second "explicit targeting" table
var en = "   - \r   \\ \r   | \rName                       Id                          Version        Available      Source\n" +
         "------------------------------------------------------------------------------------------------\n" +
         "Google Chrome              Google.Chrome               130.0.6723.70  131.0.6778.86  winget\n" +
         "Discord                    Discord.Discord             1.0.9163       1.0.9170       winget\n" +
         "Microsoft Visual Studio C… Microsoft.VCRedist.2015+.x… 14.38.33135.0  14.42.34433.0  winget\n" +
         "3 upgrades available.\n\n" +
         "The following packages have an upgrade available, but require explicit targeting for upgrade:\n" +
         "Name     Id              Version  Available  Source\n" +
         "---------------------------------------------------\n" +
         "Spotify  Spotify.Spotify 1.2.48   1.2.50     winget\n";
var a = Winget.ParseUpgradeTable(en);
Check(a.Count == 4, "en count " + a.Count);
Check(a[0].Name == "Google Chrome" && a[0].Id == "Google.Chrome" && a[0].Version == "130.0.6723.70" && a[0].Available == "131.0.6778.86" && a[0].Source == "winget", "en row 0");
Check(a[2].IdTruncated && !a[0].IdTruncated, "truncated id");
Check(a[3].Id == "Spotify.Spotify" && a[3].Available == "1.2.50", "second table");

// Turkish Windows, CRLF line endings
var tr = "Ad              Kimlik            Sürüm     Kullanılabilir  Kaynak\r\n" +
         "-----------------------------------------------------------------\r\n" +
         "WhatsApp        9NKSQGP7F2NH      2.24.1    2.24.5          msstore\r\n" +
         "Ollama          Ollama.Ollama     0.40.1    0.40.17         winget\r\n" +
         "2 yükseltme kullanılabilir.\r\n";
var b = Winget.ParseUpgradeTable(tr);
Check(b.Count == 2 && b[1].Id == "Ollama.Ollama" && b[1].Available == "0.40.17" && b[0].Source == "msstore", "tr");

Check(Winget.ParseUpgradeTable("No installed package found matching input criteria.").Count == 0, "empty");

// Progress: percent bar, then size bar wins because it comes later
Check(Winget.LastPercent("  ██████████              45%") == 45, "pct");
Check(Math.Abs(Winget.LastPercent("██ 10%\r  ████  20.0 MB / 80.0 MB").Value - 25) < 0.01, "size");
Check(Winget.LastPercent("Starting package install...") == null, "none");
Console.WriteLine("parser tests ok");
