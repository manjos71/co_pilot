import 'package:flutter_test/flutter_test.dart';
import 'package:gcodeflow/bridge.dart';
import 'package:gcodeflow/widgets/semaforo_tarja.dart';

void main() {
  group('Semáforo Logic Tests', () {
    test('Calculates BAD status when \$/Km is below Ruim threshold (Image 3 case)', () {
      const cfg = SemaforoConfig(
        kmRuim: 1.90,
        kmBom: 2.00,
        horaRuim: 43.0,
        horaBom: 48.0,
        notaRuim: 4.80,
        notaBom: 4.90,
      );

      // Corrida da imagem 3: R$ 17, 10.2km, 23min, nota 5.0
      const widget = SemaforoTarjaWidget(
        source: 'inDrive',
        totalKm: 10.2,
        totalMin: 23,
        price: 17.0,
        rating: 5.0,
        config: cfg,
      );

      expect(widget.perKm, closeTo(1.666, 0.01));
      expect(widget.perHour, closeTo(44.347, 0.01));
      expect(widget.kmStatus, equals('BAD'));
      expect(widget.hourStatus, equals('REGULAR')); // 44.35 is between 43.0 and 48.0
      expect(widget.ratingStatus, equals('GOOD'));
      // Como $/Km foi RUIM, o Semáforo Geral da Tarja fica VERMELHO (BAD)
      expect(widget.overallStatus, equals('BAD'));
    });

    test('Calculates GOOD status when all metrics exceed Bom thresholds', () {
      const cfg = SemaforoConfig(
        kmRuim: 1.90,
        kmBom: 2.00,
        horaRuim: 43.0,
        horaBom: 48.0,
        notaRuim: 4.80,
        notaBom: 4.90,
      );

      // Corrida lucrativa: R$ 35, 12km, 25min, nota 4.95
      const widget = SemaforoTarjaWidget(
        source: 'Uber',
        totalKm: 12.0,
        totalMin: 25,
        price: 35.0,
        rating: 4.95,
        config: cfg,
      );

      expect(widget.perKm, closeTo(2.916, 0.01));
      expect(widget.perHour, closeTo(84.0, 0.01));
      expect(widget.kmStatus, equals('GOOD'));
      expect(widget.hourStatus, equals('GOOD'));
      expect(widget.ratingStatus, equals('GOOD'));
      expect(widget.overallStatus, equals('GOOD'));
    });

    test('Calculates inDrive ride from user screenshot: R\$ 10,00, 3,5 km, 14 min (Nota 5.0)', () {
      const cfg = SemaforoConfig(
        kmRuim: 1.90,
        kmBom: 2.00,
        horaRuim: 40.0,
        horaBom: 45.0,
        notaRuim: 4.80,
        notaBom: 4.90,
      );

      // Corrida do print: 3,5 km e 14 min por R$ 10,00 (Embarque 2,3km/7min + Viagem 1,2km/7min)
      const widget = SemaforoTarjaWidget(
        source: 'inDrive',
        totalKm: 3.5,
        totalMin: 14,
        price: 10.0,
        rating: 5.0,
        config: cfg,
      );

      // 10.0 / 3.5 = 2.857... R$/Km (R$ 2,86/km)
      expect(widget.perKm, closeTo(2.857, 0.01));
      // 10.0 / (14 / 60) = 42.857... R$/Hora (R$ 42,86/h)
      expect(widget.perHour, closeTo(42.857, 0.01));
      // Com $/Km acima de 2.00 (2.86 >= 2.00), kmStatus é GOOD
      expect(widget.kmStatus, equals('GOOD'));
      // 42.86 $/Hora está entre 40.0 e 45.0 -> REGULAR
      expect(widget.hourStatus, equals('REGULAR'));
      // Nota 5.0 >= 4.90 -> GOOD
      expect(widget.ratingStatus, equals('GOOD'));
      expect(widget.overallStatus, equals('REGULAR'));
    });

    test('Calculates inDrive ride Isabela: R\$ 28,00, 22,3 km (4,9 + 17,4), 48 min (17 + 31), Nota 4.76', () {
      const cfg = SemaforoConfig(
        kmRuim: 1.90,
        kmBom: 2.00,
        horaRuim: 40.0,
        horaBom: 45.0,
        notaRuim: 4.80,
        notaBom: 4.90,
      );

      // Corrida Isabela: 4,9 km / 17 min (ponto A) + 17,4 km / 31 min (ponto B) = 22,3 km e 48 min
      const widget = SemaforoTarjaWidget(
        source: 'inDrive',
        totalKm: 22.3,
        totalMin: 48,
        price: 28.0,
        rating: 4.76,
        config: cfg,
      );

      // 28.0 / 22.3 = 1.2556... R$/Km -> 1.26 $/Km (RUIM / BAD)
      expect(widget.perKm, closeTo(1.256, 0.01));
      expect(widget.kmStatus, equals('BAD'));

      // 28.0 / (48 / 60) = 35.00 R$/Hora -> 35.00 $/Hora (RUIM / BAD, pois < 40.0)
      expect(widget.perHour, closeTo(35.0, 0.01));
      expect(widget.hourStatus, equals('BAD'));

      // Nota 4.76 < 4.80 -> RUIM / BAD
      expect(widget.ratingStatus, equals('BAD'));

      // Tarja Geral: BAD
      expect(widget.overallStatus, equals('BAD'));
    });

    test('Calculates inDrive ride 17min + 19min (36 min total), 22,3 km por R\$ 28,00', () {
      const cfg = SemaforoConfig(
        kmRuim: 1.90,
        kmBom: 2.00,
        horaRuim: 40.0,
        horaBom: 48.0,
        notaRuim: 4.80,
        notaBom: 4.90,
      );

      // Cenário com 17 min (Embarque) + 19 min (Viagem) = 36 min e 22,3 km
      const widget = SemaforoTarjaWidget(
        source: 'inDrive',
        totalKm: 22.3,
        totalMin: 36,
        price: 28.0,
        rating: 4.76,
        config: cfg,
      );

      // 28.0 / 22.3 = 1.256 $/Km (RUIM / BAD)
      expect(widget.perKm, closeTo(1.256, 0.01));
      expect(widget.kmStatus, equals('BAD'));

      // 28.0 / (36 / 60) = 46.667 $/Hora (REGULAR / ATENÇÃO, entre 40.0 e 48.0)
      expect(widget.perHour, closeTo(46.67, 0.01));
      expect(widget.hourStatus, equals('REGULAR'));

      // Nota 4.76 < 4.80 -> RUIM / BAD
      expect(widget.ratingStatus, equals('BAD'));

      // Como $/Km foi RUIM e Nota foi RUIM, o Semáforo Geral da Tarja fica BAD
      expect(widget.overallStatus, equals('BAD'));
    });

    test('Per-app settings override global config properly', () {
      const global = SemaforoConfig(kmRuim: 1.80, kmBom: 2.00);
      const uberCustom = SemaforoConfig(kmRuim: 2.20, kmBom: 2.50);

      const appSettings = AppSettings(
        global: global,
        uber: uberCustom,
        uberEnabled: true,
      );

      expect(appSettings.getForApp('Uber').kmRuim, equals(2.20));
      expect(appSettings.getForApp('99').kmRuim, equals(1.80)); // Fallback para global
    });
  });
}
