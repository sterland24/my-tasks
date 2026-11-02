# my-tasks (مدیریت وظایف من)

یک اپلیکیشن اندروید سبک، سریع، کاملاً آفلاین و متمرکز بر حریم خصوصی برای مدیریت وظایف روزانه، تقویم شمسی و یادآورها به زبان فارسی با رابط کاربری راست‌چین (RTL).

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Build APK](https://github.com/sterland24/my-tasks/actions/workflows/build.yml/badge.svg)](https://github.com/sterland24/my-tasks/actions/workflows/build.yml)

---

## ویژگی‌های کلیدی
- **کاملاً آفلاین و ایمن:** برنامه هیچ دسترسی به اینترنت ندارد (`android.permission.INTERNET` درخواست نشده است) و داده‌ها فقط روی دستگاه کاربر ذخیره می‌شوند.
- **بدون ردیاب و تبلیغات:** بدون استفاده از سرویس‌های آنالیتیکس شخص ثالث یا رصد رفتار کاربر.
- **پشتیبان‌گیری محلی:** امکان خروجی گرفتن و بازگردانی سریع فایل‌های پشتیبان JSON بدون وابستگی ابری اجباری.
- **تقویم و یادآور دقیق:** با پشتیبانی از نوتیفیکیشن‌های زنگ‌دار (Exact Alarm) و هماهنگ با بوت دستگاه.

---

## ساخت و توسعه روی ویندوز

ابزارهای محلی مورد نیاز در صورت استفاده از ساختار اسکریپتی در `.local-tools/` قرار می‌گیرند:
- Flutter 3.32.x
- Java 17
- Android SDK (Build Tools 34/35 و NDK 27.0.12077973)

اسکریپت‌ها را در PowerShell از ریشهٔ پروژه اجرا کنید. سورس‌کد اصلی در `lib/main.dart` و تست‌ها در `test/` قرار دارند:

```powershell
# فعال کردن ابزارها در نشست جاری
. ./scripts/env.ps1

# آماده‌سازی پروژه اندروید و دریافت وابستگی‌ها
./scripts/Prepare-Android.ps1

# بررسی کد و اجرای تست‌های موجود
./scripts/Test-App.ps1

# ساخت APK آزمایشی (بدون نیاز به کلید انتشار)
./scripts/Build-Apk.ps1 -DebugApk

# اجرای برنامه روی شبیه‌ساز یا دستگاه متصل
./scripts/Start-Emulator.ps1
./scripts/Run-Android.ps1
```

خروجی APK در پوشه `artifacts/` کپی می‌شود.

---

## فرآیند امضا و انتشار (Signing & CI/CD)

کلید انتشار (`keystore/release.jks`) به دلایل امنیتی درون مخزن گیت قرار **نمی‌گیرد** و در `.gitignore` نادیده گرفته شده است.

### بیلد انتشار محلی
برای بیلد انتشار رسمی، فایل کلید خود را در `keystore/release.jks` قرار دهید و متغیرهای زیر را تنظیم نمایید:
```powershell
$secret = Read-Host 'Release keystore password' -AsSecureString
$env:KS_PASS = [Net.NetworkCredential]::new('', $secret).Password
try { ./scripts/Build-Apk.ps1 } finally { Remove-Item Env:KS_PASS }
```
در صورتی که کلید انتشار در سیستم موجود نباشد، با استفاده از سویچ `-DebugApk` می‌توانید نسخه آزمایشی را بسازید.

### استقرار خودکار در GitHub Actions
گردش کار CI در `.github/workflows/build.yml` برای امضا و انتشار خودکار APK در بخش Releases از **GitHub Secrets** استفاده می‌کند:
- `KEYSTORE_BASE64`: محتوای فایل `release.jks` کدگذاری شده در Base64.
- `KEYSTORE_PASSWORD`: کلمه عبور Keystore و کلید.
- `KEY_ALIAS` (اختیاری): پیش‌فرض `taskmgr`.

اگر مخزن را فورک کرده‌اید و Secretهای بالا را تنظیم نکرده‌اید، گردش کار به طور خودکار بیلد را با امضای دیباگ انجام می‌دهد.

---

## گزارش‌های امنیتی
لطفاً برای گزارش آسیب‌پذیری‌های امنیتی، بخش [SECURITY.md](SECURITY.md) را مطالعه فرمایید.

## مجوز (License)
این پروژه تحت مجوز [MIT](LICENSE) منتشر شده است.
