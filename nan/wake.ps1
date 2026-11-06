$ErrorActionPreference = 'Continue'
$root = 'C:\nan'
$topic = 'nan-dltest-1106'
$L = @()
$L += 'wake ' + (Get-Date -Format o)
$proc = Get-CimInstance Win32_Process -Filter "name='powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'worker\.ps1|boot\.ps1' }
if ($proc) {
  $L += 'worker RUNNING pid=' + ($proc.ProcessId -join ',')
} else {
  $wp = Join-Path $root 'worker.ps1'
  if (Test-Path $wp) {
    Start-Process powershell.exe -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',$wp -WindowStyle Hidden
    $L += 'worker STARTED'
  } else { $L += 'worker.ps1 MISSING' }
}
$L += 'C:\nan = ' + ((Get-ChildItem $root -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name) -join ', ')
foreach ($u in @('https://raw.githubusercontent.com/LJRNN/blog/main/queue/task.json','https://cdn.jsdelivr.net/gh/LJRNN/blog@main/queue/task.json')) {
  try { $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 12; $L += 'net OK ' + $u.Split('/')[2] + ' len=' + $r.Content.Length }
  catch { $L += 'net FAIL ' + $u.Split('/')[2] + ' ' + $_.Exception.Message }
}
$log = Join-Path $root 'worker.log'
if (Test-Path $log) { $L += '--- worker.log ---'; $L += (Get-Content $log -Tail 8) } else { $L += 'no worker.log' }
$sync = 'D:\联通网盘同步'
if (Test-Path -LiteralPath $sync) {
  $L += '--- sync ---'
  $L += (Get-ChildItem -LiteralPath $sync -ErrorAction SilentlyContinue | Select-Object -First 10 Name,Length | Out-String)
} else { $L += 'sync dir MISSING' }
$t = $L -join "`n"
Write-Host $t
try {
  $b = [System.Text.Encoding]::UTF8.GetBytes($t)
  Invoke-WebRequest -Uri ('https://ntfy.sh/' + $topic) -Method Post -Body $b -ContentType 'text/plain; charset=utf-8' -UseBasicParsing -TimeoutSec 15 | Out-Null
  Write-Host 'reply OK'
} catch { Write-Host ('reply FAIL ' + $_.Exception.Message) }
