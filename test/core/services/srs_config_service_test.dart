import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinapsis/core/services/srs_config_service.dart';

void main() {
  group('SRSConfig', () {
    test('constructor por defecto debe tener valores correctos', () {
      const config = SRSConfig();

      expect(config.learningStepsMinutes, [1, 10]);
      expect(config.graduatingIntervalDays, 1);
      expect(config.easyIntervalDays, 4);
      expect(config.easeFactorDefault, 2.5);
      expect(config.maxReviewsPerDay, 100);
      expect(config.newCardsPerDay, 20);
      expect(config.enableLeechHandling, true);
      expect(config.leechThreshold, 8);
    });

    test('preset easy debe tener valores relajados', () {
      const config = SRSConfig.easy;

      expect(config.learningStepsMinutes, [1, 10, 60]);
      expect(config.graduatingIntervalDays, 2);
      expect(config.easyIntervalDays, 5);
      expect(config.easeFactorDefault, 2.7);
      expect(config.maxReviewsPerDay, 50);
      expect(config.newCardsPerDay, 10);
    });

    test('preset intensive debe tener valores intensivos', () {
      const config = SRSConfig.intensive;

      expect(config.learningStepsMinutes, [1, 10, 30, 60]);
      expect(config.graduatingIntervalDays, 1);
      expect(config.easyIntervalDays, 3);
      expect(config.easeFactorDefault, 2.3);
      expect(config.maxReviewsPerDay, 200);
      expect(config.newCardsPerDay, 40);
    });

    test('preset medical debe tener valores para medicina', () {
      const config = SRSConfig.medical;

      expect(config.learningStepsMinutes, [1, 10, 60, 1440]);
      expect(config.maxReviewsPerDay, 150);
      expect(config.newCardsPerDay, 30);
      expect(config.leechThreshold, 6);
    });

    test('copyWith debe crear copia con valores modificados', () {
      const original = SRSConfig();
      final modified = original.copyWith(
        maxReviewsPerDay: 50,
        newCardsPerDay: 10,
      );

      expect(modified.maxReviewsPerDay, 50);
      expect(modified.newCardsPerDay, 10);
      // Valores no modificados deben permanecer
      expect(modified.learningStepsMinutes, original.learningStepsMinutes);
      expect(modified.easeFactorDefault, original.easeFactorDefault);
    });

    test('toJson debe serializar correctamente', () {
      const config = SRSConfig();
      final json = config.toJson();

      expect(json['learningStepsMinutes'], [1, 10]);
      expect(json['graduatingIntervalDays'], 1);
      expect(json['easyIntervalDays'], 4);
      expect(json['easeFactorDefault'], 2.5);
    });

    test('fromJson debe deserializar correctamente', () {
      final json = {
        'learningStepsMinutes': [1, 10, 30],
        'graduatingIntervalDays': 2,
        'easyIntervalDays': 5,
        'easeFactorDefault': 2.3,
        'maxReviewsPerDay': 150,
        'newCardsPerDay': 25,
        'enableLeechHandling': false,
        'leechThreshold': 10,
      };

      final config = SRSConfig.fromJson(json);

      expect(config.learningStepsMinutes, [1, 10, 30]);
      expect(config.graduatingIntervalDays, 2);
      expect(config.easyIntervalDays, 5);
      expect(config.easeFactorDefault, 2.3);
      expect(config.maxReviewsPerDay, 150);
      expect(config.newCardsPerDay, 25);
      expect(config.enableLeechHandling, false);
      expect(config.leechThreshold, 10);
    });

    test('presetName debe identificar presets correctamente', () {
      expect(const SRSConfig().presetName, 'Normal');
      expect(SRSConfig.easy.presetName, 'Relajado');
      expect(SRSConfig.intensive.presetName, 'Intensivo');
      expect(SRSConfig.medical.presetName, 'Medicina');

      // Config personalizada
      const custom = SRSConfig(maxReviewsPerDay: 999);
      expect(custom.presetName, 'Personalizado');
    });
  });

  group('SRSConfigService', () {
    late SRSConfigService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      service = SRSConfigService(prefs);
    });

    test('getConfig debe retornar config por defecto si no hay guardada', () {
      final config = service.getConfig();

      expect(config.learningStepsMinutes, [1, 10]);
      expect(config.maxReviewsPerDay, 100);
    });

    test('saveConfig debe guardar configuracion correctamente', () async {
      const newConfig = SRSConfig(
        maxReviewsPerDay: 50,
        newCardsPerDay: 15,
      );

      await service.saveConfig(newConfig);
      final loaded = service.getConfig();

      expect(loaded.maxReviewsPerDay, 50);
      expect(loaded.newCardsPerDay, 15);
    });

    test('applyPreset debe aplicar preset correctamente', () async {
      await service.applyPreset('intensive');
      final config = service.getConfig();

      expect(config.maxReviewsPerDay, 200);
      expect(config.newCardsPerDay, 40);
    });

    test('resetToDefault debe eliminar configuracion guardada', () async {
      // Guardar config personalizada
      await service.saveConfig(const SRSConfig(maxReviewsPerDay: 999));

      // Reset
      await service.resetToDefault();
      final config = service.getConfig();

      // Debe retornar valores por defecto
      expect(config.maxReviewsPerDay, 100);
    });
  });
}
