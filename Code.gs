var SHEET_NAME = 'devices';
var TZ = 'Europe/Istanbul';
var COLUMNS = ['id', 'type', 'status', 'brand', 'model', 'imei', 'serial_number', 'customer_name', 'customer_phone', 'operations_performed', 'notes', 'price', 'created_at', 'updated_at'];

function doGet() {
  return HtmlService.createHtmlOutputFromFile('index')
    .setTitle('Kuzgun İletişim CRM')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1.0')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.DEFAULT);
}

function auth_(pin) {
  var props = PropertiesService.getScriptProperties();
  var expected = props.getProperty('ACCESS_PIN');
  if (!expected) {
    expected = 'kuzgun2024';
    props.setProperty('ACCESS_PIN', expected);
  }
  if (String(pin || '') !== expected) {
    throw new Error('PIN_HATALI');
  }
}

function getSpreadsheet_() {
  var props = PropertiesService.getScriptProperties();
  var id = props.getProperty('SPREADSHEET_ID');
  if (id) {
    try {
      return SpreadsheetApp.openById(id);
    } catch (err) {
      props.deleteProperty('SPREADSHEET_ID');
    }
  }
  var active = null;
  try {
    active = SpreadsheetApp.getActiveSpreadsheet();
  } catch (err2) {}
  if (active) {
    props.setProperty('SPREADSHEET_ID', active.getId());
    return active;
  }
  var created = SpreadsheetApp.create('Kuzgun İletişim CRM Verileri');
  props.setProperty('SPREADSHEET_ID', created.getId());
  return created;
}

function getSheet_() {
  var ss = getSpreadsheet_();
  var sh = ss.getSheetByName(SHEET_NAME);
  if (!sh) {
    sh = ss.insertSheet(SHEET_NAME);
  }
  if (sh.getLastRow() === 0) {
    sh.getRange(1, 1, 1, COLUMNS.length).setValues([COLUMNS]);
    sh.setFrozenRows(1);
  }
  return sh;
}

function toObject_(row) {
  var obj = {};
  for (var i = 0; i < COLUMNS.length; i++) {
    obj[COLUMNS[i]] = row[i];
  }
  obj.id = String(obj.id);
  obj.type = String(obj.type || '');
  obj.status = String(obj.status || '');
  obj.brand = String(obj.brand || '');
  obj.model = String(obj.model || '');
  obj.imei = obj.imei === '' || obj.imei === null ? '' : String(obj.imei);
  obj.serial_number = obj.serial_number === '' || obj.serial_number === null ? '' : String(obj.serial_number);
  obj.customer_name = String(obj.customer_name || '');
  obj.customer_phone = obj.customer_phone === '' || obj.customer_phone === null ? '' : String(obj.customer_phone);
  obj.operations_performed = String(obj.operations_performed || '');
  obj.notes = String(obj.notes || '');
  obj.price = obj.price === '' || obj.price === null ? null : Number(obj.price);
  obj.created_at = Number(obj.created_at) || 0;
  obj.updated_at = Number(obj.updated_at) || 0;
  return obj;
}

function toRow_(device) {
  var row = [];
  for (var i = 0; i < COLUMNS.length; i++) {
    var v = device[COLUMNS[i]];
    row.push(v === undefined || v === null ? '' : v);
  }
  return row;
}

function readRows_() {
  var sh = getSheet_();
  var last = sh.getLastRow();
  if (last < 2) {
    return [];
  }
  var values = sh.getRange(2, 1, last - 1, COLUMNS.length).getValues();
  var out = [];
  for (var i = 0; i < values.length; i++) {
    if (values[i][0] === '' || values[i][0] === null) {
      continue;
    }
    var obj = toObject_(values[i]);
    obj._row = i + 2;
    out.push(obj);
  }
  return out;
}

function findRow_(rows, id) {
  for (var i = 0; i < rows.length; i++) {
    if (String(rows[i].id) === String(id)) {
      return i;
    }
  }
  return -1;
}

function listDevices(pin) {
  auth_(pin);
  var rows = readRows_();
  return rows.map(function (r) {
    delete r._row;
    return r;
  });
}

function upsertDevice(pin, device) {
  auth_(pin);
  if (!device || device.id === undefined || device.id === null || device.id === '') {
    throw new Error('GECERSIZ_KAYIT');
  }
  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    device.updated_at = Number(device.updated_at) || Date.now();
    if (!device.created_at) {
      device.created_at = device.updated_at;
    }
    var sh = getSheet_();
    var rows = readRows_();
    var idx = findRow_(rows, device.id);
    if (idx >= 0) {
      if (Number(rows[idx].updated_at || 0) > Number(device.updated_at || 0)) {
        var existing = rows[idx];
        delete existing._row;
        return { status: 'conflict', device: existing };
      }
      sh.getRange(rows[idx]._row, 1, 1, COLUMNS.length).setValues([toRow_(device)]);
    } else {
      sh.getRange(sh.getLastRow() + 1, 1, 1, COLUMNS.length).setValues([toRow_(device)]);
    }
    return { status: 'ok', device: device };
  } finally {
    lock.releaseLock();
  }
}

function deleteDevice(pin, id) {
  auth_(pin);
  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    var sh = getSheet_();
    var rows = readRows_();
    for (var i = rows.length - 1; i >= 0; i--) {
      if (String(rows[i].id) === String(id)) {
        sh.deleteRow(rows[i]._row);
      }
    }
    return { status: 'ok' };
  } finally {
    lock.releaseLock();
  }
}

function importDevices(pin, devices) {
  auth_(pin);
  if (!devices || !devices.length) {
    return { status: 'ok', imported: 0, total: readRows_().length };
  }
  var lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    var sh = getSheet_();
    var rows = readRows_();
    var updates = [];
    var appends = [];
    for (var i = 0; i < devices.length; i++) {
      var d = devices[i];
      if (!d || d.id === undefined || d.id === null || d.id === '') {
        continue;
      }
      d.updated_at = Number(d.updated_at) || Date.now();
      if (!d.created_at) {
        d.created_at = d.updated_at;
      }
      var idx = findRow_(rows, String(d.id));
      if (idx >= 0) {
        updates.push({ row: rows[idx]._row, data: toRow_(d) });
      } else {
        appends.push(toRow_(d));
      }
    }
    for (var j = 0; j < updates.length; j++) {
      sh.getRange(updates[j].row, 1, 1, COLUMNS.length).setValues([updates[j].data]);
    }
    if (appends.length) {
      sh.getRange(sh.getLastRow() + 1, 1, appends.length, COLUMNS.length).setValues(appends);
    }
    return { status: 'ok', imported: devices.length, updated: updates.length, added: appends.length };
  } finally {
    lock.releaseLock();
  }
}

function crmStatus(pin) {
  auth_(pin);
  var rows = readRows_();
  var ss = getSpreadsheet_();
  return {
    count: rows.length,
    spreadsheet: ss.getName(),
    url: ss.getUrl(),
    updated: rows.reduce(function (m, r) {
      return Math.max(m, Number(r.updated_at) || 0);
    }, 0)
  };
}

function changePin(pin, newPin) {
  auth_(pin);
  newPin = String(newPin || '');
  if (newPin.length < 4) {
    throw new Error('PIN_KISA');
  }
  PropertiesService.getScriptProperties().setProperty('ACCESS_PIN', newPin);
  return { status: 'ok' };
}

function backupToDrive(pin) {
  auth_(pin);
  return runBackup_();
}

function backupDaily() {
  return runBackup_();
}

function runBackup_() {
  var rows = readRows_();
  var data = rows.map(function (r) {
    delete r._row;
    return r;
  });
  var props = PropertiesService.getScriptProperties();
  var folder = null;
  var folderId = props.getProperty('BACKUP_FOLDER_ID');
  if (folderId) {
    try {
      folder = DriveApp.getFolderById(folderId);
    } catch (err) {
      folder = null;
    }
  }
  if (!folder) {
    folder = DriveApp.createFolder('Kuzgun CRM Yedekleri');
    props.setProperty('BACKUP_FOLDER_ID', folder.getId());
  }
  var day = Utilities.formatDate(new Date(), TZ, 'yyyy-MM-dd');
  var name = 'kuzgun-crm-' + day + '.json';
  var json = JSON.stringify({ exported_at: new Date().toISOString(), count: data.length, devices: data }, null, 2);
  var existing = folder.getFilesByName(name);
  if (existing.hasNext()) {
    existing.next().setContent(json);
  } else {
    folder.createFile(name, json);
  }
  var files = folder.getFiles();
  var olds = [];
  while (files.hasNext()) {
    var f = files.next();
    if (/^kuzgun-crm-\d{4}-\d{2}-\d{2}\.json$/.test(f.getName())) {
      olds.push(f);
    }
  }
  olds.sort(function (a, b) {
    return a.getName() < b.getName() ? -1 : 1;
  });
  for (var i = 0; i < olds.length - 30; i++) {
    olds[i].setTrashed(true);
  }
  return { status: 'ok', file: name, count: data.length, folder: folder.getName() };
}

function setupDailyBackup() {
  var triggers = ScriptApp.getProjectTriggers();
  for (var i = 0; i < triggers.length; i++) {
    if (triggers[i].getHandlerFunction() === 'backupDaily') {
      ScriptApp.deleteTrigger(triggers[i]);
    }
  }
  ScriptApp.newTrigger('backupDaily').timeBased().everyDays(1).atHour(3).create();
  return { status: 'ok' };
}
