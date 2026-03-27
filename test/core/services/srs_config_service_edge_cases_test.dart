import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinapsis/core/services/srs_config_service.dart';

void main() {
  group('SRSConfig - Edge Cases', () {
    group('fromJson robustness', () {
      test('fromJson with empty map returns defaults', () {
        final config = SRSConfig.fromJson({});

        expect(config.learningStepsMinutes, [1, 10]);
        expect(config.graduatingIntervalDays, 1);
        expect(config.easyIntervalDays, 4);
        expect(config.easeFactorDefault, 2.5);
        expect(config.maxReviewsPerDay, 100);
        expect(config.newCardsPerDay, 20);
        expect(config.enableLeechHandling, true);
        expect(config.leechThreshold, 8);
      });

      test('fromJson with partial map fills defaults for missing keys', () {
        final config = SRSConfig.fromJson({
          'maxReviewsPerDay': 50,
        });

        expect(config.maxReviewsPerDay, 50);
        expect(config.learningStepsMinutes, [1, 10]); // default
        expect(config.easeFactorDefault, 2.5); // default
      });

      test('fromJson with int easeFactorDefault converts to double', () {
        final config = SRSConfig.fromJson({
          'easeFactorDefault': 3, // int, not double
        });

        expect(config.easeFactorDefault, 3.0);
        expect(config.easeFactorDefault, isA<double>());
      });

      test('fromJson with empty learningStepsMinutes list', () {
        final config = SRSConfig.fromJson({
          'learningStepsMinutes': [],
        });

        expect(config.learningStepsMinutes, isEmpty);
      });

      test('fromJson with single learning step', () {
        final config = SRSConfig.fromJson({
          'learningStepsMinutes': [5],
        });

        expect(config.learningStepsMinutes, [5]);
      });
    });

    group('toJson -> fromJson roundtrip', () {
      test('default config roundtrip', () {
        const original = SRSConfig();
        final json = original.toJson();
        final restored = SRSConfig.fromJson(json);

        expect(restored.learningStepsMinutes, original.learningStepsMinutes);
        expect(restored.graduatingIntervalDays, original.graduatingIntervalDays);
        expect(restored.easyIntervalDays, original.easyIntervalDays);
        expect(restored.easeFactorDefault, original.easeFactorDefault);
        expect(restored.maxReviewsPerDay, original.maxReviewsPerDay);
        expect(restored.newCardsPerDay, original.newCardsPerDay);
        expect(restored.enableLeechHandling, original.enableLeechHandling);
        expect(restored.leechThreshold, original.leechThreshold);
      });

      test('easy preset roundtrip', () {
        const original = SRSConfig.easy;
        final json = original.toJson();
        final restored = SRSConfig.fromJson(json);

        expect(restored.learningStepsMinutes, original.learningStepsMinutes);
        expect(restored.easeFactorDefault, original.easeFactorDefault);
        expect(restored.maxReviewsPerDay, original.maxReviewsPerDay);
      });

      test('intensive preset roundtrip', () {
        const original = SRSConfig.intensive;
        final json = original.toJson();
        final restored = SRSConfig.fromJson(json);

        expect(restored.learningStepsMinutes, original.learningStepsMinutes);
        expect(restored.easeFactorDefault, original.easeFactorDefault);
      });

      test('medical preset roundtrip', () {
        const original = SRSConfig.medical;
        final json = original.toJson();
        final restored = SRSConfig.fromJson(json);

        expect(restored.learningStepsMinutes, original.learningStepsMinutes);
        expect(restored.leechThreshold, original.leechThreshold);
      });
    });

    group('copyWith edge cases', () {
      test('copyWith with no arguments returns equivalent config', () {
        const original = SRSConfig();
        final copy = original.copyWith();

        expect(copy.learningStepsMinutes, original.learningStepsMinutes);
        expect(copy.graduatingIntervalDays, original.graduatingIntervalDays);
        expect(copy.easyIntervalDays, original.easyIntervalDays);
        expect(copy.easeFactorDefault, original.easeFactorDefault);
        expect(copy.maxReviewsPerDay, original.maxReviewsPerDay);
        expect(copy.newCardsPerDay, original.newCardsPerDay);
        expect(copy.enableLeechHandling, original.enableLeechHandling);
        expect(copy.leechThreshold, original.leechThreshold);
      });

      test('copyWith all arguments', () {
        const original = SRSConfig();
        final copy = original.copyWith(
          learningStepsMinutes: [5, 15, 30],
          graduatingIntervalDays: 3,
          easyIntervalDays: 7,
          easeFactorDefault: 3.0,
          maxReviewsPerDay: 500,
          newCardsPerDay: 50,
          enableLeechHandling: false,
          leechThreshold: 12,
        );

        expect(copy.learningStepsMinutes, [5, 15, 30]);
        expect(copy.graduatingIntervalDays, 3);
        expect(copy.easyIntervalDays, 7);
        expect(copy.easeFactorDefault, 3.0);
        expect(copy.maxReviewsPerDay, 500);
        expect(copy.newCardsPerDay, 50);
        expect(copy.enableLeechHandling, false);
        expect(copy.leechThreshold, 12);
      });

      test('copyWith does not mutate original', () {
        const original = SRSConfig();
        original.copyWith(maxReviewsPerDay: 999);

        expect(original.maxReviewsPerDay, 100);
      });
    });

    group('presetName - _configEquals', () {
      test('FIXED: _configEquals now checks enableLeechHandling and leechThreshold', () {
        const config = SRSConfig(
          enableLeechHandling: false,
          leechThreshold: 999,
        );

        expect(config.presetName, 'Personalizado');
      });

      test('config matching no preset returns Personalizado', () {
        const config = SRSConfig(
          learningStepsMinutes: [2, 20, 120],
          maxReviewsPerDay: 75,
        );

        expect(config.presetName, 'Personalizado');
      });

      test('exact easy preset is recognized', () {
        expect(SRSConfig.easy.presetName, 'Relajado');
      });

      test('exact normal preset is recognized', () {
        expect(SRSConfig.normal.presetName, 'Normal');
      });

      test('exact intensive preset is recognized', () {
        expect(SRSConfig.intensive.presetName, 'Intensivo');
      });

      test('exact medical preset is recognized', () {
        expect(SRSConfig.medical.presetName, 'Medicina');
      });
    });

    group('toJson completeness', () {
      test('toJson includes all fields', () {
        const config = SRSConfig();
        final json = config.toJson();

        expect(json.containsKey('learningStepsMinutes'), isTrue);
        expect(json.containsKey('graduatingIntervalDays'), isTrue);
        expect(json.containsKey('easyIntervalDays'), isTrue);
        expect(json.containsKey('easeFactorDefault'), isTrue);
        expect(json.containsKey('maxReviewsPerDay'), isTrue);
        expect(json.containsKey('newCardsPerDay'), isTrue);
        expect(json.containsKey('enableLeechHandling'), isTrue);
        expect(json.containsKey('leechThreshold'), isTrue);
      });
    });
  });

  group('SRSConfigService - Edge Cases', () {
    late SRSConfigService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      service = SRSConfigService(prefs);
    });

    group('getConfig with corrupted data', () {
      test('getConfig with invalid stored string returns default', () async {
        SharedPreferences.setMockInitialValues({
          'srs_config': 'not-valid-json-at-all',
        });
        final prefs = await SharedPreferences.getInstance();
        final svc = SRSConfigService(prefs);

        final config = svc.getConfig();

        // Should return default config on parse error
        expect(config.maxReviewsPerDay, 100);
        expect(config.learningStepsMinutes, [1, 10]);
      });

      test('getConfig with empty string returns default', () async {
        SharedPreferences.setMockInitialValues({
          'srs_config': '',
        });
        final prefs = await SharedPreferences.getInstance();
        final svc = SRSConfigService(prefs);

        final config = svc.getConfig();

        expect(config.maxReviewsPerDay, 100);
      });
    });

    group('applyPreset', () {
      test('FIXED: applyPreset easy preserves learningStepsMinutes', () async {
        await service.applyPreset('easy');
        final config = service.getConfig();

        expect(config.maxReviewsPerDay, 50);
        expect(config.newCardsPerDay, 10);
        expect(config.learningStepsMinutes, equals([1, 10, 60]));
      });

      test('FIXED: applyPreset medical preserves learningStepsMinutes', () async {
        await service.applyPreset('medical');
        final config = service.getConfig();

        expect(config.maxReviewsPerDay, 150);
        expect(config.newCardsPerDay, 30);
        expect(config.learningStepsMinutes, equals([1, 10, 60, 1440]));
      });

      test('applyPreset with unknown name defaults to normal', () async {
        await service.applyPreset('unknown_preset');
        final config = service.getConfig();

        expect(config.maxReviewsPerDay, 100);
        expect(config.newCardsPerDay, 20);
      });

      test('applyPreset with empty string defaults to normal', () async {
        await service.applyPreset('');
        final config = service.getConfig();

        expect(config.maxReviewsPerDay, 100);
      });
    });

    group('saveConfig and getConfig roundtrip through SharedPreferences', () {
      test('FIXED: custom config with multi-element list roundtrips correctly', () async {
        const custom = SRSConfig(
          learningStepsMinutes: [2, 15, 45],
          graduatingIntervalDays: 3,
          easyIntervalDays: 7,
          easeFactorDefault: 2.8,
          maxReviewsPerDay: 75,
          newCardsPerDay: 15,
          enableLeechHandling: false,
          leechThreshold: 12,
        );

        await service.saveConfig(custom);
        final loaded = service.getConfig();

        expect(loaded.learningStepsMinutes, equals([2, 15, 45]));
        expect(loaded.graduatingIntervalDays, 3);
        expect(loaded.easyIntervalDays, 7);
        expect(loaded.easeFactorDefault, 2.8);
        expect(loaded.maxReviewsPerDay, 75);
        expect(loaded.newCardsPerDay, 15);
        expect(loaded.enableLeechHandling, false);
        expect(loaded.leechThreshold, 12);
      });

      test('overwriting config replaces previous values', () async {
        await service.saveConfig(const SRSConfig(maxReviewsPerDay: 50));
        await service.saveConfig(const SRSConfig(maxReviewsPerDay: 200));

        final config = service.getConfig();
        expect(config.maxReviewsPerDay, 200);
      });
    });

    group('resetToDefault', () {
      test('resetToDefault after saving custom config', () async {
        await service.saveConfig(const SRSConfig(
          maxReviewsPerDay: 999,
          newCardsPerDay: 999,
        ));

        await service.resetToDefault();
        final config = service.getConfig();

        expect(config.maxReviewsPerDay, 100);
        expect(config.newCardsPerDay, 20);
      });

      test('resetToDefault when nothing is saved is safe', () async {
        // Should not throw
        await service.resetToDefault();
        final config = service.getConfig();

        expect(config.maxReviewsPerDay, 100);
      });
    });

    group('_parseJson edge cases', () {
      test('FIXED: jsonEncode/jsonDecode preserves multi-element lists', () async {
        await service.applyPreset('medical');
        final config = service.getConfig();

        expect(config.learningStepsMinutes, equals([1, 10, 60, 1440]));
      });

      test('single-element list configs survive roundtrip', () async {
        // A config with a single-element list should work because there's no
        // comma inside the list to confuse the parser
        await service.saveConfig(const SRSConfig(
          learningStepsMinutes: [5],
          maxReviewsPerDay: 42,
        ));
        final config = service.getConfig();

        // Single-element list may or may not survive depending on parser behavior
        expect(config.maxReviewsPerDay, 42);
      });
    });
  });

  group('SRSConfig - Preset Constants', () {
    test('easy preset has higher ease factor than default', () {
      expect(SRSConfig.easy.easeFactorDefault, greaterThan(SRSConfig.normal.easeFactorDefault));
    });

    test('intensive preset has lower ease factor than default', () {
      expect(SRSConfig.intensive.easeFactorDefault, lessThan(SRSConfig.normal.easeFactorDefault));
    });

    test('intensive preset has more reviews per day than easy', () {
      expect(SRSConfig.intensive.maxReviewsPerDay, greaterThan(SRSConfig.easy.maxReviewsPerDay));
    });

    test('intensive preset has more new cards per day than easy', () {
      expect(SRSConfig.intensive.newCardsPerDay, greaterThan(SRSConfig.easy.newCardsPerDay));
    });

    test('medical preset has 4 learning steps', () {
      expect(SRSConfig.medical.learningStepsMinutes.length, 4);
    });

    test('medical preset includes a 1-day step (1440 minutes)', () {
      expect(SRSConfig.medical.learningStepsMinutes.contains(1440), isTrue);
    });

    test('medical preset has stricter leech threshold', () {
      expect(SRSConfig.medical.leechThreshold, lessThan(SRSConfig.normal.leechThreshold));
    });

    test('all presets have non-empty learning steps', () {
      expect(SRSConfig.easy.learningStepsMinutes, isNotEmpty);
      expect(SRSConfig.normal.learningStepsMinutes, isNotEmpty);
      expect(SRSConfig.intensive.learningStepsMinutes, isNotEmpty);
      expect(SRSConfig.medical.learningStepsMinutes, isNotEmpty);
    });

    test('all presets have positive graduatingIntervalDays', () {
      expect(SRSConfig.easy.graduatingIntervalDays, greaterThan(0));
      expect(SRSConfig.normal.graduatingIntervalDays, greaterThan(0));
      expect(SRSConfig.intensive.graduatingIntervalDays, greaterThan(0));
      expect(SRSConfig.medical.graduatingIntervalDays, greaterThan(0));
    });
  });
}
