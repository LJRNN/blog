// nan-dl.js  -  nan download poller for Windows
// pure JScript (no powershell / no python / no node): double click  start-nan-dl.bat
var ROOT = 'C:\\nan';
// D drive folder name built from code points so this file stays pure ASCII
var SYNC = 'D:\\' + String.fromCharCode(0x8054, 0x901A, 0x7F51, 0x76D8, 0x540C, 0x6B65);
var OUT_DIR = SYNC;
var SEEN = ROOT + '\\dl_seen.json';
var LOG = ROOT + '\\dl.log';
var ARIA = 'C:\\aria2\\aria2c.exe';
var CURL = 'C:\\Windows\\System32\\curl.exe';
var INTERVAL = 60 * 1000;

function fso() { return new ActiveXObject('Scripting.FileSystemObject'); }
function pad(n) { return n < 10 ? '0' + n : '' + n; }

function ensureDir(p) {
  try { var f = fso(); if (!f.FolderExists(p)) f.CreateFolder(p); return true; }
  catch (e) { return false; }
}

function log(msg) {
  try {
    var s = fso().OpenTextFile(LOG, 8, true, -1);
    var d = new Date();
    s.WriteLine('[' + d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) +
      ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds()) + '] ' + msg);
    s.Close();
  } catch (e) {}
}

function exists(p) { try { return fso().FileExists(p); } catch (e) { return false; } }
function sizeOf(p) { try { return fso().GetFile(p).Size; } catch (e) { return -1; } }

function httpObj() {
  var ids = ['MSXML2.ServerXMLHTTP.6.0', 'MSXML2.ServerXMLHTTP.3.0', 'MSXML2.XMLHTTP', 'WinHttp.WinHttpRequest.5.1'];
  for (var i = 0; i < ids.length; i++) {
    try { return new ActiveXObject(ids[i]); } catch (e) {}
  }
  throw new Error('no http object available');
}

function httpGet(url, binary) {
  var x = httpObj();
  try { x.setTimeouts(20000, 20000, 60000, 1800000); } catch (e) {}
  x.open('GET', url, false);
  try { x.setRequestHeader('User-Agent', 'nan-dl/1.0'); } catch (e) {}
  try { x.setRequestHeader('Cache-Control', 'no-cache'); } catch (e) {}
  x.send();
  var st = 0;
  try { st = x.status; } catch (e) { st = 0; }
  if (st < 200 || st >= 300) throw new Error('HTTP ' + st);
  if (typeof x.responseBody !== 'undefined' && binary) return x.responseBody;
  if (typeof x.ResponseBody !== 'undefined' && binary) return x.ResponseBody;
  if (binary) return x.responseText;
  return x.responseText;
}

function saveBinary(url, dest) {
  var body = httpGet(url, true);
  var st = new ActiveXObject('ADODB.Stream');
  st.Type = 1;
  st.Open();
  st.Write(body);
  if (exists(dest)) { try { fso().DeleteFile(dest); } catch (e) {} }
  st.SaveToFile(dest, 2);
  st.Close();
}

function baseName(u) {
  var p = String(u).split('?')[0];
  var i = p.lastIndexOf('/');
  if (i >= 0 && i < p.length - 1) p = p.substring(i + 1);
  try { p = decodeURIComponent(p); } catch (e) {}
  p = p.replace(/[\\\/:*?"<>|]/g, '_');
  return p || 'file';
}

function safeName(s) {
  var n = String(s).replace(/[\\\/:*?"<>|]/g, '_');
  if (n.length > 40) n = n.substring(0, 40);
  return n || 'task';
}

function decodeHtml(s) {
  var t = String(s);
  t = t.split('&lt;').join('<');
  t = t.split('&gt;').join('>');
  t = t.split(String.fromCharCode(38) + 'quot;').join(String.fromCharCode(34));
  t = t.split('&#' + '39;').join(String.fromCharCode(39));
  t = t.split('&amp;').join('&');
  return t;
}

var seenList = [];
var seenMap = {};

function loadSeen() {
  try {
    var f = fso();
    if (!f.FileExists(SEEN)) return;
    var t = f.OpenTextFile(SEEN, 1, false, -2).ReadAll();
    if (!t) return;
    var arr = eval('(' + t + ')');
    for (var i = 0; i < arr.length; i++) {
      seenList.push(String(arr[i]));
      seenMap[String(arr[i])] = 1;
    }
  } catch (e) {}
}

function saveSeen() {
  try {
    var out = [];
    for (var i = 0; i < seenList.length; i++) {
      out.push('"' + seenList[i].replace(/"/g, '\\"') + '"');
    }
    var f = fso();
    if (f.FileExists(SEEN)) f.DeleteFile(SEEN);
    var s = f.OpenTextFile(SEEN, 2, true, -1);
    s.Write('[' + out.join(',') + ']');
    s.Close();
  } catch (e) {}
}

function runQuiet(cmd) {
  try {
    var sh = new ActiveXObject('WScript.Shell');
    return sh.Run(cmd, 0, true);
  } catch (e) { return -1; }
}

function hasExe(p) { return exists(p); }

function fetchTo(url, name, dir) {
  var dest = dir + '\\' + name;
  if (exists(dest) && sizeOf(dest) > 0) { log('skip exists ' + name); return; }
  var i;

  if (hasExe(ARIA)) {
    runQuiet('"' + ARIA + '" -x4 -s4 -c -o "' + name + '" -d "' + dir + '" "' + url + '"');
    if (exists(dest) && sizeOf(dest) > 0) { log('ok aria ' + name + ' ' + sizeOf(dest)); return; }
    log('aria fail ' + name + ' -> curl');
  }

  if (hasExe(CURL)) {
    runQuiet('"' + CURL + '" -L --fail --retry 3 --connect-timeout 20 -s -o "' + dest + '" "' + url + '"');
    if (exists(dest) && sizeOf(dest) > 0) { log('ok curl ' + name + ' ' + sizeOf(dest)); return; }
    log('curl fail ' + name + ' -> http');
  }

  try {
    saveBinary(url, dest);
    log('ok http ' + name + ' ' + sizeOf(dest));
  } catch (e) {
    log('fail ' + name + ' :: ' + e.message);
  }
}

function runAtom() {
  var txt = httpGet('https://github.com/LJRNN/blog/releases.atom?t=' + new Date().getTime(), false);
  var re = /<entry>([\s\S]*?)<\/entry>/g;
  var m, n = 0;
  while ((m = re.exec(txt)) != null) {
    var e = m[1];
    var idm = e.match(/<id>([\s\S]*?)<\/id>/);
    if (!idm) continue;
    var id = idm[1].replace(/^\s+|\s+$/g, '');
    if (seenMap[id]) continue;
    var tm = e.match(/<title>([\s\S]*?)<\/title>/);
    var title = tm ? decodeHtml(tm[1]).replace(/^\s+|\s+$/g, '') : 'task';
    var um = decodeHtml(e).match(/https?:\/\/[^\s"<>()]+/g) || [];
    var urls = [], uniq = {};
    for (var i = 0; i < um.length; i++) {
      var u = um[i];
      if (u.indexOf('/releases/tag/') >= 0) continue;
      if (u.indexOf('avatars.githubusercontent') >= 0) continue;
      if (u.indexOf('github.com/LJRNN/blog') >= 0) continue;
      if (uniq[u]) continue;
      uniq[u] = 1;
      urls.push(u);
    }
    if (urls.length > 0) {
      var sub = OUT_DIR + '\\' + safeName(title);
      ensureDir(sub);
      log('task ' + title + ' urls=' + urls.length);
      for (var k = 0; k < urls.length; k++) fetchTo(urls[k], baseName(urls[k]), sub);
    }
    seenList.push(id);
    seenMap[id] = 1;
    n++;
  }
  if (n > 0) saveSeen();
  return n;
}

function runJson() {
  var feeds = [
    'https://raw.githubusercontent.com/LJRNN/blog/main/queue/dl.json',
    'https://cdn.jsdelivr.net/gh/LJRNN/blog@main/queue/dl.json'
  ];
  for (var i = 0; i < feeds.length; i++) {
    var txt;
    try { txt = httpGet(feeds[i] + '?t=' + new Date().getTime(), false); } catch (e) { continue; }
    var j;
    try { j = eval('(' + txt + ')'); } catch (e) { continue; }
    var tasks = (j && j.tasks) ? j.tasks : [];
    var n = 0;
    for (var k = 0; k < tasks.length; k++) {
      var t = tasks[k];
      if (!t || !t.url) continue;
      var id = 'json:' + (t.id ? t.id : t.url);
      if (seenMap[id]) continue;
      var nm = t.name ? String(t.name) : baseName(t.url);
      nm = nm.replace(/[\\\/:*?"<>|]/g, '_');
      log('json task ' + nm);
      fetchTo(String(t.url), nm, OUT_DIR);
      seenList.push(id);
      seenMap[id] = 1;
      n++;
    }
    if (n > 0) saveSeen();
    return;
  }
}

ensureDir(ROOT);
if (!ensureDir(OUT_DIR)) {
  OUT_DIR = ROOT + '\\downloads';
  ensureDir(OUT_DIR);
}
loadSeen();

var args = [];
try { for (var ai = 0; ai < WScript.Arguments.length; ai++) args.push(String(WScript.Arguments(ai))); } catch (e) {}
var ONCE = args.join(',').indexOf('once') >= 0 || args.join(',').indexOf('test') >= 0;

function SAY(m) {
  try {
    if (String(WScript.FullName).toLowerCase().indexOf('cscript') >= 0) WScript.Echo(m);
  } catch (e) {}
}

log('js poller start | out=' + OUT_DIR + ' | aria=' + exists(ARIA) + ' | seen=' + seenList.length);
SAY('out=' + OUT_DIR);
SAY('aria=' + exists(ARIA) + '  seen=' + seenList.length);

if (ONCE) {
  var na = 0, nj = 0;
  try { na = runAtom(); } catch (e) { log('atom err :: ' + e.message); SAY('atom err :: ' + e.message); }
  try { runJson(); nj = 1; } catch (e) { log('json err :: ' + e.message); SAY('json err :: ' + e.message); }
  SAY('one-shot done, new releases=' + na + ' json=' + nj);
  WScript.Quit(0);
}

while (true) {
  try { runAtom(); } catch (e) { log('atom err :: ' + e.message); }
  try { runJson(); } catch (e) { log('json err :: ' + e.message); }
  try { WScript.Sleep(INTERVAL); } catch (e) {}
}