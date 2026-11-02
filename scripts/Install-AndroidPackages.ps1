. "$PSScriptRoot/env.ps1"
[xml]$repo = Get-Content "$ToolsRoot/downloads/repo-0.xml" -Raw
[xml]$images = Get-Content "$ToolsRoot/downloads/repo-1.xml" -Raw
$wanted = @('platform-tools', 'platforms;android-35', 'platforms;android-34', 'build-tools;35.0.0', 'build-tools;34.0.0', 'ndk;27.0.12077973', 'cmake;3.22.1', 'emulator', 'system-images;android-35;google_apis;x86_64')
foreach ($id in $wanted) {
  if (Test-Path (Join-Path $env:ANDROID_HOME ($id.Replace(';', '/') + '/package.xml'))) { continue }
  $doc = if ($id.StartsWith('system-images;')) { $images } else { $repo }
  $package = $doc.SelectNodes('//*[local-name()="remotePackage"]') | Where-Object { $_.path -eq $id -and $_.'channelRef'.ref -eq 'channel-0' } | Select-Object -First 1
  if (!$package) { throw "Missing SDK metadata: $id" }
  $archive = $package.archives.archive | Where-Object { (!$_.'host-os' -or $_.'host-os' -eq 'windows') -and (!$_.'host-arch' -or $_.'host-arch' -in @('x86_64', 'x64')) } | Select-Object -First 1
  if (!$archive) { throw "Missing Windows archive: $id" }
  $relative = [string]$archive.complete.url
  $base = if ($id.StartsWith('system-images;')) { 'https://redirector.gvt1.com/edgedl/android/repository/sys-img/google_apis/' } else { 'https://redirector.gvt1.com/edgedl/android/repository/' }
  $file = Join-Path "$ToolsRoot/downloads" ($id.Replace(';', '-') + '.zip')
  Write-Host "Downloading $id"
  if (!(Test-Path $file) -or (Get-Item $file).Length -ne [long]$archive.complete.size) {
    & curl.exe -4 -fL --retry 3 --speed-time 60 --speed-limit 1024 --max-time 1800 --silent --show-error -o $file ($base + $relative)
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $id" }
  }
  if ((Get-FileHash $file -Algorithm SHA1).Hash.ToLowerInvariant() -ne $archive.complete.checksum.InnerText) { throw "Checksum mismatch: $id" }
  $unpack = Join-Path "$ToolsRoot/unpack" ($id.Replace(';', '-'))
  New-Item -ItemType Directory -Force $unpack | Out-Null
  Expand-Archive $file $unpack -Force
  $source = if (Test-Path "$unpack/source.properties") { Get-Item $unpack } else { Get-ChildItem $unpack -Directory | Select-Object -First 1 }
  $destination = Join-Path $env:ANDROID_HOME $id.Replace(';', '/')
  New-Item -ItemType Directory -Force (Split-Path $destination -Parent) | Out-Null
  Move-Item -LiteralPath $source.FullName -Destination $destination
  $localDoc = New-Object System.Xml.XmlDocument
  $root = $localDoc.ImportNode($doc.DocumentElement, $false)
  [void]$localDoc.AppendChild($root)
  foreach ($license in $doc.DocumentElement.ChildNodes | Where-Object LocalName -eq 'license') { [void]$root.AppendChild($localDoc.ImportNode($license, $true)) }
  $localPackage = $localDoc.CreateElement('localPackage')
  $localPackage.SetAttribute('path', $id)
  foreach ($child in $package.ChildNodes) {
    if ($child.LocalName -notin @('archives', 'channelRef')) { [void]$localPackage.AppendChild($localDoc.ImportNode($child, $true)) }
  }
  [void]$root.AppendChild($localPackage)
  $localDoc.Save((Join-Path $destination 'package.xml'))
  Write-Host "Installed $id"
}
