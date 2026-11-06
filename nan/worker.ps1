$ErrorActionPreference = 'Continue'
$root = 'C:\nan'
$work = Join-Path $root 'work'
$doneFile = Join-Path $root 'done.json'
$log = Join-Path $root 'worker.log'
$queues = @(
  'https://raw.githubusercontent.com/LJRNN/blog/main/queue/task.json',
  'https://cdn.jsdelivr.net/gh/LJRNN/blog@main/queue/task.json'
)
function Log($m) {
  Add-Content -Path $log -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) -Encoding UTF8
}
New-Item -ItemType Directory -Force -Path $work | Out-Null
$done = @()
if (Test-Path $doneFile) {
  try { $done = @((Get-Content $doneFile -Raw -Encoding UTF8 | ConvertFrom-Json)) } catch { $done = @() }
}
$aria = 'C:\aria2\aria2c.exe'
$sync = 'D:\联通网盘同步'
if (-not (Test-Path -LiteralPath $sync)) {
  $alt = Get-ChildItem -LiteralPath 'D:\' -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($alt) { $sync = $alt.FullName }
}
Log ('worker up | sync -> ' + $sync)
while ($true) {
  $data = $null
  foreach ($u in $queues) {
    try {
      $r = Invoke-WebRequest -Uri ($u + '?t=' + [DateTime]::UtcNow.Ticks) -UseBasicParsing -TimeoutSec 20
      $d = $r.Content | ConvertFrom-Json
      if (-not $data -or ($d.revision -gt $data.revision)) { $data = $d }
    } catch { }
  }
  if ($data -and $data.tasks) {
    foreach ($tk in $data.tasks) {
      if (-not $tk.name -or -not $tk.url) { continue }
      if ($tk.done) { continue }
      if ($done -contains $tk.name) { continue }
      $name = ($tk.name -replace '[\\/:*?"<>|]', '_')
      $part = Join-Path $work ($name + '.part')
      $merged = Join-Path $work $name
      Log ('fetch ' + $tk.name)
      try {
        if (Test-Path $aria) {
          & $aria -x 8 -s 8 -o $name -d $work $tk.url | Out-Null
        } else {
          & curl.exe -L --fail --output $part $tk.url
        }
        if (-not (Test-Path $part) -and (Test-Path $merged)) { $part = $merged }
        if ((Test-Path $part) -and ((Get-Item $part).Length -gt 0)) {
          if (Test-Path -LiteralPath $sync) {
            Move-Item -Force $part (Join-Path $sync $name)
            Log ('-> ' + $sync + '\' + $name)
          } else {
            Move-Item -Force $part $merged
            Log ('-> ' + $merged + ' (no sync dir on D:)')
          }
          $done += $tk.name
          Set-Content -Path $doneFile -Value (ConvertTo-Json -InputObject @($done) -Compress) -Encoding UTF8
        } else {
          Log ('empty/failed ' + $tk.name)
        }
      } catch { Log ('ERR ' + $_.Exception.Message) }
    }
  }
  Start-Sleep -Seconds 60
}
