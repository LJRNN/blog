$ErrorActionPreference = 'Continue'
$root = 'C:\nan'
$work = Join-Path $root 'work'
$doneFile = Join-Path $root 'done.json'
$log = Join-Path $root 'worker.log'
$self = Join-Path $root 'worker.ps1'
$ver = 1
$queues = @(
  'https://raw.githubusercontent.com/LJRNN/blog/main/queue/task.json',
  'https://cdn.jsdelivr.net/gh/LJRNN/blog@main/queue/task.json'
)
$verUrls = @(
  'https://raw.githubusercontent.com/LJRNN/blog/main/nan/version.json',
  'https://cdn.jsdelivr.net/gh/LJRNN/blog@main/nan/version.json'
)
$srcUrls = @(
  'https://raw.githubusercontent.com/LJRNN/blog/main/nan/worker.ps1',
  'https://cdn.jsdelivr.net/gh/LJRNN/blog@main/nan/worker.ps1'
)
function Log($m) {
  Add-Content -Path $log -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) -Encoding UTF8
}
function Post($topic, $text) {
  try {
    $b = [System.Text.Encoding]::UTF8.GetBytes($text)
    Invoke-WebRequest -Uri ('https://ntfy.sh/' + $topic) -Method Post -Body $b -ContentType 'text/plain; charset=utf-8' -UseBasicParsing -TimeoutSec 20 -Headers @{'X-Title'='nan-reply'} | Out-Null
  } catch { Log ('reply ERR ' + $_.Exception.Message) }
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
Log ('worker up v' + $ver + ' | sync -> ' + $sync)
while ($true) {
  foreach ($u in $verUrls) {
    try {
      $vr = Invoke-WebRequest -Uri ($u + '?t=' + [DateTime]::UtcNow.Ticks) -UseBasicParsing -TimeoutSec 15
      $vj = $vr.Content | ConvertFrom-Json
      if ($vj.rev -gt $ver) {
        foreach ($su in $srcUrls) {
          try {
            Invoke-WebRequest -Uri ($su + '?t=' + [DateTime]::UtcNow.Ticks) -UseBasicParsing -TimeoutSec 20 -OutFile ($self + '.new')
            $nt = Get-Content ($self + '.new') -Raw -Encoding UTF8
            $mm = [regex]::Match($nt, '\$ver\s*=\s*(\d+)')
            if ($mm.Success -and ([int]$mm.Groups[1].Value -ge [int]$vj.rev)) {
              Move-Item -Force ($self + '.new') $self
              Log ('self-update -> rev ' + $vj.rev + ', restarting')
              Start-Process powershell.exe -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',$self -WindowStyle Hidden
              exit
            } else {
              Remove-Item ($self + '.new') -Force -ErrorAction SilentlyContinue
            }
          } catch { }
        }
      }
      break
    } catch { }
  }
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
      if (-not $tk.name) { continue }
      if ($tk.done) { continue }
      if ($done -contains $tk.name) { continue }
      if ($tk.type -eq 'cmd') {
        Log ('cmd ' + $tk.name)
        $out = ''
        try {
          $out = & ([scriptblock]::Create([string]$tk.script)) 2>&1 | Out-String
        } catch { $out = 'THROW: ' + $_.Exception.Message }
        if (-not $out) { $out = '(no output)' }
        if ($out.Length -gt 3400) { $out = $out.Substring(0, 3400) + "`n...[truncated]" }
        $msg = '[nan] ' + $tk.name + "`n" + (Get-Date -Format 'HH:mm:ss') + "`n---`n" + $out
        $reply = [string]$tk.reply
        if ($reply) { Post $reply $msg; Log ('cmd done ' + $tk.name + ' -> ' + $reply) }
        else { Log ('cmd done ' + $tk.name + ' (no reply)') }
        $done += $tk.name
        Set-Content -Path $doneFile -Value (ConvertTo-Json -InputObject @($done) -Compress) -Encoding UTF8
        continue
      }
      if (-not $tk.url) { continue }
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
