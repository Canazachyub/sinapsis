import 'package:flutter_test/flutter_test.dart';
import 'package:sinapsis/core/constants/app_constants.dart';

void main() {
  group('AppConstants', () {
    test('app name is Sinapsis', () {
      expect(AppConstants.appName, 'Sinapsis');
    });

    test('default page size is positive', () {
      expect(AppConstants.defaultPageSize, greaterThan(0));
    });

    test('network timeout is reasonable (between 5s and 120s)', () {
      expect(AppConstants.networkTimeout.inSeconds, greaterThanOrEqualTo(5));
      expect(AppConstants.networkTimeout.inSeconds, lessThanOrEqualTo(120));
    });

    test('cache timeout is positive', () {
      expect(AppConstants.cacheTimeout.inSeconds, greaterThan(0));
    });

    test('share code length is positive', () {
      expect(AppConstants.shareCodeLength, greaterThan(0));
    });

    test('default cards per session is positive', () {
      expect(AppConstants.defaultCardsPerSession, greaterThan(0));
    });

    test('FIXED: dbVersion constant matches database.dart schemaVersion (3)', () {
      expect(AppConstants.dbVersion, 3);
    });

    test('study interval values are reasonable', () {
      expect(AppConstants.easyInterval, greaterThan(0));
      expect(AppConstants.mediumInterval, greaterThan(0));
      expect(AppConstants.hardInterval, greaterThan(0));
      // Easy should have longer interval than medium
      expect(AppConstants.easyInterval, greaterThan(AppConstants.mediumInterval));
    });
  });
}
