import 'package:flutter/services.dart';

/// Configurações do Semáforo para um aplicativo ou globais.
/// Ruim: abaixo deste valor é considerado prejudicial / rejeitado (Vermelho).
/// Bom: igual ou acima deste valor é considerado lucrativo / recomendado (Verde).
/// Entre Ruim e Bom: intermediário (Amarelo).
class SemaforoConfig {
  const SemaforoConfig({
    this.kmRuim = 1.90,
    this.kmBom = 2.00,
    this.horaRuim = 43.0,
    this.horaBom = 48.0,
    this.notaRuim = 4.80,
    this.notaBom = 4.90,
  });

  final double kmRuim;
  final double kmBom;
  final double horaRuim;
  final double horaBom;
  final double notaRuim;
  final double notaBom;

  SemaforoConfig copyWith({
    double? kmRuim,
    double? kmBom,
    double? horaRuim,
    double? horaBom,
    double? notaRuim,
    double? notaBom,
  }) {
    return SemaforoConfig(
      kmRuim: kmRuim ?? this.kmRuim,
      kmBom: kmBom ?? this.kmBom,
      horaRuim: horaRuim ?? this.horaRuim,
      horaBom: horaBom ?? this.horaBom,
      notaRuim: notaRuim ?? this.notaRuim,
      notaBom: notaBom ?? this.notaBom,
    );
  }

  Map<String, dynamic> toMap() => {
        'kmRuim': kmRuim,
        'kmBom': kmBom,
        'horaRuim': horaRuim,
        'horaBom': horaBom,
        'notaRuim': notaRuim,
        'notaBom': notaBom,
      };

  factory SemaforoConfig.fromMap(Map<dynamic, dynamic>? m) {
    if (m == null) return const SemaforoConfig();
    return SemaforoConfig(
      kmRuim: (m['kmRuim'] as num?)?.toDouble() ?? 1.90,
      kmBom: (m['kmBom'] as num?)?.toDouble() ?? 2.00,
      horaRuim: (m['horaRuim'] as num?)?.toDouble() ?? 43.0,
      horaBom: (m['horaBom'] as num?)?.toDouble() ?? 48.0,
      notaRuim: (m['notaRuim'] as num?)?.toDouble() ?? 4.80,
      notaBom: (m['notaBom'] as num?)?.toDouble() ?? 4.90,
    );
  }
}

/// Configurações compartilhadas com o Kotlin nativo.
class AppSettings {
  const AppSettings({
    this.overlayEnabled = true,
    this.global = const SemaforoConfig(),
    this.uber,
    this.app99,
    this.inDrive,
    this.uberEnabled = true,
    this.app99Enabled = true,
    this.inDriveEnabled = true,
  });

  final bool overlayEnabled;
  final SemaforoConfig global;
  final SemaforoConfig? uber;
  final SemaforoConfig? app99;
  final SemaforoConfig? inDrive;
  final bool uberEnabled;
  final bool app99Enabled;
  final bool inDriveEnabled;

  // Compatibilidade com código legado
  double get minPerKm => global.kmBom;
  double get minPerHour => global.horaBom;
  String get mode => 'semaforo';

  SemaforoConfig getForApp(String appName) {
    switch (appName.toLowerCase().trim()) {
      case 'uber':
        return uber ?? global;
      case '99':
        return app99 ?? global;
      case 'indrive':
        return inDrive ?? global;
      default:
        return global;
    }
  }

  AppSettings copyWith({
    bool? overlayEnabled,
    SemaforoConfig? global,
    SemaforoConfig? uber,
    SemaforoConfig? app99,
    SemaforoConfig? inDrive,
    bool? uberEnabled,
    bool? app99Enabled,
    bool? inDriveEnabled,
  }) {
    return AppSettings(
      overlayEnabled: overlayEnabled ?? this.overlayEnabled,
      global: global ?? this.global,
      uber: uber ?? this.uber,
      app99: app99 ?? this.app99,
      inDrive: inDrive ?? this.inDrive,
      uberEnabled: uberEnabled ?? this.uberEnabled,
      app99Enabled: app99Enabled ?? this.app99Enabled,
      inDriveEnabled: inDriveEnabled ?? this.inDriveEnabled,
    );
  }

  Map<String, dynamic> toMap() => {
        'overlayEnabled': overlayEnabled,
        'global': global.toMap(),
        'uber': uber?.toMap(),
        'app99': app99?.toMap(),
        'inDrive': inDrive?.toMap(),
        'uberEnabled': uberEnabled,
        'app99Enabled': app99Enabled,
        'inDriveEnabled': inDriveEnabled,
      };

  factory AppSettings.fromMap(Map<dynamic, dynamic> m) {
    return AppSettings(
      overlayEnabled: (m['overlayEnabled'] as bool?) ?? true,
      global: SemaforoConfig.fromMap(m['global'] as Map<dynamic, dynamic>?),
      uber: m['uber'] != null ? SemaforoConfig.fromMap(m['uber'] as Map<dynamic, dynamic>) : null,
      app99: m['app99'] != null ? SemaforoConfig.fromMap(m['app99'] as Map<dynamic, dynamic>) : null,
      inDrive: m['inDrive'] != null ? SemaforoConfig.fromMap(m['inDrive'] as Map<dynamic, dynamic>) : null,
      uberEnabled: (m['uberEnabled'] as bool?) ?? true,
      app99Enabled: (m['app99Enabled'] as bool?) ?? true,
      inDriveEnabled: (m['inDriveEnabled'] as bool?) ?? true,
    );
  }
}

class OfferRecord {
  const OfferRecord({
    required this.time,
    required this.source,
    required this.price,
    required this.pickupKm,
    required this.pickupMin,
    required this.tripKm,
    required this.tripMin,
    required this.totalKm,
    required this.totalMin,
    required this.rating,
    required this.perKm,
    required this.perHour,
    required this.score,
    required this.verdict,
    required this.overallStatus,
    required this.kmStatus,
    required this.hourStatus,
    required this.ratingStatus,
  });

  final int time;
  final String source;
  final double price;
  final double pickupKm;
  final int pickupMin;
  final double tripKm;
  final int tripMin;
  final double totalKm;
  final int totalMin;
  final double? rating;
  final double perKm;
  final double perHour;
  final int score;
  final String verdict; // ACCEPT | MAYBE | REJECT
  final String overallStatus; // BAD | REGULAR | GOOD
  final String kmStatus;
  final String hourStatus;
  final String ratingStatus;

  factory OfferRecord.fromMap(Map<dynamic, dynamic> m) => OfferRecord(
        time: (m['time'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        source: (m['source'] as String?) ?? '',
        price: (m['price'] as num).toDouble(),
        pickupKm: (m['pickupKm'] as num).toDouble(),
        pickupMin: (m['pickupMin'] as num).toInt(),
        tripKm: (m['tripKm'] as num).toDouble(),
        tripMin: (m['tripMin'] as num).toInt(),
        totalKm: (m['totalKm'] as num?)?.toDouble() ??
            ((m['pickupKm'] as num).toDouble() + (m['tripKm'] as num).toDouble()),
        totalMin: (m['totalMin'] as num?)?.toInt() ??
            ((m['pickupMin'] as num).toInt() + (m['tripMin'] as num).toInt()),
        rating: (m['rating'] as num?)?.toDouble(),
        perKm: (m['perKm'] as num).toDouble(),
        perHour: (m['perHour'] as num).toDouble(),
        score: (m['score'] as num?)?.toInt() ?? 50,
        verdict: (m['verdict'] as String?) ?? 'REJECT',
        overallStatus: (m['overallStatus'] as String?) ?? 'REGULAR',
        kmStatus: (m['kmStatus'] as String?) ?? 'REGULAR',
        hourStatus: (m['hourStatus'] as String?) ?? 'REGULAR',
        ratingStatus: (m['ratingStatus'] as String?) ?? 'REGULAR',
      );
}

class Native {
  static const _channel = MethodChannel('ai.gcodeflow/native');

  static Future<bool> isAccessibilityEnabled() async =>
      (await _channel.invokeMethod<bool>('isAccessibilityEnabled')) ?? false;

  static Future<void> openAccessibilitySettings() =>
      _channel.invokeMethod('openAccessibilitySettings');

  static Future<AppSettings> getSettings() async {
    final m = await _channel.invokeMethod<Map<dynamic, dynamic>>('getSettings');
    return m == null ? const AppSettings() : AppSettings.fromMap(m);
  }

  static Future<void> saveSettings(AppSettings s) =>
      _channel.invokeMethod('saveSettings', s.toMap());

  static Future<Map<dynamic, dynamic>> testOverlay({
    String source = 'inDrive',
    double price = 17.0,
    double totalKm = 10.2,
    int totalMin = 23,
    double rating = 5.0,
  }) async {
    final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('testOverlay', {
      'source': source,
      'price': price,
      'totalKm': totalKm,
      'totalMin': totalMin,
      'rating': rating,
    });
    return res ?? {};
  }

  static Future<Map<String, dynamic>> analyzeScreenshot() async {
    final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('analyzeScreenshot');
    if (res == null) return {'success': false, 'message': 'Operação cancelada.'};
    return res.map((k, v) => MapEntry(k.toString(), v));
  }

  static Future<List<OfferRecord>> getHistory() async {
    final l = await _channel.invokeMethod<List<dynamic>>('getHistory') ?? const [];
    return l.map((e) => OfferRecord.fromMap(e as Map<dynamic, dynamic>)).toList();
  }
  

  static Future<void> clearHistory() => _channel.invokeMethod('clearHistory');
}
/// github
