. "$PSScriptRoot/env.ps1"
& "$PSScriptRoot/Prepare-Android.ps1"
Push-Location "$ProjectRoot/app_build"
try {
  & flutter --no-version-check analyze --no-fatal-infos --no-fatal-warnings
  if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed' }
  & flutter --no-version-check test
  if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed' }
} finally { Pop-Location }
