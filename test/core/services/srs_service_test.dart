import 'package:flutter_test/flutter_test.dart';
import 'package:sinapsis/core/services/srs_service.dart';

void main() {
  group('SRSService', () {
    group('calculateNextReview', () {
      test('nueva tarjeta con rating Easy debe graduarse directamente a review', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 0,
          currentEaseFactor: 2.5,
          consecutiveCorrect: 0,
          srsState: 'new',
          rating: 3, // Easy
        );

        expect(result['srsState'], 'review');
        expect(result['interval'], 4); // easyInterval
        expect(result['consecutiveCorrect'], 1);
      });

      test('nueva tarjeta con rating Good debe moverse a learning', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 0,
          currentEaseFactor: 2.5,
          consecutiveCorrect: 0,
          srsState: 'new',
          rating: 2, // Good
        );

        expect(result['srsState'], 'learning');
        expect(result['consecutiveCorrect'], 1);
      });

      test('nueva tarjeta con rating Again debe permanecer en learning con consecutiveCorrect=0', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 0,
          currentEaseFactor: 2.5,
          consecutiveCorrect: 0,
          srsState: 'new',
          rating: 0, // Again
        );

        expect(result['srsState'], 'learning');
        expect(result['consecutiveCorrect'], 0);
      });

      test('tarjeta en learning con suficientes pasos completos debe graduarse', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 0,
          currentEaseFactor: 2.5,
          consecutiveCorrect: 1, // Ya completó un paso
          srsState: 'learning',
          rating: 2, // Good
        );

        expect(result['srsState'], 'review');
        expect(result['interval'], 1); // graduatingInterval
      });

      test('tarjeta en review con rating Again debe ir a relearning', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 10,
          currentEaseFactor: 2.5,
          consecutiveCorrect: 5,
          srsState: 'review',
          rating: 0, // Again
        );

        expect(result['srsState'], 'relearning');
        expect(result['interval'], 0);
        expect(result['consecutiveCorrect'], 0);
        expect(result['easeFactor'], lessThan(2.5)); // Debe reducirse
      });

      test('tarjeta en review con rating Good debe incrementar intervalo', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 10,
          currentEaseFactor: 2.5,
          consecutiveCorrect: 5,
          srsState: 'review',
          rating: 2, // Good
        );

        expect(result['srsState'], 'review');
        expect(result['interval'], 25); // 10 * 2.5
        expect(result['consecutiveCorrect'], 6);
      });

      test('tarjeta en review con rating Hard debe reducir ease factor', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 10,
          currentEaseFactor: 2.5,
          consecutiveCorrect: 5,
          srsState: 'review',
          rating: 1, // Hard
        );

        expect(result['easeFactor'], 2.35); // 2.5 - 0.15
        expect(result['interval'], 12); // 10 * 1.2
      });

      test('tarjeta en review con rating Easy debe incrementar ease factor', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 10,
          currentEaseFactor: 2.0, // Empezar con factor menor para poder incrementar
          consecutiveCorrect: 5,
          srsState: 'review',
          rating: 3, // Easy
        );

        expect(result['easeFactor'], greaterThan(2.0)); // Debe incrementar
        expect(result['easeFactor'], lessThanOrEqualTo(SRSService.maxEaseFactor));
        expect(result['interval'], greaterThan(20)); // Mayor que con Good (10 * 2.0)
      });

      test('tarjeta en relearning con rating Good debe volver a review', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 0,
          currentEaseFactor: 2.0,
          consecutiveCorrect: 0,
          srsState: 'relearning',
          rating: 2, // Good
        );

        expect(result['srsState'], 'review');
        expect(result['interval'], 1);
        expect(result['consecutiveCorrect'], 1);
      });

      test('ease factor nunca debe ser menor que minEaseFactor', () {
        // Simular muchos "Again" para reducir ease factor
        double easeFactor = 2.5;
        for (int i = 0; i < 20; i++) {
          final result = SRSService.calculateNextReview(
            currentInterval: 10,
            currentEaseFactor: easeFactor,
            consecutiveCorrect: 5,
            srsState: 'review',
            rating: 0, // Again
          );
          easeFactor = result['easeFactor'];
        }

        expect(easeFactor, greaterThanOrEqualTo(SRSService.minEaseFactor));
      });

      test('debe lanzar error con rating invalido', () {
        expect(
          () => SRSService.calculateNextReview(
            currentInterval: 0,
            currentEaseFactor: 2.5,
            consecutiveCorrect: 0,
            srsState: 'new',
            rating: 5, // Invalido
          ),
          throwsArgumentError,
        );
      });
    });

    group('helper methods', () {
      test('getStateDescription debe retornar descripcion correcta', () {
        expect(SRSService.getStateDescription('new'), 'Nueva');
        expect(SRSService.getStateDescription('learning'), 'Aprendiendo');
        expect(SRSService.getStateDescription('review'), 'En Repaso');
        expect(SRSService.getStateDescription('relearning'), 'Reaprendiendo');
        expect(SRSService.getStateDescription('unknown'), 'Desconocido');
      });

      test('isReadyForReview debe verificar fecha correctamente', () {
        expect(SRSService.isReadyForReview(null), true);
        expect(
          SRSService.isReadyForReview(DateTime.now().subtract(const Duration(days: 1))),
          true,
        );
        expect(
          SRSService.isReadyForReview(DateTime.now().add(const Duration(days: 1))),
          false,
        );
      });

      test('estimateRetention debe retornar valor entre 0 y 1', () {
        expect(SRSService.estimateRetention(1.3), closeTo(1.3 / 3.0, 0.01));
        expect(SRSService.estimateRetention(3.0), 1.0);
        expect(SRSService.estimateRetention(0), 0.0);
      });
    });
  });
}
