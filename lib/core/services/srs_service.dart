/// Servicio de Algoritmo de Repaso Espaciado (SRS)
/// Implementa el algoritmo SM-2 (SuperMemo 2) utilizado en Anki
///
/// Estados de las notas:
/// - new: Nota nueva, nunca revisada
/// - learning: En proceso de aprendizaje inicial
/// - review: En fase de repaso espaciado
/// - relearning: Olvidada, necesita reaprender

class SRSService {
  // Constantes del algoritmo SM-2
  static const double minEaseFactor = 1.3;
  static const double maxEaseFactor = 2.5;
  static const double easeFactorDefault = 2.5;

  // Intervalos de aprendizaje inicial (en minutos)
  static const List<int> learningSteps = [1, 10]; // 1 min, 10 min

  // Intervalos de graduación
  static const int graduatingInterval = 1; // 1 día
  static const int easyInterval = 4; // 4 días

  /// Calcula el nuevo estado de la nota después de una revisión
  ///
  /// Parámetros:
  /// - currentInterval: Intervalo actual en días
  /// - currentEaseFactor: Factor de facilidad actual
  /// - consecutiveCorrect: Respuestas correctas consecutivas
  /// - srsState: Estado actual ('new', 'learning', 'review', 'relearning')
  /// - rating: Calificación del usuario (0: again, 1: hard, 2: good, 3: easy)
  ///
  /// Retorna un mapa con los nuevos valores
  static Map<String, dynamic> calculateNextReview({
    required int currentInterval,
    required double currentEaseFactor,
    required int consecutiveCorrect,
    required String srsState,
    required int rating, // 0: again, 1: hard, 2: good, 3: easy
  }) {
    // Validar rating
    if (rating < 0 || rating > 3) {
      throw ArgumentError('Rating must be between 0 and 3');
    }

    double newEaseFactor = currentEaseFactor;
    int newInterval = currentInterval;
    int newConsecutiveCorrect = consecutiveCorrect;
    String newState = srsState;
    DateTime nextReview = DateTime.now(); // Inicializar con valor por defecto

    switch (srsState) {
      case 'new':
        final newResult = _handleNewCard(rating);
        newState = newResult['state'];
        newInterval = newResult['interval'];
        newConsecutiveCorrect = newResult['consecutiveCorrect'];
        nextReview = newResult['nextReview'];
        break;

      case 'learning':
        final learningResult = _handleLearningCard(rating, consecutiveCorrect);
        newState = learningResult['state'];
        newInterval = learningResult['interval'];
        newConsecutiveCorrect = learningResult['consecutiveCorrect'];
        nextReview = learningResult['nextReview'];
        break;

      case 'review':
        final result = _handleReviewCard(
          rating,
          currentInterval,
          currentEaseFactor,
          consecutiveCorrect,
        );
        newState = result['state'];
        newInterval = result['interval'];
        newEaseFactor = result['easeFactor'];
        newConsecutiveCorrect = result['consecutiveCorrect'];
        nextReview = result['nextReview'];
        break;

      case 'relearning':
        final relearnResult = _handleRelearningCard(rating, currentEaseFactor);
        newState = relearnResult['state'];
        newInterval = relearnResult['interval'];
        newConsecutiveCorrect = relearnResult['consecutiveCorrect'];
        newEaseFactor = relearnResult['easeFactor'];
        nextReview = relearnResult['nextReview'];
        break;

      default:
        // Estado desconocido, tratar como nueva
        newState = 'new';
        newInterval = 0;
        newConsecutiveCorrect = 0;
        nextReview = DateTime.now();
    }

    return {
      'interval': newInterval,
      'easeFactor': newEaseFactor.clamp(minEaseFactor, maxEaseFactor),
      'consecutiveCorrect': newConsecutiveCorrect,
      'srsState': newState,
      'nextReview': nextReview,
    };
  }

  /// Maneja una carta nueva
  static Map<String, dynamic> _handleNewCard(int rating) {
    if (rating == 3) {
      // Easy - graduar directamente a review con intervalo fácil
      return {
        'state': 'review',
        'interval': easyInterval,
        'consecutiveCorrect': 1,
        'nextReview': DateTime.now().add(Duration(days: easyInterval)),
      };
    } else if (rating >= 2) {
      // Good - mover a learning
      return {
        'state': 'learning',
        'interval': 0,
        'consecutiveCorrect': 1,
        'nextReview': DateTime.now().add(const Duration(minutes: 1)),
      };
    } else {
      // Again o Hard - permanecer como nueva
      return {
        'state': 'learning',
        'interval': 0,
        'consecutiveCorrect': 0,
        'nextReview': DateTime.now().add(const Duration(minutes: 1)),
      };
    }
  }

  /// Maneja una carta en aprendizaje
  static Map<String, dynamic> _handleLearningCard(
    int rating,
    int consecutiveCorrect,
  ) {
    if (rating == 0) {
      // Again - volver al inicio
      return {
        'state': 'learning',
        'interval': 0,
        'consecutiveCorrect': 0,
        'nextReview': DateTime.now().add(const Duration(minutes: 1)),
      };
    } else if (rating == 3) {
      // Easy - graduar con intervalo fácil
      return {
        'state': 'review',
        'interval': easyInterval,
        'consecutiveCorrect': 1,
        'nextReview': DateTime.now().add(Duration(days: easyInterval)),
      };
    } else if (consecutiveCorrect >= learningSteps.length - 1) {
      // Good/Hard después de completar pasos de aprendizaje - graduar
      return {
        'state': 'review',
        'interval': graduatingInterval,
        'consecutiveCorrect': 1,
        'nextReview': DateTime.now().add(Duration(days: graduatingInterval)),
      };
    } else {
      // Avanzar al siguiente paso de aprendizaje
      final nextStepIndex = consecutiveCorrect + 1;
      return {
        'state': 'learning',
        'interval': 0,
        'consecutiveCorrect': nextStepIndex,
        'nextReview': DateTime.now().add(Duration(minutes: learningSteps[nextStepIndex])),
      };
    }
  }

  /// Maneja una carta en revisión
  static Map<String, dynamic> _handleReviewCard(
    int rating,
    int currentInterval,
    double currentEaseFactor,
    int consecutiveCorrect,
  ) {
    double newEaseFactor = currentEaseFactor;
    int newInterval;
    int newConsecutiveCorrect;
    String newState;
    DateTime nextReview;

    if (rating == 0) {
      // Again - olvidada, volver a aprender
      newState = 'relearning';
      newInterval = 0;
      newConsecutiveCorrect = 0;
      newEaseFactor = (currentEaseFactor - 0.2).clamp(minEaseFactor, maxEaseFactor);
      nextReview = DateTime.now().add(const Duration(minutes: 10));
    } else {
      // Ajustar ease factor según rating
      switch (rating) {
        case 1: // Hard
          newEaseFactor = (currentEaseFactor - 0.15).clamp(minEaseFactor, maxEaseFactor);
          newInterval = (currentInterval * 1.2).round();
          break;
        case 2: // Good
          newInterval = (currentInterval * currentEaseFactor).round();
          break;
        case 3: // Easy
          newEaseFactor = (currentEaseFactor + 0.15).clamp(minEaseFactor, maxEaseFactor);
          newInterval = (currentInterval * currentEaseFactor * 1.3).round();
          break;
        default:
          newInterval = currentInterval;
      }

      // Intervalo mínimo de 1 día en review
      newInterval = newInterval.clamp(1, 36500); // Máximo ~100 años
      newState = 'review';
      newConsecutiveCorrect = consecutiveCorrect + 1;
      nextReview = DateTime.now().add(Duration(days: newInterval));
    }

    return {
      'state': newState,
      'interval': newInterval,
      'easeFactor': newEaseFactor,
      'consecutiveCorrect': newConsecutiveCorrect,
      'nextReview': nextReview,
    };
  }

  /// Maneja una carta en reaprendizaje
  static Map<String, dynamic> _handleRelearningCard(
    int rating,
    double currentEaseFactor,
  ) {
    if (rating == 0) {
      // Again - permanecer en reaprendizaje
      return {
        'state': 'relearning',
        'interval': 0,
        'consecutiveCorrect': 0,
        'easeFactor': currentEaseFactor,
        'nextReview': DateTime.now().add(const Duration(minutes: 10)),
      };
    } else if (rating == 3) {
      // Easy - volver a review con intervalo fácil
      return {
        'state': 'review',
        'interval': easyInterval,
        'consecutiveCorrect': 1,
        'easeFactor': currentEaseFactor,
        'nextReview': DateTime.now().add(Duration(days: easyInterval)),
      };
    } else {
      // Good/Hard - volver a review con intervalo de 1 día
      return {
        'state': 'review',
        'interval': 1,
        'consecutiveCorrect': 1,
        'easeFactor': currentEaseFactor,
        'nextReview': DateTime.now().add(const Duration(days: 1)),
      };
    }
  }

  /// Obtiene el texto descriptivo del estado SRS
  static String getStateDescription(String state) {
    switch (state) {
      case 'new':
        return 'Nueva';
      case 'learning':
        return 'Aprendiendo';
      case 'review':
        return 'En Repaso';
      case 'relearning':
        return 'Reaprendiendo';
      default:
        return 'Desconocido';
    }
  }

  /// Obtiene el color del estado SRS
  static String getStateColor(String state) {
    switch (state) {
      case 'new':
        return 'blue';
      case 'learning':
        return 'orange';
      case 'review':
        return 'green';
      case 'relearning':
        return 'red';
      default:
        return 'grey';
    }
  }

  /// Calcula cuántas notas están listas para revisar
  static bool isReadyForReview(DateTime? nextReview) {
    if (nextReview == null) return true;
    return DateTime.now().isAfter(nextReview);
  }

  /// Calcula la retención estimada basada en el ease factor
  static double estimateRetention(double easeFactor) {
    // Fórmula aproximada: retención = ease factor / max ease factor
    return (easeFactor / maxEaseFactor).clamp(0.0, 1.0);
  }
}
