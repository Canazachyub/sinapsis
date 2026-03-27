import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuración del algoritmo de repaso espaciado
class SRSConfig {
  final List<int> learningStepsMinutes; // Pasos en minutos [1, 10]
  final int graduatingIntervalDays; // Días para graduarse
  final int easyIntervalDays; // Días para respuesta fácil
  final double easeFactorDefault; // Factor de facilidad inicial
  final int maxReviewsPerDay; // Máximo de repasos diarios
  final int newCardsPerDay; // Nuevas tarjetas por día
  final bool enableLeechHandling; // Manejar tarjetas problemáticas
  final int leechThreshold; // Umbral para marcar como "leech"

  const SRSConfig({
    this.learningStepsMinutes = const [1, 10],
    this.graduatingIntervalDays = 1,
    this.easyIntervalDays = 4,
    this.easeFactorDefault = 2.5,
    this.maxReviewsPerDay = 100,
    this.newCardsPerDay = 20,
    this.enableLeechHandling = true,
    this.leechThreshold = 8,
  });

  /// Presets de configuración
  static const SRSConfig easy = SRSConfig(
    learningStepsMinutes: [1, 10, 60],
    graduatingIntervalDays: 2,
    easyIntervalDays: 5,
    easeFactorDefault: 2.7,
    maxReviewsPerDay: 50,
    newCardsPerDay: 10,
  );

  static const SRSConfig normal = SRSConfig();

  static const SRSConfig intensive = SRSConfig(
    learningStepsMinutes: [1, 10, 30, 60],
    graduatingIntervalDays: 1,
    easyIntervalDays: 3,
    easeFactorDefault: 2.3,
    maxReviewsPerDay: 200,
    newCardsPerDay: 40,
  );

  static const SRSConfig medical = SRSConfig(
    learningStepsMinutes: [1, 10, 60, 1440], // Incluye 1 día
    graduatingIntervalDays: 1,
    easyIntervalDays: 4,
    easeFactorDefault: 2.5,
    maxReviewsPerDay: 150,
    newCardsPerDay: 30,
    leechThreshold: 6,
  );

  SRSConfig copyWith({
    List<int>? learningStepsMinutes,
    int? graduatingIntervalDays,
    int? easyIntervalDays,
    double? easeFactorDefault,
    int? maxReviewsPerDay,
    int? newCardsPerDay,
    bool? enableLeechHandling,
    int? leechThreshold,
  }) {
    return SRSConfig(
      learningStepsMinutes: learningStepsMinutes ?? this.learningStepsMinutes,
      graduatingIntervalDays: graduatingIntervalDays ?? this.graduatingIntervalDays,
      easyIntervalDays: easyIntervalDays ?? this.easyIntervalDays,
      easeFactorDefault: easeFactorDefault ?? this.easeFactorDefault,
      maxReviewsPerDay: maxReviewsPerDay ?? this.maxReviewsPerDay,
      newCardsPerDay: newCardsPerDay ?? this.newCardsPerDay,
      enableLeechHandling: enableLeechHandling ?? this.enableLeechHandling,
      leechThreshold: leechThreshold ?? this.leechThreshold,
    );
  }

  Map<String, dynamic> toJson() => {
        'learningStepsMinutes': learningStepsMinutes,
        'graduatingIntervalDays': graduatingIntervalDays,
        'easyIntervalDays': easyIntervalDays,
        'easeFactorDefault': easeFactorDefault,
        'maxReviewsPerDay': maxReviewsPerDay,
        'newCardsPerDay': newCardsPerDay,
        'enableLeechHandling': enableLeechHandling,
        'leechThreshold': leechThreshold,
      };

  factory SRSConfig.fromJson(Map<String, dynamic> json) {
    return SRSConfig(
      learningStepsMinutes: List<int>.from(json['learningStepsMinutes'] ?? [1, 10]),
      graduatingIntervalDays: json['graduatingIntervalDays'] ?? 1,
      easyIntervalDays: json['easyIntervalDays'] ?? 4,
      easeFactorDefault: (json['easeFactorDefault'] ?? 2.5).toDouble(),
      maxReviewsPerDay: json['maxReviewsPerDay'] ?? 100,
      newCardsPerDay: json['newCardsPerDay'] ?? 20,
      enableLeechHandling: json['enableLeechHandling'] ?? true,
      leechThreshold: json['leechThreshold'] ?? 8,
    );
  }

  String get presetName {
    if (_configEquals(easy)) return 'Relajado';
    if (_configEquals(normal)) return 'Normal';
    if (_configEquals(intensive)) return 'Intensivo';
    if (_configEquals(medical)) return 'Medicina';
    return 'Personalizado';
  }

  bool _configEquals(SRSConfig other) {
    return learningStepsMinutes.toString() == other.learningStepsMinutes.toString() &&
        graduatingIntervalDays == other.graduatingIntervalDays &&
        easyIntervalDays == other.easyIntervalDays &&
        easeFactorDefault == other.easeFactorDefault &&
        maxReviewsPerDay == other.maxReviewsPerDay &&
        newCardsPerDay == other.newCardsPerDay &&
        enableLeechHandling == other.enableLeechHandling &&
        leechThreshold == other.leechThreshold;
  }
}

/// Servicio para gestionar la configuración SRS
class SRSConfigService {
  static const String _configKey = 'srs_config';
  final SharedPreferences _prefs;

  SRSConfigService(this._prefs);

  /// Obtiene la configuración actual
  SRSConfig getConfig() {
    final jsonString = _prefs.getString(_configKey);
    if (jsonString == null) return const SRSConfig();

    try {
      final json = _parseJson(jsonString);
      return SRSConfig.fromJson(json);
    } catch (e) {
      return const SRSConfig();
    }
  }

  /// Guarda la configuración
  Future<bool> saveConfig(SRSConfig config) async {
    final jsonString = _toJsonString(config.toJson());
    return _prefs.setString(_configKey, jsonString);
  }

  /// Aplica un preset
  Future<bool> applyPreset(String presetName) async {
    SRSConfig config;
    switch (presetName) {
      case 'easy':
        config = SRSConfig.easy;
        break;
      case 'intensive':
        config = SRSConfig.intensive;
        break;
      case 'medical':
        config = SRSConfig.medical;
        break;
      default:
        config = SRSConfig.normal;
    }
    return saveConfig(config);
  }

  /// Resetea a valores por defecto
  Future<bool> resetToDefault() async {
    return _prefs.remove(_configKey);
  }

  Map<String, dynamic> _parseJson(String jsonString) {
    return Map<String, dynamic>.from(jsonDecode(jsonString));
  }

  String _toJsonString(Map<String, dynamic> json) {
    return jsonEncode(json);
  }
}
