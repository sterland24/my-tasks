$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$ToolsRoot = Join-Path $ProjectRoot '.local-tools'
$env:JAVA_HOME = (Get-ChildItem "$ToolsRoot/java" -Directory | Select-Object -First 1).FullName
$env:ANDROID_HOME = "$ToolsRoot/android-sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:ANDROID_USER_HOME = "$ToolsRoot/android-user"
$env:ANDROID_AVD_HOME = "$ToolsRoot/avd"
$env:GRADLE_USER_HOME = "$ToolsRoot/gradle"
$env:PUB_CACHE = "$ToolsRoot/pub-cache"
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$toolPaths = @("$ToolsRoot/flutter/bin", "$env:JAVA_HOME/bin", "$env:ANDROID_HOME/platform-tools", "$env:ANDROID_HOME/emulator", "$env:ANDROID_HOME/cmdline-tools/latest/bin")
$env:PATH = (@($toolPaths + ($env:PATH -split ';')) | Where-Object { $_ } | ForEach-Object { $_.Replace('/', '\') } | Select-Object -Unique) -join ';'
$mirrorDirectory = Join-Path $env:GRADLE_USER_HOME 'init.d'
New-Item -ItemType Directory -Force $mirrorDirectory | Out-Null
Copy-Item "$PSScriptRoot/gradle-mirrors.gradle" "$mirrorDirectory/network-mirrors.gradle" -Force
