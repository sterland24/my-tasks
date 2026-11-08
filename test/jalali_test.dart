import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/src/jalali.dart';

void main() {
  group('Jalali Calendar Conversions', () {
    test('converts Gregorian to Jalali correctly', () {
      // 2026-11-08 is 17 Aban 1405
      final j = gregorianToJalali(2026, 11, 8);
      expect(j, equals([1405, 8, 17]));

      // 2024-03-20 is 1 Farvardin 1403 (leap year)
      final nowruz = gregorianToJalali(2024, 3, 20);
      expect(nowruz, equals([1403, 1, 1]));

      // 2023-03-21 is 1 Farvardin 1402
      final nowruz1402 = gregorianToJalali(2023, 3, 21);
      expect(nowruz1402, equals([1402, 1, 1]));
    });

    test('converts Jalali to Gregorian correctly', () {
      final g = jalaliToGregorian(1405, 8, 17);
      expect(g, equals([2026, 11, 8]));

      final gNowruz = jalaliToGregorian(1403, 1, 1);
      expect(gNowruz, equals([2024, 3, 20]));
    });

    test('bidirectional conversion is consistent', () {
      for (int day = 1; day <= 30; day++) {
        final j = parseJalaliDate('2026-11-${day.toString().padLeft(2, '0')}');
        final g = jalaliToGregorian(j[0], j[1], j[2]);
        expect(g[0], equals(2026));
        expect(g[1], equals(11));
        expect(g[2], equals(day));
      }
    });

    test('validates Jalali month lengths', () {
      // First 6 months have 31 days
      for (int m = 1; m <= 6; m++) {
        expect(jalaliMonthLength(m, 1405), equals(31));
      }

      // Months 7 to 11 have 30 days
      for (int m = 7; m <= 11; m++) {
        expect(jalaliMonthLength(m, 1405), equals(30));
      }

      // Esfand has 29 days in standard year, 30 in leap year
      expect(jalaliMonthLength(12, 1405), equals(29));
      expect(jalaliMonthLength(12, 1403), equals(30)); // 1403 was a leap year
    });

    test('detects Jalali leap years', () {
      expect(isLeapJalaliYear(1403), isTrue);
      expect(isLeapJalaliYear(1404), isFalse);
      expect(isLeapJalaliYear(1405), isFalse);
      expect(isLeapJalaliYear(1399), isTrue);
    });

    test('formats Jalali dates accurately', () {
      expect(formatJalaliDate('2026-11-08'), equals('17 آبان'));
      expect(formatJalaliDate('2024-03-20'), equals('1 فروردین'));
    });
  });

  group('Date Arithmetic and Day of Week', () {
    test('adds days correctly', () {
      expect(addDays('2026-11-08', 1), equals('2026-11-09'));
      expect(addDays('2026-11-08', -1), equals('2026-11-07'));
      expect(addDays('2026-11-30', 1), equals('2026-12-01'));
    });

    test('determines weekday in Jalali week numbering (0=Sun, 6=Sat)', () {
      // 2026-11-08 is Sunday (weekday=0)
      expect(weekdayOf('2026-11-08'), equals(0));
      // 2026-11-07 is Saturday (weekday=6)
      expect(weekdayOf('2026-11-07'), equals(6));
    });
  });

  group('Digit Conversions', () {
    test('converts English digits to Farsi digits', () {
      expect(toFarsiDigits('1234567890'), equals('۱۲۳۴۵۶۷۸۹۰'));
      expect(toFarsiDigits('ساعت 14:30'), equals('ساعت ۱۴:۳۰'));
    });

    test('converts Farsi digits to English digits', () {
      expect(toEnglishDigits('۱۲۳۴۵۶۷۸۹۰'), equals('1234567890'));
      expect(toEnglishDigits('۱۴۰۵-۰۸-۱۸'), equals('1405-08-18'));
    });
  });
}
