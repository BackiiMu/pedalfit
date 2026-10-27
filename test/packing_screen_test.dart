import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pedalboard/main.dart';
import 'package:pedalboard/design/app_design.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pedalboard/game/packing_engine.dart';
import 'package:pedalboard/game/packing_screen.dart';
import 'package:pedalboard/models/board_project.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final size in [
    const Size(320, 700),
    const Size(390, 844),
    const Size(844, 390),
    const Size(1200, 900),
  ]) {
    testWidgets('packing drag and controls fit $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const capture = bool.fromEnvironment('CAPTURE_PACKING');
      if (capture) {
        await tester.runAsync(() async {
          final bytes = await File(
            '/System/Library/Fonts/AppleSDGothicNeo.ttc',
          ).readAsBytes();
          final loader = FontLoader('PreviewKorean')
            ..addFont(Future.value(ByteData.sublistView(bytes)));
          await loader.load();
          await (FontLoader(
            'Ahem',
          )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
          final icons = await File(
            '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytes();
          await (FontLoader(
            'MaterialIcons',
          )..addFont(Future.value(ByteData.sublistView(icons)))).load();
        });
      }
      late ThemeData appTheme;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            appTheme =
                (const PedalboardApp().build(context) as MaterialApp).theme!;
            return const SizedBox();
          },
        ),
      );
      final boundary = GlobalKey();
      late PackingEngine g;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: capture
              ? buildAppTheme(fontFamily: 'PreviewKorean')
              : appTheme,
          home: RepaintBoundary(
            key: boundary,
            child: PackingScreen(
              boards: [
                BoardProject(
                  id: 'source',
                  name: 'Classic 2',
                  presetId: 'pedaltrain_classic_2',
                  presetName: 'Classic 2',
                  widthMm: 610,
                  depthMm: 318,
                ),
              ],
              presets: const [],
              onSave: (_) async {},
              engineFactory: (c, t) => g = PackingEngine(c, timed: t),
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('packing-start')),
        200,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('packing-start')));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('packing-start')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('packing-start')));
      await tester.pumpAndSettle();
      final deck = tester.getRect(find.byKey(const ValueKey('packing-drop')));
      final scale = math.min((deck.width - 80) / 610, (deck.height - 96) / 318);
      final origin = deck.center - Offset(610 * scale / 2, 318 * scale / 2);
      final i = 0, solution = g.challenge.solution[i];
      g.select(i);
      if (solution.turns != 0) g.rotate();
      await tester.pump();
      final area = g.rect(i, solution);
      final center =
          origin +
          Offset(
            (solution.x + area.width / 2) * scale,
            (solution.y + area.height / 2) * scale,
          );
      await tester.dragFrom(
        tester.getCenter(find.byKey(const ValueKey('packing-tray-0'))),
        center - tester.getCenter(find.byKey(const ValueKey('packing-tray-0'))),
      );
      await tester.pumpAndSettle();
      expect(g.placements[0]!.x, closeTo(solution.x, 1));
      expect(g.placements[0]!.y, closeTo(solution.y, 1));
      if (capture && size.width == 390) {
        for (var j = 1; j < 5; j++) {
          g.place(j, g.challenge.solution[j]);
        }
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'docs/implementation/packing-play.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(g.placed, capture && size.width == 390 ? 5 : 1);
      expect(find.byKey(const ValueKey('packing-placed-0')), findsOneWidget);
      await tester.tap(find.byTooltip('퍼즐 일시정지'));
      await tester.pumpAndSettle();
      expect(g.paused, isTrue);
      await tester.tap(find.text('계속하기'));
      await tester.pumpAndSettle();
      expect(g.paused, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'last drag completion, pending save navigation and stale drop callbacks are safe',
    (tester) async {
      late PackingEngine g;
      final saved = Completer<void>();
      final exported = <BoardProject>[];
      await tester.pumpWidget(
        MaterialApp(
          home: PackingScreen(
            boards: const [],
            presets: const [],
            engineFactory: (c, t) => g = PackingEngine(c, timed: t),
            onSave: (p) {
              exported.add(p);
              return saved.future;
            },
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('packing-start')),
        200,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('packing-start')));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('packing-start')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('packing-start')));
      await tester.pumpAndSettle();
      final oldTarget = tester.widget<DragTarget<int>>(
        find.byKey(const ValueKey('packing-drop')),
      );
      final last = g.placements.length - 1;
      for (var i = 0; i < last; i++) {
        g.place(i, g.challenge.solution[i]);
      }
      g.select(last);
      final solution = g.challenge.solution[last];
      if (solution.turns != 0) g.rotate();
      await tester.pumpAndSettle();
      final deck = tester.getRect(find.byKey(const ValueKey('packing-drop')));
      final b = g.challenge.board;
      final scale = math.min(
        (deck.width - 80) / b.widthMm,
        (deck.height - 96) / b.depthMm,
      );
      final origin =
          deck.center - Offset(b.widthMm * scale / 2, b.depthMm * scale / 2);
      final area = g.rect(last, solution);
      final center =
          origin +
          Offset(
            (solution.x + area.width / 2) * scale,
            (solution.y + area.height / 2) * scale,
          );
      final source = tester.getCenter(
        find.byKey(ValueKey('packing-tray-$last')),
      );
      await tester.dragFrom(source, center - source);
      await tester.pumpAndSettle();
      expect(find.text('배치 완료'), findsOneWidget);
      await tester.ensureVisible(find.text('배치 저장'));
      await tester.tap(find.text('배치 저장'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('저장 중…'), findsOneWidget);
      saved.complete();
      await tester.pumpAndSettle();
      expect(exported.length, 1);
      await tester.ensureVisible(find.text('다른 보드 선택'));
      await tester.tap(find.text('다른 보드 선택'));
      await tester.pumpAndSettle();
      oldTarget.onMove?.call(DragTargetDetails(data: 0, offset: Offset.zero));
      oldTarget.onAcceptWithDetails?.call(
        DragTargetDetails(data: 0, offset: Offset.zero),
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('packing-start')),
        200,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('packing-start')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('packing-start')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('packing-start')));
      await tester.pumpAndSettle();
      oldTarget.onAcceptWithDetails?.call(
        DragTargetDetails(data: 0, offset: Offset.zero),
      );
      expect(g.placed, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'result, record, failed save retry, independent saved layout, and restart',
    (tester) async {
      late PackingEngine g;
      BoardProject? saved;
      var fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: PackingScreen(
            boards: const [],
            presets: const [],
            engineFactory: (c, t) => g = PackingEngine(c, timed: t),
            onSave: (p) async {
              if (fail) throw StateError('storage');
              saved = p;
            },
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('packing-start')),
        200,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('packing-start')));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('packing-start')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('packing-start')));
      await tester.pumpAndSettle();
      g.advance(12);
      for (var i = 0; i < g.challenge.pedals.length; i++) {
        g.place(i, g.challenge.solution[i]);
      }
      await tester.pumpAndSettle();
      expect(find.text('배치 완료'), findsOneWidget);
      expect(find.text('힌트 없는 최고 기록 갱신!'), findsOneWidget);
      await tester.tap(find.text('배치 저장'));
      await tester.pumpAndSettle();
      expect(find.textContaining('배치를 저장하지 못했습니다'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('배치 저장'));
      await tester.pumpAndSettle();
      expect(saved!.pedals.length, 8);
      expect(find.text('내 보드에 저장했어요'), findsOneWidget);
      await tester.tap(find.text('다시 도전'));
      await tester.pumpAndSettle();
      expect(g.placed, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
