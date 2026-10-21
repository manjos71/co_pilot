import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gcodeflow/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    const channel = MethodChannel('ai.gcodeflow/native');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'getSettings') {
        return <String, dynamic>{};
      }
      return null;
    });
  });

  testWidgets('SettingsScreen renders without overflow on narrow device (360x800)',
      (WidgetTester tester) async {
    // Define tamanho da tela simulando aparelho estreito (360 dp de largura)
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0; // 360 logical width

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verifica que o título e a legenda do semáforo são renderizados
    expect(find.text('SEMÁFORO'), findsOneWidget);
    expect(find.text('Ruim (Recusar)'), findsOneWidget);
    expect(find.text('Atenção (Avaliar)'), findsOneWidget);
    expect(find.text('Bom (Aceitar)'), findsOneWidget);

    // Não deve haver nenhuma exceção de overflow
    expect(tester.takeException(), isNull);
  });

  testWidgets('SettingsScreen renders without overflow on extra narrow device (320x640)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2.0; // 320 logical width

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SEMÁFORO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
