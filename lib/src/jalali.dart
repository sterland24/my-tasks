import 'dart:math';

// ============================================================
// تاریخ، تقویم شمسی (با پشتیبانی سال کبیسه) و اعداد فارسی
// ============================================================

/// نام ماه‌های تقویم جلالی
const jalaliMonthNames = [
  'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
  'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
];
const MN = jalaliMonthNames;

/// نام روزهای هفته (یکشنبه=۰ تا شنبه=۶)
const jalaliDayNames = [
  'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه'
];
const DN = jalaliDayNames;

/// ترتیب روزهای هفته بر اساس گاه‌شماری ایرانی (شنبه تا جمعه)
const jalaliWeekOrder = [6, 0, 1, 2, 3, 4, 5];
const DORD = jalaliWeekOrder;

/// پد کردن اعداد یک‌رقمی با صفر قبل از آن
String padTwoDigits(int n) => n.toString().padLeft(2, '0');
String pad(int n) => padTwoDigits(n);

/// تبدیل DateTime به رشته استاندارد yyyy-MM-dd
String dateToString(DateTime d) => '${d.year}-${padTwoDigits(d.month)}-${padTwoDigits(d.day)}';
String ds(DateTime d) => dateToString(d);

/// تبدیل رشته yyyy-MM-dd به DateTime
DateTime parseDate(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}
DateTime pd(String s) => parseDate(s);

/// افزودن یا کاستن تعداد مشخصی روز به تاریخ
String addDays(String s, int n) {
  final d = parseDate(s);
  return dateToString(DateTime(d.year, d.month, d.day + n));
}
String addD(String s, int n) => addDays(s, n);

/// تاریخ امروز به فرمت yyyy-MM-dd
String today() => dateToString(DateTime.now());

/// شماره روز هفته (یکشنبه=۰ تا شنبه=۶)
int weekdayOf(String s) => parseDate(s).weekday % 7;
int wd(String s) => weekdayOf(s);

/// تبدیل ارقام انگلیسی به فارسی
String toFarsiDigits(Object o) => o.toString().replaceAllMapped(RegExp(r'\d'), (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m[0]!)]);
String fa(Object o) => toFarsiDigits(o);

/// تبدیل ارقام فارسی به انگلیسی
String toEnglishDigits(String s) {
  const f = '۰۱۲۳۴۵۶۷۸۹';
  var r = s;
  for (int i = 0; i < 10; i++) {
    r = r.replaceAll(f[i], '$i');
  }
  return r;
}
String toEn(String s) => toEnglishDigits(s);

/// تبدیل تاریخ میلادی به شمسی
List<int> gregorianToJalali(int gy, int gm, int gd) {
  const m = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  int jy = gy <= 1600 ? 0 : 979;
  gy -= gy <= 1600 ? 621 : 1600;
  final g2 = gm > 2 ? gy + 1 : gy;
  int days = 365 * gy + ((g2 + 3) ~/ 4) - ((g2 + 99) ~/ 100) + ((g2 + 399) ~/ 400) - 80 + gd + m[gm - 1];
  jy += 33 * (days ~/ 12053);
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  final jm = days < 186 ? 1 + days ~/ 31 : 7 + (days - 186) ~/ 30;
  final jd = 1 + (days < 186 ? days % 31 : (days - 186) % 30);
  return [jy, jm, jd];
}
List<int> g2j(int gy, int gm, int gd) => gregorianToJalali(gy, gm, gd);

/// تبدیل تاریخ شمسی به میلادی
List<int> jalaliToGregorian(int jy, int jm, int jd) {
  int gy = jy <= 979 ? 621 : 1600;
  jy -= jy <= 979 ? 0 : 979;
  int days = 365 * jy + (jy ~/ 33) * 8 + (((jy % 33) + 3) ~/ 4) + 78 + jd + (jm < 7 ? (jm - 1) * 31 : ((jm - 7) * 30) + 186);
  gy += 400 * (days ~/ 146097);
  days %= 146097;
  if (days > 36524) {
    days--;
    gy += 100 * (days ~/ 36524);
    days %= 36524;
    if (days >= 365) days++;
  }
  gy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    gy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  int gd = days + 1;
  final sal = [0, 31, ((gy % 4 == 0 && gy % 100 != 0) || gy % 400 == 0) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  int gm = 0;
  while (gm < 13 && gd > sal[gm]) {
    gd -= sal[gm];
    gm++;
  }
  return [gy, gm, gd];
}
List<int> j2g(int jy, int jm, int jd) => jalaliToGregorian(jy, jm, jd);

/// بررسی سال کبیسه جلالی
bool isLeapJalaliYear(int jy) {
  final y = jy - (jy <= 979 ? 0 : 979);
  return ((y % 33) % 4) == 0;
}
bool isLeapJ(int jy) => isLeapJalaliYear(jy);

/// طول ماه شمسی (ماه ۱ تا ۶ = ۳۱ روز، ماه ۷ تا ۱۱ = ۳۰ روز، ماه ۱۲ = ۲۹ یا ۳۰ روز در سال کبیسه)
int jalaliMonthLength(int m, [int? jy]) => m <= 6 ? 31 : (m <= 11 ? 30 : (jy != null && isLeapJalaliYear(jy) ? 30 : 29));
int mlen(int m, [int? jy]) => jalaliMonthLength(m, jy);

/// تبدیل رشته تاریخ میلادی (yyyy-MM-dd) به اجزای جلالی [سال، ماه، روز]
List<int> parseJalaliDate(String s) {
  final p = s.split('-').map(int.parse).toList();
  return gregorianToJalali(p[0], p[1], p[2]);
}
List<int> jl(String s) => parseJalaliDate(s);

/// تبدیل تاریخ جلالی به رشته تاریخ میلادی استاندارد
String jalaliToDateString(int y, int m, int d) {
  final g = jalaliToGregorian(y, m, min(d, jalaliMonthLength(m, y)));
  return '${g[0]}-${padTwoDigits(g[1])}-${padTwoDigits(g[2])}';
}
String fromJ(int y, int m, int d) => jalaliToDateString(y, m, d);

/// فرمت تاریخ شمسی به صورت «۱۸ آبان»
String formatJalaliDate(String s) {
  final j = parseJalaliDate(s);
  return '${j[2]} ${jalaliMonthNames[j[1] - 1]}';
}
String jfmt(String s) => formatJalaliDate(s);

/// تولید شناسه منحصر‌به‌فرد تصادفی
String generateUniqueId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36) + Random().nextInt(99999).toRadixString(36);
String uid() => generateUniqueId();
