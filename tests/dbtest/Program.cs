using System; using System.Collections.Generic; using System.IO; using System.Text; using System.Globalization; using System.Threading; using System.Text.Json;
class JavaScriptSerializer { public int MaxJsonLength; public string Serialize(object o){ return JsonSerializer.Serialize(o);} public T Deserialize<T>(string s){ return JsonSerializer.Deserialize<T>(s);} }
static class Program { public static string Root; public static string GetCrmRootDir(){ return Root; } }
static class StandaloneServer {
  static readonly object _dbLock = new object();
  static string GetDbFilePath(){ return Path.Combine(Program.GetCrmRootDir(),"veritabani.json"); }
  static JavaScriptSerializer CreateSerializer(){ return new JavaScriptSerializer(); }
  static List<Dictionary<string,object>> ParseDevicesFromJson(string raw){ var l = JsonSerializer.Deserialize<List<Dictionary<string,object>>>(raw); if (l==null) throw new Exception("x"); return l; }
  static List<Dictionary<string,object>> CreateDemoDevices(){ return new List<Dictionary<string,object>>{ new Dictionary<string,object>{{"id",1},{"model","demo"}} }; }
  public static List<Dictionary<string,object>> Load(){ lock(_dbLock){ return LoadDevicesUnlocked(); } }
  public static void Save(List<Dictionary<string,object>> l){ lock(_dbLock){ SaveDevicesUnlocked(l); } }
  public static void ResetMemory(){ lock(_dbLock){ _cache=null; _cacheSer=null; _snapshotDirty=false; } }
        // ---- Veritabani katmani: bellek onbellegi + aninda gunluk (journal) + 300ms debounce'lu atomik snapshot ----
        private const int FLUSH_DELAY_MS = 300;
        private const int JOURNAL_BULK_LIMIT = 100;
        private static List<Dictionary<string, object>> _cache = null;
        private static Dictionary<string, string> _cacheSer = null;
        private static bool _snapshotDirty = false;
        private static System.Threading.Timer _flushTimer = null;
        private static bool _exitHooked = false;
        internal static string LastRecoveryNote = null;

        private static string JournalPath() { return GetDbFilePath() + ".journal"; }

        private static string RecKey(Dictionary<string, object> d)
        {
            object v;
            if (d != null && d.TryGetValue("id", out v) && v != null) return Convert.ToString(v, CultureInfo.InvariantCulture);
            return "";
        }

        private static List<Dictionary<string, object>> CloneList(List<Dictionary<string, object>> src)
        {
            List<Dictionary<string, object>> copy = new List<Dictionary<string, object>>(src.Count);
            for (int i = 0; i < src.Count; i++) copy.Add(new Dictionary<string, object>(src[i]));
            return copy;
        }

        private static void IndexCache()
        {
            JavaScriptSerializer ser = CreateSerializer();
            _cacheSer = new Dictionary<string, string>();
            for (int i = 0; i < _cache.Count; i++) _cacheSer[RecKey(_cache[i])] = ser.Serialize(_cache[i]);
        }

        private static void HookExit()
        {
            if (_exitHooked) return;
            _exitHooked = true;
            try
            {
                AppDomain.CurrentDomain.ProcessExit += delegate { FlushDb(); };
                Console.CancelKeyPress += delegate { FlushDb(); };
            }
            catch {}
        }

        internal static void FlushDb()
        {
            lock (_dbLock)
            {
                FlushUnlocked();
            }
        }

        private static void FlushUnlocked()
        {
            if (_cache == null || !_snapshotDirty) return;
            try
            {
                WriteSnapshotAtomic(_cache);
                _snapshotDirty = false;
                try { if (File.Exists(JournalPath())) File.Delete(JournalPath()); } catch {}
            }
            catch {}
        }

        private static void ScheduleFlush()
        {
            if (_flushTimer == null)
            {
                _flushTimer = new System.Threading.Timer(delegate { FlushDb(); }, null, FLUSH_DELAY_MS, Timeout.Infinite);
            }
            else
            {
                _flushTimer.Change(FLUSH_DELAY_MS, Timeout.Infinite);
            }
        }

        private static List<Dictionary<string, object>> ReadBaseFromDisk()
        {
            string dbFile = GetDbFilePath();
            try
            {
                return ParseDevicesFromJson(File.ReadAllText(dbFile, Encoding.UTF8));
            }
            catch {}

            try
            {
                string bak = dbFile + ".bak";
                if (File.Exists(bak))
                {
                    List<Dictionary<string, object>> b = ParseDevicesFromJson(File.ReadAllText(bak, Encoding.UTF8));
                    LastRecoveryNote = "veritabani.json bozuk: .bak dosyasindan kurtarildi";
                    return b;
                }
            }
            catch {}

            try
            {
                string dir = Path.Combine(Program.GetCrmRootDir(), "yedekler");
                if (Directory.Exists(dir))
                {
                    string[] files = Directory.GetFiles(dir, "*.json");
                    Array.Sort(files, delegate(string x, string y) { return File.GetLastWriteTimeUtc(y).CompareTo(File.GetLastWriteTimeUtc(x)); });
                    for (int i = 0; i < files.Length; i++)
                    {
                        try
                        {
                            List<Dictionary<string, object>> r = ParseDevicesFromJson(File.ReadAllText(files[i], Encoding.UTF8));
                            LastRecoveryNote = "veritabani.json bozuk: en yeni yedekten kurtarildi (" + Path.GetFileName(files[i]) + ")";
                            return r;
                        }
                        catch {}
                    }
                }
            }
            catch {}
            return new List<Dictionary<string, object>>();
        }

        private static void ReplayJournal(List<Dictionary<string, object>> list)
        {
            string jp = JournalPath();
            if (!File.Exists(jp)) return;
            JavaScriptSerializer ser = CreateSerializer();
            Dictionary<string, int> pos = new Dictionary<string, int>();
            for (int i = 0; i < list.Count; i++) pos[RecKey(list[i])] = i;
            string[] lines;
            try { lines = File.ReadAllLines(jp, Encoding.UTF8); } catch { return; }
            for (int i = 0; i < lines.Length; i++)
            {
                string ln = lines[i];
                if (ln.Length < 3) continue;
                try
                {
                    char op = ln[0];
                    string payload = ln.Substring(2);
                    if (op == 'U')
                    {
                        Dictionary<string, object> rec = ser.Deserialize<Dictionary<string, object>>(payload);
                        string k = RecKey(rec);
                        int idx;
                        if (pos.TryGetValue(k, out idx)) list[idx] = rec;
                        else { pos[k] = list.Count; list.Add(rec); }
                    }
                    else if (op == 'D')
                    {
                        int idx;
                        if (pos.TryGetValue(payload, out idx))
                        {
                            list.RemoveAt(idx);
                            pos.Clear();
                            for (int j = 0; j < list.Count; j++) pos[RecKey(list[j])] = j;
                        }
                    }
                }
                catch {}
            }
        }

        private static List<Dictionary<string, object>> LoadDevicesUnlocked()
        {
            HookExit();
            if (_cache != null) return CloneList(_cache);

            string dbFile = GetDbFilePath();

            if (!File.Exists(dbFile) && !File.Exists(dbFile + ".bak") && !File.Exists(JournalPath()))
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
                            return CloneList(_cache);
                        }
                    }
                    catch {}
                }

                SaveDevicesUnlocked(CreateDemoDevices());
                return CloneList(_cache);
            }

            List<Dictionary<string, object>> loaded = ReadBaseFromDisk();
            ReplayJournal(loaded);
            _cache = loaded;
            IndexCache();
            if (File.Exists(JournalPath()))
            {
                _snapshotDirty = true;
                FlushUnlocked();
            }
            return CloneList(_cache);
        }

        private static void SaveDevicesUnlocked(List<Dictionary<string, object>> devices)
        {
            HookExit();
            JavaScriptSerializer ser = CreateSerializer();
            List<Dictionary<string, object>> next = CloneList(devices);

            if (_cache == null || _cacheSer == null)
            {
                _cache = next;
                IndexCache();
                WriteSnapshotAtomic(_cache);
                _snapshotDirty = false;
                return;
            }

            // Fark hesapla: degisen/eklenen kayitlar (U) ve silinen kimlikler (D)
            Dictionary<string, string> nextSer = new Dictionary<string, string>();
            List<string> ops = new List<string>();
            for (int i = 0; i < next.Count; i++)
            {
                string k = RecKey(next[i]);
                string s = ser.Serialize(next[i]);
                nextSer[k] = s;
                string old;
                if (!_cacheSer.TryGetValue(k, out old) || old != s) ops.Add("U\t" + s);
            }
            foreach (KeyValuePair<string, string> kv in _cacheSer)
            {
                if (!nextSer.ContainsKey(kv.Key)) ops.Add("D\t" + kv.Key);
            }

            _cache = next;
            _cacheSer = nextSer;
            if (ops.Count == 0) return;

            if (ops.Count > JOURNAL_BULK_LIMIT)
            {
                // Toplu islem (iceri aktar / geri yukle / degistir): hemen atomik snapshot
                WriteSnapshotAtomic(_cache);
                _snapshotDirty = false;
                try { if (File.Exists(JournalPath())) File.Delete(JournalPath()); } catch {}
                return;
            }

            // Tekil islem: ANINDA diske gunluk satiri, tam snapshot 300ms sonra
            try
            {
                File.AppendAllText(JournalPath(), string.Join("\n", ops.ToArray()) + "\n", new UTF8Encoding(false));
            }
            catch
            {
                WriteSnapshotAtomic(_cache);
                _snapshotDirty = false;
                return;
            }
            _snapshotDirty = true;
            ScheduleFlush();
        }

        private static void WriteSnapshotAtomic(List<Dictionary<string, object>> devices)
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

}
static class T {
  static int fails=0; static void Ok(bool c,string m){ Console.WriteLine((c?"PASS - ":"FAIL - ")+m); if(!c) fails++; }
  static Dictionary<string,object> R(int id,string model){ return new Dictionary<string,object>{{"id",id},{"model",model}}; }
  static string Fresh(){ var d=Path.Combine(Path.GetTempPath(),"kz"+Guid.NewGuid().ToString("N")); Directory.CreateDirectory(d); Program.Root=d; StandaloneServer.ResetMemory(); return d; }
  static int Main(){
    var d=Fresh(); var l=StandaloneServer.Load(); Ok(l.Count==1,"ilk acilis demo");
    l=StandaloneServer.Load(); l.Add(R(2,"a")); StandaloneServer.Save(l);
    Ok(File.Exists(d+"/veritabani.json.journal"),"tekil islem ANINDA gunluge yazildi");
    var snapBefore=File.ReadAllText(d+"/veritabani.json"); Ok(!snapBefore.Contains("\"a\""),"snapshot henuz yazilmadi (debounce)");
    // simule kill: bellegi at, diskten yeniden yukle (flush OLMADAN)
    StandaloneServer.ResetMemory(); l=StandaloneServer.Load(); Ok(l.Count==2,"kill sonrasi journal replay: kayit kaybolmadi");
    Thread.Sleep(700);
    // debounce flush
    l=StandaloneServer.Load(); l.Add(R(3,"b")); StandaloneServer.Save(l); Thread.Sleep(900);
    Ok(File.ReadAllText(d+"/veritabani.json").Contains("\"b\"")&&!File.Exists(d+"/veritabani.json.journal"),"300ms sonra snapshot yazildi, gunluk silindi");
    // duzenleme + silme + kill
    l=StandaloneServer.Load(); l[0]["model"]="EDIT"; l.RemoveAll(x=>Convert.ToString(x["id"])=="2"); StandaloneServer.Save(l);
    StandaloneServer.ResetMemory(); l=StandaloneServer.Load();
    Ok(l.Count==2&&l.Exists(x=>Convert.ToString(x["model"])=="EDIT")&&!l.Exists(x=>Convert.ToString(x["id"])=="2"),"duzenleme+silme kill sonrasi dogru");
    Thread.Sleep(700);
    // 100 ardisik kayit
    var sw=System.Diagnostics.Stopwatch.StartNew(); l=StandaloneServer.Load(); for(int i=0;i<5000;i++) l.Add(R(1000+i,"m"+i)); StandaloneServer.Save(l); Thread.Sleep(100);
    sw.Restart(); for(int i=0;i<100;i++){ var x=StandaloneServer.Load(); x.Add(R(9000+i,"n"+i)); StandaloneServer.Save(x);} sw.Stop();
    Ok(sw.ElapsedMilliseconds<3000,"5000 kayitta 100 ardisik kayit "+sw.ElapsedMilliseconds+" ms");
    StandaloneServer.ResetMemory(); l=StandaloneServer.Load(); Ok(l.Count>=5100,"toplu+ardisik sonrasi kill: tum kayitlar var ("+l.Count+")");
    Thread.Sleep(700);
    // bozuk json -> .bak
    d=Fresh(); l=StandaloneServer.Load(); l.Add(R(2,"x")); StandaloneServer.Save(l); Thread.Sleep(700); l=StandaloneServer.Load(); l.Add(R(3,"y")); StandaloneServer.Save(l); Thread.Sleep(700);
    File.WriteAllText(d+"/veritabani.json","{bozuk"); StandaloneServer.ResetMemory(); l=StandaloneServer.Load();
    Ok(l.Count>=2,"bozuk veritabani.json -> .bak kurtarma ("+l.Count+")"); Ok(StandaloneServer.LastRecoveryNote!=null,"kurtarma notu set");
    // bozuk json + bak yok -> yedekler
    d=Fresh(); Directory.CreateDirectory(d+"/yedekler"); File.WriteAllText(d+"/yedekler/b.json","[{\"id\":7,\"model\":\"yedek\"}]"); File.WriteAllText(d+"/veritabani.json","}}}");
    l=StandaloneServer.Load(); Ok(l.Count==1&&Convert.ToString(l[0]["model"])=="yedek","bozuk + .bak yok -> en yeni yedekten kurtarma");
    // yarim yazilmis journal satiri
    d=Fresh(); l=StandaloneServer.Load(); l.Add(R(5,"ok")); StandaloneServer.Save(l); File.AppendAllText(d+"/veritabani.json.journal","U\t{\"id\":6,\"mod"); StandaloneServer.ResetMemory(); l=StandaloneServer.Load();
    Ok(l.Exists(x=>Convert.ToString(x["id"])=="5"),"yarim yazilmis journal satiri yok sayildi, onceki kayitlar korundu");
    Console.WriteLine(fails==0?"ALL OK":fails+" FAIL"); return fails==0?0:1; }
}
