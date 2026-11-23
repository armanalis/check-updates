using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.Linq;
using System.Threading.Tasks;
using System.Windows.Forms;
using static Lang;

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
    public const string RepoUrl = "https://github.com/armanalis/check-updates";
    static readonly string[] Spinner = { "◐", "◓", "◑", "◒" };

    readonly Label title = new Label { AutoSize = true, Font = new Font("Segoe UI", 15, FontStyle.Bold), Anchor = AnchorStyles.Left };
    readonly LinkLabel repo = new LinkLabel { Text = "github.com/armanalis/check-updates", AutoSize = true, Anchor = AnchorStyles.Right,
                                              LinkColor = SystemColors.GrayText, LinkBehavior = LinkBehavior.HoverUnderline };
    readonly Button checkBtn = new Button { AutoSize = true };
    readonly Button oneBtn = new Button { AutoSize = true };
    readonly Button allBtn = new Button { AutoSize = true };
    readonly Button settingsBtn = new Button { Text = "⚙", AutoSize = true, Font = new Font("Segoe UI Symbol", 10) };
    readonly ListView list = new ListView { View = View.Details, FullRowSelect = true, Dock = DockStyle.Fill, Font = new Font("Segoe UI", 10), ShowItemToolTips = true };
    readonly ContextMenuStrip menu = new ContextMenuStrip();
    readonly ToolTip tips = new ToolTip();
    readonly Timer spin = new Timer { Interval = 150 };

    Settings settings = Settings.Load();
    List<Pkg> all = new List<Pkg>();     // everything winget reported
    List<Pkg> pkgs = new List<Pkg>();    // what the list shows (after Settings)
    readonly Dictionary<string, string> status = new Dictionary<string, string>();   // by package id
    readonly Dictionary<string, string> details = new Dictionary<string, string>();  // tooltip: raw winget output
    readonly HashSet<string> failed = new HashSet<string>();
    readonly Dictionary<string, double?> working = new Dictionary<string, double?>();
    int frame;
    string titleText = "";
    bool busy;

    public MainForm()
    {
        Lang.Choice = settings.Lang;
        Text = "Check Updates";
        Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
        AutoScaleMode = AutoScaleMode.Dpi;
        ClientSize = new Size(820, 580);
        MinimumSize = new Size(620, 400);

        for (int i = 0; i < 4; i++) list.Columns.Add("", new[] { 280, 130, 130, 250 }[i]);
        list.DoubleClick += async (s, e) => await UpdateSelected();
        list.ContextMenuStrip = menu;
        menu.Opening += (s, e) => BuildMenu(e);

        // header: title on the left; small repo link above the buttons on the right
        var buttons = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Margin = Padding.Empty, Anchor = AnchorStyles.Right };
        buttons.Controls.AddRange(new Control[] { checkBtn, oneBtn, allBtn, settingsBtn });
        var right = new TableLayoutPanel { AutoSize = true, ColumnCount = 1, Anchor = AnchorStyles.Right };
        right.Controls.Add(repo); right.Controls.Add(buttons);
        var header = new TableLayoutPanel { Dock = DockStyle.Top, AutoSize = true, ColumnCount = 2, Padding = new Padding(12, 8, 12, 8) };
        header.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        header.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        header.Controls.Add(title, 0, 0); header.Controls.Add(right, 1, 0);
        Controls.Add(list);
        Controls.Add(header);

        repo.LinkClicked += (s, e) => Process.Start(new ProcessStartInfo(RepoUrl) { UseShellExecute = true });
        checkBtn.Click += async (s, e) => await Check();
        oneBtn.Click += async (s, e) => await UpdateSelected();
        allBtn.Click += async (s, e) =>
        {
            var todo = pkgs.Where(p => !p.IdTruncated).ToList();
            if (todo.Count == 0) return;
            if (MessageBox.Show(this, L("confirmMsg", todo.Count), L("confirmTitle"), MessageBoxButtons.OKCancel, MessageBoxIcon.Question) == DialogResult.OK)
                await UpdateMany(todo, elevated: false);
        };
        settingsBtn.Click += (s, e) =>
        {
            using (var f = new SettingsForm(settings))
                if (f.ShowDialog(this) == DialogResult.OK)
                {
                    settings = f.Result;
                    settings.Save();
                    Lang.Choice = settings.Lang;
                    ApplyTexts();
                    pkgs = all.Where(settings.Shows).ToList();
                    SetBusy(false, null);
                }
        };
        spin.Tick += (s, e) => { frame++; Render(); };
        Shown += async (s, e) => await Check();
        ApplyTexts();
    }

    void ApplyTexts()
    {
        checkBtn.Text = L("check");
        oneBtn.Text = L("updateSelected");
        allBtn.Text = L("updateAll");
        tips.SetToolTip(settingsBtn, L("settings"));
        string[] cols = { "colApp", "colInstalled", "colLatest", "colStatus" };
        for (int i = 0; i < 4; i++) list.Columns[i].Text = L(cols[i]);
    }

    void BuildMenu(CancelEventArgs e)
    {
        menu.Items.Clear();
        var p = list.SelectedItems.Count > 0 ? list.SelectedItems[0].Tag as Pkg : null;
        if (p == null || busy) { e.Cancel = true; return; }
        if (!p.IdTruncated)
        {
            menu.Items.Add(L("menuUpdate"), null, async (s, a) => await UpdateMany(new List<Pkg> { p }, elevated: false));
            menu.Items.Add(L("menuAdmin"), null, async (s, a) => await UpdateMany(new List<Pkg> { p }, elevated: true));
            menu.Items.Add(new ToolStripSeparator());
        }
        var hide = new ToolStripMenuItem(L("menuHide"), null, (s, a) => HideApp(p)) { ToolTipText = L("hideHelp") };
        menu.Items.Add(hide);
    }

    /// Same list Settings edits, so the user can bring it back there.
    void HideApp(Pkg p)
    {
        settings.Hidden.Add(p.Id);
        settings.Save();
        pkgs.Remove(p);
        status.Remove(p.Id); failed.Remove(p.Id);
        SetBusy(false, null);
    }

    async Task Check()
    {
        SetBusy(true, L("checking"));
        try { all = await Winget.ListUpgrades(); }
        catch (Win32Exception) // winget missing
        {
            SetBusy(false, L("noWinget"));
            if (MessageBox.Show(this, L("noWingetMsg"), L("noWinget"), MessageBoxButtons.YesNo) == DialogResult.Yes)
                Process.Start(new ProcessStartInfo("ms-windows-store://pdp/?productid=9NBLGGH4NNS1") { UseShellExecute = true });
            return;
        }
        pkgs = all.Where(settings.Shows).ToList();
        SetBusy(false, null);
    }

    async Task UpdateSelected()
    {
        var p = list.SelectedItems.Count > 0 ? list.SelectedItems[0].Tag as Pkg : null;
        if (p == null || busy) return;
        if (p.IdTruncated) { MessageBox.Show(this, L("truncatedMsg")); return; }
        await UpdateMany(new List<Pkg> { p }, elevated: false);
    }

    async Task UpdateMany(List<Pkg> todo, bool elevated)
    {
        if (busy) return;
        foreach (var p in todo) { status.Remove(p.Id); failed.Remove(p.Id); details.Remove(p.Id); }
        var done = new HashSet<string>();
        for (int i = 0; i < todo.Count; i++)
        {
            var p = todo[i];
            SetBusy(true, L("updating", i, todo.Count));
            working[p.Id] = null;
            int code; string output = "";
            if (elevated) code = await Winget.UpgradeElevated(p);
            else (code, output) = await Winget.Upgrade(p, pct => BeginInvoke((Action)(() => working[p.Id] = pct)));
            working.Remove(p.Id);
            var f = Errors.Classify(code, output);
            if (f == Failure.None || f == Failure.Reboot) done.Add(p.Id);
            if (f == Failure.None) status[p.Id] = L("updated");
            else
            {
                status[p.Id] = "⚠ " + Errors.Message(f, code);
                failed.Add(p.Id);
                var lastLines = output.Replace("\r", "\n").Split('\n').Where(l => l.Trim().Length > 2).Reverse().Take(4).Reverse();
                details[p.Id] = string.Join("\n", lastLines);
            }
        }
        SetBusy(false, null);
        // re-check, but keep failed rows' messages visible
        SetBusy(true, L("checking"));
        all = await Winget.ListUpgrades();
        pkgs = all.Where(settings.Shows).ToList();
        foreach (var id in done) status.Remove(id);
        SetBusy(false, null);
    }

    void SetBusy(bool on, string text)
    {
        busy = on;
        checkBtn.Enabled = oneBtn.Enabled = allBtn.Enabled = settingsBtn.Enabled = !on;
        if (on) spin.Start(); else spin.Stop();
        titleText = text ?? (pkgs.Count == 0 ? L("allUpToDate") : pkgs.Count == 1 ? L("update1") : L("updates", pkgs.Count));
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
            if (working.TryGetValue(p.Id, out var pct)) s = spinner + " " + (pct.HasValue ? Pct(pct.Value) : L("preparing"));
            else if (!status.TryGetValue(p.Id, out s)) s = p.IdTruncated ? L("truncated") : L("doubleClick");
            if (it.SubItems[3].Text != s) it.SubItems[3].Text = s;
            it.ForeColor = failed.Contains(p.Id) ? Color.DarkOrange : SystemColors.WindowText;
            it.ToolTipText = details.TryGetValue(p.Id, out var d) ? d : "";
        }
        list.EndUpdate();
    }
}

class SettingsForm : Form
{
    public Settings Result { get; private set; }
    readonly CheckBox store = new CheckBox { AutoSize = true };
    readonly CheckBox other = new CheckBox { AutoSize = true };
    readonly RadioButton sys = new RadioButton { AutoSize = true }, en = new RadioButton { Text = "English", AutoSize = true }, tr = new RadioButton { Text = "Türkçe", AutoSize = true };
    readonly CheckedListBox hidden = new CheckedListBox { CheckOnClick = true, Height = 140, Width = 400 };

    public SettingsForm(Settings current)
    {
        Text = L("settings");
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = MinimizeBox = false;
        StartPosition = FormStartPosition.CenterParent;
        AutoScaleMode = AutoScaleMode.Dpi;
        AutoSize = true; AutoSizeMode = AutoSizeMode.GrowAndShrink;
        Font = new Font("Segoe UI", 9.5f);

        store.Text = L("storeApps"); store.Checked = current.StoreApps;
        other.Text = L("otherApps"); other.Checked = current.OtherApps;
        sys.Text = L("system");
        (current.Lang == "en" ? en : current.Lang == "tr" ? tr : sys).Checked = true;
        foreach (var id in current.Hidden) hidden.Items.Add(id, true);

        var ok = new Button { Text = L("ok"), DialogResult = DialogResult.OK, AutoSize = true };
        var cancel = new Button { Text = L("cancel"), DialogResult = DialogResult.Cancel, AutoSize = true };
        AcceptButton = ok; CancelButton = cancel;
        var repo = new LinkLabel { Text = "github.com/armanalis/check-updates", AutoSize = true };
        repo.LinkClicked += (s, e) => Process.Start(new ProcessStartInfo(MainForm.RepoUrl) { UseShellExecute = true });
        var version = typeof(SettingsForm).Assembly.GetName().Version;

        Control Section(string title, params Control[] items)
        {
            var box = new FlowLayoutPanel { FlowDirection = FlowDirection.TopDown, AutoSize = true, WrapContents = false, Margin = new Padding(0, 0, 0, 10) };
            box.Controls.Add(new Label { Text = title, AutoSize = true, Font = new Font(Font, FontStyle.Bold), Margin = new Padding(0, 0, 0, 4) });
            box.Controls.AddRange(items);
            return box;
        }
        var langRow = new FlowLayoutPanel { AutoSize = true, WrapContents = false };
        langRow.Controls.AddRange(new Control[] { sys, en, tr });
        var btnRow = new FlowLayoutPanel { AutoSize = true, FlowDirection = FlowDirection.RightToLeft, Anchor = AnchorStyles.Right };
        btnRow.Controls.AddRange(new Control[] { cancel, ok });

        var root = new FlowLayoutPanel { FlowDirection = FlowDirection.TopDown, AutoSize = true, WrapContents = false, Padding = new Padding(16) };
        root.Controls.Add(Section(L("whatToCheck"), store, other));
        root.Controls.Add(Section(L("language"), langRow));
        root.Controls.Add(current.Hidden.Count > 0 ? Section(L("hiddenApps"), hidden) : Section(L("hiddenApps"), new Label { Text = L("none"), AutoSize = true }));
        root.Controls.Add(Section(L("about"), new Label { Text = $"Check Updates {version.Major}.{version.Minor}", AutoSize = true }, repo));
        root.Controls.Add(btnRow);
        Controls.Add(root);

        FormClosing += (s, e) =>
        {
            if (DialogResult != DialogResult.OK) return;
            var r = new Settings { StoreApps = store.Checked, OtherApps = other.Checked, Lang = en.Checked ? "en" : tr.Checked ? "tr" : "system" };
            foreach (var item in hidden.CheckedItems) r.Hidden.Add((string)item);
            Result = r;
        };
    }
}
