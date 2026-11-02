param([switch]$SoftwareOnly, [switch]$Headless)
. "$PSScriptRoot/env.ps1"
$name = 'MyTasks_API_35'
$devices = & adb devices
if ($devices -match '^emulator-5554\s+(device|offline)') {
  Write-Host 'The emulator is already running on port 5554.'
  return
}
if (!(Test-Path "$env:ANDROID_AVD_HOME/$name.ini")) {
  New-Item -ItemType Directory -Force $env:ANDROID_AVD_HOME | Out-Null
  'no' | & avdmanager.bat create avd --name $name --package 'system-images;android-35;google_apis;x86_64' --device pixel_6 --force
  if ($LASTEXITCODE -ne 0) { throw 'Android virtual device creation failed' }
  Add-Content "$env:ANDROID_AVD_HOME/$name.avd/config.ini" "`nhw.ramSize=2048`nhw.keyboard=yes`ndisk.dataPartition.size=4G"
}
$emulatorArgs = @('-avd', $name, '-port', '5554', '-gpu', 'swiftshader', '-no-boot-anim', '-no-snapshot')
if ($SoftwareOnly) { $emulatorArgs += @('-accel', 'off') }
if ($Headless) { $emulatorArgs += '-no-window' }
New-Item -ItemType Directory -Force "$ToolsRoot/logs" | Out-Null
$process = Start-Process -FilePath "$env:ANDROID_HOME/emulator/emulator.exe" -ArgumentList $emulatorArgs -WindowStyle Hidden -RedirectStandardOutput "$ToolsRoot/logs/emulator.log" -RedirectStandardError "$ToolsRoot/logs/emulator-error.log" -PassThru
Start-Sleep -Seconds 2
if ($process.HasExited -and $process.ExitCode -ne 0) { throw "Emulator failed; see $ToolsRoot/logs/emulator-error.log" }
Write-Host 'Emulator started. Run scripts/Run-Android.ps1 when Android finishes booting.'
