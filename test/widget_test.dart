import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pedalboard/main.dart';
import 'package:pedalboard/data/board_repository.dart';
import 'package:pedalboard/models/board_project.dart';
import 'package:pedalboard/widgets/board_canvas.dart';
import 'package:pedalboard/screens/board_screen.dart';
import 'package:pedalboard/data/pedal_catalog.dart';

class TestRepository extends BoardRepository {
  @override
  Future<List<BoardPreset>> presets() async => [
    BoardPreset.fromJson({
      'id': 'pedaltrain_classic_2',
      'model': 'Classic 2',
      'series': 'Classic',
      'width_mm': 609.6,
      'depth_mm': 317.5,
    }),
  ];
}

class SeedRepository extends TestRepository {
  @override
  Future<List<BoardProject>> load() async => [
    BoardProject(
      id: 'seed',
      name: '테스트 보드',
      widthMm: 600,
      depthMm: 320,
      pedals: [
        PlacedPedal(id: 'test-pedal', pedal: pedalCatalog[3], x: 20, y: 20),
      ],
    ),
  ];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final size in [const Size(320, 700), const Size(1200, 900)]) {
    testWidgets('empty home and preset creation fit $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(PedalboardApp(repository: TestRepository()));
      await tester.pumpAndSettle();
      expect(find.text('첫 페달보드를 만들어 보세요.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('create-board')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Classic 2'), findsAtLeastNWidgets(1));
    });
  }
  testWidgets('create custom board, add, drag, rotate, undo, save and reopen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(PedalboardApp(repository: TestRepository()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-board')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('커스텀').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('board-width')), '600');
    await tester.enterText(find.byKey(const ValueKey('board-depth')), '320');
    await tester.tap(find.text('이 보드로 시작'));
    await tester.pumpAndSettle();
    expect(find.byType(BoardScreen), findsOneWidget);
    await tester.tap(find.text('페달 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mini Boost'));
    await tester.pumpAndSettle();
    final c = tester
        .widget<BoardCanvas>(find.byType(BoardCanvas).last)
        .controller!;
    final id = c.selected!.id;
    final oldX = c.selected!.x;
    await tester.drag(find.byKey(ValueKey('pedal-$id')), const Offset(45, 15));
    await tester.pumpAndSettle();
    expect(c.selected!.x, isNot(oldX));
    await tester.tap(find.byTooltip('확대'));
    await tester.pumpAndSettle();
    final state = tester.state<BoardCanvasState>(find.byType(BoardCanvas).last);
    c.setSnap(false);
    await tester.pump();
    final beforeZoomDrag = c.selected!.x;
    await tester.drag(
      find.byKey(ValueKey('pedal-$id')),
      Offset(40 * state.fit * state.transform.value.getMaxScaleOnAxis(), 0),
    );
    await tester.pumpAndSettle();
    expect(c.selected!.x - beforeZoomDrag, closeTo(40, 0.1));
    await tester.tap(find.byTooltip('90도 회전'));
    await tester.pumpAndSettle();
    expect(c.selected!.turns, 1);
    await tester.tap(find.byTooltip('실행 취소'));
    await tester.pumpAndSettle();
    expect(c.project.pedals.single.turns, 0);
    await tester.tap(find.byTooltip('보드 저장'));
    await tester.pumpAndSettle();
    expect(c.isDirty, false);
    await tester.tap(find.byTooltip('내 보드로 돌아가기'));
    await tester.pumpAndSettle();
    expect(find.text('페달 1개'), findsOneWidget);
    await tester.tap(find.text('새 페달보드'));
    await tester.pumpAndSettle();
    final reloaded = tester
        .widget<BoardCanvas>(find.byType(BoardCanvas).last)
        .controller!;
    expect(reloaded.project.pedals.single.id, id);
  });

  for (final size in [
    const Size(320, 700),
    const Size(844, 390),
    const Size(1200, 900),
  ]) {
    testWidgets('selected editor and library fit $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(PedalboardApp(repository: SeedRepository()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('테스트 보드'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('테스트 보드'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pedal-test-pedal')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('90도 회전'), findsOneWidget);
      await tester.tap(find.text('페달 추가'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('커스텀 페달 만들기'));
      await tester.pumpAndSettle();
      expect(find.text('만들고 보드에 추가'), findsOneWidget);
      if (size.width == 320) {
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'My Fuzz');
        await tester.enterText(fields.at(1), '0');
        await tester.tap(find.text('만들고 보드에 추가'));
        await tester.pumpAndSettle();
        expect(find.text('10–1500 mm'), findsOneWidget);
        await tester.enterText(fields.at(1), '70');
        await tester.tap(find.text('만들고 보드에 추가'));
        await tester.pumpAndSettle();
        final board = tester
            .widget<BoardCanvas>(find.byType(BoardCanvas).last)
            .controller!;
        expect(board.selected!.pedal.isCustom, true);
        expect(board.selected!.pedal.name, 'My Fuzz');
        expect(board.selected!.leftMm, 12);
      }
    });
  }

  testWidgets('discarding edits leaves the saved project unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(PedalboardApp(repository: SeedRepository()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('테스트 보드'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('테스트 보드'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pedal-test-pedal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('페달 복제'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('내 보드로 돌아가기'));
    await tester.pumpAndSettle();
    expect(find.text('변경 사항을 저장할까요?'), findsOneWidget);
    await tester.tap(find.text('저장 안 함'));
    await tester.pumpAndSettle();
    expect(find.text('페달 1개'), findsOneWidget);
  });
}
