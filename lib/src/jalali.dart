import 'dart:math';

// ============================================================
// تاریخ، تقویم شمسی (با پشتیبانی سال کبیسه) و اعداد فارسی
// ============================================================
const MN = ['فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور', 'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'];
const DN = ['یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه'];
const DORD = [6, 0, 1, 2, 3, 4, 5];

String pad(int n) => n.toString().padLeft(2, '0');
String ds(DateTime d) => '${d.year}-${pad(d.month)}-${pad(d.day)}';
DateTime pd(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

String addD(String s, int n) {
  final d = pd(s);
  return ds(DateTime(d.year, d.month, d.day + n));
}

String today() => ds(DateTime.now());
int wd(String s) => pd(s).weekday % 7; // یکشنبه=۰ ... شنبه=۶
String fa(Object o) => o.toString().replaceAllMapped(RegExp(r'\d'), (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m[0]!)]);
String toEn(String s) {
  const f = '۰۱۲۳۴۵۶۷۸۹';
  var r = s;
  for (int i = 0; i < 10; i++) {
    r = r.replaceAll(f[i], '$i');
  }
  return r;
}

List<int> g2j(int gy, int gm, int gd) {
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

List<int> j2g(int jy, int jm, int jd) {
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

bool isLeapJ(int jy) {
  final y = jy - (jy <= 979 ? 0 : 979);
  return ((y % 33) % 4) == 0;
}

int mlen(int m, [int? jy]) => m <= 6 ? 31 : (m <= 11 ? 30 : (jy != null && isLeapJ(jy) ? 30 : 29));

List<int> jl(String s) {
  final p = s.split('-').map(int.parse).toList();
  return g2j(p[0], p[1], p[2]);
}

String fromJ(int y, int m, int d) {
  final g = j2g(y, m, min(d, mlen(m, y)));
  return '${g[0]}-${pad(g[1])}-${pad(g[2])}';
}

String jfmt(String s) {
  final j = jl(s);
  return '${j[2]} ${MN[j[1] - 1]}';
}

String uid() => DateTime.now().microsecondsSinceEpoch.toRadixString(36) + Random().nextInt(99999).toRadixString(36);
