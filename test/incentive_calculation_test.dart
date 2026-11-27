import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Incentive and Decimal Quantity Tests', () {
    const int incentiveOsPerPcs = 25000;
    const int incentiveNhPerPcs = 50000;
    const int incentiveSofaPerPcs = 85000;

    double getIncentiveRate(double storeAchievementPct) {
      if (storeAchievementPct < 50.0) return 0.0;
      if (storeAchievementPct < 85.0) return 0.5;
      if (storeAchievementPct < 100.0) return 0.8;
      if (storeAchievementPct < 120.0) return 1.0;
      return 1.2;
    }

    int computeQtyIncentive({required num lawOs, required num lawNh, required num sofa}) {
      return ((lawOs * incentiveOsPerPcs) +
          (lawNh * incentiveNhPerPcs) +
          (sofa * incentiveSofaPerPcs)).round();
    }

    int computeTotalIncentive({
      required int salesAmount,
      required double storeAchievementPct,
      required num lawOs,
      required num lawNh,
      required num sofa,
    }) {
      final rate = getIncentiveRate(storeAchievementPct);
      final valueIncentive = (salesAmount * (rate / 100.0)).round();
      final qtyIncentive = computeQtyIncentive(lawOs: lawOs, lawNh: lawNh, sofa: sofa);
      return valueIncentive + qtyIncentive;
    }

    num parseQuantity(String text) {
      final cleaned = text.trim().replaceAll(',', '.');
      if (cleaned.isEmpty) return 0;
      final val = double.tryParse(cleaned);
      if (val == null || val <= 0) return 0;
      if (val % 1 == 0) return val.toInt();
      return val;
    }

    String formatQty(num qty) {
      if (qty % 1 == 0) {
        return qty.toInt().toString();
      }
      return qty.toString();
    }

    test('computes quantity incentive correctly for whole numbers', () {
      final qtyIncentive = computeQtyIncentive(lawOs: 2, lawNh: 1, sofa: 3);
      // (2 * 25.000) + (1 * 50.000) + (3 * 85.000) = 50.000 + 50.000 + 255.000 = 355.000
      expect(qtyIncentive, equals(355000));
    });

    test('computes quantity incentive accurately for decimal quantity (e.g. 0.5 pcs)', () {
      // OS: 0.5 * 25.000 = 12.500
      final osIncentive = (0.5 * incentiveOsPerPcs).round();
      expect(osIncentive, equals(12500));

      // NH: 0.5 * 50.000 = 25.000
      final nhIncentive = (0.5 * incentiveNhPerPcs).round();
      expect(nhIncentive, equals(25000));

      // Sofa: 0.5 * 85.000 = 42.500
      final sofaIncentive = (0.5 * incentiveSofaPerPcs).round();
      expect(sofaIncentive, equals(42500));

      // Combined 0.5 pcs each: 12.500 + 25.000 + 42.500 = 80.000
      final combined = computeQtyIncentive(lawOs: 0.5, lawNh: 0.5, sofa: 0.5);
      expect(combined, equals(80000));
    });

    test('parses decimal quantity inputs with dot or comma correctly', () {
      expect(parseQuantity('0.5'), equals(0.5));
      expect(parseQuantity('0,5'), equals(0.5));
      expect(parseQuantity(',5'), equals(0.5));
      expect(parseQuantity('.5'), equals(0.5));
      expect(parseQuantity('1.5'), equals(1.5));
      expect(parseQuantity('1,5'), equals(1.5));
      expect(parseQuantity('2'), equals(2));
      expect(parseQuantity('2.0'), equals(2));
      expect(parseQuantity(''), equals(0));
      expect(parseQuantity('0'), equals(0));
      expect(parseQuantity('-1'), equals(0));
      expect(parseQuantity('abc'), equals(0));
    });

    test('formats quantity nicely without redundant trailing zeros', () {
      expect(formatQty(1), equals('1'));
      expect(formatQty(1.0), equals('1'));
      expect(formatQty(0.5), equals('0.5'));
      expect(formatQty(2.75), equals('2.75'));
      expect(formatQty(0), equals('0'));
    });

    test('earns quantity incentive even when store achievement is below 50% (Tier 0%)', () {
      final total = computeTotalIncentive(
        salesAmount: 10000000,
        storeAchievementPct: 45.0, // < 50% -> rate = 0%
        lawOs: 4,                  // 4 * 25.000 = 100.000
        lawNh: 2,                  // 2 * 50.000 = 100.000
        sofa: 1,                   // 1 * 85.000 = 85.000
      );
      // Value incentive = 0
      // Qty incentive = 285.000
      // Total = 285.000
      expect(total, equals(285000));
    });

    test('combines value and quantity incentive with decimal quantities when store achievement >= 100%', () {
      final total = computeTotalIncentive(
        salesAmount: 20000000,
        storeAchievementPct: 105.0, // 100-120% -> rate = 1.0%
        lawOs: 1.5,                 // 1.5 * 25.000 = 37.500
        lawNh: 0.5,                 // 0.5 * 50.000 = 25.000
        sofa: 2,                    // 2 * 85.000 = 170.000
      );
      // Value incentive = 20.000.000 * 1.0% = 200.000
      // Qty incentive = 37.500 + 25.000 + 170.000 = 232.500
      // Total = 432.500
      expect(total, equals(432500));
    });

    test('spg ranking correctly prioritizes total incentive descending', () {
      final spgList = [
        {
          'name': 'SPG A',
          'totalIncentive': computeTotalIncentive(
            salesAmount: 15000000,
            storeAchievementPct: 90.0, // 0.8% -> 120.000
            lawOs: 1, // 25.000
            lawNh: 0,
            sofa: 0,
          ), // Total: 145.000
        },
        {
          'name': 'SPG B',
          'totalIncentive': computeTotalIncentive(
            salesAmount: 5000000,
            storeAchievementPct: 40.0, // 0% -> 0
            lawOs: 2.5, // 2.5 * 25.000 = 62.500
            lawNh: 2,   // 100.000
            sofa: 2,    // 170.000
          ), // Total: 332.500
        },
        {
          'name': 'SPG C',
          'totalIncentive': computeTotalIncentive(
            salesAmount: 30000000,
            storeAchievementPct: 125.0, // 1.2% -> 360.000
            lawOs: 2, // 50.000
            lawNh: 1, // 50.000
            sofa: 1, // 85.000
          ), // Total: 545.000
        },
      ];

      spgList.sort((a, b) =>
          (b['totalIncentive'] as int).compareTo(a['totalIncentive'] as int));

      expect(spgList[0]['name'], equals('SPG C'));
      expect(spgList[0]['totalIncentive'], equals(545000));
      expect(spgList[1]['name'], equals('SPG B'));
      expect(spgList[1]['totalIncentive'], equals(332500));
      expect(spgList[2]['name'], equals('SPG A'));
      expect(spgList[2]['totalIncentive'], equals(145000));
    });
  });
}
