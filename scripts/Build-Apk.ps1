param([switch]$DebugApk)
. "$PSScriptRoot/env.ps1"
if (!$DebugApk) {
  $defaultKeyPath = Join-Path $ProjectRoot 'keystore/release.jks'
  if (!$env:KS_PATH -and (Test-Path $defaultKeyPath)) {
    $env:KS_PATH = $defaultKeyPath
  }
  if (!$env:KS_ALIAS) { $env:KS_ALIAS = 'taskmgr' }
  if ($env:KS_PATH -and (Test-Path $env:KS_PATH) -and !$env:KS_PASS) {
    Write-Warning "KS_PATH is set but KS_PASS is empty. Set `$env:KS_PASS to sign with your release key, or run with -DebugApk."
  }
}
& "$PSScriptRoot/Prepare-Android.ps1"
Push-Location "$ProjectRoot/app_build"
try {
  $mode = if ($DebugApk) { 'debug' } else { 'release' }
  & flutter --no-version-check build apk "--$mode"
  if ($LASTEXITCODE -ne 0) { throw 'APK build failed' }
  New-Item -ItemType Directory -Force "$ProjectRoot/artifacts" | Out-Null
  Copy-Item "build/app/outputs/flutter-apk/app-$mode.apk" "$ProjectRoot/artifacts/app-$mode.apk" -Force
  Write-Host "APK: $ProjectRoot/artifacts/app-$mode.apk"
} finally { Pop-Location }
