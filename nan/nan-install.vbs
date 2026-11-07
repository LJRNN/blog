' nan-install.vbs  --  one click setup. double click this file only.
'
' it will
'   1. create C:\nan
'   2. download nan-dl.js and its two launchers from the blog repo
'   3. add a shortcut into your Startup folder
'   4. start the downloader hidden right away
'
' after that, publish a GitHub release with a download link in the body,
' and the file lands in D:\联通网盘同步 within two minutes.

Option Explicit

Dim ROOT, BASE
ROOT = "C:\nan"
BASE = "https://raw.githubusercontent.com/LJRNN/blog/main/nan/"

Dim sh, fso, names, i, ok, report, url, dest

Set sh  = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

If Not fso.FolderExists(ROOT) Then fso.CreateFolder ROOT

names = Array("nan-dl.js", "start-nan-dl.vbs", "test-nan-dl.vbs")
ok = 0
report = ""

For i = 0 To UBound(names)
  url  = BASE & names(i)
  dest = ROOT & "\" & names(i)
  If Grab(url, dest) Then
    ok = ok + 1
    report = report & "ok   " & names(i) & vbCrLf
  Else
    report = report & "FAIL " & names(i) & vbCrLf
  End If
Next

If ok = 0 Then
  MsgBox "全都下载失败了，可能没网或者被拦。" & vbCrLf & vbCrLf & _
         "可以用浏览器手动打开下面地址，另存到 C:\nan" & vbCrLf & _
         BASE & "nan-dl.js", 48, "nan 安装失败"
  WScript.Quit 1
End If

AddStartup
sh.Run "wscript.exe """ & ROOT & "\nan-dl.js""", 0, False

MsgBox "装好了，后台已经跑起来" & vbCrLf & vbCrLf & report & vbCrLf & _
       "发任务的地方：" & vbCrLf & _
       "https://github.com/LJRNN/blog/releases/new" & vbCrLf & vbCrLf & _
       "标题随便写，正文贴下载链接，点 Publish" & vbCrLf & _
       "两分钟内文件会进 D:\联通网盘同步" & vbCrLf & vbCrLf & _
       "日志：C:\nan\dl.log", 64, "nan 装好了"


Function Grab(u, d)
  Dim xml, body, stream, engines, k
  Grab = False
  engines = Array("MSXML2.XMLHTTP.6.0", "MSXML2.XMLHTTP.3.0", "WinHttp.WinHttpRequest.5.1", "MSXML2.ServerXMLHTTP.6.0")
  For k = 0 To UBound(engines)
    On Error Resume Next
    Set xml = CreateObject(engines(k))
    If Err.Number = 0 Then
      Err.Clear
      xml.open "GET", u, False
      If Err.Number = 0 Then
        Err.Clear
        xml.setRequestHeader "User-Agent", "nan/1.0"
        xml.send
        If Err.Number = 0 Then
          If xml.status >= 200 And xml.status < 300 Then
            Err.Clear
            body = xml.responseBody
            If Err.Number = 0 Then
              Set stream = CreateObject("ADODB.Stream")
              stream.Type = 1
              stream.Open
              stream.Write body
              If fso.FileExists(d) Then fso.DeleteFile d
              stream.SaveToFile d, 2
              stream.Close
              If Err.Number = 0 Then
                On Error GoTo 0
                Grab = True
                Exit Function
              End If
            End If
          End If
        End If
      End If
    End If
    On Error GoTo 0
  Next
  On Error GoTo 0
End Function

Sub AddStartup()
  Dim lnk, s
  On Error Resume Next
  lnk = sh.SpecialFolders("Startup") & "\nan-dl.lnk"
  If fso.FileExists(lnk) Then
    On Error GoTo 0
    Exit Sub
  End If
  Set s = sh.CreateShortcut(lnk)
  s.TargetPath = "wscript.exe"
  s.Arguments = """" & ROOT & "\nan-dl.js"""
  s.WorkingDirectory = ROOT
  s.WindowStyle = 7
  s.Save
  On Error GoTo 0
End Sub