param([string]$Device = 'emulator-5554')
. "$PSScriptRoot/env.ps1"
& "$PSScriptRoot/Prepare-Android.ps1"
Push-Location "$ProjectRoot/app_build"
try {
  & flutter --no-version-check run -d $Device
  if ($LASTEXITCODE -ne 0) { throw 'Application launch failed' }
} finally { Pop-Location }
