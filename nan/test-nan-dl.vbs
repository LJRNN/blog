' test-nan-dl.vbs  --  run one pass and show what happened
Option Explicit
Dim sh, fso, root, js, cmd, out

Set sh  = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

root = "C:\nan"
js   = root & "\nan-dl.js"

If Not fso.FileExists(js) Then
  MsgBox "找不到 " & js, 48, "nan-dl test"
  WScript.Quit 1
End If

' one pass only: pass a dummy argument
cmd = "cmd /c cscript //nologo """ & js & """ once"
sh.Run cmd, 1, True

out = ""
If fso.FileExists(root & "\dl.log") Then out = fso.OpenTextFile(root & "\dl.log", 1).ReadAll
If Len(out) > 2500 Then out = Right(out, 2500)

MsgBox "---- dl.log ----" & vbCrLf & out, 64, "nan-dl test"