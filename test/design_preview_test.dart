import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pedalboard/design/app_design.dart';
import 'package:pedalboard/screens/my_boards_screen.dart';
import 'package:pedalboard/screens/pedal_library.dart';
import 'package:pedalboard/data/board_repository.dart';
import 'package:pedalboard/data/pedal_catalog.dart';
import 'package:pedalboard/models/board_project.dart';

class _DesignRepository extends BoardRepository {
  @override
  Future<List<BoardPreset>> presets() async => [
    BoardPreset.fromJson({
      'id': 'classic2',
      'model': 'Classic 2',
      'series': 'Classic',
      'width_mm': 609.6,
      'depth_mm': 317.5,
    }),
  ];
  @override
  Future<List<BoardProject>> load() async => [
    BoardProject(
      id: 'preview',
      name: '메인 보드',
      widthMm: 609.6,
      depthMm: 317.5,
      presetId: 'classic2',
      presetName: 'Classic 2',
      series: 'Classic',
      pedals: [
        PlacedPedal(
          id: 'ts9',
          pedal: pedalCatalog.singleWhere((p) => p.id == 'ibanez_ts9'),
          x: 24,
          y: 24,
        ),
        PlacedPedal(
          id: 'muff',
          pedal: pedalCatalog.singleWhere((p) => p.id == 'ehx_big_muff_pi'),
          x: 122,
          y: 24,
        ),
        PlacedPedal(
          id: 'tonex',
          pedal: pedalCatalog.singleWhere((p) => p.id == 'ik_tonex_pedal'),
          x: 290,
          y: 24,
        ),
      ],
    ),
  ];
}

void main() {
  testWidgets('paper theme keeps planner, library and game navigation readable', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const capture = bool.fromEnvironment('CAPTURE_DESIGN');
    if (capture) {
      await tester.runAsync(() async {
        final bytes = await File(
          '/System/Library/Fonts/AppleSDGothicNeo.ttc',
        ).readAsBytes();
        await (FontLoader(
          'PreviewKorean',
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        final icons = await File(
          '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ).readAsBytes();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(ByteData.sublistView(icons)))).load();
      });
    }
    final theme = buildAppTheme(fontFamily: capture ? 'PreviewKorean' : null);
    final boundary = GlobalKey();
    Future<void> shot(String name) async {
      if (!capture) return;
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('docs/design/paper-v1').create(recursive: true);
        await File(
          'docs/design/paper-v1/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: MyBoardsScreen(repository: _DesignRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.light,
    );
    expect(find.text('메인 보드'), findsOneWidget);
    await shot('01-boards');
    await tester.tap(find.text('메인 보드'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pedal-ts9')));
    await tester.pumpAndSettle();
    await shot('02-editor');
    await tester.tap(find.text('페달 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ibanez');
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(PedalLibrary),
        matching: find.text('TS9'),
      ),
      findsOneWidget,
    );
    await shot('03-library');
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('내 보드로 돌아가기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-tetris')));
    await tester.pumpAndSettle();
    await shot('04-games');
    await tester.tap(find.text('클래식 테트리스'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('tetris-start')),
      150,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('tetris-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tetris-start')));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text(i.isEven ? '왼쪽' : '오른쪽'));
      await tester.pump();
      await tester.tap(find.text('드롭'));
      await tester.pump();
    }
    await shot('05-tetris');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
