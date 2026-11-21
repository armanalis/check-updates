using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.Linq;
using System.Threading.Tasks;
using System.Windows.Forms;

static class Program
{
    [STAThread]
    static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new MainForm());
    }
}

class MainForm : Form
{
    static readonly string[] Spinner = { "◐", "◓", "◑", "◒" };

    readonly Label title = new Label { AutoSize = true, Font = new Font("Segoe UI", 15, FontStyle.Bold), Margin = new Padding(0, 6, 0, 0) };
    readonly Button checkBtn = new Button { Text = "Kontrol Et", AutoSize = true };
    readonly Button oneBtn = new Button { Text = "Seçileni Güncelle", AutoSize = true };
    readonly Button allBtn = new Button { Text = "Hepsini Güncelle", AutoSize = true };
    readonly ListView list = new ListView { View = View.Details, FullRowSelect = true, Dock = DockStyle.Fill, Font = new Font("Segoe UI", 10) };
    readonly Timer spin = new Timer { Interval = 150 };

    List<Pkg> pkgs = new List<Pkg>();
    readonly Dictionary<string, string> status = new Dictionary<string, string>(); // by package id
    readonly Dictionary<string, double?> working = new Dictionary<string, double?>();
    int frame;
    string titleText = "";
    bool busy;

    public MainForm()
    {
        Text = "Check Updates";
        Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
        AutoScaleMode = AutoScaleMode.Dpi;
        ClientSize = new Size(760, 560);
        MinimumSize = new Size(560, 400);

        list.Columns.Add("Uygulama", 300);
        list.Columns.Add("Yüklü", 130);
        list.Columns.Add("Yeni", 130);
        list.Columns.Add("Durum", 170);
        list.DoubleClick += async (s, e) => await UpdateSelected();

        var bar = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true, Padding = new Padding(12), WrapContents = false };
        bar.Controls.AddRange(new Control[] { title, new Label { Width = 20 }, checkBtn, oneBtn, allBtn });
        Controls.Add(list);
        Controls.Add(bar);

        checkBtn.Click += async (s, e) => await Check();
        oneBtn.Click += async (s, e) => await UpdateSelected();
        allBtn.Click += async (s, e) =>
        {
            var todo = pkgs.Where(p => !p.IdTruncated).ToList();
            if (todo.Count == 0) return;
            var ok = MessageBox.Show(this, $"{todo.Count} uygulama güncellensin mi?\n\nBazı uygulamalar güncellenirken kapanabilir; kaydedilmemiş işin varsa önce kaydet.",
                "Hepsini Güncelle", MessageBoxButtons.OKCancel, MessageBoxIcon.Question);
            if (ok == DialogResult.OK) await UpdateMany(todo);
        };
        spin.Tick += (s, e) => { frame++; Render(); };
        Shown += async (s, e) => await Check();
    }

    async Task Check()
    {
        SetBusy(true, "Kontrol ediliyor…");
        try { pkgs = await Winget.ListUpgrades(); }
        catch (Win32Exception) // winget missing
        {
            SetBusy(false, "winget bulunamadı");
            if (MessageBox.Show(this, "Bu uygulama Windows'un 'Uygulama Yükleyicisi' (winget) ile çalışır. Microsoft Store'dan yüklemek ister misin?",
                    "winget gerekli", MessageBoxButtons.YesNo) == DialogResult.Yes)
                Process.Start(new ProcessStartInfo("ms-windows-store://pdp/?productid=9NBLGGH4NNS1") { UseShellExecute = true });
            return;
        }
        SetBusy(false, null);
    }

    async Task UpdateSelected()
    {
        var p = list.SelectedItems.Count > 0 ? list.SelectedItems[0].Tag as Pkg : null;
        if (p == null || busy) return;
        if (p.IdTruncated) { MessageBox.Show(this, "Bu uygulamanın kimliği kısaltılmış, tek başına güncellenemiyor."); return; }
        await UpdateMany(new List<Pkg> { p });
    }

    async Task UpdateMany(List<Pkg> todo)
    {
        if (busy) return;
        foreach (var p in todo) status.Remove(p.Id);
        for (int i = 0; i < todo.Count; i++)
        {
            var p = todo[i];
            SetBusy(true, $"Güncelleniyor {i}/{todo.Count}");
            working[p.Id] = null;
            var (code, output) = await Winget.Upgrade(p, pct => BeginInvoke((Action)(() => working[p.Id] = pct)));
            working.Remove(p.Id);
            status[p.Id] = code == 0 ? "✓ Güncellendi" : $"⚠ Hata (0x{code:X8})";
        }
        var done = new HashSet<string>(status.Where(s => s.Value.StartsWith("✓")).Select(s => s.Key));
        SetBusy(false, null);
        // re-check, but keep failed rows' messages visible
        SetBusy(true, "Kontrol ediliyor…");
        pkgs = await Winget.ListUpgrades();
        foreach (var id in done) status.Remove(id);
        SetBusy(false, null);
    }

    void SetBusy(bool on, string text)
    {
        busy = on;
        checkBtn.Enabled = oneBtn.Enabled = allBtn.Enabled = !on;
        if (on) spin.Start(); else spin.Stop();
        titleText = text ?? (pkgs.Count == 0 ? "Hepsi güncel" : $"{pkgs.Count} güncelleme var");
        Render();
    }

    void Render()
    {
        var spinner = Spinner[frame % Spinner.Length];
        title.Text = busy ? spinner + " " + titleText : titleText;

        list.BeginUpdate();
        if (list.Items.Count != pkgs.Count || list.Items.Cast<ListViewItem>().Select(it => (Pkg)it.Tag).Except(pkgs).Any())
        {
            list.Items.Clear();
            foreach (var p in pkgs) list.Items.Add(new ListViewItem(new[] { p.Name, p.Version, p.Available, "" }) { Tag = p });
        }
        foreach (ListViewItem it in list.Items)
        {
            var p = (Pkg)it.Tag;
            string s;
            if (working.TryGetValue(p.Id, out var pct)) s = spinner + " " + (pct.HasValue ? $"%{(int)pct.Value}" : "Hazırlanıyor…");
            else if (!status.TryGetValue(p.Id, out s)) s = p.IdTruncated ? "Tek tek güncellenemiyor" : "Güncelle (çift tık)";
            if (it.SubItems[3].Text != s) it.SubItems[3].Text = s;
        }
        list.EndUpdate();
    }
}
