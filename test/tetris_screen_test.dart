import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pedalboard/game/tetris_engine.dart';
import 'package:pedalboard/game/tetris_screen.dart';
import 'package:pedalboard/models/board_project.dart';
import 'package:pedalboard/main.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final size in [
    const Size(320, 700),
    const Size(844, 390),
    const Size(1200, 900),
  ]) {
    testWidgets('game fits $size and pause stops controls and elapsed time', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late TetrisEngine g;
      await tester.pumpWidget(
        MaterialApp(
          home: TetrisScreen(
            boards: const [],
            engineFactory: () => g = TetrisEngine(random: Random(8)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('tetris-start')),
        180,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('tetris-start')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tetris-start')));
      await tester.pump();
      final x = g.active.x;
      await tester.tap(find.text('왼쪽'));
      await tester.pump();
      expect(g.active.x, x - 1);
      await tester.tap(find.byTooltip('일시정지'));
      await tester.pumpAndSettle();
      final y = g.active.y;
      await tester.pump(const Duration(seconds: 5));
      expect(g.active.y, y);
      expect(find.text('잠시 쉬어가기'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(FilledButton, '계속하기'));
      await tester.tap(find.widgetWithText(FilledButton, '계속하기'));
      await tester.pump();
      expect(g.paused, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'lifecycle pauses, score persists, restart clears state and leaves source board untouched',
    (tester) async {
      final board = BoardProject(
        id: 'saved',
        name: '내 클래식',
        widthMm: 600,
        depthMm: 300,
      );
      final before = board.toJson().toString();
      var round = 0;
      late TetrisEngine g;
      await tester.pumpWidget(
        MaterialApp(
          home: TetrisScreen(
            boards: [board],
            engineFactory: () {
              g = TetrisEngine(random: Random(round++));
              return g;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('tetris-start')),
        180,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('tetris-start')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tetris-start')));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(g.paused, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(g.paused, isTrue);
      await tester.tap(find.widgetWithText(FilledButton, '계속하기'));
      await tester.pump();
      for (var x = 3; x < 7; x++) {
        g.grid[0][x] = Tetromino.z;
      }
      g.active = const FallingPiece(Tetromino.o, x: 0, y: 18);
      g.score = 1234;
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.text('게임 종료'), findsOneWidget);
      expect(find.text('최고 기록 갱신!'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('pedalboard.tetris.best.v1'), 1234);
      await tester.tap(find.widgetWithText(FilledButton, '다시 시작'));
      await tester.pump();
      expect(g.score, 0);
      expect(g.gameOver, isFalse);
      expect(g.held, isNull);
      expect(board.toJson().toString(), before);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('home game entry works with no boards and returns to planner', (
    tester,
  ) async {
    await tester.pumpWidget(const PedalboardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-tetris')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('클래식 테트리스'));
    await tester.pumpAndSettle();
    expect(find.text('기본 페달보드'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('첫 페달보드를 만들어 보세요.'), findsOneWidget);
  });
}
