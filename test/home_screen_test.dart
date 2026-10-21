import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gcodeflow/screens/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    const channel = MethodChannel('ai.gcodeflow/native');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'isAccessibilityEnabled':
          return true;
        case 'getSettings':
          return <String, dynamic>{};
        case 'getHistory':
          return <dynamic>[];
        case 'analyzeScreenshot':
          return <String, dynamic>{
            'success': true,
            'time': DateTime.now().millisecondsSinceEpoch,
            'source': 'inDrive',
            'price': 28.0,
            'pickupKm': 4.9,
            'pickupMin': 17,
            'tripKm': 17.4,
            'tripMin': 19,
            'totalKm': 22.3,
            'totalMin': 36,
            'rating': 4.76,
            'perKm': 1.256,
            'perHour': 46.67,
            'score': 45,
            'verdict': 'REJECT',
            'overallStatus': 'BAD',
            'kmStatus': 'BAD',
            'hourStatus': 'REGULAR',
            'ratingStatus': 'BAD',
          };
        default:
          return null;
      }
    });
  });

  testWidgets('HomeScreen renders OCR Scan Card and opens analysis modal',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HomeScreen(active: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verifica card do OCR
    expect(find.text('Analisar Print da Galeria'), findsOneWidget);
    expect(find.text('LER'), findsOneWidget);

    // Toca no botão LER
    await tester.tap(find.text('LER'));
    await tester.pumpAndSettle();

    // Verifica que o modal abre com os dados analisados do print
    expect(find.text('Print Lido com Sucesso (inDrive)'), findsOneWidget);
    expect(find.text('22.3km - 36min'), findsOneWidget);

    // Fecha o modal
    await tester.tap(find.text('FECHAR'));
    await tester.pumpAndSettle();

    expect(find.text('Print Lido com Sucesso (inDrive)'), findsNothing);
  });
}
