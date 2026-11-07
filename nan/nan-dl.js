// nan-dl.js   --  GitHub release note -> downloaded files
//
// every 2 minutes:
//   read https://github.com/LJRNN/blog/releases.atom
//   take every http(s) link inside a release body
//   save it into the Union-Netdisk sync folder on D: (client uploads it, phone grabs it)
//   write a readable log there: _nan-dl-log.txt
//
// run: start-nan-dl.vbs (hidden background)  |  test-nan-dl.vbs (one pass + popup)
// needs nothing: no cmd, no powershell, no python, no curl, no admin.

var ROOT = 'C:\\nan';
var OUT  = 'D:\\' + String.fromCharCode(0x8054, 0x901A, 0x7F51, 0x76D8, 0x540C, 0x6B65);
var LOG  = ROOT + '\\dl.log';
var PUB  = OUT + '\\_nan-dl-log.txt';
var SEEN = ROOT + '\\seen.txt';
var ATOM = 'https://github.com/LJRNN/blog/releases.atom';
var AMP  = String.fromCharCode(38);
var FSO  = new ActiveXObject('Scripting.FileSystemObject');

function pad(n){ return n < 10 ? '0' + n : '' + n; }

function stamp(){
  var d = new Date();
  return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + ' ' +
         pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds());
}

function mk(p){ try{ if(!FSO.FolderExists(p)) FSO.CreateFolder(p); }catch(e){} }

function isFile(p){
  try{ return FSO.FileExists(p) && FSO.GetFile(p).Size > 0; }catch(e){ return false; }
}

function log(m){
  try{ FSO.OpenTextFile(LOG, 8, true, -1).WriteLine(stamp() + ' ' + m); }catch(e){}
}

// several COM http stacks: locked-down boxes often break a few of them
function req(url, asBinary){
  var names = ['MSXML2.XMLHTTP.6.0', 'MSXML2.XMLHTTP.3.0',
               'MSXML2.ServerXMLHTTP.6.0', 'WinHttp.WinHttpRequest.5.1'];
  for(var i = 0; i < names.length; i++){
    try{
      var x = new ActiveXObject(names[i]);
      x.open('GET', url, false);
      try{ x.setRequestHeader('User-Agent', 'nan/1.0'); }catch(e){}
      try{ x.setRequestHeader('Cache-Control', 'no-cache'); }catch(e){}
      x.send();
      var st = 0;
      try{ st = x.status; }catch(e){ st = 0; }
      if(st < 200 || st >= 300) continue;
      if(asBinary){
        var body = null;
        try{ body = x.responseBody; }catch(e){}
        if(!body || body.length === 0) continue;
        return body;
      }
      return x.responseText;
    }catch(e){}
  }
  return null;
}

function writeBinary(body, dest){
  try{
    var s = new ActiveXObject('ADODB.Stream');
    s.Type = 1;
    s.Open();
    s.Write(body);
    try{ if(FSO.FileExists(dest)) FSO.DeleteFile(dest); }catch(e){}
    s.SaveToFile(dest, 2);
    s.Close();
    return true;
  }catch(e){
    log('write err ' + e.message);
    return false;
  }
}

function dec(s){
  s = s.split(AMP + 'lt;').join('<');
  s = s.split(AMP + 'gt;').join('>');
  s = s.split(AMP + 'quot;').join(String.fromCharCode(34));
  s = s.split(AMP + '#39;').join(String.fromCharCode(39));
  s = s.split(AMP + 'amp;').join(AMP);
  return s;
}

function fname(u){
  var p = String(u).split('?')[0];
  var i = p.lastIndexOf('/');
  if(i >= 0) p = p.substring(i + 1);
  try{ p = decodeURIComponent(p); }catch(e){}
  p = p.split(String.fromCharCode(34)).join('');
  p = p.replace(/[\\\/:*?<>|]/g, '_');
  return p || ('file' + new Date().getTime());
}

function seenAll(){
  try{ return '|' + FSO.OpenTextFile(SEEN, 1).ReadAll().replace(/\r/g, '') + '|'; }
  catch(e){ return '||'; }
}

function markSeen(id){
  try{ FSO.OpenTextFile(SEEN, 8, true, -1).WriteLine(id); }catch(e){}
}

function grab(url, dest){
  if(isFile(dest)) return false;
  log('get ' + url);
  var body = req(url, true);
  if(!body){ log('fail ' + dest); return false; }
  if(!writeBinary(body, dest)){ log('fail ' + dest); return false; }
  log('ok ' + dest + ' ' + FSO.GetFile(dest).Size);
  return true;
}

function rounds(){
  var got = 0, list = seenAll(), k;
  var xml = req(ATOM + '?t=' + new Date().getTime(), false);
  if(!xml){
    log('atom unreachable');
    return 0;
  }
  var re = /<entry>([\s\S]*?)<\/entry>/g, m;
  while((m = re.exec(xml)) != null){
    var e = m[1];
    var im = e.match(/<id>([\s\S]*?)<\/id>/);
    if(!im) continue;
    var id = dec(im[1]).replace(/^\s+|\s+$/g, '');
    if(list.indexOf('|' + id + '|') >= 0) continue;
    var all = dec(e).match(/https?:\/\/[^\s"<>()]+/g) || [];
    var uniq = {}, keep = [];
    for(k = 0; k < all.length; k++){
      var u = all[k];
      if(u.indexOf('/releases/tag/') >= 0) continue;
      if(u.indexOf('avatars.githubusercontent') >= 0) continue;
      if(u.indexOf('github.com/LJRNN') >= 0) continue;
      if(u.indexOf('api.github.com') >= 0) continue;
      if(uniq[u]) continue;
      uniq[u] = 1;
      keep.push(u);
    }
    for(k = 0; k < keep.length; k++){
      if(grab(keep[k], OUT + '\\' + fname(keep[k]))) got++;
    }
    markSeen(id);
  }
  return got;
}

function publishLog(){
  try{
    var txt = '';
    try{ txt = FSO.OpenTextFile(LOG, 1).ReadAll(); }catch(e){}
    if(txt.length > 3500) txt = txt.substring(txt.length - 3500);
    var f = FSO.CreateTextFile(PUB, true, false);
    f.Write('nan-dl status ' + stamp() + '\r\n' + txt);
    f.Close();
  }catch(e){}
}

function installStartup(){
  try{
    var sh = new ActiveXObject('WScript.Shell');
    var lnk = sh.SpecialFolders('Startup') + '\\nan-dl.lnk';
    if(FSO.FileExists(lnk)) return;
    var s = sh.CreateShortcut(lnk);
    s.TargetPath = 'wscript.exe';
    s.Arguments = String.fromCharCode(34) + ROOT + '\\nan-dl.js' + String.fromCharCode(34);
    s.WorkingDirectory = ROOT;
    s.WindowStyle = 7;
    s.Save();
    log('startup shortcut installed');
  }catch(e){
    log('startup err ' + e.message);
  }
}

mk(ROOT);
mk(OUT);
installStartup();
log('boot | out=' + OUT);

var once = false;
try{ once = WScript.Arguments.length > 0; }catch(e){}

do{
  var n = 0;
  try{ n = rounds(); }catch(e){ log('err ' + e.message); }
  if(n > 0) log('round files=' + n);
  publishLog();
  if(once) break;
  try{ WScript.Sleep(120000); }catch(e){ break; }
}while(true);