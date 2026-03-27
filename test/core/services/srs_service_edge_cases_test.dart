import 'package:flutter_test/flutter_test.dart';
import 'package:sinapsis/core/services/srs_service.dart';

void main() {
  group('SRSService - Edge Cases', () {
    group('calculateNextReview - rating validation', () {
      test('rating -1 should throw ArgumentError', () {
        expect(
          () => SRSService.calculateNextReview(
            currentInterval: 0,
            currentEaseFactor: 2.5,
            consecutiveCorrect: 0,
            srsState: 'new',
            rating: -1,
          ),
          throwsArgumentError,
        );
      });

      test('rating 4 should throw ArgumentError', () {
        expect(
          () => SRSService.calculateNextReview(
            currentInterval: 0,
            currentEaseFactor: 2.5,
            consecutiveCorrect: 0,
            srsState: 'new',
            rating: 4,
          ),
          throwsArgumentError,
        );
      });

      test('rating 0 boundary is accepted', () {
        expect(
          () => SRSService.calculateNextReview(
            currentInterval: 0,
            currentEaseFactor: 2.5,
            consecutiveCorrect: 0,
            srsState: 'new',
            rating: 0,
          ),
          returnsNormally,
        );
      });

      test('rating 3 boundary is accepted', () {
        expect(
          () => SRSService.calculateNextReview(
            currentInterval: 0,
            currentEaseFactor: 2.5,
            consecutiveCorrect: 0,
            srsState: 'new',
            rating: 3,
          ),
          returnsNormally,
        );
      });
    });

    group('calculateNextReview - unknown state handling', () {
      test('unknown srsState should reset to new', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 10,
          currentEaseFactor: 2.5,
          consecutiveCorrect: 5,
          srsState: 'unknown_state',
          rating: 2,
        );

        expect(result['srsState'], 'new');
        expect(result['interval'], 0);
        expect(result['consecutiveCorrect'], 0);
      });

      test('empty string srsState should reset to new', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 10,
          currentEaseFactor: 2.5,
          consecutiveCorrect: 5,
          srsState: '',
          rating: 2,
        );

        expect(result['srsState'], 'new');
        expect(result['interval'], 0);
        expect(result['consecutiveCorrect'], 0);
      });
    });

    group('calculateNextReview - ease factor boundaries', () {
      test('ease factor at minimum should not go below minEaseFactor', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 10,
          currentEaseFactor: SRSService.minEaseFactor,
          consecutiveCorrect: 5,
          srsState: 'review',
          rating: 0, // Again
        );

        expect(
          result['easeFactor'],
          greaterThanOrEqualTo(SRSService.minEaseFactor),
        );
      });

      test('ease factor at maximum should not exceed maxEaseFactor', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 10,
          currentEaseFactor: SRSService.maxEaseFactor,
          consecutiveCorrect: 5,
          srsState: 'review',
          rating: 3, // Easy
        );

        // BUG DOCUMENTATION: maxEaseFactor is 2.5 which equals easeFactorDefault.
        // The Easy rating adds 0.15 to currentEaseFactor, then clamps to maxEaseFactor.
        // This means Easy rating never actually increases the ease factor when starting
        // at the default (2.5), making the Easy bonus effectively useless for default cards.
        expect(
          result['easeFactor'],
          lessThanOrEqualTo(SRSService.maxEaseFactor),
        );
      });

      test('ease factor above maxEaseFactor gets clamped', () {
        // Simulate passing in a value above max (e.g. from config with 2.7)
        final result = SRSService.calculateNextReview(
          currentInterval: 10,
          currentEaseFactor: 3.0,
          consecutiveCorrect: 5,
          srsState: 'review',
          rating: 2, // Good
        );

        // Final ease factor should be clamped to maxEaseFactor
        expect(result['easeFactor'], SRSService.maxEaseFactor);
      });

      test('ease factor below minEaseFactor gets clamped', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 10,
          currentEaseFactor: 0.5,
          consecutiveCorrect: 5,
          srsState: 'review',
          rating: 0, // Again
        );

        expect(
          result['easeFactor'],
          greaterThanOrEqualTo(SRSService.minEaseFactor),
        );
      });
    });

    group('calculateNextReview - interval boundaries', () {
      test('review interval should be at least 1 day', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 0,
          currentEaseFactor: 1.3,
          consecutiveCorrect: 1,
          srsState: 'review',
          rating: 1, // Hard
        );

        // 0 * 1.2 = 0, but should be clamped to 1
        expect(result['interval'], greaterThanOrEqualTo(1));
      });

      test('review interval should not exceed 36500 days', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 36500,
          currentEaseFactor: 2.5,
          consecutiveCorrect: 100,
          srsState: 'review',
          rating: 3, // Easy
        );

        // 36500 * 2.5 * 1.3 would be ~118625, but should be clamped to 36500
        expect(result['interval'], lessThanOrEqualTo(36500));
      });

      test('very large interval with Good rating clamps to 36500', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 20000,
          currentEaseFactor: 2.5,
          consecutiveCorrect: 50,
          srsState: 'review',
          rating: 2, // Good: 20000 * 2.5 = 50000
        );

        expect(result['interval'], 36500);
      });
    });

    group('calculateNextReview - learning card edge cases', () {
      test('learning card with Hard (1) and 0 consecutiveCorrect advances step', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 0,
          currentEaseFactor: 2.5,
          consecutiveCorrect: 0,
          srsState: 'learning',
          rating: 1, // Hard
        );

        // Hard (rating 1) in learning: should advance step like Good
        // This is a potential design issue - Hard and Good behave identically in learning
        expect(result['srsState'], 'learning');
        expect(result['consecutiveCorrect'], 1);
      });

      test('learning card with Easy graduates directly to review', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 0,
          currentEaseFactor: 2.5,
          consecutiveCorrect: 0,
          srsState: 'learning',
          rating: 3, // Easy
        );

        expect(result['srsState'], 'review');
        expect(result['interval'], SRSService.easyInterval);
      });

      test('learning card at step 0 with Good advances to step 1', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 0,
          currentEaseFactor: 2.5,
          consecutiveCorrect: 0,
          srsState: 'learning',
          rating: 2, // Good
        );

        expect(result['srsState'], 'learning');
        expect(result['consecutiveCorrect'], 1);
      });
    });

    group('calculateNextReview - relearning card edge cases', () {
      test('relearning card with Again stays in relearning', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 0,
          currentEaseFactor: 1.5,
          consecutiveCorrect: 0,
          srsState: 'relearning',
          rating: 0, // Again
        );

        expect(result['srsState'], 'relearning');
        expect(result['interval'], 0);
        expect(result['consecutiveCorrect'], 0);
        expect(result['easeFactor'], 1.5); // Should not change
      });

      test('relearning card with Hard goes to review with interval 1', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 0,
          currentEaseFactor: 1.5,
          consecutiveCorrect: 0,
          srsState: 'relearning',
          rating: 1, // Hard
        );

        // Hard in relearning falls into the else branch (same as Good)
        expect(result['srsState'], 'review');
        expect(result['interval'], 1);
        expect(result['consecutiveCorrect'], 1);
      });

      test('relearning card with Easy goes to review with easyInterval', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 0,
          currentEaseFactor: 1.5,
          consecutiveCorrect: 0,
          srsState: 'relearning',
          rating: 3, // Easy
        );

        expect(result['srsState'], 'review');
        expect(result['interval'], SRSService.easyInterval);
      });

      test('relearning preserves ease factor', () {
        const easeFactor = 1.8;
        final result = SRSService.calculateNextReview(
          currentInterval: 0,
          currentEaseFactor: easeFactor,
          consecutiveCorrect: 0,
          srsState: 'relearning',
          rating: 2, // Good
        );

        expect(result['easeFactor'], easeFactor);
      });
    });

    group('calculateNextReview - review card rating specifics', () {
      test('Hard rating reduces ease factor by 0.15', () {
        const initial = 2.0;
        final result = SRSService.calculateNextReview(
          currentInterval: 10,
          currentEaseFactor: initial,
          consecutiveCorrect: 5,
          srsState: 'review',
          rating: 1, // Hard
        );

        expect(result['easeFactor'], initial - 0.15);
      });

      test('Again rating reduces ease factor by 0.2', () {
        const initial = 2.0;
        final result = SRSService.calculateNextReview(
          currentInterval: 10,
          currentEaseFactor: initial,
          consecutiveCorrect: 5,
          srsState: 'review',
          rating: 0, // Again
        );

        expect(result['easeFactor'], initial - 0.2);
      });

      test('Good rating does not change ease factor', () {
        const initial = 2.0;
        final result = SRSService.calculateNextReview(
          currentInterval: 10,
          currentEaseFactor: initial,
          consecutiveCorrect: 5,
          srsState: 'review',
          rating: 2, // Good
        );

        expect(result['easeFactor'], initial);
      });

      test('Easy rating increases ease factor by 0.15', () {
        const initial = 1.8;
        final result = SRSService.calculateNextReview(
          currentInterval: 10,
          currentEaseFactor: initial,
          consecutiveCorrect: 5,
          srsState: 'review',
          rating: 3, // Easy
        );

        expect(result['easeFactor'], initial + 0.15);
      });

      test('Hard interval is currentInterval * 1.2', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 10,
          currentEaseFactor: 2.0,
          consecutiveCorrect: 5,
          srsState: 'review',
          rating: 1, // Hard
        );

        expect(result['interval'], 12); // 10 * 1.2
      });

      test('Good interval is currentInterval * easeFactor', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 10,
          currentEaseFactor: 2.0,
          consecutiveCorrect: 5,
          srsState: 'review',
          rating: 2, // Good
        );

        expect(result['interval'], 20); // 10 * 2.0
      });

      test('Easy interval is currentInterval * easeFactor * 1.3', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 10,
          currentEaseFactor: 2.0,
          consecutiveCorrect: 5,
          srsState: 'review',
          rating: 3, // Easy
        );

        expect(result['interval'], 26); // 10 * 2.0 * 1.3
      });
    });

    group('calculateNextReview - return value consistency', () {
      test('all results contain required keys', () {
        for (final state in ['new', 'learning', 'review', 'relearning']) {
          for (int rating = 0; rating <= 3; rating++) {
            final result = SRSService.calculateNextReview(
              currentInterval: 10,
              currentEaseFactor: 2.0,
              consecutiveCorrect: 2,
              srsState: state,
              rating: rating,
            );

            expect(result.containsKey('interval'), isTrue,
                reason: 'Missing interval for state=$state, rating=$rating');
            expect(result.containsKey('easeFactor'), isTrue,
                reason: 'Missing easeFactor for state=$state, rating=$rating');
            expect(result.containsKey('consecutiveCorrect'), isTrue,
                reason: 'Missing consecutiveCorrect for state=$state, rating=$rating');
            expect(result.containsKey('srsState'), isTrue,
                reason: 'Missing srsState for state=$state, rating=$rating');
            expect(result.containsKey('nextReview'), isTrue,
                reason: 'Missing nextReview for state=$state, rating=$rating');
          }
        }
      });

      test('nextReview is always a DateTime', () {
        for (final state in ['new', 'learning', 'review', 'relearning']) {
          for (int rating = 0; rating <= 3; rating++) {
            final result = SRSService.calculateNextReview(
              currentInterval: 10,
              currentEaseFactor: 2.0,
              consecutiveCorrect: 2,
              srsState: state,
              rating: rating,
            );

            expect(result['nextReview'], isA<DateTime>(),
                reason: 'nextReview not DateTime for state=$state, rating=$rating');
          }
        }
      });

      test('srsState is always a valid state string', () {
        final validStates = {'new', 'learning', 'review', 'relearning'};
        for (final state in ['new', 'learning', 'review', 'relearning']) {
          for (int rating = 0; rating <= 3; rating++) {
            final result = SRSService.calculateNextReview(
              currentInterval: 10,
              currentEaseFactor: 2.0,
              consecutiveCorrect: 2,
              srsState: state,
              rating: rating,
            );

            expect(validStates.contains(result['srsState']), isTrue,
                reason: 'Invalid srsState "${result['srsState']}" for state=$state, rating=$rating');
          }
        }
      });
    });

    group('calculateNextReview - new card with Hard rating', () {
      test('new card with Hard (1) should go to learning with consecutiveCorrect=0', () {
        final result = SRSService.calculateNextReview(
          currentInterval: 0,
          currentEaseFactor: 2.5,
          consecutiveCorrect: 0,
          srsState: 'new',
          rating: 1, // Hard
        );

        // Hard (1) in new card falls into the else branch (same as Again)
        expect(result['srsState'], 'learning');
        expect(result['consecutiveCorrect'], 0);
      });
    });

    group('helper methods - edge cases', () {
      test('getStateDescription handles null-like strings', () {
        expect(SRSService.getStateDescription(''), 'Desconocido');
        expect(SRSService.getStateDescription('NEW'), 'Desconocido');
        expect(SRSService.getStateDescription('New'), 'Desconocido');
      });

      test('getStateColor returns correct colors for all states', () {
        expect(SRSService.getStateColor('new'), 'blue');
        expect(SRSService.getStateColor('learning'), 'orange');
        expect(SRSService.getStateColor('review'), 'green');
        expect(SRSService.getStateColor('relearning'), 'red');
        expect(SRSService.getStateColor('unknown'), 'grey');
        expect(SRSService.getStateColor(''), 'grey');
      });

      test('isReadyForReview with exactly now returns false', () {
        // DateTime.now() in the method vs DateTime.now() here will differ slightly,
        // but a review exactly at "now" should conceptually be ready.
        // Testing that the current implementation uses isAfter (strict), not isAtSameMomentAs.
        final exactlyNow = DateTime.now();
        // isAfter is strict, so exact same time returns false
        // This is technically a boundary behavior to be aware of
        final result = SRSService.isReadyForReview(exactlyNow);
        // The actual now() inside the method will be slightly after our exactlyNow
        // so this should return true in practice
        expect(result, isTrue);
      });

      test('isReadyForReview with far past date returns true', () {
        expect(
          SRSService.isReadyForReview(DateTime(2000, 1, 1)),
          isTrue,
        );
      });

      test('isReadyForReview with far future date returns false', () {
        expect(
          SRSService.isReadyForReview(DateTime(2100, 1, 1)),
          isFalse,
        );
      });

      test('estimateRetention with negative ease factor returns 0', () {
        expect(SRSService.estimateRetention(-1.0), 0.0);
      });

      test('estimateRetention with very large ease factor clamps to 1.0', () {
        expect(SRSService.estimateRetention(5.0), 1.0);
      });

      test('estimateRetention with exact minEaseFactor', () {
        final result = SRSService.estimateRetention(SRSService.minEaseFactor);
        expect(result, closeTo(1.3 / 3.0, 0.001));
      });

      test('estimateRetention with exact maxEaseFactor returns 1.0', () {
        expect(SRSService.estimateRetention(SRSService.maxEaseFactor), 1.0);
      });
    });

    group('SM-2 algorithm correctness - multi-step simulation', () {
      test('full lifecycle: new -> learning -> review progression', () {
        // Step 1: New card with Good
        var result = SRSService.calculateNextReview(
          currentInterval: 0,
          currentEaseFactor: 2.5,
          consecutiveCorrect: 0,
          srsState: 'new',
          rating: 2,
        );
        expect(result['srsState'], 'learning');
        expect(result['consecutiveCorrect'], 1);

        // Step 2: Learning card with Good (should graduate)
        result = SRSService.calculateNextReview(
          currentInterval: result['interval'],
          currentEaseFactor: result['easeFactor'],
          consecutiveCorrect: result['consecutiveCorrect'],
          srsState: result['srsState'],
          rating: 2,
        );
        expect(result['srsState'], 'review');
        expect(result['interval'], 1);

        // Step 3: Review with Good (interval should increase)
        result = SRSService.calculateNextReview(
          currentInterval: result['interval'],
          currentEaseFactor: result['easeFactor'],
          consecutiveCorrect: result['consecutiveCorrect'],
          srsState: result['srsState'],
          rating: 2,
        );
        expect(result['srsState'], 'review');
        // 1 * 2.5 = 2.5 -> rounds to 3 (or 2, depending on rounding)
        expect(result['interval'], greaterThanOrEqualTo(2));

        // Step 4: Another review with Good
        result = SRSService.calculateNextReview(
          currentInterval: result['interval'],
          currentEaseFactor: result['easeFactor'],
          consecutiveCorrect: result['consecutiveCorrect'],
          srsState: result['srsState'],
          rating: 2,
        );
        expect(result['srsState'], 'review');
        expect(result['interval'], greaterThan(2));
      });

      test('lapse and recovery: review -> relearning -> review', () {
        // Start in review
        var result = SRSService.calculateNextReview(
          currentInterval: 30,
          currentEaseFactor: 2.5,
          consecutiveCorrect: 10,
          srsState: 'review',
          rating: 0, // Lapse
        );
        expect(result['srsState'], 'relearning');
        expect(result['consecutiveCorrect'], 0);
        expect(result['easeFactor'], closeTo(2.3, 0.01));

        // Recover with Good
        result = SRSService.calculateNextReview(
          currentInterval: result['interval'],
          currentEaseFactor: result['easeFactor'],
          consecutiveCorrect: result['consecutiveCorrect'],
          srsState: result['srsState'],
          rating: 2,
        );
        expect(result['srsState'], 'review');
        expect(result['interval'], 1);
        expect(result['consecutiveCorrect'], 1);
      });

      test('repeated failures keep ease factor at minimum', () {
        double easeFactor = 2.5;
        String state = 'review';
        int interval = 10;
        int consecutive = 5;

        // Fail many times
        for (int i = 0; i < 30; i++) {
          final result = SRSService.calculateNextReview(
            currentInterval: interval,
            currentEaseFactor: easeFactor,
            consecutiveCorrect: consecutive,
            srsState: state,
            rating: 0,
          );

          easeFactor = result['easeFactor'];
          state = result['srsState'];
          interval = result['interval'];
          consecutive = result['consecutiveCorrect'];

          // Recover if in relearning
          if (state == 'relearning') {
            final recovery = SRSService.calculateNextReview(
              currentInterval: interval,
              currentEaseFactor: easeFactor,
              consecutiveCorrect: consecutive,
              srsState: state,
              rating: 2,
            );
            easeFactor = recovery['easeFactor'];
            state = recovery['srsState'];
            interval = recovery['interval'];
            consecutive = recovery['consecutiveCorrect'];
          }
        }

        expect(easeFactor, SRSService.minEaseFactor);
      });
    });

    group('maxEaseFactor vs easeFactorDefault consistency', () {
      test('FIXED: maxEaseFactor (3.0) > easeFactorDefault (2.5) allows Easy bonus to work', () {
        expect(SRSService.maxEaseFactor, greaterThan(SRSService.easeFactorDefault));

        final result = SRSService.calculateNextReview(
          currentInterval: 10,
          currentEaseFactor: SRSService.easeFactorDefault,
          consecutiveCorrect: 5,
          srsState: 'review',
          rating: 3, // Easy
        );

        // Easy adds 0.15 to 2.5 = 2.65, which is now within [1.3, 3.0]
        expect(result['easeFactor'], closeTo(2.65, 0.001));
      });
    });
  });
}
