. "$PSScriptRoot/env.ps1"
Push-Location $ProjectRoot
try {
  & flutter --no-version-check config --android-sdk $env:ANDROID_HOME --jdk-dir $env:JAVA_HOME
  if ($LASTEXITCODE -ne 0) { throw 'Flutter configuration failed' }
  if (!(Test-Path app_build/android)) {
    & flutter --no-version-check create --platforms=android --org com.mytasks --project-name task_manager --no-pub app_build
    if ($LASTEXITCODE -ne 0) { throw 'Android scaffold creation failed' }
    $sample = Join-Path $ProjectRoot 'app_build/test/widget_test.dart'
    if (Test-Path $sample) { Remove-Item -LiteralPath $sample }
  }
  $propertiesPath = Join-Path $ProjectRoot 'app_build/android/gradle.properties'
  $properties = Get-Content $propertiesPath -Raw
  $properties = [regex]::Replace($properties, '(?m)^org.gradle.jvmargs=.*$', 'org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=1G -XX:ReservedCodeCacheSize=256m -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8')
  if ($properties -notmatch 'org.gradle.workers.max=') { $properties += "`norg.gradle.workers.max=2`nkotlin.daemon.jvmargs=-Xmx1G`n" }
  [IO.File]::WriteAllText($propertiesPath, $properties)
  if (Test-Path app_build/lib) { Remove-Item app_build/lib -Recurse -Force }
  Copy-Item lib app_build -Recurse -Force
  Copy-Item test app_build -Recurse -Force
  Copy-Item pubspec.yaml app_build/pubspec.yaml -Force
  if (Test-Path analysis_options.yaml) {
    Copy-Item analysis_options.yaml app_build/analysis_options.yaml -Force
  }
  New-Item -ItemType Directory -Force app_build/assets/fonts | Out-Null
  foreach ($weight in @('Regular', 'Bold')) {
    $localFont = "assets/fonts/Vazirmatn-$weight.ttf"
    $font = "app_build/assets/fonts/Vazirmatn-$weight.ttf"
    if (Test-Path $localFont) {
      Copy-Item $localFont $font -Force
    } elseif (!(Test-Path $font)) {
      & curl.exe -fL --retry 3 --silent --show-error -o $font "https://cdn.jsdelivr.net/gh/rastikerdar/vazirmatn@v33.003/fonts/ttf/Vazirmatn-$weight.ttf"
      if ($LASTEXITCODE -ne 0) { throw "Font download failed: $weight" }
    }
  }
  $manifestPath = 'app_build/android/app/src/main/AndroidManifest.xml'
  $manifest = Get-Content $manifestPath -Raw
  if ($manifest -notmatch 'ScheduledNotificationReceiver') {
    $permissions = @'
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" android:maxSdkVersion="32"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
'@
    $receivers = @'
    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
      <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
      </intent-filter>
    </receiver>
    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver"/>
'@
    $manifest = $manifest.Replace('<application', "$permissions`n    <application").Replace('</application>', "$receivers`n    </application>")
    $manifest = [regex]::Replace($manifest, 'android:label="[^"]*"', 'android:label="وظایف من"')
    [IO.File]::WriteAllText((Join-Path $ProjectRoot $manifestPath), $manifest)
  }
  $proguardPath = Join-Path $ProjectRoot 'app_build/android/app/proguard-rules.pro'
  if (!(Test-Path $proguardPath)) {
    $pgRules = @'
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepattributes Signature, InnerClasses, EnclosingMethod
'@
    [IO.File]::WriteAllText($proguardPath, $pgRules)
  }
  $gradlePath = 'app_build/android/app/build.gradle.kts'
  $gradle = Get-Content $gradlePath -Raw
  if ($gradle -notmatch 'isCoreLibraryDesugaringEnabled') {
    $gradle = $gradle.Replace('compileOptions {', "compileOptions {`n        isCoreLibraryDesugaringEnabled = true")
    $gradle = $gradle.Replace('ndkVersion = flutter.ndkVersion', 'ndkVersion = "27.0.12077973"')
    $signing = @'
    signingConfigs {
        create("release") {
            val keyPath = System.getenv("KS_PATH")
            if (!keyPath.isNullOrBlank() && file(keyPath).exists()) {
                storeFile = file(keyPath)
                storePassword = System.getenv("KS_PASS")
                keyAlias = System.getenv("KS_ALIAS")
                keyPassword = System.getenv("KS_PASS")
            }
        }
    }
    buildTypes {
'@
    $gradle = $gradle.Replace('    buildTypes {', $signing)
    $gradle = $gradle.Replace('signingConfig = signingConfigs.getByName("debug")', "val keyPath = System.getenv(`"KS_PATH`")`n            signingConfig = if (!keyPath.isNullOrBlank() && file(keyPath).exists()) signingConfigs.getByName(`"release`") else signingConfigs.getByName(`"debug`")`n            isMinifyEnabled = true`n            isShrinkResources = true`n            proguardFiles(getDefaultProguardFile(`"proguard-android-optimize.txt`"), `"proguard-rules.pro`")")
    $gradle += "`ndependencies {`n    coreLibraryDesugaring(`"com.android.tools:desugar_jdk_libs:2.1.4`")`n}`n"
    [IO.File]::WriteAllText((Join-Path $ProjectRoot $gradlePath), $gradle)
  }
  Push-Location app_build
  try {
    & flutter --no-version-check pub get
    if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed' }
  } finally { Pop-Location }
} finally { Pop-Location }
