# Project: Kuzgun İletişim CRM (v2.3.0 Complete Overhaul, GUI Installer & Legacy Migration)

## Architecture
Kuzgun İletişim CRM consists of three tightly integrated components:
1. **Cloud & Local Backend (`Code.gs` + `appsscript.json`)**:
   - Google Apps Script backend backed by Google Sheets (`Kuzgun İletişim CRM Verileri`, sheet `devices`) and Google Drive (`Kuzgun CRM Yedekleri`, automatic daily backups at 03:00 `Europe/Istanbul` + manual backups + pre-restore safety backups `kuzgun-crm-oncesi-...`, retaining up to 40 backups).
   - Dual-transport RPC: serves both `HtmlService` (`google.script.run` when opened in browser via `/exec`) and standalone desktop HTTP JSON RPC (`doPost(e)` accepting `text/plain;charset=utf-8` payload `{"fn": "...", "args": [...]}`).
   - `appsscript.json` deployed with `"access": "ANYONE_ANONYMOUS"` and `"executeAs": "USER_DEPLOYING"` so desktop `file://` and `--app` clients can call `doPost(e)` without CORS or Google login redirect errors, authenticated via `ACCESS_PIN`.
2. **Single-File SPA Frontend (`Kuzgun_Iletisim_CRM.html`)**:
   - Vue 3 + Tailwind CSS + FontAwesome single-file application (`index.html` in Apps Script, `Kuzgun_CRM.html` in `%LOCALAPPDATA%\KuzgunCRM`, and `Kuzgun_Iletisim_CRM.html` in project root).
   - Supports embedded cloud URL (`EMBED_URL`), embedded migrated legacy data (`EMBED_DEVICES`), local storage persistence (`kuzgun_crm_data_v2`), offline mutation queue (`kuzgun_crm_queue_v1`), local undo snapshots (`kuzgun_crm_snapshots_v1`), and automatic legacy `127.0.0.1` / `kuzgun_crm_data` migration.
   - Features First-Run Cloud & Google Account Setup Wizard, Instant Backup & Restore Center (local JSON, local snapshots, Google Drive cloud backups, smart merge vs full replace with accurate diff preview), Repair & Sale tracking with editable `datetime-local` (defaulting to today) and date range + quick filters (`ALL`, `TODAY`, `WEEK`, `MONTH`), Minecraft-style random Phone & Car Fun Fact splash widget on open/close/navigation, and clean application exit (`exitApplication`) without hanging or leaving zombie listeners.
3. **One-Click Native WinForms GUI Installer, Updater, Legacy Migrator & App Launcher (`exe/Program.cs` -> `KuzgunCRM_Kurulum.exe`, `Kurulum.ps1`, `exe/Uret-Exe.ps1`)**:
   - Compiled as a `.NET Framework 4.0` Windows executable (`KuzgunCRM_Kurulum.exe`) containing embedded resources (`Kurulum.ps1`, `Code.gs`, `Kuzgun_Iletisim_CRM.html`, `appsscript.json`, `README.md`).
   - Provides a full **Windows Forms GUI Wizard** when launched interactively (while hiding console window via `ShowWindow(GetConsoleWindow(), SW_HIDE)` and preserving headless CLI modes `-Test`, `-Hazirlik`, `-Bilgi`, `-Manuel`, `-Sessiz`, `-Baslat`).
   - Automatically detects previous installations (both v2.x cloud configs and legacy v1.x/v2.0 `127.0.0.1` servers, desktop/startup shortcuts, `C:\ozi`, `%LOCALAPPDATA%`, `%APPDATA%`, JSON/SQLite/CSV/LevelDB stores), migrates all legacy records into `migrated_devices.json` and embeds them into `Kuzgun_CRM.html` + `Kuzgun_Iletisim_CRM.html`, cleanly kills stuck `127.0.0.1` processes and startup entries, isolates `clasp` in `%LOCALAPPDATA%\KuzgunCRM\araclar` with `.claspignore` in `proje`, creates Desktop shortcuts (`Desktop` + `Masaüstü` + `CommonDesktopDirectory`) launching in standalone `--app` window mode, and terminates its entire child process tree (`taskkill /F /T`) on exit so it never freezes.

## Feature Inventory
Every feature from the Survey phase and `ORIGINAL_REQUEST.md` is catalogued below and assigned to a milestone:

| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| F1 | `doPost` Complete RPC Dispatch (`setupDailyBackup` & all endpoints) | Expose all backend RPC functions in `Code.gs` `API_FUNCS_` including `setupDailyBackup(pin)`, `crmStatus`, `syncGoogleAccount`, `listDevices`, `upsertDevice`, `deleteDevice`, `importDevices`, `replaceAllDevices`, `changePin`, `backupToDrive`, `listDriveBackups`, `getDriveBackup`, `deleteDriveBackup`, `restoreFromDriveBackup` with PIN auth. | M1 | survey / request #1, #5 |
| F2 | Formula Injection Protection & Safe Sheet Serialization | Escape leading `=`, `+`, `-`, `@` in `Code.gs` `toRow_()` and strip leading escape apostrophe on read in `toObject_()` so phone numbers (`+90...`) and notes (`- ...`) never break Google Sheets as `#ERROR!`. | M1 | survey / request #4 |
| F3 | Universal Pre-Restore Safety Backups & Legacy Schema Normalization in Backend | Ensure `replaceAllDevices(pin, devices, safety)` and `restoreFromDriveBackup(pin, fileId, mode, safety)` create a `kuzgun-crm-oncesi-...` Drive safety backup whenever `safety !== false` (both `replace` and `merge`), and normalize legacy Turkish/v1 field names in `parseBackup_()` / `importDevices()`. | M1 | survey / request #1, #4 |
| F4 | Anonymous WebApp Access (`ANYONE_ANONYMOUS`) for `file://` CORS Compatibility | Configure `appsscript.json` and `Kurulum.ps1` with `"access": "ANYONE_ANONYMOUS"` so desktop `file://` / `--app` `fetch()` POST calls to `doPost` succeed without Google login HTML redirect failures. | M1 | survey / request #3, #5 |
| F5 | First-Run Setup Wizard, Auto-Binding & Elimination of `NO_BACKEND` | Guided First-Run Cloud & Google Account Wizard (`showSetup`), prominent Cloud Connect CTA in Backup Center when unconnected, guard `installBackup()` against raw `NO_BACKEND`, support `EMBED_URL` + `EMBED_DEVICES` + automatic local `127.0.0.1` probe from browser on first run. | M2 | survey / request #3, #5 |
| F6 | Local/Offline/Legacy Data Preservation & Smart Cloud Sync (No Demo Overwrite) | Prevent demo devices (`id: 1, 2`) from overwriting user data or polluting cloud sheets; queue offline changes even when `isCloud && !authed` (`offlineContinue`); merge unsynced local non-demo devices into cloud on `pull()` instead of blindly overwriting `this.devices = remote`. | M2 | survey / request #1, #3, #4 |
| F7 | Instant Backup, Instant Restore & Cloud Backup Center Fixes | Fix `confirmRestore()` computed `restoreStats` mutation order bug so added/updated counts are accurate; pass `safety` flag to `replaceAllDevices`/`importDevices`; support importing legacy v1/v2 JSON/CSV schemas (`marka`, `musteri_adi`, `telefon`, `seri_no`, `durum`, `fiyat`, `notlar`, `tarih`, `sifre`) with deterministic ID generation. | M2 | survey / request #1, #4 |
| F8 | Device Date Picker (Default Today, Editable) & Date Range / Quick Search | Default new device `created_at_str` to current local date/time (`YYYY-MM-DDTHH:mm`), allow editing, fix `matchesDate` end-of-day boundary (`T23:59:59.999`), reset `dateFilterQuick` to `'CUSTOM'` when user manually edits start/end dates, and support optional customer name/phone on `SALE` records & search. | M2 | survey / request #1, #4 |
| F9 | Minecraft-Style Phone & Car Fun Fact Splash Widget on Open & Close | Display random phone & car fun facts (`FUN_FACTS`) with splash styling on app open, tab/modal transitions, and rotate to a fresh fact (`nextFunFact()`) when closing the application (`exitApplication`). | M2 | survey / request #2 |
| F10 | Clean Application Close (`exitApplication`) Without Freezing or Zombie Listeners | Flush pending local/cloud state, detach `window` `focus`/`online` listeners, clear timers, rotate fun fact, attempt `window.close()` (works in `--app` mode) + notify optional local launcher shutdown endpoint, and transition cleanly to a reactive Vue closed state (`isClosed = true`) with "Yeniden Aç" button. | M2 | survey / request #1, #2 |
| F11 | One-Click Native WinForms GUI Installer & Launcher (`KuzgunCRM_Kurulum.exe`) | Upgrade `exe/Program.cs` from console-only wrapper to a full `.NET Framework 4.0` WinForms GUI Wizard (hiding console in GUI mode, supporting CLI flags `-Test`, `-Hazirlik`, `-Bilgi`, `-Manuel`, `-Sessiz`, `-Baslat`), live progress bar, step indicators, async process execution, `taskkill /F /T` tree cleanup on close, and `--Baslat` (`--app`) launcher mode. | M3 | survey / request #1, #3, #5 |
| F12 | Legacy Version (`127.0.0.1` / v1.x / v2.0) Detection, Data Migration & Shortcut Replacement (`Kurulum.ps1`) | Detect active `127.0.0.1` servers, shortcuts, and legacy folders (`C:\ozi`, `%LOCALAPPDATA%`, `%APPDATA%`, Desktop/`Masaüstü`, Chrome/Edge LevelDB), extract and normalize legacy data into `migrated_devices.json` and `EMBED_DEVICES` in both `Kuzgun_CRM.html` and `Kuzgun_Iletisim_CRM.html`, isolate `clasp` into `araclar/` with `.claspignore`, kill legacy processes/autostarts, and create Desktop shortcuts (`Masaüstü`/`Desktop`/`Public Desktop`) that launch the new version cleanly. | M3 | survey / request #1, #3, #5 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Backend & Cloud RPC Overhaul (`Code.gs`, `appsscript.json`) | Features F1, F2, F3, F4 (`Code.gs`, `appsscript.json`) | none | PLANNED |
| M2 | CRM SPA Overhaul: Setup Wizard, Backup/Restore, Legacy Migration, Dates, Fun Facts & Clean Exit (`Kuzgun_Iletisim_CRM.html`) | Features F5, F6, F7, F8, F9, F10 (`Kuzgun_Iletisim_CRM.html`) | M1 contract | PLANNED |
| M3 | One-Click WinForms GUI Installer, Legacy `127.0.0.1` Migrator & Exe Build (`exe/Program.cs`, `Kurulum.ps1`, `exe/Uret-Exe.ps1`, `KuzgunCRM_Kurulum.exe`, `README.md`) | Features F11, F12 (`exe/Program.cs`, `Kurulum.ps1`, `exe/Uret-Exe.ps1`, `KuzgunCRM_Kurulum.exe`, `README.md`) | M1, M2 | PLANNED |
| M4 | Final Milestone: 100% E2E Test Suite Pass (Tiers 1–4) & Tier 5 Adversarial Coverage Hardening + Git Sync | Pass all E2E tests (Tiers 1–4), run Tier 5 white-box adversarial hardening, verify git status & remotes (`origin` and `v22`). | M1, M2, M3, E2E Track | PLANNED |

## Interface Contracts

### M1 (`Code.gs` / `appsscript.json`) ↔ M2 (`Kuzgun_Iletisim_CRM.html`)
- **`doPost(e)` RPC Contract**:
  - Request: HTTP POST with body `JSON.stringify({ fn: string, args: Array })`
  - Allowed `API_FUNCS_` in `Code.gs`:
    - `crmStatus(pin)` -> `{ count, spreadsheet, spreadsheetId, url, dailyBackupActive, accountEmail, activeUserEmail, version: '2.3.0', updated }`
    - `syncGoogleAccount(pin)` -> alias to `crmStatus(pin)`
    - `listDevices(pin)` -> `Array<Device>`
    - `upsertDevice(pin, device)` -> `{ status: 'ok' | 'conflict', device }`
    - `deleteDevice(pin, id)` -> `{ status: 'ok', deleted: number }`
    - `importDevices(pin, devices, safety)` -> `{ status: 'ok', imported, updated, added, safetyBackup?: object }` (normalizes legacy fields if present; creates safety backup `kuzgun-crm-oncesi-...` when `safety === true`)
    - `replaceAllDevices(pin, devices, safety)` -> `{ status: 'ok', replaced: number, safetyBackup?: object }` (creates safety backup `kuzgun-crm-oncesi-...` when `safety !== false`)
    - `changePin(pin, newPin)` -> `{ status: 'ok' }`
    - `backupToDrive(pin)` -> `{ id, name, url, count, size, created }`
    - `listDriveBackups(pin)` -> `{ folderName, folderUrl, keep, backups: Array<BackupMeta> }`
    - `getDriveBackup(pin, fileId)` -> `{ name, count, devices: Array<Device> }`
    - `deleteDriveBackup(pin, fileId)` -> `{ deleted: true, id }`
    - `restoreFromDriveBackup(pin, fileId, mode, safety)` -> `{ mode, count, restored, added, updated }` (creates safety backup when `safety !== false` for both `'replace'` and `'merge'` modes)
    - `setupDailyBackup(pin)` -> `{ status: 'ok', message: string, dailyBackupActive: true }` (validates `auth_(pin)` if `pin` is provided)
- **Formula Escaping Contract (`Code.gs`)**:
  - `toRow_(device)` prefixes any string value matching `/^[=+\-@]/` with `'` so Google Sheets stores literal text (e.g. `'+90532...`, `'- ekran kırık`), and `toObject_(row)` strips a leading `'` if followed by `[=+\-@]` when Google Sheets returns it.

### M2 (`Kuzgun_Iletisim_CRM.html`) ↔ M3 (`Kurulum.ps1` / `exe/Program.cs`)
- **Embedded Configuration & Migration Constants in `Kuzgun_Iletisim_CRM.html`**:
  - `const EMBED_URL = '';` — replaced by `Kurulum.ps1` / installer with `'https://script.google.com/macros/s/.../exec'` in both `%LOCALAPPDATA%\KuzgunCRM\Kuzgun_CRM.html` and the source `Kuzgun_Iletisim_CRM.html` copy (when deployed on user machine).
  - `const EMBED_DEVICES = [];` — replaced by `Kurulum.ps1` / installer with migrated legacy records JSON array `[...]` if legacy data was discovered during installation/update.
  - On startup, `Kuzgun_Iletisim_CRM.html` merges any records in `EMBED_DEVICES` (and any records found in `localStorage['kuzgun_crm_data']` or probed from `http://127.0.0.1` ports if running locally) into `localStorage['kuzgun_crm_data_v2']` using `normalizeDevices()` and marks them for cloud sync (`importDevices`) so zero legacy records are ever lost.

## Code Layout
- `/home/antigravity/ziyarduc/kuzgun-iletisim-crm/Code.gs` — Google Apps Script backend (owned by M1)
- `/home/antigravity/ziyarduc/kuzgun-iletisim-crm/appsscript.json` — Google Apps Script manifest (owned by M1)
- `/home/antigravity/ziyarduc/kuzgun-iletisim-crm/Kuzgun_Iletisim_CRM.html` — Single-file Vue 3 CRM SPA (owned by M2)
- `/home/antigravity/ziyarduc/kuzgun-iletisim-crm/Kurulum.ps1` — PowerShell installer, updater & legacy migrator (owned by M3)
- `/home/antigravity/ziyarduc/kuzgun-iletisim-crm/exe/Program.cs` — C# WinForms GUI installer & launcher source (owned by M3)
- `/home/antigravity/ziyarduc/kuzgun-iletisim-crm/exe/Uret-Exe.ps1` — Build script for `KuzgunCRM_Kurulum.exe` (owned by M3)
- `/home/antigravity/ziyarduc/kuzgun-iletisim-crm/KuzgunCRM_Kurulum.exe` — Compiled Windows GUI installer & launcher binary (owned by M3)
- `/home/antigravity/ziyarduc/kuzgun-iletisim-crm/README.md` — Documentation (owned by M3)
- `/home/antigravity/ziyarduc/kuzgun-iletisim-crm/tests/` — Automated E2E test suite (owned by E2E Testing Track & M4)
