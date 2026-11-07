' test-nan-dl.vbs  --  run one pass and show the result
' double click when you want to check whether it works

Option Explicit

Dim sh, fso, root, js, out

Set sh  = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

root = "C:\nan"
js   = root & "\nan-dl.js"

If Not fso.FileExists(js) Then
  MsgBox "找不到 " & js & vbCrLf & "先双击 nan-install.vbs 装一下", 48, "nan 测试"
  WScript.Quit 1
End If

' any extra argument makes the script do a single pass
sh.Run "wscript.exe """ & js & """ once", 0, True

out = ""
If fso.FileExists(root & "\dl.log") Then out = fso.OpenTextFile(root & "\dl.log", 1).ReadAll
If Len(out) > 2600 Then out = Right(out, 2600)
If out = "" Then out = "(日志还是空的，可能一次都没跑起来)"

MsgBox "---- C:\nan\dl.log ----" & vbCrLf & vbCrLf & out, 64, "nan 测试"