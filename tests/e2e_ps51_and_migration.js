const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = path.join(__dirname, '..');
let fails = 0;
const ok = (cond, msg) => {
    console.log((cond ? 'PASS' : 'FAIL') + ' - ' + msg);
    if (!cond) fails++;
};

console.log('=== TEST SUITE: Zero-Dep PowerShell 5.1 Syntax, BOM, Parity & Real VM Multi-Envelope Migration ===\n');

// =========================================================================
// 1. Kurulum.ps1: UTF-8 BOM (0xEF, 0xBB, 0xBF) and Pure ASCII Body
// =========================================================================
const ps1Raw = fs.readFileSync(path.join(ROOT, 'Kurulum.ps1'));
ok(ps1Raw.length >= 3 && ps1Raw[0] === 0xEF && ps1Raw[1] === 0xBB && ps1Raw[2] === 0xBF,
    'Kurulum.ps1 starts with UTF-8 BOM (0xEF, 0xBB, 0xBF)');

const ps1Body = ps1Raw.slice(3);
const nonAscii = [];
for (let i = 0; i < ps1Body.length; i++) {
    if (ps1Body[i] >= 128) nonAscii.push({ offset: i, byte: ps1Body[i] });
}
ok(nonAscii.length === 0, 'Kurulum.ps1 body contains ZERO non-ASCII bytes (count: ' + nonAscii.length + ')');

const ps1Text = ps1Body.toString('utf-8');

// =========================================================================
// 2. Structural PowerShell Lexer & Control Flow Parser
// =========================================================================
function analyzePowerShell(src) {
    const controlFlowErrors = [];
    const bracketStack = [];
    const bracketErrors = [];
    let i = 0;
    const n = src.length;
    let inSingle = false, inDouble = false, inComment = false;

    function lineOf(idx) { return src.slice(0, idx).split('\n').length; }

    while (i < n) {
        const ch = src[i];
        const next = i + 1 < n ? src[i + 1] : '';
        const prev = i > 0 ? src[i - 1] : '';

        if (ch === '\n') { inComment = false; i++; continue; }
        if (inComment) { i++; continue; }
        if (!inSingle && !inDouble && ch === '#') { inComment = true; i++; continue; }

        // Single quote literal
        if (!inDouble && ch === "'") {
            if (!inSingle) inSingle = true;
            else if (next === "'") { i++; } // escaped ''
            else inSingle = false;
            i++;
            continue;
        }

        // Double quote literal
        if (!inSingle && ch === '"') {
            if (!inDouble) inDouble = true;
            else if (prev === '`') {} // escaped `"
            else if (next === '"') { i++; } // escaped ""
            else inDouble = false;
            i++;
            continue;
        }

        if (inSingle || inDouble) { i++; continue; }

        // Subexpression $(
        if (ch === '$' && next === '(') {
            bracketStack.push({ type: '$(', idx: i, line: lineOf(i) });
            i += 2;
            continue;
        }

        // Brackets
        if (ch === '(' || ch === '{' || ch === '[') {
            bracketStack.push({ type: ch, idx: i, line: lineOf(i) });
            i++;
            continue;
        }

        if (ch === ')' || ch === '}' || ch === ']') {
            if (bracketStack.length === 0) {
                bracketErrors.push({ type: 'unexpected_close', found: ch, line: lineOf(i) });
            } else {
                const top = bracketStack.pop();
                const expected = (top.type === '$(' || top.type === '(') ? ')' : (top.type === '{' ? '}' : ']');
                if (ch !== expected) {
                    bracketErrors.push({ type: 'mismatched', found: ch, expected, openedAt: top.line, line: lineOf(i) });
                }
            }
            i++;
            continue;
        }

        // Control flow: if / elseif / while
        const sub = src.slice(i);
        const cfMatch = sub.match(/^(?:if|elseif|while)\b/i);
        if (cfMatch) {
            const kw = cfMatch[0];
            const kwIdx = i;
            const kwLine = lineOf(i);
            i += kw.length;
            while (i < n && /\s/.test(src[i])) i++;
            if (src[i] === '(') {
                let depth = 1;
                i++;
                let innerSingle = false, innerDouble = false, innerComment = false;
                while (i < n && depth > 0) {
                    const c = src[i];
                    const nxt = i + 1 < n ? src[i + 1] : '';
                    const prv = i > 0 ? src[i - 1] : '';
                    if (c === '\n') { innerComment = false; i++; continue; }
                    if (innerComment) { i++; continue; }
                    if (!innerSingle && !innerDouble && c === '#') { innerComment = true; i++; continue; }
                    if (!innerDouble && c === "'") {
                        if (!innerSingle) innerSingle = true;
                        else if (nxt === "'") i++;
                        else innerSingle = false;
                        i++; continue;
                    }
                    if (!innerSingle && c === '"') {
                        if (!innerDouble) innerDouble = true;
                        else if (prv === '`') {}
                        else if (nxt === '"') i++;
                        else innerDouble = false;
                        i++; continue;
                    }
                    if (innerSingle || innerDouble) { i++; continue; }
                    if (c === '(') depth++;
                    else if (c === ')') depth--;
                    i++;
                }

                // Skip whitespace & comments after condition closing paren
                while (i < n && (/\s/.test(src[i]) || src[i] === '#')) {
                    if (src[i] === '#') {
                        while (i < n && src[i] !== '\n') i++;
                    } else {
                        i++;
                    }
                }

                if (src[i] !== '{') {
                    const tokenAfter = src.slice(i, i + 20).trim().split(/\s+/)[0];
                    controlFlowErrors.push({
                        kw,
                        line: kwLine,
                        found: tokenAfter,
                        context: src.slice(kwIdx, Math.min(n, i + 35)).replace(/\n/g, ' ')
                    });
                }
                continue;
            }
        }

        i++;
    }

    return {
        bracketErrors,
        unclosedBrackets: bracketStack,
        controlFlowErrors,
        isQuotesBalanced: !inSingle && !inDouble
    };
}

const analysis = analyzePowerShell(ps1Text);
ok(analysis.isQuotesBalanced, 'PowerShell parser: all quote literals balanced');
ok(analysis.controlFlowErrors.length === 0,
    'PowerShell control flow: all if/elseif/while conditions followed immediately by statement block { (no dangling -and/-or; errors: ' + JSON.stringify(analysis.controlFlowErrors) + ')');
ok(analysis.bracketErrors.length === 0 && analysis.unclosedBrackets.length === 0,
    'PowerShell bracket nesting: all (), {}, [], and $() subexpressions properly matched and closed (stack errors: ' + JSON.stringify(analysis.bracketErrors) + ')');

// Check LHS [string] on [char]0x...
const lines = ps1Text.split('\n');
const bareCharOnLhs = [];
lines.forEach((line, idx) => {
    // A bare [char] on LHS of + is not preceded by [string] or string operand like '...' +
    // i.e. ([char]0x... + ...) or (^[char]0x... + ...)
    if (/(?:^|[^\w'"])(?<!\[string\])\[char\]0x[0-9a-fA-F]+\s*\+\s*['"]/.test(line)) {
        bareCharOnLhs.push({ line: idx + 1, text: line.trim() });
    }
});
ok(bareCharOnLhs.length === 0,
    'Zero occurrences of bare [char]0x... on LHS of + without [string] cast (found: ' + JSON.stringify(bareCharOnLhs) + ')');

// Check ArrayList + ArrayList direct addition
const badArrayListAdds = lines.filter(l =>
    /(\$(?:canliVeriler|dosyaVerileri|mevcutMigVerileri|bulunanlar|kayitlar))\s*\+\s*(\$)/.test(l) &&
    !l.includes('@(')
);
ok(badArrayListAdds.length === 0,
    'Zero direct "+" operations between ArrayList variables without @() array coercion');

// Check ConvertTo-Json preserves 1-element arrays in PS 5.1
const devJsonPipedWithoutInputObject = lines.filter(l =>
    l.includes('ConvertTo-Json') &&
    (l.includes('$migObj') || l.includes('$cihazlar') || l.includes('$siraliListe') || l.includes('$testDevList')) &&
    l.includes('|') && !l.includes('-InputObject')
);
ok(devJsonPipedWithoutInputObject.length === 0,
    'Device JSON serialization uses ConvertTo-Json -InputObject @(...) to preserve single-item arrays in PS 5.1');

// Check no Get-Random in deterministic ID generation
const getRandomInId = lines.filter(l => l.includes('Get-Random') && !l.includes('FUN_FACT'));
ok(getRandomInId.length === 0,
    'Zero Get-Random calls in deterministic ID generation or migration pipelines');

// Check no $var: drive-qualified parser traps inside expandable double-quoted strings
const validScopes = new Set(['env', 'script', 'global', 'local', 'private', 'using', 'variable']);
const invalidDriveRefs = [];
{
    let ii = 0, nn = ps1Text.length, sq = false, dq = false, cm = false, ln = 1, dqBuf = '', dqLn = 1;
    while (ii < nn) {
        const ch = ps1Text[ii], nxt = ps1Text[ii + 1] || '', prv = ps1Text[ii - 1] || '';
        if (ch === '\n') { ln++; cm = false; ii++; continue; }
        if (cm) { ii++; continue; }
        if (!sq && !dq && ch === '#') { cm = true; ii++; continue; }
        if (!sq && !dq && ch === '@' && nxt === "'") {
            const endHs = ps1Text.indexOf("\n'@", ii);
            if (endHs !== -1) { ln += ps1Text.slice(ii, endHs + 3).split('\n').length - 1; ii = endHs + 3; continue; }
        }
        if (!dq && ch === "'") {
            if (!sq) sq = true;
            else if (nxt === "'") ii++;
            else sq = false;
            ii++; continue;
        }
        if (!sq && ch === '"') {
            if (!dq) { dq = true; dqBuf = ''; dqLn = ln; }
            else if (prv === '`') dqBuf += ch;
            else if (nxt === '"') { dqBuf += ch; ii++; }
            else {
                for (const m of dqBuf.matchAll(/(?<!`)\$([A-Za-z_][A-Za-z0-9_]*):(.?)/g)) {
                    const vr = m[1].toLowerCase(), af = m[2];
                    if (!validScopes.has(vr) || !/[A-Za-z0-9_]/.test(af)) {
                        invalidDriveRefs.push({ line: dqLn, ref: '$' + m[1] + ':' + af });
                    }
                }
                dq = false;
            }
            ii++; continue;
        }
        if (dq) dqBuf += ch;
        ii++;
    }
}
ok(invalidDriveRefs.length === 0,
    'Zero InvalidVariableReferenceWithDrive ($var:) patterns in expandable strings (found: ' + JSON.stringify(invalidDriveRefs) + ')');

// Check byte-for-byte embedded resource match in KuzgunCRM_Kurulum.exe
const exePath = path.join(ROOT, 'KuzgunCRM_Kurulum.exe');
const exeBuf = fs.readFileSync(exePath);
const ps1LenBytes = Buffer.alloc(4);
ps1LenBytes.writeUInt32LE(ps1Raw.length, 0);
const needle = Buffer.concat([ps1LenBytes, ps1Raw]);
const exeOffset = exeBuf.indexOf(needle);
ok(exeOffset > 0,
    'KuzgunCRM_Kurulum.exe embedded payload.Kurulum.ps1 matches Kurulum.ps1 on disk byte-for-byte at offset ' + exeOffset);

// Check function ordering and safe properties
const masaDefPos = ps1Text.indexOf('function MasaustuKlasorleri {');
const eskiTaraPos = ps1Text.indexOf('function EskiDosyalariTara {');
ok(masaDefPos !== -1 && eskiTaraPos !== -1 && masaDefPos < eskiTaraPos,
    'function MasaustuKlasorleri is defined before function EskiDosyalariTara');

// =========================================================================
// 3. Real Code.gs & Kuzgun_Iletisim_CRM.html Execution via Node vm Module
// =========================================================================

// 3.1 Setup Real Code.gs Context
const codeGsRaw = fs.readFileSync(path.join(ROOT, 'Code.gs'), 'utf8');
const gasRows = [];
const scriptProperties = { ACCESS_PIN: 'kuzgun2024' };
const mockSheet = {
    getLastRow: () => gasRows.length + 1,
    getRange: (r, c, nr, nc) => ({
        setValues: (vals) => {
            for (let i = 0; i < vals.length; i++) {
                gasRows[r - 2 + i] = vals[i];
            }
        }
    }),
    setFrozenRows: () => {}
};
const gasCtx = {
    console, JSON, Date, Math, String, Number, Array, Object, Error, RegExp,
    COLUMNS: ['id', 'type', 'status', 'brand', 'model', 'imei', 'serial_number', 'customer_name', 'customer_phone', 'operations_performed', 'notes', 'price', 'created_at', 'updated_at'],
    PropertiesService: {
        getScriptProperties: () => ({
            getProperty: (k) => scriptProperties[k] ?? null,
            setProperty: (k, v) => { scriptProperties[k] = String(v); },
            deleteProperty: (k) => { delete scriptProperties[k]; }
        })
    },
    LockService: {
        getScriptLock: () => ({
            waitLock: () => {},
            releaseLock: () => {}
        })
    },
    SpreadsheetApp: {
        openById: () => ({
            getSheetByName: () => mockSheet,
            insertSheet: () => mockSheet,
            getId: () => 'MOCK_SSID',
            getName: () => 'Kuzgun CRM',
            getUrl: () => 'https://mock.sheet.url'
        }),
        create: () => ({
            getSheetByName: () => mockSheet,
            insertSheet: () => mockSheet,
            getId: () => 'MOCK_SSID',
            getName: () => 'Kuzgun CRM',
            getUrl: () => 'https://mock.sheet.url'
        })
    },
    readRows_: () => gasRows.map((r, i) => {
        const obj = gasCtx.toObject_(r);
        obj._row = i + 2;
        return obj;
    }),
    findRow_: (rows, id) => rows.findIndex(r => String(r.id) === String(id)),
    runBackup_: () => ({ file: 'safety.json', fileId: 'FID_SAFE', count: gasRows.length }),
    auth_: () => true
};
vm.createContext(gasCtx);
vm.runInContext(codeGsRaw, gasCtx);

// 3.2 Setup Real Kuzgun_Iletisim_CRM.html Context
const htmlRaw = fs.readFileSync(path.join(ROOT, 'Kuzgun_Iletisim_CRM.html'), 'utf8');
let vueAppDefinition = null;
const htmlCtx = {
    window: {},
    document: { addEventListener: () => {} },
    localStorage: {
        _data: {},
        getItem(k) { return this._data[k] ?? null; },
        setItem(k, v) { this._data[k] = String(v); },
        removeItem(k) { delete this._data[k]; }
    },
    Vue: { createApp: (def) => { vueAppDefinition = def; return { mount: () => {} }; } },
    createApp: (def) => { vueAppDefinition = def; return { mount: () => {} }; },
    console, JSON, Date, Math, String, Number, Array, Object, Error, RegExp,
    URL: { createObjectURL: () => '', revokeObjectURL: () => {} },
    FileReader: class {},
    setTimeout: () => {},
    clearTimeout: () => {},
    setInterval: () => {},
    clearInterval: () => {}
};
vm.createContext(htmlCtx);
const scrMatch = htmlRaw.match(/<script>([\s\S]*?)<\/script>/i);
if (!scrMatch) throw new Error('Could not find script block in Kuzgun_Iletisim_CRM.html');
vm.runInContext(scrMatch[1], htmlCtx);

// Extract real unpackEnvelope function from production script
const unpackMatch = scrMatch[1].match(/const unpackEnvelope = \(([^)]*)\)\s*=>\s*\{([\s\S]*?)\n\s*\};/);
const htmlUnpackEnvelope = new Function('parsed', unpackMatch[2]);
const htmlNormalizeDevices = vueAppDefinition.methods.normalizeDevices;

// =========================================================================
// 4. Multi-Envelope Verification Against Real Implementations
// =========================================================================
const envelopes = [
    { name: 'Plain Array', data: [{ id: 101, brand: 'Apple', model: 'iPhone 13' }] },
    { name: '.devices Array', data: { devices: [{ id: 102, brand: 'Samsung', model: 'S22' }] } },
    { name: '.data Array', data: { data: [{ id: 103, brand: 'Xiaomi', model: '12T' }] } },
    { name: '.records Array', data: { records: [{ id: 104, brand: 'Huawei', model: 'P40' }] } },
    { name: '.items Array', data: { items: [{ id: 105, brand: 'OnePlus', model: '10 Pro' }] } },
    { name: '.backup.devices Array', data: { backup: { devices: [{ id: 106, brand: 'Sony', model: 'Xperia 1' }] } } },
    { name: 'Single Device Object', data: { id: 107, brand: 'Google', model: 'Pixel 7', musteri_adi: 'Ahmet' } }
];

envelopes.forEach(env => {
    // 1. Real Code.gs parseBackup_
    const mockFile = { getBlob: () => ({ getDataAsString: () => JSON.stringify(env.data) }) };
    const gasOut = gasCtx.parseBackup_(mockFile);
    ok(Array.isArray(gasOut) && gasOut.length === 1 && gasOut[0].brand,
        '[Real Code.gs parseBackup_] Successfully parsed envelope: ' + env.name);

    // 2. Real HTML unpackEnvelope + normalizeDevices
    const htmlUnpacked = htmlUnpackEnvelope(env.data);
    const htmlNorm = htmlNormalizeDevices(htmlUnpacked);
    ok(Array.isArray(htmlNorm) && htmlNorm.length === 1 && htmlNorm[0].brand,
        '[Real HTML unpackEnvelope & normalizeDevices] Successfully parsed envelope: ' + env.name);
});

// =========================================================================
// 5. Verification of REPRO 1 – REPRO 5 Edge Cases Against Real Code
// =========================================================================

// REPRO 1: Records missing explicit ID must receive deterministic fallback ID
const noIdRecord = { musteri_adi: 'Ali Yılmaz', musteri_tel: '05551234567', marka: 'Samsung', model: 'S20', fiyat: '1.450,50 ₺' };
const normGasNoId = gasCtx.normalizeDevice_(noIdRecord);
ok(normGasNoId && normGasNoId.id && String(normGasNoId.id).length > 0 && normGasNoId.customer_name === 'Ali Yılmaz',
    '[Real Code.gs] Record without ID receives deterministic fallback ID: ' + (normGasNoId && normGasNoId.id));

const normHtmlNoId = htmlNormalizeDevices([noIdRecord]);
ok(normHtmlNoId.length === 1 && normHtmlNoId[0].id && String(normHtmlNoId[0].id).length > 0 && normHtmlNoId[0].customer_name === 'Ali Yılmaz',
    '[Real HTML] Record without ID receives deterministic fallback ID: ' + (normHtmlNoId[0] && normHtmlNoId[0].id));

// REPRO 2: Turkish tur 'satış'/'alım' and status infer SALE; id: 0 preserved
const satisRecord = { id: 201, tur: 'satış', durum: 'satılık', fiyat: '1.250 TL' };
const alimRecord = { id: 202, tur: 'alım', durum: 'stokta' };
const zeroRecord = { id: 0, brand: 'Nokia', model: '3310' };

const gasSatis = gasCtx.normalizeDevice_(satisRecord);
const gasAlim = gasCtx.normalizeDevice_(alimRecord);
const gasZero = gasCtx.normalizeDevice_(zeroRecord);
ok(gasSatis.type === 'SALE' && gasAlim.type === 'SALE',
    '[Real Code.gs] Turkish "satış" and "alım" normalize to type SALE');
ok(String(gasZero.id) === '0',
    '[Real Code.gs] id: 0 is strictly preserved and not converted to empty string');

const htmlZero = htmlNormalizeDevices([zeroRecord]);
ok(htmlZero.length === 1 && String(htmlZero[0].id) === '0',
    '[Real HTML] id: 0 is strictly preserved and not dropped');

// REPRO 3: Code.gs importDevices intra-batch deduplication
gasRows.length = 0; // reset mock sheet
const duplicateBatch = [
    { id: 501, brand: 'First', model: 'One' },
    { id: 501, brand: 'Second', model: 'Two' }
];
gasCtx.importDevices('kuzgun2024', duplicateBatch, false);
ok(gasRows.length === 1,
    '[Real Code.gs importDevices] Duplicate IDs within single batch deduplicated (rows: ' + gasRows.length + ', expected: 1)');

// REPRO 4: HTML loadLocal single-object EMBED_DEVICES preservation
const singleEmbedObj = { id: 99, brand: 'Samsung', model: 'A54' };
const unpackedEmbed = htmlUnpackEnvelope(singleEmbedObj);
ok(unpackedEmbed.length === 1 && unpackedEmbed[0].brand === 'Samsung',
    '[Real HTML unpackEnvelope] Single object from PS 5.1 ConvertTo-Json successfully unpacked as 1-element array');

// REPRO 5: Whitespace-only id rejected from becoming 0
const wsRecord = { id: '   ', brand: 'Apple', model: 'iPhone 12' };
const wsNorm = htmlNormalizeDevices([wsRecord]);
ok(wsNorm.length === 1 && String(wsNorm[0].id).trim() !== '' && wsNorm[0].id !== 0,
    '[Real HTML] Whitespace-only ID is assigned deterministic fallback ID, NOT 0 (id: ' + (wsNorm[0] && wsNorm[0].id) + ')');

console.log('\n------------------------------------------------');
if (fails === 0) {
    console.log('ALL PS5.1, BOM, PARITY & REAL MIGRATION TESTS PASSED (100% OK)');
    process.exit(0);
} else {
    console.log('FAILED ' + fails + ' TESTS');
    process.exit(1);
}
