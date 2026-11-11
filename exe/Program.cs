using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Resources;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

[assembly: AssemblyTitle("Kuzgun Iletisim CRM Kurulum")]
[assembly: AssemblyDescription("Tek tikla kurulum, guncelleme ve yonetim sihirbazi - Kuzgun Iletisim CRM v2.3")]
[assembly: AssemblyProduct("Kuzgun Iletisim CRM")]
[assembly: AssemblyCompany("Kuzgun Iletisim")]
[assembly: AssemblyVersion("2.3.0.0")]
[assembly: AssemblyFileVersion("2.3.0.0")]
[assembly: NeutralResourcesLanguage("tr-TR")]

namespace KuzgunCrmSetup
{
    internal static class Program
    {
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool AttachConsole(uint dwProcessId);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool AllocConsole();

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool SetConsoleOutputCP(uint wCodePageID);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool SetConsoleCP(uint wCodePageID);

        [DllImport("user32.dll")]
        private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        [DllImport("kernel32.dll")]
        private static extern IntPtr GetConsoleWindow();

        private const uint ATTACH_PARENT_PROCESS = 0xFFFFFFFF;
        private const int SW_HIDE = 0;

        internal static Process CurrentChildProcess = null;

        internal static readonly string[] Payload = new string[]
        {
            "Kurulum.ps1",
            "Code.gs",
            "Kuzgun_Iletisim_CRM.html",
            "appsscript.json",
            "README.md"
        };

        [STAThread]
        private static int Main(string[] args)
        {
            try
            {
                // Standalone app launch mode
                if (HasArg(args, "-Baslat") || HasArg(args, "--baslat"))
                {
                    return LaunchCrmApp();
                }

                // Determine whether to run in GUI or CLI mode
                bool forceGui = HasArg(args, "-Gui") || HasArg(args, "--gui");
                bool isCli = (args != null && args.Length > 0 && !forceGui);

                if (isCli)
                {
                    return RunConsoleMode(args);
                }

                // GUI Mode: hide console window if present
                IntPtr consoleWnd = GetConsoleWindow();
                if (consoleWnd != IntPtr.Zero)
                {
                    ShowWindow(consoleWnd, SW_HIDE);
                }

                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);

                using (InstallerForm form = new InstallerForm(args))
                {
                    Application.Run(form);
                    return form.ExitCode;
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    "Kurulum programi calisirken beklenmeyen bir hata olustu:\n\n" + ex.Message,
                    "Kuzgun CRM Kurulum Hatasi",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
                return 97;
            }
        }

        private static bool HasArg(string[] args, string flag)
        {
            if (args == null || args.Length == 0) return false;
            for (int i = 0; i < args.Length; i++)
            {
                if (string.Equals(args[i], flag, StringComparison.OrdinalIgnoreCase)) return true;
            }
            return false;
        }

        private static int RunConsoleMode(string[] args)
        {
            if (!AttachConsole(ATTACH_PARENT_PROCESS))
            {
                AllocConsole();
            }

            try
            {
                SetConsoleCP(65001);
                SetConsoleOutputCP(65001);
                ResetConsoleStreams();
            }
            catch {}

            Console.CancelKeyPress += delegate(object sender, ConsoleCancelEventArgs e)
            {
                e.Cancel = true;
                KillProcessTree(CurrentChildProcess);
                Environment.Exit(1);
            };

            string baseDir = GetPayloadDir();
            ExtractPayloadFiles(baseDir);

            string ps = FindPowerShellExe();
            StringBuilder sb = new StringBuilder();
            sb.Append("-NoProfile -ExecutionPolicy Bypass -File ");
            sb.Append(Quote(Path.Combine(baseDir, "Kurulum.ps1")));

            for (int i = 0; i < args.Length; i++)
            {
                if (string.IsNullOrEmpty(args[i])) continue;
                if (string.Equals(args[i], "-Gui", StringComparison.OrdinalIgnoreCase) ||
                    string.Equals(args[i], "--gui", StringComparison.OrdinalIgnoreCase)) continue;

                sb.Append(' ');
                sb.Append(Quote(args[i]));
            }

            ProcessStartInfo psi = new ProcessStartInfo(ps, sb.ToString());
            psi.UseShellExecute = false;
            psi.WorkingDirectory = baseDir;
            psi.RedirectStandardOutput = true;
            psi.RedirectStandardError = true;
            psi.StandardOutputEncoding = Encoding.UTF8;
            psi.StandardErrorEncoding = Encoding.UTF8;

            using (Process p = new Process())
            {
                p.StartInfo = psi;
                CurrentChildProcess = p;

                p.OutputDataReceived += delegate(object s, DataReceivedEventArgs e)
                {
                    if (e.Data != null) Console.Out.WriteLine(e.Data);
                };
                p.ErrorDataReceived += delegate(object s, DataReceivedEventArgs e)
                {
                    if (e.Data != null) Console.Error.WriteLine(e.Data);
                };

                p.Start();
                p.BeginOutputReadLine();
                p.BeginErrorReadLine();
                p.WaitForExit();

                return p.ExitCode;
            }
        }

        private static void ResetConsoleStreams()
        {
            try
            {
                Stream stdout = Console.OpenStandardOutput();
                if (stdout != null && stdout != Stream.Null)
                {
                    StreamWriter sw = new StreamWriter(stdout, Encoding.UTF8) { AutoFlush = true };
                    Console.SetOut(sw);
                }
                Stream stderr = Console.OpenStandardError();
                if (stderr != null && stderr != Stream.Null)
                {
                    StreamWriter sw = new StreamWriter(stderr, Encoding.UTF8) { AutoFlush = true };
                    Console.SetError(sw);
                }
            }
            catch {}
        }

        internal static string GetPayloadDir()
        {
            string baseDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "KuzgunCRM", "kaynak");
            Directory.CreateDirectory(baseDir);
            return baseDir;
        }

        internal static void ExtractPayloadFiles(string baseDir)
        {
            Directory.CreateDirectory(baseDir);
            Assembly asm = Assembly.GetExecutingAssembly();
            for (int i = 0; i < Payload.Length; i++)
            {
                string name = Payload[i];
                byte[] data = ReadResource(asm, "payload." + name);
                WriteRetry(Path.Combine(baseDir, name), data);
            }
        }

        internal static string FindPowerShellExe()
        {
            string ps = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.Windows),
                "System32", "WindowsPowerShell", "v1.0", "powershell.exe");
            if (!File.Exists(ps)) ps = "powershell";
            return ps;
        }

        internal static int LaunchCrmApp()
        {
            try
            {
                string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                string yerelHtml = Path.Combine(localAppData, "KuzgunCRM", "Kuzgun_CRM.html");

                if (!File.Exists(yerelHtml))
                {
                    yerelHtml = Path.Combine(localAppData, "KuzgunCRM", "kaynak", "Kuzgun_Iletisim_CRM.html");
                }

                if (File.Exists(yerelHtml))
                {
                    ProcessStartInfo psi = new ProcessStartInfo(yerelHtml) { UseShellExecute = true };
                    Process.Start(psi);
                    return 0;
                }

                string desktop = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
                string lnk = Path.Combine(desktop, "Kuzgun CRM.lnk");
                if (File.Exists(lnk))
                {
                    Process.Start(new ProcessStartInfo(lnk) { UseShellExecute = true });
                    return 0;
                }

                MessageBox.Show(
                    "Kuzgun CRM dosyalari bulunamadi. Lutfen once kurulumu tamamlayiniz.",
                    "Kuzgun CRM",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning);
                return 1;
            }
            catch (Exception ex)
            {
                MessageBox.Show("CRM baslatilamadi: " + ex.Message, "Hata", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return 1;
            }
        }

        internal static void KillProcessTree(Process proc)
        {
            if (proc == null) return;
            try
            {
                if (!proc.HasExited)
                {
                    int pid = proc.Id;
                    try
                    {
                        ProcessStartInfo psi = new ProcessStartInfo("taskkill.exe", string.Format("/F /T /PID {0}", pid))
                        {
                            CreateNoWindow = true,
                            UseShellExecute = false
                        };
                        using (Process killer = Process.Start(psi))
                        {
                            if (killer != null) killer.WaitForExit(3000);
                        }
                    }
                    catch {}

                    try
                    {
                        if (!proc.HasExited) proc.Kill();
                    }
                    catch {}
                }
            }
            catch {}
        }

        private static byte[] ReadResource(Assembly asm, string name)
        {
            using (Stream s = asm.GetManifestResourceStream(name))
            {
                if (s == null) throw new InvalidOperationException("Gomulu kaynak bulunamadi: " + name);
                using (MemoryStream ms = new MemoryStream())
                {
                    s.CopyTo(ms);
                    return ms.ToArray();
                }
            }
        }

        private static void WriteRetry(string path, byte[] data)
        {
            for (int attempt = 0; ; attempt++)
            {
                try
                {
                    File.WriteAllBytes(path, data);
                    return;
                }
                catch (IOException)
                {
                    if (attempt >= 4) throw;
                    Thread.Sleep(150);
                }
            }
        }

        internal static string Quote(string value)
        {
            if (string.IsNullOrEmpty(value)) return "\"\"";
            bool simple = true;
            for (int i = 0; i < value.Length; i++)
            {
                char c = value[i];
                if (c == ' ' || c == '\t' || c == '"')
                {
                    simple = false;
                    break;
                }
            }
            if (simple) return value;

            StringBuilder q = new StringBuilder("\"");
            int backslashes = 0;
            for (int i = 0; i < value.Length; i++)
            {
                char c = value[i];
                if (c == '\\')
                {
                    backslashes++;
                    continue;
                }
                if (c == '"')
                {
                    q.Append('\\', backslashes * 2 + 1);
                    q.Append('"');
                }
                else
                {
                    q.Append('\\', backslashes);
                    q.Append(c);
                }
                backslashes = 0;
            }
            q.Append('\\', backslashes * 2);
            q.Append('"');
            return q.ToString();
        }
    }

    internal class SystemDetection
    {
        public bool HasCloudConfig;
        public string CloudVersion;
        public string CloudUrl;
        public bool HasLegacyOzi;
        public bool HasLegacyAppData;
        public bool HasDesktopShortcuts;
        public int LegacyFilesCount;
        public string SummaryTitle;
        public string SummaryDetail;
        public Color TitleColor;

        public static SystemDetection Scan()
        {
            SystemDetection det = new SystemDetection();
            try
            {
                string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                string appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                string crmDir = Path.Combine(localAppData, "KuzgunCRM");
                string cfgFile = Path.Combine(crmDir, "kurulum.json");

                if (File.Exists(cfgFile))
                {
                    det.HasCloudConfig = true;
                    string json = File.ReadAllText(cfgFile);
                    det.CloudVersion = SimpleJsonExtract(json, "surum") ?? "v2.3.0";
                    det.CloudUrl = SimpleJsonExtract(json, "url");
                }

                string ozi = @"C:\ozi";
                if (Directory.Exists(ozi))
                {
                    det.HasLegacyOzi = true;
                    try
                    {
                        string[] files = Directory.GetFiles(ozi, "*.*", SearchOption.TopDirectoryOnly);
                        det.LegacyFilesCount += files.Length;
                    }
                    catch {}
                }

                string roamingCrm = Path.Combine(appData, "KuzgunCRM");
                if (Directory.Exists(roamingCrm))
                {
                    det.HasLegacyAppData = true;
                }

                string[] desktopDirs = new string[]
                {
                    Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
                    Environment.GetFolderPath(Environment.SpecialFolder.CommonDesktopDirectory),
                    Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "OneDrive", "Masaüstü"),
                    Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "OneDrive", "Desktop"),
                    Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Masaüstü")
                };

                for (int i = 0; i < desktopDirs.Length; i++)
                {
                    string d = desktopDirs[i];
                    if (string.IsNullOrEmpty(d) || !Directory.Exists(d)) continue;
                    try
                    {
                        string[] found = Directory.GetFiles(d, "*kuzgun*.*", SearchOption.TopDirectoryOnly);
                        if (found.Length > 0)
                        {
                            det.HasDesktopShortcuts = true;
                            det.LegacyFilesCount += found.Length;
                        }
                    }
                    catch {}
                }
            }
            catch {}

            if (det.HasCloudConfig)
            {
                det.SummaryTitle = "MEVCUT BULUT SÜRÜMÜ BULUNDU (GÜNCELLEME MODU)";
                det.TitleColor = Color.FromArgb(14, 116, 144);
                det.SummaryDetail = string.Format(
                    "Sistemde aktif Kuzgun CRM ({0}) bulundu. Tek tikla guncelleme yapildiginda kodlar yenilenecek, Google E-Tablo veritabaniniz ve musterileriniz aynen korunacaktir.",
                    det.CloudVersion ?? "v2.3.0");
            }
            else if (det.HasLegacyOzi || det.HasLegacyAppData || det.HasDesktopShortcuts)
            {
                det.SummaryTitle = "ESKİ YEREL SÜRÜM (127.0.0.1 / C:\\ozi) TESPİT EDİLDİ";
                det.TitleColor = Color.FromArgb(180, 83, 9);
                det.SummaryDetail = "Eski v1.x/v2.0 yerel surum kalintilari (C:\\ozi veya masaustu) bulundu. Kurulum sirasinda eski veritabaniniz otomatik taranacak ve tum musterileriniz kayipsiz yeni CRM'e aktarilacaktir.";
            }
            else
            {
                det.SummaryTitle = "TEMİZ KURULUM HAZIR";
                det.TitleColor = Color.FromArgb(15, 118, 110);
                det.SummaryDetail = "Sisteminizde onceki kurulum kaydi bulunamadi. Tek tikla yeni Google Apps Script bulut CRM altyapisi, e-tablo veritabani ve masaustu kisayollari kurulacaktir.";
            }

            return det;
        }

        private static string SimpleJsonExtract(string json, string key)
        {
            if (string.IsNullOrEmpty(json)) return null;
            string pattern = "\"" + key + "\"";
            int idx = json.IndexOf(pattern, StringComparison.OrdinalIgnoreCase);
            if (idx < 0) return null;
            int colon = json.IndexOf(':', idx + pattern.Length);
            if (colon < 0) return null;
            int quote1 = json.IndexOf('"', colon + 1);
            if (quote1 < 0) return null;
            int quote2 = json.IndexOf('"', quote1 + 1);
            if (quote2 < 0) return null;
            return json.Substring(quote1 + 1, quote2 - quote1 - 1);
        }
    }

    internal class InstallerForm : Form
    {
        private Panel _pnlHeader;
        private Label _lblTitle;
        private Label _lblSubtitle;
        private Label _lblVersion;

        private Panel _pnlStatus;
        private Label _lblStatusTitle;
        private Label _lblStatusDetail;

        private Label _lblStep;
        private ProgressBar _progressBar;

        private Label _lblLogTitle;
        private TextBox _txtLog;

        private CheckBox _chkAutoLaunch;
        private Button _btnOpenCrm;
        private Button _btnStart;
        private Button _btnCancel;

        private Process _childProcess = null;
        private bool _isInstalling = false;
        private string[] _cliArgs;

        public int ExitCode { get; private set; }

        public InstallerForm(string[] args)
        {
            _cliArgs = args;
            InitializeComponent();
        }

        private void InitializeComponent()
        {
            this.SuspendLayout();

            this.Text = "Kuzgun İletişim CRM - Kurulum ve Yönetim Sihirbazı";
            this.ClientSize = new Size(684, 530);
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;
            this.MinimizeBox = true;
            this.StartPosition = FormStartPosition.CenterScreen;
            this.BackColor = Color.FromArgb(248, 250, 252);
            this.Font = new Font("Segoe UI", 9F, FontStyle.Regular, GraphicsUnit.Point);

            try
            {
                this.Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
            }
            catch {}

            // Header Panel
            _pnlHeader = new Panel();
            _pnlHeader.Dock = DockStyle.Top;
            _pnlHeader.Height = 75;
            _pnlHeader.BackColor = Color.FromArgb(30, 58, 95);

            _lblTitle = new Label();
            _lblTitle.Text = "KUZGUN İLETİŞİM CRM";
            _lblTitle.Font = new Font("Segoe UI", 14F, FontStyle.Bold);
            _lblTitle.ForeColor = Color.White;
            _lblTitle.Location = new Point(20, 15);
            _lblTitle.AutoSize = true;

            _lblSubtitle = new Label();
            _lblSubtitle.Text = "Bulut Entegrasyonlu Teknik Servis & Satış Takip Sistemi";
            _lblSubtitle.Font = new Font("Segoe UI", 9F, FontStyle.Regular);
            _lblSubtitle.ForeColor = Color.FromArgb(147, 197, 253);
            _lblSubtitle.Location = new Point(22, 43);
            _lblSubtitle.AutoSize = true;

            _lblVersion = new Label();
            _lblVersion.Text = "v2.3.0";
            _lblVersion.Font = new Font("Segoe UI", 11F, FontStyle.Bold);
            _lblVersion.ForeColor = Color.FromArgb(252, 211, 77);
            _lblVersion.Location = new Point(585, 25);
            _lblVersion.AutoSize = true;

            _pnlHeader.Controls.Add(_lblTitle);
            _pnlHeader.Controls.Add(_lblSubtitle);
            _pnlHeader.Controls.Add(_lblVersion);

            // Status Panel
            _pnlStatus = new Panel();
            _pnlStatus.Location = new Point(20, 90);
            _pnlStatus.Size = new Size(644, 75);
            _pnlStatus.BackColor = Color.White;
            _pnlStatus.BorderStyle = BorderStyle.FixedSingle;

            _lblStatusTitle = new Label();
            _lblStatusTitle.Location = new Point(12, 10);
            _lblStatusTitle.Size = new Size(620, 18);
            _lblStatusTitle.Font = new Font("Segoe UI", 8.5F, FontStyle.Bold);
            _lblStatusTitle.Text = "SİSTEM DURUMU: KONTROL EDİLİYOR...";

            _lblStatusDetail = new Label();
            _lblStatusDetail.Location = new Point(12, 30);
            _lblStatusDetail.Size = new Size(620, 38);
            _lblStatusDetail.Font = new Font("Segoe UI", 8.5F, FontStyle.Regular);
            _lblStatusDetail.ForeColor = Color.FromArgb(51, 65, 85);
            _lblStatusDetail.Text = "Sistem kontrol ediliyor...";

            _pnlStatus.Controls.Add(_lblStatusTitle);
            _pnlStatus.Controls.Add(_lblStatusDetail);

            // Step Label & Progress Bar
            _lblStep = new Label();
            _lblStep.Location = new Point(20, 175);
            _lblStep.Size = new Size(644, 20);
            _lblStep.Font = new Font("Segoe UI", 9F, FontStyle.Bold);
            _lblStep.ForeColor = Color.FromArgb(30, 58, 95);
            _lblStep.Text = "Hazır: Başlamak için 'Tek Tıkla Kur / Güncelle' butonuna basınız.";

            _progressBar = new ProgressBar();
            _progressBar.Location = new Point(20, 198);
            _progressBar.Size = new Size(644, 22);
            _progressBar.Minimum = 0;
            _progressBar.Maximum = 100;
            _progressBar.Value = 0;

            // Log Section
            _lblLogTitle = new Label();
            _lblLogTitle.Location = new Point(20, 228);
            _lblLogTitle.Text = "İşlem Günlüğü (Canlı Çıktı):";
            _lblLogTitle.Font = new Font("Segoe UI", 8.5F, FontStyle.Regular);
            _lblLogTitle.ForeColor = Color.FromArgb(100, 116, 139);
            _lblLogTitle.AutoSize = true;

            _txtLog = new TextBox();
            _txtLog.Location = new Point(20, 248);
            _txtLog.Size = new Size(644, 215);
            _txtLog.Multiline = true;
            _txtLog.ReadOnly = true;
            _txtLog.ScrollBars = ScrollBars.Vertical;
            _txtLog.BackColor = Color.FromArgb(15, 23, 42);
            _txtLog.ForeColor = Color.FromArgb(226, 232, 240);
            _txtLog.Font = new Font("Consolas", 8.5F, FontStyle.Regular);

            // Bottom Buttons & CheckBox
            _chkAutoLaunch = new CheckBox();
            _chkAutoLaunch.Location = new Point(20, 483);
            _chkAutoLaunch.Text = "Kurulum tamamlandığında CRM'i aç";
            _chkAutoLaunch.Font = new Font("Segoe UI", 8.5F, FontStyle.Regular);
            _chkAutoLaunch.ForeColor = Color.FromArgb(51, 65, 85);
            _chkAutoLaunch.Checked = true;
            _chkAutoLaunch.AutoSize = true;

            _btnOpenCrm = new Button();
            _btnOpenCrm.Location = new Point(314, 477);
            _btnOpenCrm.Size = new Size(115, 34);
            _btnOpenCrm.Text = "CRM'i Aç";
            _btnOpenCrm.Font = new Font("Segoe UI", 9F, FontStyle.Bold);
            _btnOpenCrm.BackColor = Color.FromArgb(13, 148, 136);
            _btnOpenCrm.ForeColor = Color.White;
            _btnOpenCrm.FlatStyle = FlatStyle.Flat;
            _btnOpenCrm.FlatAppearance.BorderSize = 0;
            _btnOpenCrm.Visible = false;
            _btnOpenCrm.Enabled = false;
            _btnOpenCrm.Click += delegate { Program.LaunchCrmApp(); };

            _btnStart = new Button();
            _btnStart.Location = new Point(439, 477);
            _btnStart.Size = new Size(135, 34);
            _btnStart.Text = "Tek Tıkla Kur";
            _btnStart.Font = new Font("Segoe UI", 9F, FontStyle.Bold);
            _btnStart.BackColor = Color.FromArgb(37, 99, 235);
            _btnStart.ForeColor = Color.White;
            _btnStart.FlatStyle = FlatStyle.Flat;
            _btnStart.FlatAppearance.BorderSize = 0;
            _btnStart.Click += delegate { StartInstallation(); };

            _btnCancel = new Button();
            _btnCancel.Location = new Point(584, 477);
            _btnCancel.Size = new Size(80, 34);
            _btnCancel.Text = "Kapat";
            _btnCancel.Font = new Font("Segoe UI", 9F, FontStyle.Regular);
            _btnCancel.BackColor = Color.FromArgb(226, 232, 240);
            _btnCancel.ForeColor = Color.FromArgb(51, 65, 85);
            _btnCancel.FlatStyle = FlatStyle.Flat;
            _btnCancel.FlatAppearance.BorderSize = 1;
            _btnCancel.FlatAppearance.BorderColor = Color.FromArgb(203, 213, 225);
            _btnCancel.Click += delegate { this.Close(); };

            this.Controls.Add(_pnlHeader);
            this.Controls.Add(_pnlStatus);
            this.Controls.Add(_lblStep);
            this.Controls.Add(_progressBar);
            this.Controls.Add(_lblLogTitle);
            this.Controls.Add(_txtLog);
            this.Controls.Add(_chkAutoLaunch);
            this.Controls.Add(_btnOpenCrm);
            this.Controls.Add(_btnStart);
            this.Controls.Add(_btnCancel);

            this.ResumeLayout(false);
            this.PerformLayout();
        }

        protected override void OnLoad(EventArgs e)
        {
            base.OnLoad(e);

            SystemDetection det = SystemDetection.Scan();
            _lblStatusTitle.Text = det.SummaryTitle;
            _lblStatusTitle.ForeColor = det.TitleColor;
            _lblStatusDetail.Text = det.SummaryDetail;

            if (det.HasCloudConfig)
            {
                _btnStart.Text = "Hızlı Güncelle";
            }
            else if (det.HasLegacyOzi || det.HasLegacyAppData || det.HasDesktopShortcuts)
            {
                _btnStart.Text = "Verileri Aktar ve Kur";
            }
            else
            {
                _btnStart.Text = "Tek Tıkla Kur";
            }

            AppendLog("Kuzgun CRM v2.3.0 Kurulum ve Yonetim Sihirbazi hazir.");
            AppendLog("Durum: " + det.SummaryTitle);
        }

        private void StartInstallation()
        {
            if (_isInstalling) return;

            _isInstalling = true;
            _btnStart.Enabled = false;
            _btnCancel.Text = "İptal Et";
            _progressBar.Value = 5;
            _lblStep.Text = "Kurulum paketleri hazirlaniyor...";
            _lblStep.ForeColor = Color.FromArgb(30, 58, 95);

            Thread worker = new Thread(RunInstallWorker) { IsBackground = true };
            worker.Start();
        }

        private void RunInstallWorker()
        {
            try
            {
                this.BeginInvoke((Action)delegate
                {
                    AppendLog("Kaynak paketler cozuluyor...");
                    _progressBar.Value = 10;
                });

                string baseDir = Program.GetPayloadDir();
                Program.ExtractPayloadFiles(baseDir);

                this.BeginInvoke((Action)delegate
                {
                    AppendLog("Kurulum motoru baslatiliyor (Kurulum.ps1)...");
                    _progressBar.Value = 20;
                });

                string ps = Program.FindPowerShellExe();
                StringBuilder sb = new StringBuilder();
                sb.Append("-NoProfile -ExecutionPolicy Bypass -File ");
                sb.Append(Program.Quote(Path.Combine(baseDir, "Kurulum.ps1")));

                if (_cliArgs != null)
                {
                    for (int i = 0; i < _cliArgs.Length; i++)
                    {
                        string a = _cliArgs[i];
                        if (string.IsNullOrEmpty(a)) continue;
                        if (string.Equals(a, "-Gui", StringComparison.OrdinalIgnoreCase) ||
                            string.Equals(a, "--gui", StringComparison.OrdinalIgnoreCase)) continue;

                        sb.Append(' ');
                        sb.Append(Program.Quote(a));
                    }
                }

                ProcessStartInfo psi = new ProcessStartInfo(ps, sb.ToString());
                psi.UseShellExecute = false;
                psi.CreateNoWindow = true;
                psi.WorkingDirectory = baseDir;
                psi.RedirectStandardOutput = true;
                psi.RedirectStandardError = true;
                psi.StandardOutputEncoding = Encoding.UTF8;
                psi.StandardErrorEncoding = Encoding.UTF8;

                Process p = new Process();
                p.StartInfo = psi;
                _childProcess = p;
                Program.CurrentChildProcess = p;

                p.OutputDataReceived += delegate(object sender, DataReceivedEventArgs e)
                {
                    if (e.Data != null)
                    {
                        this.BeginInvoke((Action)delegate { OnProcessOutput(e.Data, false); });
                    }
                };

                p.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs e)
                {
                    if (e.Data != null)
                    {
                        this.BeginInvoke((Action)delegate { OnProcessOutput(e.Data, true); });
                    }
                };

                p.Start();
                p.BeginOutputReadLine();
                p.BeginErrorReadLine();
                p.WaitForExit();

                int code = p.ExitCode;
                this.BeginInvoke((Action)delegate { OnProcessFinished(code); });
            }
            catch (Exception ex)
            {
                this.BeginInvoke((Action)delegate
                {
                    AppendLog("HATA: " + ex.Message);
                    OnProcessFinished(99);
                });
            }
        }

        private void OnProcessOutput(string line, bool isError)
        {
            AppendLog(line);

            string upper = line.ToUpperInvariant();

            if (upper.Contains("ASAMA 1") || upper.Contains("BILGILENDIRME"))
            {
                SetStep("Aşama 1: Bilgilendirme ve hazırlık", 25);
            }
            else if (upper.Contains("ASAMA 2") || upper.Contains("GEREKSINIM"))
            {
                SetStep("Aşama 2: Sistem gereksinimleri kontrol ediliyor...", 35);
            }
            else if (upper.Contains("NODE.JS") || upper.Contains("WINGET"))
            {
                SetStep("Node.js çalışma ortamı kontrol ediliyor / kuruluyor...", 45);
            }
            else if (upper.Contains("MIGRAS") || upper.Contains("ESKI SURUM") || upper.Contains("AKTAR"))
            {
                SetStep("Eski sürüm verileri taranıyor ve yeni şemaya aktarılıyor...", 55);
            }
            else if (upper.Contains("CLASP") || upper.Contains("GOOGLE ARACISI"))
            {
                SetStep("Aşama 3: Google Apps Script araçları hazırlanıyor...", 65);
            }
            else if (upper.Contains("YAYIN") || upper.Contains("DAGITIM") || upper.Contains("DEVICES"))
            {
                SetStep("Google Cloud Apps Script dağıtımı yapılıyor...", 80);
            }
            else if (upper.Contains("KISAYOL") || upper.Contains("MASAUSTU"))
            {
                SetStep("Aşama 4: Masaüstü kısayolları ve entegrasyon oluşturuluyor...", 90);
            }
            else if (upper.Contains("KURULUM TAMAMLANDI") || upper.Contains("URET TAMAM") || upper.Contains("ASAMA 4 - TAMAM"))
            {
                SetStep("Kurulum ve veri aktarımı başarıyla tamamlandı!", 100);
            }
            else if (upper.Contains("[OK]") && _progressBar.Value < 90)
            {
                _progressBar.Value = Math.Min(90, _progressBar.Value + 2);
            }
        }

        private void SetStep(string text, int progress)
        {
            _lblStep.Text = text;
            if (progress >= 0 && progress <= 100)
            {
                _progressBar.Value = progress;
            }
        }

        private void OnProcessFinished(int exitCode)
        {
            _isInstalling = false;
            ExitCode = exitCode;

            if (exitCode == 0)
            {
                _progressBar.Value = 100;
                _lblStep.Text = "✓ Tebrikler! Kuzgun CRM başarıyla kuruldu ve hazır.";
                _lblStep.ForeColor = Color.FromArgb(16, 120, 70);
                _btnStart.Text = "Yeniden Kur";
                _btnStart.Enabled = true;
                _btnCancel.Text = "Kapat";
                _btnOpenCrm.Visible = true;
                _btnOpenCrm.Enabled = true;

                AppendLog(">> KURULUM BASARIYLA TAMAMLANDI. CRM KULLANIMA HAZIR.");

                if (_chkAutoLaunch.Checked)
                {
                    Program.LaunchCrmApp();
                }
            }
            else
            {
                _lblStep.Text = "⚠ Kurulum tamamlanamadı (Hata Kodu: " + exitCode + "). Yukarıdaki günlüğü inceleyiniz.";
                _lblStep.ForeColor = Color.FromArgb(185, 28, 28);
                _btnStart.Text = "Yeniden Dene";
                _btnStart.Enabled = true;
                _btnCancel.Text = "Kapat";

                AppendLog(">> KURULUM TAMAMLANAMADI (Hata kodu: " + exitCode + ").");
            }
        }

        private void AppendLog(string text)
        {
            if (string.IsNullOrEmpty(text)) return;
            _txtLog.AppendText(text + Environment.NewLine);
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (_isInstalling && _childProcess != null && !_childProcess.HasExited)
            {
                DialogResult dr = MessageBox.Show(
                    this,
                    "Kurulum islemi henuz tamamlanmadi. Islemi iptal edip cikmak istiyor musunuz?",
                    "Kurulum Devam Ediyor",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Warning);

                if (dr == DialogResult.No)
                {
                    e.Cancel = true;
                    return;
                }

                Program.KillProcessTree(_childProcess);
                _isInstalling = false;
            }
            base.OnFormClosing(e);
        }
    }
}
