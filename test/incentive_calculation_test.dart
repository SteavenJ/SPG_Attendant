import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Incentive Calculation Tests', () {
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

    int computeQtyIncentive({required int lawOs, required int lawNh, required int sofa}) {
      return (lawOs * incentiveOsPerPcs) +
          (lawNh * incentiveNhPerPcs) +
          (sofa * incentiveSofaPerPcs);
    }

    int computeTotalIncentive({
      required int salesAmount,
      required double storeAchievementPct,
      required int lawOs,
      required int lawNh,
      required int sofa,
    }) {
      final rate = getIncentiveRate(storeAchievementPct);
      final valueIncentive = (salesAmount * (rate / 100.0)).round();
      final qtyIncentive = computeQtyIncentive(lawOs: lawOs, lawNh: lawNh, sofa: sofa);
      return valueIncentive + qtyIncentive;
    }

    test('computes quantity incentive correctly for OS, NH, and Sofa', () {
      final qtyIncentive = computeQtyIncentive(lawOs: 2, lawNh: 1, sofa: 3);
      // (2 * 25.000) + (1 * 50.000) + (3 * 85.000) = 50.000 + 50.000 + 255.000 = 355.000
      expect(qtyIncentive, equals(355000));
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

    test('combines value and quantity incentive when store achievement >= 100%', () {
      final total = computeTotalIncentive(
        salesAmount: 20000000,
        storeAchievementPct: 105.0, // 100-120% -> rate = 1.0%
        lawOs: 2,                   // 2 * 25.000 = 50.000
        lawNh: 1,                   // 1 * 50.000 = 50.000
        sofa: 2,                    // 2 * 85.000 = 170.000
      );
      // Value incentive = 20.000.000 * 1.0% = 200.000
      // Qty incentive = 270.000
      // Total = 470.000
      expect(total, equals(470000));
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
            lawOs: 2, // 50.000
            lawNh: 2, // 100.000
            sofa: 2, // 170.000
          ), // Total: 320.000
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
      expect(spgList[1]['totalIncentive'], equals(320000));
      expect(spgList[2]['name'], equals('SPG A'));
      expect(spgList[2]['totalIncentive'], equals(145000));
    });
  });
}
