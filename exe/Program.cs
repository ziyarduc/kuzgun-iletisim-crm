using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Resources;
using System.Text;

[assembly: AssemblyTitle("Kuzgun Iletisim CRM Kurulum")]
[assembly: AssemblyDescription("Tek tikla kurulum sihirbazi - Kuzgun Iletisim CRM")]
[assembly: AssemblyProduct("Kuzgun Iletisim CRM")]
[assembly: AssemblyCompany("Kuzgun Iletisim")]
[assembly: AssemblyVersion("1.2.0.0")]
[assembly: AssemblyFileVersion("1.2.0.0")]
[assembly: NeutralResourcesLanguage("tr-TR")]

namespace KuzgunCrmSetup
{
    internal static class Program
    {
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool SetConsoleOutputCP(uint wCodePageID);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool SetConsoleCP(uint wCodePageID);

        private static readonly string[] Payload = new string[]
        {
            "Kurulum.ps1",
            "Code.gs",
            "Kuzgun_Iletisim_CRM.html",
            "appsscript.json",
            "README.md"
        };

        private static int Main(string[] args)
        {
            try
            {
                SetConsoleCP(65001);
                SetConsoleOutputCP(65001);

                string baseDir = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "KuzgunCRM", "kaynak");
                Directory.CreateDirectory(baseDir);

                Assembly asm = Assembly.GetExecutingAssembly();
                for (int i = 0; i < Payload.Length; i++)
                {
                    string name = Payload[i];
                    byte[] data = ReadResource(asm, "payload." + name);
                    WriteRetry(Path.Combine(baseDir, name), data);
                }

                string ps = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.Windows),
                    "System32", "WindowsPowerShell", "v1.0", "powershell.exe");
                if (!File.Exists(ps)) ps = "powershell";

                StringBuilder sb = new StringBuilder();
                sb.Append("-NoProfile -ExecutionPolicy Bypass -File ");
                sb.Append(Quote(Path.Combine(baseDir, "Kurulum.ps1")));
                for (int i = 0; i < args.Length; i++)
                {
                    if (args[i] == null || args[i].Length == 0) continue;
                    sb.Append(' ');
                    sb.Append(Quote(args[i]));
                }

                ProcessStartInfo psi = new ProcessStartInfo(ps, sb.ToString());
                psi.UseShellExecute = false;
                using (Process p = Process.Start(psi))
                {
                    if (p == null) throw new InvalidOperationException("PowerShell sureci baslatilamadi");
                    p.WaitForExit();
                    return p.ExitCode;
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine("KURULUM BASLATILAMADI: " + ex.Message);
                return 97;
            }
        }

        private static byte[] ReadResource(Assembly asm, string name)
        {
            using (Stream s = asm.GetManifestResourceStream(name))
            {
                if (s == null) throw new InvalidOperationException("Gomulu dosya bulunamadi: " + name);
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
                    System.Threading.Thread.Sleep(150);
                }
            }
        }

        private static string Quote(string value)
        {
            bool simple = value.Length > 0;
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
}
