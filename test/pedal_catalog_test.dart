import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:pedalboard/screens/pedal_library.dart';
import 'package:pedalboard/data/pedal_catalog.dart';
import 'package:pedalboard/models/pedal.dart';

void main() {
  testWidgets('wide real pedals and Korean search fit a narrow library', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PedalLibrary())),
    );
    await tester.enterText(find.byType(TextField), '쿼드코덱스');
    await tester.pumpAndSettle();
    expect(find.text('Quad Cortex mini'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), '톤엑스');
    await tester.pumpAndSettle();
    expect(find.text('TONEX Pedal'), findsOneWidget);
    expect(find.text('TONEX ONE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('real model footprints survive board persistence', () {
    final expected = {
      'ibanez_ts9': [74.0, 124.0],
      'ibanez_ts808': [70.0, 125.0],
      'ibanez_tsmini': [50.9, 92.6],
      'ibanez_ts9dx': [74.0, 124.0],
      'neural_quad_cortex_mini': [228.0, 118.0],
      'ehx_big_muff_pi': [139.7, 174.752],
      'ik_tonex_pedal': [176.0, 142.0],
      'ik_tonex_one': [48.0, 94.0],
    };
    for (final entry in expected.entries) {
      final pedal = Pedal.fromJson(
        pedalCatalog.singleWhere((p) => p.id == entry.key).toJson(),
      );
      expect([pedal.widthMm, pedal.depthMm], entry.value);
      expect(pedal.sourceUrl, startsWith('https://'));
      expect(pedal.brand, isNotEmpty);
    }
    expect(pedalCatalog.map((p) => p.id).toSet().length, pedalCatalog.length);
  });
  test('Korean model names are searchable and old saves remain readable', () {
    expect(pedalCatalog.where((p) => p.searchText.contains('톤엑스')).length, 2);
    expect(pedalCatalog.where((p) => p.searchText.contains('쿼드코덱스')).length, 1);
    final old = pedalCatalog.first.toJson()
      ..remove('brand')
      ..remove('artwork')
      ..remove('sourceUrl')
      ..remove('searchAliases');
    expect(Pedal.fromJson(old).artwork, 'stomp');
  });
}
