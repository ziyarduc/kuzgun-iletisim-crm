using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Reflection;
using System.Resources;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: AssemblyTitle("Kuzgun Iletisim CRM")]
[assembly: AssemblyDescription("Standalone Masaustu Uygulamasi ve Kurulum Sihirbazi - Kuzgun Iletisim CRM v2.4.0")]
[assembly: AssemblyProduct("Kuzgun Iletisim CRM")]
[assembly: AssemblyCompany("Kuzgun Iletisim")]
[assembly: AssemblyVersion("2.4.0.0")]
[assembly: AssemblyFileVersion("2.4.0.0")]
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
                // Background local server mode for standalone desktop app
                if (HasArg(args, "-Sunucu") || HasArg(args, "--sunucu"))
                {
                    IntPtr cw = GetConsoleWindow();
                    if (cw != IntPtr.Zero) ShowWindow(cw, SW_HIDE);
                    return StandaloneServer.RunServerBlocking();
                }

                // Standalone desktop app launch mode (invoked by desktop shortcut or 'CRM'i Ac' button)
                if (HasArg(args, "-Baslat") || HasArg(args, "--baslat"))
                {
                    IntPtr cw = GetConsoleWindow();
                    if (cw != IntPtr.Zero) ShowWindow(cw, SW_HIDE);
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
                    "Program calisirken beklenmeyen bir hata olustu:\n\n" + ex.Message,
                    "Kuzgun CRM Hatasi",
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
            InstallStandaloneExe();

            string ps = FindPowerShellExe();
            string exeDir = AppDomain.CurrentDomain.BaseDirectory ?? string.Empty;
            exeDir = exeDir.TrimEnd('\\', '/');

            StringBuilder sb = new StringBuilder();
            sb.Append("-NoProfile -ExecutionPolicy Bypass -File ");
            sb.Append(Quote(Path.Combine(baseDir, "Kurulum.ps1")));
            if (!string.IsNullOrEmpty(exeDir))
            {
                sb.Append(" -ExeDir ");
                sb.Append(Quote(exeDir));
            }

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

        internal static string GetCrmRootDir()
        {
            string dir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "KuzgunCRM");
            Directory.CreateDirectory(dir);
            return dir;
        }

        internal static string GetPayloadDir()
        {
            string baseDir = Path.Combine(GetCrmRootDir(), "kaynak");
            Directory.CreateDirectory(baseDir);
            return baseDir;
        }

        internal static string InstallStandaloneExe()
        {
            string crmDir = GetCrmRootDir();
            string targetExe = Path.Combine(crmDir, "KuzgunCRM.exe");
            try
            {
                string currentExe = Application.ExecutablePath;
                if (!string.IsNullOrEmpty(currentExe) && File.Exists(currentExe))
                {
                    if (!string.Equals(Path.GetFullPath(currentExe), Path.GetFullPath(targetExe), StringComparison.OrdinalIgnoreCase))
                    {
                        File.Copy(currentExe, targetExe, true);
                    }
                }
            }
            catch {}
            return File.Exists(targetExe) ? targetExe : Application.ExecutablePath;
        }

        internal static void ExtractPayloadFiles(string baseDir)
        {
            Directory.CreateDirectory(baseDir);
            Assembly asm = Assembly.GetExecutingAssembly();
            for (int i = 0; i < Payload.Length; i++)
            {
                string name = Payload[i];
                byte[] data = ReadResource(asm, "payload." + name);
                if (name.EndsWith(".ps1", StringComparison.OrdinalIgnoreCase))
                {
                    if (data == null || data.Length < 3 || data[0] != 0xEF || data[1] != 0xBB || data[2] != 0xBF)
                    {
                        byte[] raw = data ?? new byte[0];
                        byte[] bomData = new byte[raw.Length + 3];
                        bomData[0] = 0xEF;
                        bomData[1] = 0xBB;
                        bomData[2] = 0xBF;
                        Buffer.BlockCopy(raw, 0, bomData, 3, raw.Length);
                        data = bomData;
                    }
                }
                string destPath = Path.Combine(baseDir, name);
                WriteRetry(destPath, data);

                if (name.Equals("Kurulum.ps1", StringComparison.OrdinalIgnoreCase))
                {
                    if (!File.Exists(destPath))
                    {
                        throw new FileNotFoundException("Cikarilan Kurulum.ps1 bulunamadi: " + destPath);
                    }
                    FileInfo fi = new FileInfo(destPath);
                    if (fi.Length < 3)
                    {
                        throw new InvalidDataException("Cikarilan Kurulum.ps1 bos veya cok kucuk: " + destPath);
                    }
                    byte[] check = new byte[3];
                    using (FileStream fs = File.OpenRead(destPath))
                    {
                        int read = fs.Read(check, 0, 3);
                        if (read < 3 || check[0] != 0xEF || check[1] != 0xBB || check[2] != 0xBF)
                        {
                            throw new InvalidDataException("Kurulum.ps1 UTF-8 BOM ile yazilamadi: " + destPath);
                        }
                    }
                }
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
                string payloadDir = GetPayloadDir();
                if (!File.Exists(Path.Combine(payloadDir, "Kuzgun_Iletisim_CRM.html")))
                {
                    ExtractPayloadFiles(payloadDir);
                }
                string standaloneExe = InstallStandaloneExe();

                int port = StandaloneServer.EnsureServerRunning(standaloneExe);
                string appUrl = "http://127.0.0.1:" + port + "/";

                OpenStandaloneAppWindow(appUrl);
                return 0;
            }
            catch (Exception ex)
            {
                MessageBox.Show("CRM baslatilamadi: " + ex.Message, "Hata", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return 1;
            }
        }

        private static void OpenStandaloneAppWindow(string appUrl)
        {
            string browserExe = FindChromiumBrowserExe();
            if (!string.IsNullOrEmpty(browserExe) && File.Exists(browserExe))
            {
                string profileDir = Path.Combine(GetCrmRootDir(), "uygulama_profili");
                Directory.CreateDirectory(profileDir);

                StringBuilder args = new StringBuilder();
                args.Append("--app=").Append(Quote(appUrl));
                args.Append(" --window-size=1360,860");
                args.Append(" --user-data-dir=").Append(Quote(profileDir));
                args.Append(" --no-first-run --no-default-browser-check");

                ProcessStartInfo psi = new ProcessStartInfo(browserExe, args.ToString())
                {
                    UseShellExecute = false
                };
                Process.Start(psi);
                return;
            }

            Process.Start(new ProcessStartInfo(appUrl) { UseShellExecute = true });
        }

        private static string FindChromiumBrowserExe()
        {
            string pf86 = Environment.GetEnvironmentVariable("ProgramFiles(x86)") ?? @"C:\Program Files (x86)";
            string pf = Environment.GetEnvironmentVariable("ProgramFiles") ?? @"C:\Program Files";
            string localApp = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);

            string[] candidates = new string[]
            {
                Path.Combine(pf86, @"Microsoft\Edge\Application\msedge.exe"),
                Path.Combine(pf, @"Microsoft\Edge\Application\msedge.exe"),
                Path.Combine(localApp, @"Microsoft\Edge\Application\msedge.exe"),
                Path.Combine(pf, @"Google\Chrome\Application\chrome.exe"),
                Path.Combine(pf86, @"Google\Chrome\Application\chrome.exe"),
                Path.Combine(localApp, @"Google\Chrome\Application\chrome.exe")
            };

            for (int i = 0; i < candidates.Length; i++)
            {
                if (!string.IsNullOrEmpty(candidates[i]) && File.Exists(candidates[i]))
                {
                    return candidates[i];
                }
            }

            string[] regNames = new string[] { "msedge.exe", "chrome.exe" };
            for (int i = 0; i < regNames.Length; i++)
            {
                try
                {
                    using (RegistryKey key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\" + regNames[i]))
                    {
                        if (key != null)
                        {
                            string val = key.GetValue(null) as string;
                            if (!string.IsNullOrEmpty(val) && File.Exists(val)) return val;
                        }
                    }
                }
                catch {}
            }

            return null;
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

    internal static class StandaloneServer
    {
        private const int DEFAULT_PORT = 18881;
        private static readonly object _dbLock = new object();
        private static int _activePort = DEFAULT_PORT;

        internal static int EnsureServerRunning(string exePath)
        {
            int savedPort = ReadSavedPort();
            if (PingServer(savedPort))
            {
                return savedPort;
            }

            ProcessStartInfo psi = new ProcessStartInfo(exePath, "-Sunucu")
            {
                CreateNoWindow = true,
                UseShellExecute = false,
                WorkingDirectory = Program.GetCrmRootDir()
            };
            Process.Start(psi);

            for (int i = 0; i < 30; i++)
            {
                Thread.Sleep(120);
                int p = ReadSavedPort();
                if (PingServer(p)) return p;
            }
            return ReadSavedPort();
        }

        private static int ReadSavedPort()
        {
            try
            {
                string portFile = Path.Combine(Program.GetCrmRootDir(), "server_port.txt");
                if (File.Exists(portFile))
                {
                    int p;
                    if (int.TryParse(File.ReadAllText(portFile).Trim(), out p) && p > 1024 && p < 65535)
                    {
                        return p;
                    }
                }
            }
            catch {}
            return DEFAULT_PORT;
        }

        private static bool PingServer(int port)
        {
            try
            {
                HttpWebRequest req = (HttpWebRequest)WebRequest.Create("http://127.0.0.1:" + port + "/ping");
                req.Method = "GET";
                req.Timeout = 500;
                req.ReadWriteTimeout = 500;
                using (HttpWebResponse resp = (HttpWebResponse)req.GetResponse())
                {
                    return resp.StatusCode == HttpStatusCode.OK;
                }
            }
            catch
            {
                return false;
            }
        }

        internal static int RunServerBlocking()
        {
            string crmDir = Program.GetCrmRootDir();
            string payloadDir = Program.GetPayloadDir();
            if (!File.Exists(Path.Combine(payloadDir, "Kuzgun_Iletisim_CRM.html")))
            {
                Program.ExtractPayloadFiles(payloadDir);
            }

            TcpListener listener = null;
            for (int port = DEFAULT_PORT; port <= DEFAULT_PORT + 20; port++)
            {
                try
                {
                    TcpListener cand = new TcpListener(IPAddress.Loopback, port);
                    cand.Start();
                    listener = cand;
                    _activePort = port;
                    break;
                }
                catch {}
            }

            if (listener == null) return 2;

            try
            {
                File.WriteAllText(Path.Combine(crmDir, "server_port.txt"), _activePort.ToString(CultureInfo.InvariantCulture));
            }
            catch {}

            // Initialize DB and daily backup on startup
            try
            {
                lock (_dbLock)
                {
                    LoadDevicesUnlocked();
                    EnsureDailyBackupUnlocked();
                }
            }
            catch {}

            while (true)
            {
                try
                {
                    TcpClient client = listener.AcceptTcpClient();
                    ThreadPool.QueueUserWorkItem(HandleClient, client);
                }
                catch
                {
                    Thread.Sleep(50);
                }
            }
        }

        private static void HandleClient(object state)
        {
            TcpClient client = (TcpClient)state;
            try
            {
                client.ReceiveTimeout = 30000;
                client.SendTimeout = 30000;
                using (NetworkStream ns = client.GetStream())
                {
                    string method;
                    string path;
                    string body;
                    if (!ReadHttpRequest(ns, out method, out path, out body))
                    {
                        return;
                    }

                    if (string.Equals(method, "OPTIONS", StringComparison.OrdinalIgnoreCase))
                    {
                        WriteHttpResponse(ns, "200 OK", "text/plain; charset=utf-8", new byte[0]);
                        return;
                    }

                    if (path.StartsWith("/ping", StringComparison.OrdinalIgnoreCase))
                    {
                        WriteHttpResponse(ns, "200 OK", "text/plain; charset=utf-8", Encoding.UTF8.GetBytes("OK"));
                        return;
                    }

                    if (path.StartsWith("/api", StringComparison.OrdinalIgnoreCase))
                    {
                        string jsonResp = HandleApiRequest(body);
                        WriteHttpResponse(ns, "200 OK", "application/json; charset=utf-8", Encoding.UTF8.GetBytes(jsonResp));
                        return;
                    }

                    byte[] htmlBytes = BuildStandaloneHtmlBytes();
                    WriteHttpResponse(ns, "200 OK", "text/html; charset=utf-8", htmlBytes);
                }
            }
            catch {}
            finally
            {
                try { client.Close(); } catch {}
            }
        }

        private static bool ReadHttpRequest(NetworkStream ns, out string method, out string path, out string body)
        {
            method = "GET";
            path = "/";
            body = string.Empty;

            List<byte> headerBuf = new List<byte>(2048);
            int b;
            while ((b = ns.ReadByte()) != -1)
            {
                headerBuf.Add((byte)b);
                int n = headerBuf.Count;
                if (n >= 4 &&
                    headerBuf[n - 4] == '\r' && headerBuf[n - 3] == '\n' &&
                    headerBuf[n - 2] == '\r' && headerBuf[n - 1] == '\n')
                {
                    break;
                }
                if (n > 65536) return false;
            }
            if (headerBuf.Count == 0) return false;

            string headerStr = Encoding.ASCII.GetString(headerBuf.ToArray());
            string[] lines = headerStr.Split(new string[] { "\r\n" }, StringSplitOptions.None);
            if (lines.Length == 0) return false;

            string[] reqParts = lines[0].Split(' ');
            if (reqParts.Length >= 2)
            {
                method = reqParts[0].Trim();
                path = reqParts[1].Trim();
            }

            int contentLength = 0;
            for (int i = 1; i < lines.Length; i++)
            {
                string line = lines[i];
                if (line.StartsWith("Content-Length:", StringComparison.OrdinalIgnoreCase))
                {
                    int.TryParse(line.Substring(15).Trim(), out contentLength);
                }
            }

            if (contentLength > 0 && contentLength < 50 * 1024 * 1024)
            {
                byte[] bodyBytes = new byte[contentLength];
                int offset = 0;
                while (offset < contentLength)
                {
                    int read = ns.Read(bodyBytes, offset, contentLength - offset);
                    if (read <= 0) break;
                    offset += read;
                }
                body = Encoding.UTF8.GetString(bodyBytes, 0, offset);
            }

            return true;
        }

        private static void WriteHttpResponse(NetworkStream ns, string status, string contentType, byte[] body)
        {
            byte[] payload = body ?? new byte[0];
            StringBuilder sb = new StringBuilder();
            sb.Append("HTTP/1.1 ").Append(status).Append("\r\n");
            sb.Append("Content-Type: ").Append(contentType).Append("\r\n");
            sb.Append("Content-Length: ").Append(payload.Length).Append("\r\n");
            sb.Append("Access-Control-Allow-Origin: *\r\n");
            sb.Append("Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n");
            sb.Append("Access-Control-Allow-Headers: Content-Type\r\n");
            sb.Append("Cache-Control: no-store, no-cache, must-revalidate\r\n");
            sb.Append("Connection: close\r\n\r\n");

            byte[] headerBytes = Encoding.ASCII.GetBytes(sb.ToString());
            ns.Write(headerBytes, 0, headerBytes.Length);
            if (payload.Length > 0)
            {
                ns.Write(payload, 0, payload.Length);
            }
            ns.Flush();
        }

        private static byte[] BuildStandaloneHtmlBytes()
        {
            string crmDir = Program.GetCrmRootDir();
            string payloadHtml = Path.Combine(Program.GetPayloadDir(), "Kuzgun_Iletisim_CRM.html");
            string localHtml = Path.Combine(crmDir, "Kuzgun_CRM.html");
            string srcPath = File.Exists(payloadHtml) ? payloadHtml : localHtml;

            string html = File.ReadAllText(srcPath, Encoding.UTF8);

            // Inject standalone server API endpoint so the UI connects immediately to the built-in C# server
            string apiUrl = "http://127.0.0.1:" + _activePort + "/api";
            string injection = "window.__STANDALONE_SERVER__ = true; window.__STANDALONE_API__ = '" + apiUrl + "';\r\n        const { createApp } = Vue";
            html = html.Replace("const { createApp } = Vue", injection);

            // Inject cloud URL if saved in kurulum.json
            Dictionary<string, object> cfg = ReadConfigUnlocked();
            string cloudUrl = GetString(cfg, "url");
            if (!string.IsNullOrEmpty(cloudUrl) && cloudUrl.StartsWith("https://script.google.com/", StringComparison.OrdinalIgnoreCase))
            {
                html = html.Replace("const EMBED_URL = '';", "const EMBED_URL = '" + cloudUrl + "';");
            }

            return Encoding.UTF8.GetBytes(html);
        }

        private static JavaScriptSerializer CreateSerializer()
        {
            JavaScriptSerializer ser = new JavaScriptSerializer();
            ser.MaxJsonLength = int.MaxValue;
            ser.RecursionLimit = 100;
            return ser;
        }

        private static string HandleApiRequest(string body)
        {
            JavaScriptSerializer ser = CreateSerializer();
            try
            {
                Dictionary<string, object> req = ser.Deserialize<Dictionary<string, object>>(string.IsNullOrEmpty(body) ? "{}" : body);
                string fn = GetString(req, "fn");
                ArrayList args = new ArrayList();
                if (req != null && req.ContainsKey("args") && req["args"] is IEnumerable && !(req["args"] is string))
                {
                    foreach (object item in (IEnumerable)req["args"])
                    {
                        args.Add(item);
                    }
                }

                object result = DispatchRpc(fn, args);
                Dictionary<string, object> okEnv = new Dictionary<string, object>();
                okEnv["ok"] = true;
                okEnv["result"] = result;
                return ser.Serialize(okEnv);
            }
            catch (Exception ex)
            {
                Dictionary<string, object> errEnv = new Dictionary<string, object>();
                errEnv["ok"] = false;
                errEnv["error"] = ex.Message;
                return ser.Serialize(errEnv);
            }
        }

        private static object DispatchRpc(string fn, ArrayList args)
        {
            string arg0 = args.Count > 0 ? Convert.ToString(args[0] ?? string.Empty) : string.Empty;

            switch (fn)
            {
                case "crmStatus":
                case "syncGoogleAccount":
                    lock (_dbLock)
                    {
                        CheckPinUnlocked(arg0);
                        return CrmStatusUnlocked();
                    }

                case "listDevices":
                    lock (_dbLock)
                    {
                        CheckPinUnlocked(arg0);
                        return LoadDevicesUnlocked();
                    }

                case "upsertDevice":
                    lock (_dbLock)
                    {
                        CheckPinUnlocked(arg0);
                        Dictionary<string, object> dev = args.Count > 1 ? ToDict(args[1]) : null;
                        return UpsertDeviceUnlocked(dev);
                    }

                case "deleteDevice":
                    lock (_dbLock)
                    {
                        CheckPinUnlocked(arg0);
                        string id = args.Count > 1 ? Convert.ToString(args[1] ?? string.Empty) : string.Empty;
                        return DeleteDeviceUnlocked(id);
                    }

                case "importDevices":
                    lock (_dbLock)
                    {
                        CheckPinUnlocked(arg0);
                        ArrayList incoming = args.Count > 1 ? ToArrayList(args[1]) : new ArrayList();
                        bool safety = args.Count > 2 && args[2] is bool && (bool)args[2];
                        return ImportDevicesUnlocked(incoming, safety);
                    }

                case "replaceAllDevices":
                    lock (_dbLock)
                    {
                        CheckPinUnlocked(arg0);
                        ArrayList incoming = args.Count > 1 ? ToArrayList(args[1]) : new ArrayList();
                        bool safety = args.Count <= 2 || !(args[2] is bool) || (bool)args[2];
                        return ReplaceAllDevicesUnlocked(incoming, safety);
                    }

                case "changePin":
                    lock (_dbLock)
                    {
                        CheckPinUnlocked(arg0);
                        string newPin = args.Count > 1 ? Convert.ToString(args[1] ?? string.Empty) : string.Empty;
                        if (newPin.Length < 4) throw new Exception("PIN_KISA");
                        Dictionary<string, object> cfg = ReadConfigUnlocked();
                        cfg["pin"] = newPin;
                        WriteConfigUnlocked(cfg);
                        Dictionary<string, object> r = new Dictionary<string, object>();
                        r["status"] = "ok";
                        return r;
                    }

                case "backupToDrive":
                    lock (_dbLock)
                    {
                        CheckPinUnlocked(arg0);
                        return CreateBackupUnlocked(true, null);
                    }

                case "listDriveBackups":
                    lock (_dbLock)
                    {
                        CheckPinUnlocked(arg0);
                        return ListBackupsUnlocked();
                    }

                case "getDriveBackup":
                    lock (_dbLock)
                    {
                        CheckPinUnlocked(arg0);
                        string fileId = args.Count > 1 ? Convert.ToString(args[1] ?? string.Empty) : string.Empty;
                        return GetBackupUnlocked(fileId);
                    }

                case "deleteDriveBackup":
                    lock (_dbLock)
                    {
                        CheckPinUnlocked(arg0);
                        string fileId = args.Count > 1 ? Convert.ToString(args[1] ?? string.Empty) : string.Empty;
                        return DeleteBackupUnlocked(fileId);
                    }

                case "restoreFromDriveBackup":
                    lock (_dbLock)
                    {
                        CheckPinUnlocked(arg0);
                        string fileId = args.Count > 1 ? Convert.ToString(args[1] ?? string.Empty) : string.Empty;
                        string mode = args.Count > 2 ? Convert.ToString(args[2] ?? "merge") : "merge";
                        bool safety = args.Count <= 3 || !(args[3] is bool) || (bool)args[3];
                        return RestoreFromBackupUnlocked(fileId, mode, safety);
                    }

                case "setupDailyBackup":
                    lock (_dbLock)
                    {
                        if (!string.IsNullOrEmpty(arg0)) CheckPinUnlocked(arg0);
                        EnsureDailyBackupUnlocked();
                        Dictionary<string, object> r = new Dictionary<string, object>();
                        r["status"] = "ok";
                        r["dailyBackupActive"] = true;
                        return r;
                    }

                case "copyCodeGsAndOpenGoogle":
                    return CopyCodeGsAndOpenGoogle();

                case "checkClipboardExecUrl":
                    return CheckClipboardExecUrl();

                case "saveCloudExecUrl":
                    lock (_dbLock)
                    {
                        Dictionary<string, object> cfg = ReadConfigUnlocked();
                        if (!string.IsNullOrEmpty(arg0) && arg0.StartsWith("https://script.google.com/", StringComparison.OrdinalIgnoreCase))
                        {
                            cfg["url"] = arg0.Trim();
                            WriteConfigUnlocked(cfg);
                        }
                        Dictionary<string, object> r = new Dictionary<string, object>();
                        r["status"] = "ok";
                        r["url"] = arg0;
                        return r;
                    }

                case "openBackupFolder":
                    return OpenBackupFolderInExplorer();

                default:
                    throw new Exception("BILINMEYEN_ISLEM");
            }
        }

        private static void CheckPinUnlocked(string pin)
        {
            Dictionary<string, object> cfg = ReadConfigUnlocked();
            string expected = GetString(cfg, "pin");
            if (string.IsNullOrEmpty(expected))
            {
                expected = "kuzgun2024";
                cfg["pin"] = expected;
                WriteConfigUnlocked(cfg);
            }
            if (!string.Equals(pin ?? string.Empty, expected, StringComparison.Ordinal))
            {
                throw new Exception("PIN_HATALI");
            }
        }

        private static Dictionary<string, object> CrmStatusUnlocked()
        {
            List<Dictionary<string, object>> devices = LoadDevicesUnlocked();
            EnsureDailyBackupUnlocked();

            Dictionary<string, object> cfg = ReadConfigUnlocked();
            string cloudUrl = GetString(cfg, "url");
            bool hasGoogleCloud = !string.IsNullOrEmpty(cloudUrl) && cloudUrl.StartsWith("https://script.google.com/", StringComparison.OrdinalIgnoreCase);
            string driveFolder = FindGoogleDriveDesktopFolder();
            string acc = GetString(cfg, "googleAccount");
            if (string.IsNullOrEmpty(acc))
            {
                acc = driveFolder != null
                    ? "Google Drive Masaustu (" + driveFolder + ")"
                    : "Masaustu Veritabani (" + Environment.UserName + ")";
            }

            long maxUpdated = 0;
            for (int i = 0; i < devices.Count; i++)
            {
                long u = GetLong(devices[i], "updated_at");
                if (u > maxUpdated) maxUpdated = u;
            }

            Dictionary<string, object> res = new Dictionary<string, object>();
            res["count"] = devices.Count;
            res["spreadsheet"] = hasGoogleCloud
                ? "Google Sheets + Yerel Disk"
                : (driveFolder != null ? "Yerel Disk + Google Drive Klasoru" : "Yerel Disk Veritabani (KuzgunCRM)");
            res["spreadsheetId"] = "LOCAL_STANDALONE_DB";
            res["url"] = hasGoogleCloud ? cloudUrl : string.Empty;
            res["dailyBackupActive"] = true;
            res["accountEmail"] = acc;
            res["activeUserEmail"] = acc;
            res["isStandalone"] = true;
            res["hasGoogleCloud"] = hasGoogleCloud;
            res["version"] = "2.4.0";
            res["updated"] = maxUpdated;
            return res;
        }

        private static string GetDbFilePath()
        {
            return Path.Combine(Program.GetCrmRootDir(), "veritabani.json");
        }

        private static string GetBackupDirPath()
        {
            string dir = Path.Combine(Program.GetCrmRootDir(), "yedekler");
            Directory.CreateDirectory(dir);
            return dir;
        }

        private static string FindGoogleDriveDesktopFolder()
        {
            try
            {
                string userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
                string[] candidates = new string[]
                {
                    Path.Combine(userProfile, "Google Drive", "My Drive"),
                    Path.Combine(userProfile, "Google Drive", "Drive'ım"),
                    Path.Combine(userProfile, "Google Drive"),
                    @"G:\My Drive",
                    @"G:\Drive'ım",
                    Path.Combine(userProfile, "OneDrive")
                };
                for (int i = 0; i < candidates.Length; i++)
                {
                    if (Directory.Exists(candidates[i]))
                    {
                        string backupSub = Path.Combine(candidates[i], "Kuzgun CRM Yedekleri");
                        try
                        {
                            Directory.CreateDirectory(backupSub);
                            return backupSub;
                        }
                        catch {}
                    }
                }
            }
            catch {}
            return null;
        }

        private static List<Dictionary<string, object>> LoadDevicesUnlocked()
        {
            string dbFile = GetDbFilePath();
            JavaScriptSerializer ser = CreateSerializer();

            if (!File.Exists(dbFile))
            {
                string migFile = Path.Combine(Program.GetCrmRootDir(), "migrated_devices.json");
                if (File.Exists(migFile))
                {
                    try
                    {
                        List<Dictionary<string, object>> migList = ParseDevicesFromJson(File.ReadAllText(migFile, Encoding.UTF8));
                        if (migList.Count > 0)
                        {
                            SaveDevicesUnlocked(migList);
                            return migList;
                        }
                    }
                    catch {}
                }

                List<Dictionary<string, object>> demo = CreateDemoDevices();
                SaveDevicesUnlocked(demo);
                return demo;
            }

            try
            {
                string raw = File.ReadAllText(dbFile, Encoding.UTF8);
                return ParseDevicesFromJson(raw);
            }
            catch
            {
                try
                {
                    string bak = dbFile + ".bak";
                    if (File.Exists(bak))
                        return ParseDevicesFromJson(File.ReadAllText(bak, Encoding.UTF8));
                }
                catch {}
                return new List<Dictionary<string, object>>();
            }
        }

        private static void SaveDevicesUnlocked(List<Dictionary<string, object>> devices)
        {
            JavaScriptSerializer ser = CreateSerializer();
            string json = ser.Serialize(devices);
            string dbFile = GetDbFilePath();
            string tmp = dbFile + ".tmp";
            File.WriteAllText(tmp, json, new UTF8Encoding(false));
            if (File.Exists(dbFile))
            {
                try { File.Replace(tmp, dbFile, dbFile + ".bak"); }
                catch
                {
                    File.Copy(tmp, dbFile, true);
                    try { File.Delete(tmp); } catch {}
                }
            }
            else
            {
                File.Move(tmp, dbFile);
            }
        }

        private static List<Dictionary<string, object>> CreateDemoDevices()
        {
            long now = ToUnixMs(DateTime.UtcNow);
            List<Dictionary<string, object>> list = new List<Dictionary<string, object>>();

            Dictionary<string, object> d1 = new Dictionary<string, object>();
            d1["id"] = "1";
            d1["type"] = "REPAIR";
            d1["status"] = "IN_PROGRESS";
            d1["brand"] = "Apple";
            d1["model"] = "iPhone 13";
            d1["imei"] = "123456789012345";
            d1["serial_number"] = "";
            d1["customer_name"] = "Ahmet Yılmaz";
            d1["customer_phone"] = "0532 123 4567";
            d1["operations_performed"] = "Ekran değişimi yapılacak";
            d1["notes"] = "Şifre: 1453";
            d1["price"] = 1500;
            d1["created_at"] = now - 86400000L;
            d1["updated_at"] = now - 86400000L;
            list.Add(d1);

            Dictionary<string, object> d2 = new Dictionary<string, object>();
            d2["id"] = "2";
            d2["type"] = "SALE";
            d2["status"] = "IN_STOCK";
            d2["brand"] = "Samsung";
            d2["model"] = "Galaxy S23 Ultra";
            d2["imei"] = "987654321098765";
            d2["serial_number"] = "R5CW32";
            d2["customer_name"] = "";
            d2["customer_phone"] = "";
            d2["operations_performed"] = "";
            d2["notes"] = "İkinci el, temiz, kutulu";
            d2["price"] = 35000;
            d2["created_at"] = now - 172800000L;
            d2["updated_at"] = now - 172800000L;
            list.Add(d2);

            return list;
        }

        private static Dictionary<string, object> UpsertDeviceUnlocked(Dictionary<string, object> raw)
        {
            Dictionary<string, object> dev = NormalizeDevice(raw);
            if (dev == null || string.IsNullOrEmpty(GetString(dev, "id")))
            {
                throw new Exception("GECERSIZ_KAYIT");
            }

            List<Dictionary<string, object>> list = LoadDevicesUnlocked();
            string id = GetString(dev, "id");
            int idx = -1;
            for (int i = 0; i < list.Count; i++)
            {
                if (string.Equals(GetString(list[i], "id"), id, StringComparison.Ordinal))
                {
                    idx = i;
                    break;
                }
            }

            if (idx >= 0)
            {
                list[idx] = dev;
            }
            else
            {
                list.Add(dev);
            }

            SaveDevicesUnlocked(list);
            Dictionary<string, object> res = new Dictionary<string, object>();
            res["status"] = "ok";
            res["device"] = dev;
            return res;
        }

        private static Dictionary<string, object> DeleteDeviceUnlocked(string id)
        {
            List<Dictionary<string, object>> list = LoadDevicesUnlocked();
            list.RemoveAll(delegate(Dictionary<string, object> d)
            {
                return string.Equals(GetString(d, "id"), id, StringComparison.Ordinal);
            });
            SaveDevicesUnlocked(list);

            Dictionary<string, object> res = new Dictionary<string, object>();
            res["status"] = "ok";
            return res;
        }

        private static Dictionary<string, object> ImportDevicesUnlocked(ArrayList incoming, bool safety)
        {
            string safetyFile = null;
            if (safety)
            {
                Dictionary<string, object> bRes = CreateBackupUnlocked(true, "oncesi");
                safetyFile = GetString(bRes, "file");
            }

            List<Dictionary<string, object>> current = LoadDevicesUnlocked();
            Dictionary<string, int> indexById = new Dictionary<string, int>(StringComparer.Ordinal);
            for (int i = 0; i < current.Count; i++)
            {
                indexById[GetString(current[i], "id")] = i;
            }

            int added = 0;
            int updated = 0;
            int processed = 0;
            HashSet<string> seenBatch = new HashSet<string>(StringComparer.Ordinal);

            if (incoming != null)
            {
                for (int i = 0; i < incoming.Count; i++)
                {
                    Dictionary<string, object> d = NormalizeDevice(ToDict(incoming[i]));
                    if (d == null) continue;
                    string id = GetString(d, "id");
                    if (string.IsNullOrEmpty(id)) continue;

                    if (!seenBatch.Contains(id))
                    {
                        seenBatch.Add(id);
                        processed++;
                        if (indexById.ContainsKey(id))
                        {
                            current[indexById[id]] = d;
                            updated++;
                        }
                        else
                        {
                            indexById[id] = current.Count;
                            current.Add(d);
                            added++;
                        }
                    }
                    else
                    {
                        current[indexById[id]] = d;
                    }
                }
            }

            SaveDevicesUnlocked(current);
            Dictionary<string, object> res = new Dictionary<string, object>();
            res["status"] = "ok";
            res["imported"] = processed;
            res["updated"] = updated;
            res["added"] = added;
            res["safetyFile"] = safetyFile;
            return res;
        }

        private static Dictionary<string, object> ReplaceAllDevicesUnlocked(ArrayList incoming, bool safety)
        {
            string safetyFile = null;
            if (safety)
            {
                Dictionary<string, object> bRes = CreateBackupUnlocked(true, "oncesi");
                safetyFile = GetString(bRes, "file");
            }

            List<Dictionary<string, object>> next = new List<Dictionary<string, object>>();
            HashSet<string> seen = new HashSet<string>(StringComparer.Ordinal);
            if (incoming != null)
            {
                for (int i = 0; i < incoming.Count; i++)
                {
                    Dictionary<string, object> d = NormalizeDevice(ToDict(incoming[i]));
                    if (d == null) continue;
                    string id = GetString(d, "id");
                    if (string.IsNullOrEmpty(id) || seen.Contains(id)) continue;
                    seen.Add(id);
                    next.Add(d);
                }
            }

            SaveDevicesUnlocked(next);
            Dictionary<string, object> res = new Dictionary<string, object>();
            res["status"] = "ok";
            res["count"] = next.Count;
            res["safetyFile"] = safetyFile;
            return res;
        }

        private static void EnsureDailyBackupUnlocked()
        {
            string backupDir = GetBackupDirPath();
            string todayName = "kuzgun-crm-" + DateTime.Now.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) + ".json";
            string fullPath = Path.Combine(backupDir, todayName);
            if (!File.Exists(fullPath))
            {
                CreateBackupUnlocked(false, null);
            }
        }

        private static Dictionary<string, object> CreateBackupUnlocked(bool instant, string prefix)
        {
            List<Dictionary<string, object>> devices = LoadDevicesUnlocked();
            string backupDir = GetBackupDirPath();
            DateTime now = DateTime.Now;
            string day = now.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
            string ts = now.ToString("HHmmss", CultureInfo.InvariantCulture);
            string baseName = "kuzgun-crm-" + (!string.IsNullOrEmpty(prefix) ? (prefix + "-") : string.Empty);
            string fileName = instant ? (baseName + day + "-" + ts + ".json") : (baseName + day + ".json");

            Dictionary<string, object> envelope = new Dictionary<string, object>();
            envelope["app"] = "kuzgun-crm";
            envelope["version"] = "2.4.0";
            envelope["exported_at"] = DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture);
            envelope["count"] = devices.Count;
            envelope["devices"] = devices;

            JavaScriptSerializer ser = CreateSerializer();
            string json = ser.Serialize(envelope);
            string destPath = Path.Combine(backupDir, fileName);
            File.WriteAllText(destPath, json, new UTF8Encoding(false));

            // Mirror to Google Drive Desktop / OneDrive folder if present
            string driveFolder = FindGoogleDriveDesktopFolder();
            if (!string.IsNullOrEmpty(driveFolder))
            {
                try
                {
                    File.WriteAllText(Path.Combine(driveFolder, fileName), json, new UTF8Encoding(false));
                }
                catch {}
            }

            // Keep last 40 backups
            try
            {
                FileInfo[] files = new DirectoryInfo(backupDir).GetFiles("kuzgun-crm-*.json");
                Array.Sort(files, delegate(FileInfo a, FileInfo b) { return a.LastWriteTimeUtc.CompareTo(b.LastWriteTimeUtc); });
                for (int i = 0; i < files.Length - 40; i++)
                {
                    try { files[i].Delete(); } catch {}
                }
            }
            catch {}

            Dictionary<string, object> res = new Dictionary<string, object>();
            res["status"] = "ok";
            res["file"] = fileName;
            res["fileId"] = fileName;
            res["count"] = devices.Count;
            res["folder"] = "Kuzgun CRM Yedekleri";
            return res;
        }

        private static List<Dictionary<string, object>> ListBackupsUnlocked()
        {
            string backupDir = GetBackupDirPath();
            FileInfo[] files = new DirectoryInfo(backupDir).GetFiles("kuzgun-crm-*.json");
            Array.Sort(files, delegate(FileInfo a, FileInfo b) { return b.LastWriteTimeUtc.CompareTo(a.LastWriteTimeUtc); });

            List<Dictionary<string, object>> list = new List<Dictionary<string, object>>();
            for (int i = 0; i < files.Length; i++)
            {
                FileInfo fi = files[i];
                int count = 0;
                try
                {
                    List<Dictionary<string, object>> devs = ParseDevicesFromJson(File.ReadAllText(fi.FullName, Encoding.UTF8));
                    count = devs.Count;
                }
                catch {}

                Dictionary<string, object> item = new Dictionary<string, object>();
                item["id"] = fi.Name;
                item["name"] = fi.Name;
                item["size"] = fi.Length;
                item["updated"] = ToUnixMs(fi.LastWriteTimeUtc);
                item["updatedStr"] = fi.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture);
                item["count"] = count;
                item["kind"] = fi.Name.StartsWith("kuzgun-crm-oncesi-", StringComparison.OrdinalIgnoreCase) ? "safety" : "normal";
                list.Add(item);
            }
            return list;
        }

        private static string ResolveBackupFilePath(string fileId)
        {
            if (string.IsNullOrEmpty(fileId)) throw new Exception("YEDEK_BULUNAMADI");
            string safeName = Path.GetFileName(fileId);
            if (!safeName.StartsWith("kuzgun-crm-", StringComparison.OrdinalIgnoreCase) || !safeName.EndsWith(".json", StringComparison.OrdinalIgnoreCase))
            {
                throw new Exception("GECERSIZ_YEDEK");
            }
            string fullPath = Path.Combine(GetBackupDirPath(), safeName);
            if (!File.Exists(fullPath)) throw new Exception("YEDEK_BULUNAMADI");
            return fullPath;
        }

        private static Dictionary<string, object> GetBackupUnlocked(string fileId)
        {
            string fullPath = ResolveBackupFilePath(fileId);
            List<Dictionary<string, object>> devices = ParseDevicesFromJson(File.ReadAllText(fullPath, Encoding.UTF8));
            Dictionary<string, object> res = new Dictionary<string, object>();
            res["name"] = Path.GetFileName(fullPath);
            res["count"] = devices.Count;
            res["devices"] = devices;
            return res;
        }

        private static Dictionary<string, object> DeleteBackupUnlocked(string fileId)
        {
            string fullPath = ResolveBackupFilePath(fileId);
            File.Delete(fullPath);
            Dictionary<string, object> res = new Dictionary<string, object>();
            res["status"] = "ok";
            return res;
        }

        private static Dictionary<string, object> RestoreFromBackupUnlocked(string fileId, string mode, bool safety)
        {
            string fullPath = ResolveBackupFilePath(fileId);
            List<Dictionary<string, object>> incomingList = ParseDevicesFromJson(File.ReadAllText(fullPath, Encoding.UTF8));
            ArrayList incomingArr = new ArrayList(incomingList);

            if (string.Equals(mode, "replace", StringComparison.OrdinalIgnoreCase))
            {
                Dictionary<string, object> rep = ReplaceAllDevicesUnlocked(incomingArr, safety);
                rep["mode"] = "replace";
                rep["name"] = Path.GetFileName(fullPath);
                return rep;
            }
            else
            {
                Dictionary<string, object> imp = ImportDevicesUnlocked(incomingArr, safety);
                imp["mode"] = "merge";
                imp["count"] = incomingList.Count;
                imp["name"] = Path.GetFileName(fullPath);
                return imp;
            }
        }

        private static Dictionary<string, object> CopyCodeGsAndOpenGoogle()
        {
            string codePath = Path.Combine(Program.GetPayloadDir(), "Code.gs");
            if (!File.Exists(codePath))
            {
                Program.ExtractPayloadFiles(Program.GetPayloadDir());
            }
            string codeText = File.ReadAllText(codePath, Encoding.UTF8);

            Thread sta = new Thread((ThreadStart)delegate
            {
                try
                {
                    Clipboard.SetText(codeText);
                }
                catch {}
            });
            sta.SetApartmentState(ApartmentState.STA);
            sta.Start();
            sta.Join(3000);

            try
            {
                Process.Start(new ProcessStartInfo("https://script.new") { UseShellExecute = true });
            }
            catch {}

            Dictionary<string, object> res = new Dictionary<string, object>();
            res["status"] = "ok";
            return res;
        }

        private static Dictionary<string, object> CheckClipboardExecUrl()
        {
            string clipText = string.Empty;
            Thread sta = new Thread((ThreadStart)delegate
            {
                try
                {
                    if (Clipboard.ContainsText())
                    {
                        clipText = (Clipboard.GetText() ?? string.Empty).Trim();
                    }
                }
                catch {}
            });
            sta.SetApartmentState(ApartmentState.STA);
            sta.Start();
            sta.Join(1500);

            Regex rx = new Regex(@"https://script\.google\.com/(?:a/[^/\s]+/)?macros/s/[\w-]+/exec", RegexOptions.IgnoreCase);
            Match m = rx.Match(clipText);

            Dictionary<string, object> res = new Dictionary<string, object>();
            res["found"] = m.Success;
            res["url"] = m.Success ? m.Value : string.Empty;
            res["text"] = clipText;
            return res;
        }

        private static Dictionary<string, object> OpenBackupFolderInExplorer()
        {
            try
            {
                string dir = FindGoogleDriveDesktopFolder() ?? GetBackupDirPath();
                Process.Start(new ProcessStartInfo("explorer.exe", Program.Quote(dir)) { UseShellExecute = true });
            }
            catch {}
            Dictionary<string, object> res = new Dictionary<string, object>();
            res["status"] = "ok";
            return res;
        }

        private static List<Dictionary<string, object>> ParseDevicesFromJson(string rawJson)
        {
            List<Dictionary<string, object>> result = new List<Dictionary<string, object>>();
            if (string.IsNullOrEmpty(rawJson)) return result;

            JavaScriptSerializer ser = CreateSerializer();
            object parsed = ser.DeserializeObject(rawJson);
            if (parsed == null) return result;

            IEnumerable items = null;
            if (parsed is IDictionary)
            {
                IDictionary dict = (IDictionary)parsed;
                string[] keys = new string[] { "devices", "data", "records", "items" };
                for (int i = 0; i < keys.Length; i++)
                {
                    if (dict.Contains(keys[i]) && dict[keys[i]] is IEnumerable && !(dict[keys[i]] is string))
                    {
                        items = (IEnumerable)dict[keys[i]];
                        break;
                    }
                }
                if (items == null && dict.Contains("backup") && dict["backup"] is IDictionary)
                {
                    IDictionary bDict = (IDictionary)dict["backup"];
                    if (bDict.Contains("devices") && bDict["devices"] is IEnumerable)
                    {
                        items = (IEnumerable)bDict["devices"];
                    }
                }
                if (items == null)
                {
                    items = new object[] { dict };
                }
            }
            else if (parsed is IEnumerable && !(parsed is string))
            {
                items = (IEnumerable)parsed;
            }

            if (items == null) return result;

            HashSet<string> seen = new HashSet<string>(StringComparer.Ordinal);
            foreach (object obj in items)
            {
                Dictionary<string, object> norm = NormalizeDevice(ToDict(obj));
                if (norm != null)
                {
                    string id = GetString(norm, "id");
                    if (!string.IsNullOrEmpty(id) && !seen.Contains(id))
                    {
                        seen.Add(id);
                        result.Add(norm);
                    }
                }
            }
            return result;
        }

        private static Dictionary<string, object> NormalizeDevice(Dictionary<string, object> d)
        {
            if (d == null || d.Count == 0) return null;

            string id = FirstNonEmpty(d, "id", "_id", "device_id", "kayit_id", "no");
            string brand = FirstNonEmpty(d, "brand", "marka", "device_brand", "cihaz_marka");
            string model = FirstNonEmpty(d, "model", "cihaz_model", "device_model", "cihaz");
            string imei = FirstNonEmpty(d, "imei", "imei_no", "imeiNumber");
            string sn = FirstNonEmpty(d, "serial_number", "serialNumber", "seri_no", "seriNo", "serial");
            string custName = FirstNonEmpty(d, "customer_name", "customerName", "musteri_adi", "musteri", "customer", "ad_soyad", "full_name");
            string custPhone = FirstNonEmpty(d, "customer_phone", "customerPhone", "musteri_tel", "telefon", "phone", "tel");
            string ops = FirstNonEmpty(d, "operations_performed", "operations", "yapilan_islemler", "yapilan_islem", "islem", "problem", "ariza", "issue", "description");
            string notes = FirstNonEmpty(d, "notes", "notlar", "aciklama");
            string pwd = FirstNonEmpty(d, "sifre", "password", "device_password");

            if (!string.IsNullOrEmpty(pwd) && notes.IndexOf(pwd, StringComparison.OrdinalIgnoreCase) < 0)
            {
                notes = string.IsNullOrEmpty(notes) ? ("Şifre: " + pwd) : (notes + " | Şifre: " + pwd);
            }

            if (string.IsNullOrEmpty(id))
            {
                if (string.IsNullOrEmpty(custName) && string.IsNullOrEmpty(brand) && string.IsNullOrEmpty(model) && string.IsNullOrEmpty(imei) && string.IsNullOrEmpty(sn))
                {
                    return null;
                }
                string seed = custName + "|" + custPhone + "|" + brand + "|" + model + "|" + imei + "|" + sn + "|" + ops;
                int hash = 0;
                for (int i = 0; i < seed.Length; i++)
                {
                    hash = ((hash * 31) + seed[i]) & 0x7FFFFFFF;
                }
                id = (1000000000 + (hash % 900000000)).ToString(CultureInfo.InvariantCulture);
            }

            string rawType = FirstNonEmpty(d, "type", "tur", "record_type", "islem_turu", "category").ToLowerInvariant();
            string rawStatus = FirstNonEmpty(d, "status", "durum", "state").ToLowerInvariant();

            string type = "REPAIR";
            if (rawType == "sale" || rawType == "satis" || rawType == "satış" || rawType == "alim" || rawType == "alım" || rawType == "stok" || rawType == "stock" || rawType == "inventory" ||
                rawStatus == "in_stock" || rawStatus == "sold" || rawStatus == "stokta" || rawStatus == "satildi" || rawStatus == "satıldı")
            {
                type = "SALE";
            }

            string status = type == "SALE" ? "IN_STOCK" : "PENDING";
            if (rawStatus == "pending" || rawStatus == "bekliyor" || rawStatus == "beklemede" || rawStatus == "yeni") status = "PENDING";
            else if (rawStatus == "in_progress" || rawStatus == "islemde" || rawStatus == "işlemde" || rawStatus == "tamirde") status = "IN_PROGRESS";
            else if (rawStatus == "completed" || rawStatus == "tamamlandi" || rawStatus == "tamamlandı" || rawStatus == "hazir" || rawStatus == "hazır") status = "COMPLETED";
            else if (rawStatus == "delivered" || rawStatus == "teslim" || rawStatus == "teslim_edildi" || rawStatus == "teslim edildi") status = "DELIVERED";
            else if (rawStatus == "in_stock" || rawStatus == "stokta" || rawStatus == "satilik" || rawStatus == "satılık") status = "IN_STOCK";
            else if (rawStatus == "sold" || rawStatus == "satildi" || rawStatus == "satıldı") status = "SOLD";

            object priceObj = null;
            string priceStr = FirstNonEmpty(d, "price", "fiyat", "ucret", "cost", "amount", "tutar");
            if (!string.IsNullOrEmpty(priceStr))
            {
                string clean = Regex.Replace(priceStr, @"[₺TLtl\s]", "").Trim();
                if (clean.Contains(".") && clean.Contains(",")) clean = clean.Replace(".", "").Replace(",", ".");
                else if (clean.Contains(",")) clean = clean.Replace(",", ".");
                double pVal;
                if (double.TryParse(clean, NumberStyles.Any, CultureInfo.InvariantCulture, out pVal))
                {
                    priceObj = pVal;
                }
            }

            long nowMs = ToUnixMs(DateTime.UtcNow);
            long createdAt = GetLong(d, "created_at");
            if (createdAt <= 0) createdAt = nowMs;
            else if (createdAt < 100000000000L) createdAt *= 1000L;

            long updatedAt = GetLong(d, "updated_at");
            if (updatedAt <= 0) updatedAt = createdAt;
            else if (updatedAt < 100000000000L) updatedAt *= 1000L;

            Dictionary<string, object> outDev = new Dictionary<string, object>();
            outDev["id"] = id;
            outDev["type"] = type;
            outDev["status"] = status;
            outDev["brand"] = brand;
            outDev["model"] = model;
            outDev["imei"] = imei;
            outDev["serial_number"] = sn;
            outDev["customer_name"] = custName;
            outDev["customer_phone"] = custPhone;
            outDev["operations_performed"] = ops;
            outDev["notes"] = notes;
            outDev["price"] = priceObj;
            outDev["created_at"] = createdAt;
            outDev["updated_at"] = updatedAt;
            return outDev;
        }

        private static Dictionary<string, object> ReadConfigUnlocked()
        {
            string cfgPath = Path.Combine(Program.GetCrmRootDir(), "kurulum.json");
            if (File.Exists(cfgPath))
            {
                try
                {
                    JavaScriptSerializer ser = CreateSerializer();
                    Dictionary<string, object> d = ser.Deserialize<Dictionary<string, object>>(File.ReadAllText(cfgPath, Encoding.UTF8));
                    if (d != null) return d;
                }
                catch {}
            }
            return new Dictionary<string, object>();
        }

        private static void WriteConfigUnlocked(Dictionary<string, object> cfg)
        {
            try
            {
                JavaScriptSerializer ser = CreateSerializer();
                string json = ser.Serialize(cfg);
                File.WriteAllText(Path.Combine(Program.GetCrmRootDir(), "kurulum.json"), json, new UTF8Encoding(false));
            }
            catch {}
        }

        private static Dictionary<string, object> ToDict(object obj)
        {
            if (obj == null) return null;
            if (obj is Dictionary<string, object>) return (Dictionary<string, object>)obj;
            if (obj is IDictionary)
            {
                IDictionary raw = (IDictionary)obj;
                Dictionary<string, object> d = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
                foreach (DictionaryEntry de in raw)
                {
                    if (de.Key != null) d[de.Key.ToString()] = de.Value;
                }
                return d;
            }
            return null;
        }

        private static ArrayList ToArrayList(object obj)
        {
            ArrayList list = new ArrayList();
            if (obj is IEnumerable && !(obj is string))
            {
                foreach (object item in (IEnumerable)obj) list.Add(item);
            }
            return list;
        }

        private static string FirstNonEmpty(Dictionary<string, object> d, params string[] keys)
        {
            if (d == null) return string.Empty;
            for (int i = 0; i < keys.Length; i++)
            {
                if (d.ContainsKey(keys[i]) && d[keys[i]] != null)
                {
                    string s = Convert.ToString(d[keys[i]], CultureInfo.InvariantCulture).Trim();
                    if (!string.IsNullOrEmpty(s)) return s;
                }
            }
            return string.Empty;
        }

        private static string GetString(Dictionary<string, object> d, string key)
        {
            if (d != null && d.ContainsKey(key) && d[key] != null)
            {
                return Convert.ToString(d[key], CultureInfo.InvariantCulture);
            }
            return string.Empty;
        }

        private static long GetLong(Dictionary<string, object> d, string key)
        {
            if (d != null && d.ContainsKey(key) && d[key] != null)
            {
                long val;
                if (long.TryParse(Convert.ToString(d[key], CultureInfo.InvariantCulture), out val)) return val;
            }
            return 0L;
        }

        private static long ToUnixMs(DateTime dtUtc)
        {
            DateTime epoch = new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc);
            return (long)(dtUtc.ToUniversalTime() - epoch).TotalMilliseconds;
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
                    det.CloudVersion = SimpleJsonExtract(json, "surum") ?? "v2.4.0";
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
                det.SummaryTitle = "MEVCUT KURULUM BULUNDU (GÜNCELLEME MODU)";
                det.TitleColor = Color.FromArgb(14, 116, 144);
                det.SummaryDetail = string.Format(
                    "Sistemde aktif Kuzgun CRM ({0}) bulundu. Tek tikla guncelleme yapildiginda masaustu uygulamaniz yenilenecek ve tum musteri verileriniz aynen korunacaktir.",
                    det.CloudVersion ?? "v2.4.0");
            }
            else if (det.HasLegacyOzi || det.HasLegacyAppData || det.HasDesktopShortcuts)
            {
                det.SummaryTitle = "ESKİ YEREL SÜRÜM (127.0.0.1 / C:\\ozi) TESPİT EDİLDİ";
                det.TitleColor = Color.FromArgb(180, 83, 9);
                det.SummaryDetail = "Eski v1.x/v2.0 yerel surum kalintilari (C:\\ozi veya masaustu) bulundu. Kurulum sirasinda eski veritabaniniz otomatik taranacak ve tum musterileriniz kayipsiz yeni masaustu uygulamasina aktarilacaktir.";
            }
            else
            {
                det.SummaryTitle = "TEMİZ KURULUM HAZIR";
                det.TitleColor = Color.FromArgb(15, 118, 110);
                det.SummaryDetail = "Tek tikla Kuzgun CRM Standalone Masaustu Uygulamasi, yerel veritabani, otomatik yedekleme ve Google Bulut entegrasyonu kurulacaktir.";
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
            _lblSubtitle.Text = "Standalone Masaüstü Uygulaması & Bulut Entegrasyonlu Teknik Servis Sistemi";
            _lblSubtitle.Font = new Font("Segoe UI", 9F, FontStyle.Regular);
            _lblSubtitle.ForeColor = Color.FromArgb(147, 197, 253);
            _lblSubtitle.Location = new Point(22, 43);
            _lblSubtitle.AutoSize = true;

            _lblVersion = new Label();
            _lblVersion.Text = "v2.4.0";
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
            _chkAutoLaunch.Text = "Kurulum tamamlandığında CRM uygulamasını aç";
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
            _btnOpenCrm.Visible = true;
            _btnOpenCrm.Enabled = true;
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

            AppendLog("Kuzgun CRM v2.4.0 Kurulum ve Yonetim Sihirbazi hazir.");
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
                Program.InstallStandaloneExe();

                this.BeginInvoke((Action)delegate
                {
                    AppendLog("Kurulum motoru baslatiliyor (Kurulum.ps1)...");
                    _progressBar.Value = 20;
                });

                string ps = Program.FindPowerShellExe();
                string exeDir = AppDomain.CurrentDomain.BaseDirectory ?? string.Empty;
                exeDir = exeDir.TrimEnd('\\', '/');

                StringBuilder sb = new StringBuilder();
                sb.Append("-NoProfile -ExecutionPolicy Bypass -File ");
                sb.Append(Program.Quote(Path.Combine(baseDir, "Kurulum.ps1")));
                sb.Append(" -Sessiz");
                if (!string.IsNullOrEmpty(exeDir))
                {
                    sb.Append(" -ExeDir ");
                    sb.Append(Program.Quote(exeDir));
                }

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
            else if (upper.Contains("MIGRAS") || upper.Contains("ESKI SURUM") || upper.Contains("AKTAR"))
            {
                SetStep("Eski sürüm verileri taranıyor ve yeni şemaya aktarılıyor...", 60);
            }
            else if (upper.Contains("KISAYOL") || upper.Contains("MASAUSTU"))
            {
                SetStep("Masaüstü uygulaması ve kısayollar oluşturuluyor...", 85);
            }
            else if (upper.Contains("ISLEM TAMAMLANDI") || upper.Contains("KURULUM TAMAMLANDI") || upper.Contains("ASAMA 4"))
            {
                SetStep("Kurulum ve veri aktarımı başarıyla tamamlandı!", 100);
            }
            else if (upper.Contains("[OK]") && _progressBar.Value < 90)
            {
                _progressBar.Value = Math.Min(90, _progressBar.Value + 4);
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
            _btnOpenCrm.Visible = true;
            _btnOpenCrm.Enabled = true;

            if (exitCode == 0)
            {
                _progressBar.Value = 100;
                _lblStep.Text = "✓ Tebrikler! Kuzgun CRM Masaüstü Uygulaması başarıyla kuruldu ve hazır.";
                _lblStep.ForeColor = Color.FromArgb(16, 120, 70);
                _btnStart.Text = "Yeniden Kur";
                _btnStart.Enabled = true;
                _btnCancel.Text = "Kapat";

                AppendLog(">> KURULUM BASARIYLA TAMAMLANDI. MASAUSTU UYGULAMASI ACILIYOR...");

                if (_chkAutoLaunch.Checked)
                {
                    Program.LaunchCrmApp();
                }
            }
            else
            {
                _lblStep.Text = "⚠ Kurulum sırasında uyarı oluştu. 'CRM'i Aç' butonu ile uygulamayı başlatabilirsiniz.";
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
