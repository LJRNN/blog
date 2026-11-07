' start-nan-dl.vbs  --  run the downloader hidden in the background
' double click this once. it also drops a shortcut into Startup so it survives reboots.
Option Explicit
Dim sh, fso, root, js, lnk, s

Set sh  = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

root = "C:\nan"
js   = root & "\nan-dl.js"

If Not fso.FolderExists(root) Then fso.CreateFolder root

If Not fso.FileExists(js) Then
  MsgBox "找不到 " & js & vbCrLf & "先把 nan-dl.js 放进 C:\nan 再运行这个", 48, "nan-dl"
  WScript.Quit 1
End If

' already running? skip
Dim wmi, procs, p, running
running = False
Set wmi = GetObject("winmgmts:\\.\root\cimv2")
Set procs = wmi.ExecQuery("select * from Win32_Process where Name='wscript.exe'")
For Each p In procs
  If Not IsNull(p.CommandLine) Then
    If InStr(LCase(p.CommandLine), "nan-dl.js") > 0 Then running = True
  End If
Next
If running Then
  MsgBox "已经在跑了，不用再点", 64, "nan-dl"
  WScript.Quit 0
End If

lnk = sh.SpecialFolders("Startup") & "\nan-dl.lnk"
If Not fso.FileExists(lnk) Then
  Set s = sh.CreateShortcut(lnk)
  s.TargetPath = "wscript.exe"
  s.Arguments = """" & js & """"
  s.WorkingDirectory = root
  s.WindowStyle = 7
  s.Save
End If

sh.Run "wscript.exe """ & js & """", 0, False
MsgBox "已启动。日志在这里：" & vbCrLf & "C:\nan\dl.log" & vbCrLf & vbCrLf & _
       "下载的文件会出现在 D:\联通网盘同步，云盘会自动传到手机", 64, "nan-dl"