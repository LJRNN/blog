' =====================================================================
' nan.vbs   one file, nothing else needed
'
' double click once  -> starts (single instance, kills the old copy)
' double click again -> reloads this file, that is how you upgrade
' then to send a file: open https://github.com/LJRNN/blog/releases/new
'   title : anything, it becomes the file name
'   body  : the download link, one or more
'   publish, wait two minutes
'
' bilibili links are resolved by the script itself, so they never expire.
'   paste either  https://www.bilibili.com/video/BV1xxxxxxxxx
'              or  https://b23.tv/xxxxxxx  (full url, not the short code)
'
' files land in the netdisk sync folder on D: and the client pushes them
' to the phone. log is at C:\nan\dl.log
'
' no cmd, no powershell, no python, no curl, no admin rights.
' pure ASCII on purpose so no codepage can break it.
' =====================================================================

Dim oFso, oSh, sRoot, sSync, sLog, sSeen, sFail, sAtom, sAmp, lTick, sSelf

Set oFso = CreateObject("Scripting.FileSystemObject")
Set oSh  = CreateObject("WScript.Shell")

sAmp  = Chr(38)
lTick = 120000
sRoot = "C:\nan"
sAtom = "https://github.com/LJRNN/blog/releases.atom"
sLog  = sRoot & "\dl.log"
sSeen = sRoot & "\seen.txt"
sFail = sRoot & "\fail.txt"
sSelf = WScript.ScriptFullName

' netdisk sync folder on D: built from code points, file stays ASCII
sSync = "D:\" & ChrW(32852) & ChrW(36890) & ChrW(32593) & ChrW(30424) & ChrW(21516) & ChrW(27493)

Main

Sub Main()
  If Not oFso.FolderExists(sRoot) Then oFso.CreateFolder sRoot
  If Not oFso.FolderExists(sSync) Then
    sSync = sRoot & "\downloads"
    If Not oFso.FolderExists(sSync) Then oFso.CreateFolder sSync
  End If

  If InStr(LCase(WScript.FullName), "cscript") = 0 And Not WScript.Arguments.Named.Exists("bg") Then
    Boot
    Exit Sub
  End If

  Note "boot out=" & sSync
  Dim n
  Do
    n = 0
    On Error Resume Next
    n = Round1()
    If Err.Number <> 0 Then
      Note "err " & Err.Description
      Err.Clear
    End If
    On Error GoTo 0
    If n > 0 Then Note "downloaded " & n
    Pub
    WScript.Sleep lTick
  Loop
End Sub

Sub Boot()
  Dim sLink, oLink, lKill
  sLink = oSh.SpecialFolders("Startup") & "\nan.lnk"
  If Not oFso.FileExists(sLink) Then
    Set oLink = oSh.CreateShortcut(sLink)
    oLink.TargetPath = "wscript.exe"
    oLink.Arguments = """" & sSelf & """ /bg"
    oLink.WorkingDirectory = sRoot
    oLink.WindowStyle = 7
    oLink.Save
    Note "startup link added"
  End If
  lKill = KillOld()
  oSh.Run "wscript.exe """ & sSelf & """ /bg", 0, False
  MsgBox "running in background" & vbCrLf & _
         "old copies killed: " & lKill & vbCrLf & vbCrLf & _
         "send a task: https://github.com/LJRNN/blog/releases/new" & vbCrLf & _
         "title becomes the file name, body holds the link" & vbCrLf & _
         "publish, wait 2 min" & vbCrLf & vbCrLf & _
         "files: " & sSync & vbCrLf & "log: " & sLog, 64, "nan"
End Sub

Function KillOld()
  Dim oWmi, oPs, oP, lN
  lN = 0
  On Error Resume Next
  Set oWmi = GetObject("winmgmts:\\.\root\cimv2")
  If Err.Number <> 0 Then
    On Error GoTo 0
    KillOld = 0
    Exit Function
  End If
  Set oPs = oWmi.ExecQuery("select * from Win32_Process where Name='wscript.exe'")
  For Each oP In oPs
    If Not IsNull(oP.CommandLine) Then
      If InStr(LCase(oP.CommandLine), "nan.vbs") > 0 Then
        If InStr(LCase(oP.CommandLine), "/bg") > 0 Then
          oP.Terminate
          lN = lN + 1
        End If
      End If
    End If
  Next
  On Error GoTo 0
  KillOld = lN
End Function

Function Round1()
  Dim lGot, sSeenList, sXml, oRe, oMs, i, sEntry, sId, aUrl, k, sDest
  Dim lCnt, sTitle, lBad, sU, lTries
  lGot = 0
  sSeenList = SeenText()
  sXml = GetText(sAtom & "?t=" & CLng(Timer * 100))
  If Len(sXml) = 0 Then
    Note "atom empty"
    Round1 = 0
    Exit Function
  End If

  Set oRe = New RegExp
  oRe.Pattern = "<entry>([\s\S]*?)</entry>"
  oRe.Global = True
  oRe.IgnoreCase = True
  Set oMs = oRe.Execute(sXml)

  For i = 0 To oMs.Count - 1
    sEntry = oMs(i).SubMatches(0)
    sId = Pick(sEntry, "id")
    If Len(sId) > 0 Then
      If InStr(sSeenList, "|" & sId & "|") = 0 Then
        aUrl = Links(sEntry)
        lCnt = 0
        For k = 0 To UBound(aUrl)
          If Len(aUrl(k)) > 0 Then lCnt = lCnt + 1
        Next
        sTitle = Pick(sEntry, "title")
        lBad = 0
        For k = 0 To UBound(aUrl)
          If Len(aUrl(k)) > 0 Then
            sU = BiliOf(aUrl(k))
            If Len(sU) = 0 Then
              lBad = lBad + 1
            Else
              If lCnt = 1 Then
                sDest = sSync & "\" & NiceTitle(sTitle) & ExtOf(sU)
              Else
                sDest = sSync & "\" & NiceName(aUrl(k))
              End If
              If Pull(sU, sDest) Then lGot = lGot + 1 Else lBad = lBad + 1
            End If
          End If
        Next
        If lBad = 0 Then
          SeenAdd sId
          sSeenList = sSeenList & sId & "|"
        Else
          lTries = FailBump(sId)
          Note "bad " & lBad & " try " & lTries & " " & sId
          If lTries >= 3 Then
            Note "give up " & sId
            SeenAdd sId
            sSeenList = sSeenList & sId & "|"
          End If
        End If
      End If
    End If
  Next
  Round1 = lGot
End Function

Function Links(sTxt)
  Dim sBody, oRe, oMs, i, sU, oBag, aOut, n
  sBody = UnEsc(sTxt)
  Set oRe = New RegExp
  oRe.Pattern = "https?://[^\s""<>()]+"
  oRe.Global = True
  oRe.IgnoreCase = True
  Set oMs = oRe.Execute(sBody)
  Set oBag = CreateObject("Scripting.Dictionary")
  ReDim aOut(oMs.Count)
  n = -1
  For i = 0 To oMs.Count - 1
    sU = oMs(i).Value
    If InStr(1, sU, "/releases/tag/", 1) = 0 Then
      If InStr(1, sU, "avatars.githubusercontent", 1) = 0 Then
        If InStr(1, sU, "github.com/LJRNN", 1) = 0 Then
          If InStr(1, sU, "api.github.com", 1) = 0 Then
            If Not oBag.Exists(sU) Then
              oBag.Add sU, 1
              n = n + 1
              aOut(n) = sU
            End If
          End If
        End If
      End If
    End If
  Next
  If n >= 0 Then
    ReDim Preserve aOut(n)
  Else
    aOut = Array("")
  End If
  Links = aOut
End Function

' bilibili page link -> direct mp4 link, fetched fresh every time
Function BiliOf(sUrl)
  Dim sBv, sCid, sApi, sPlay, sMp4
  BiliOf = sUrl
  If InStr(1, sUrl, "bilibili.com", 1) = 0 Then Exit Function

  sBv = Rx(sUrl, "BV[0-9A-Za-z]{10}")
  If Len(sBv) = 0 Then
    If InStr(1, sUrl, "b23.tv", 1) > 0 Then sBv = Rx(GetText(sUrl), "BV[0-9A-Za-z]{10}")
  End If
  If Len(sBv) = 0 Then
    Note "bili no bv " & sUrl
    BiliOf = ""
    Exit Function
  End If

  sApi = "https://api.bilibili.com/x/player/view?bvid=" & sBv
  sCid = Rx(GetText(sApi), """cid"":([0-9]+)")
  If Len(sCid) = 0 Then
    Note "bili no cid " & sBv
    BiliOf = ""
    Exit Function
  End If

  sPlay = "https://api.bilibili.com/x/player/playurl?bvid=" & sBv & "&cid=" & sCid & _
          "&qn=16&fnval=1&platform=html5&high_quality=1"
  sMp4 = Rx(GetText(sPlay), """url"":""([^""]+)""")
  If Len(sMp4) = 0 Then
    Note "bili no url " & sBv
    BiliOf = ""
    Exit Function
  End If
  sMp4 = Replace(sMp4, "\/", "/")
  sMp4 = Replace(sMp4, "\u0026", sAmp)
  sMp4 = Replace(sMp4, sAmp & "amp;", sAmp)
  Note "bili " & sBv & " cid " & sCid
  BiliOf = sMp4
End Function

Function Rx(sTxt, sPat)
  Dim oRe, oM
  Rx = ""
  If Len(sTxt) = 0 Then Exit Function
  Set oRe = New RegExp
  oRe.Pattern = sPat
  oRe.IgnoreCase = True
  Set oM = oRe.Execute(sTxt)
  If oM.Count > 0 Then
    If oM(0).SubMatches.Count > 0 Then
      Rx = oM(0).SubMatches(0)
    Else
      Rx = oM(0).Value
    End If
  End If
End Function

Function Pick(sTxt, sTag)
  Dim oRe, oM
  Set oRe = New RegExp
  oRe.Pattern = "<" & sTag & ">([\s\S]*?)</" & sTag & ">"
  oRe.IgnoreCase = True
  Set oM = oRe.Execute(sTxt)
  If oM.Count > 0 Then
    Pick = Trim(UnEsc(oM(0).SubMatches(0)))
  Else
    Pick = ""
  End If
End Function

Function UnEsc(s)
  s = Replace(s, sAmp & "lt;", "<")
  s = Replace(s, sAmp & "gt;", ">")
  s = Replace(s, sAmp & "quot;", Chr(34))
  s = Replace(s, sAmp & "#39;", Chr(39))
  UnEsc = Replace(s, sAmp & "amp;", sAmp)
End Function

Function Clean(s)
  Dim aBad, k
  s = Replace(s, Chr(34), "")
  aBad = Array("\", "/", ":", "*", "?", "<", ">", "|", vbCr, vbLf, vbTab)
  For k = 0 To UBound(aBad)
    s = Replace(s, aBad(k), "_")
  Next
  Clean = Trim(s)
End Function

Function NiceTitle(sT)
  Dim sP
  sP = Clean(sT)
  Do While InStr(sP, "  ") > 0
    sP = Replace(sP, "  ", " ")
  Loop
  If Len(sP) = 0 Then sP = "file" & CLng(Timer * 100)
  If Len(sP) > 60 Then sP = Left(sP, 60)
  NiceTitle = sP
End Function

Function ExtOf(sUrl)
  Dim sP, i, j, sE
  sP = sUrl
  If InStr(sP, "?") > 0 Then sP = Left(sP, InStr(sP, "?") - 1)
  i = InStrRev(sP, "/")
  If i > 0 Then sP = Mid(sP, i + 1)
  sE = ""
  j = InStrRev(sP, ".")
  If j > 0 Then
    sE = LCase(Mid(sP, j))
    If Len(sE) > 6 Then sE = ""
    If InStr(sE, "_") > 0 Then sE = ""
  End If
  ExtOf = sE
End Function

Function NiceName(sUrl)
  Dim sP, i
  sP = sUrl
  If InStr(sP, "?") > 0 Then sP = Left(sP, InStr(sP, "?") - 1)
  i = InStrRev(sP, "/")
  If i > 0 Then sP = Mid(sP, i + 1)
  sP = Clean(sP)
  If Len(sP) = 0 Then sP = "file" & CLng(Timer * 100)
  If Len(sP) > 100 Then sP = Right(sP, 100)
  NiceName = sP
End Function

Function Http(sUrl)
  Dim aList, k, oX
  aList = Array("MSXML2.ServerXMLHTTP.6.0", "MSXML2.ServerXMLHTTP.3.0", _
                "MSXML2.XMLHTTP.6.0", "MSXML2.XMLHTTP.3.0", _
                "WinHttp.WinHttpRequest.5.1", "Microsoft.XMLHTTP")
  Set Http = Nothing
  For k = 0 To UBound(aList)
    On Error Resume Next
    Set oX = CreateObject(aList(k))
    If Err.Number = 0 Then
      Err.Clear
      oX.open "GET", sUrl, False
      If Err.Number = 0 Then
        Err.Clear
        oX.setRequestHeader "User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
        If InStr(1, sUrl, "bilibili", 1) + InStr(1, sUrl, "bilivideo", 1) > 0 Then oX.setRequestHeader "Referer", "https://www.bilibili.com/"
        oX.send
        If Err.Number = 0 Then
          If oX.status >= 200 And oX.status < 300 Then
            On Error GoTo 0
            Set Http = oX
            Exit Function
          End If
        End If
      End If
    End If
    On Error GoTo 0
  Next
End Function

Function GetText(sUrl)
  Dim oX
  GetText = ""
  Set oX = Http(sUrl)
  If oX Is Nothing Then Exit Function
  On Error Resume Next
  GetText = oX.responseText
  If Err.Number <> 0 Then GetText = ""
  On Error GoTo 0
End Function

Function Q(s)
  Q = Chr(34) & s & Chr(34)
End Function

Function CurlPull(sUrl, sDest)
  Dim sExe, sPart, sCmd, lRc
  CurlPull = False
  sExe = oSh.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\curl.exe"
  If Not oFso.FileExists(sExe) Then Exit Function

  sPart = sDest & ".part"
  If oFso.FileExists(sPart) Then oFso.DeleteFile sPart, True

  sCmd = Q(sExe) & " -L --fail --retry 2 --retry-delay 3 --connect-timeout 20"
  sCmd = sCmd & " -A " & Q("Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
  If InStr(1, sUrl, "bilibili", 1) + InStr(1, sUrl, "bilivideo", 1) > 0 Then
    sCmd = sCmd & " -e " & Q("https://www.bilibili.com/")
  End If
  sCmd = sCmd & " -o " & Q(sPart) & " " & Q(sUrl)

  On Error Resume Next
  lRc = oSh.Run(sCmd, 0, True)
  If Err.Number <> 0 Then
    Err.Clear
    On Error GoTo 0
    Exit Function
  End If
  On Error GoTo 0

  If lRc = 0 Then
    If oFso.FileExists(sPart) Then
      On Error Resume Next
      If oFso.GetFile(sPart).Size > 0 Then
        If oFso.FileExists(sDest) Then oFso.DeleteFile sDest, True
        oFso.MoveFile sPart, sDest
        If Err.Number = 0 Then
          Err.Clear
          On Error GoTo 0
          Note "ok " & sDest & " " & oFso.GetFile(sDest).Size
          CurlPull = True
          Exit Function
        End If
      End If
      Err.Clear
      On Error GoTo 0
    End If
  Else
    Note "curl rc " & lRc
  End If

  On Error Resume Next
  If oFso.FileExists(sPart) Then oFso.DeleteFile sPart, True
  On Error GoTo 0
End Function

Function Pull(sUrl, sDest)
  Pull = False
  If oFso.FileExists(sDest) Then
    On Error Resume Next
    If oFso.GetFile(sDest).Size > 0 Then
      On Error GoTo 0
      Note "skip exists " & sDest
      Exit Function
    End If
    On Error GoTo 0
  End If

  Note "get " & sUrl
  If CurlPull(sUrl, sDest) Then
    Pull = True
    Exit Function
  End If

  Dim oX, oSt
  Set oX = Http(sUrl)
  If oX Is Nothing Then
    Note "fail " & sDest
    Exit Function
  End If

  On Error Resume Next
  Set oSt = CreateObject("ADODB.Stream")
  oSt.Type = 1
  oSt.Open
  oSt.Write oX.responseBody
  If oFso.FileExists(sDest) Then oFso.DeleteFile sDest
  oSt.SaveToFile sDest, 2
  oSt.Close
  If Err.Number <> 0 Then
    Note "fail " & sDest & " " & Err.Description
    Err.Clear
    On Error GoTo 0
    Exit Function
  End If
  On Error GoTo 0
  Note "ok " & sDest & " " & oFso.GetFile(sDest).Size
  Pull = True
End Function

Function SeenText()
  Dim s
  s = ""
  On Error Resume Next
  If oFso.FileExists(sSeen) Then
    s = oFso.OpenTextFile(sSeen, 1).ReadAll
    s = Replace(s, vbCr, "")
    s = Replace(s, vbLf, "|")
  End If
  On Error GoTo 0
  SeenText = "|" & s & "|"
End Function

Sub SeenAdd(sId)
  On Error Resume Next
  Dim oF
  Set oF = oFso.OpenTextFile(sSeen, 8, True)
  oF.WriteLine sId
  oF.Close
  On Error GoTo 0
End Sub

Function FailBump(sId)
  Dim sAll, aLine, i, sOne, lN, oF
  lN = 0
  sAll = ""
  On Error Resume Next
  If oFso.FileExists(sFail) Then sAll = oFso.OpenTextFile(sFail, 1).ReadAll
  On Error GoTo 0
  aLine = Split(Replace(sAll, vbCr, ""), vbLf)
  sAll = ""
  For i = 0 To UBound(aLine)
    sOne = Trim(aLine(i))
    If Len(sOne) > 0 Then
      If InStr(sOne, "|") > 0 Then
        If InStr(sOne, sId & "|") = 1 Then
          lN = CLng(Mid(sOne, InStr(sOne, "|") + 1)) + 1
        Else
          sAll = sAll & sOne & vbCrLf
        End If
      End If
    End If
  Next
  If lN = 0 Then lN = 1
  sAll = sAll & sId & "|" & lN & vbCrLf
  On Error Resume Next
  Set oF = oFso.CreateTextFile(sFail, True, False)
  oF.Write sAll
  oF.Close
  On Error GoTo 0
  FailBump = lN
End Function

Sub Pub()
  On Error Resume Next
  Dim sTxt, oF
  sTxt = ""
  If oFso.FileExists(sLog) Then sTxt = oFso.OpenTextFile(sLog, 1).ReadAll
  If Len(sTxt) > 3000 Then sTxt = Right(sTxt, 3000)
  Set oF = oFso.CreateTextFile(sSync & "\_nan-log.txt", True, False)
  oF.Write "nan " & Stamp() & vbCrLf & sTxt
  oF.Close
  On Error GoTo 0
End Sub

Sub Note(sMsg)
  On Error Resume Next
  Dim oF
  Set oF = oFso.OpenTextFile(sLog, 8, True)
  oF.WriteLine Stamp() & " " & sMsg
  oF.Close
  On Error GoTo 0
End Sub

Function Stamp()
  Dim d
  d = Now
  Stamp = Year(d) & "-" & Zz(Month(d)) & "-" & Zz(Day(d)) & " " & _
          Zz(Hour(d)) & ":" & Zz(Minute(d)) & ":" & Zz(Second(d))
End Function

Function Zz(n)
  If n < 10 Then Zz = "0" & n Else Zz = "" & n
End Function