import 'package:flutter_test/flutter_test.dart';
import 'package:pedalboard/game/packing_engine.dart';
import 'package:pedalboard/models/board_project.dart';

BoardProject board(double w, double d) =>
    BoardProject(id: 'source', name: '원본', widthMm: w, depthMm: d);
void main() {
  test(
    'generated challenges always have a valid witness at actual catalog dimensions',
    () {
      for (final size in [
        (610.0, 318.0),
        (450.0, 300.0),
        (300.0, 150.0),
        (50.0, 50.0),
        (1000.0, 500.0),
      ]) {
        for (var seed = 0; seed < 12; seed++) {
          final source = board(size.$1, size.$2);
          final challenge = PackingChallenge.generate(source, seed: seed);
          final g = PackingEngine(challenge);
          for (var i = 0; i < challenge.pedals.length; i++) {
            expect(g.place(i, challenge.solution[i]), isTrue);
          }
          expect(g.placed, challenge.pedals.length);
          expect(source.pedals, isEmpty);
          if (size.$1 == 610) expect(challenge.pedals.length, 8);
        }
      }
    },
  );
  test(
    'overlap and bounds are rejected, drag undo and tray rotation restore state',
    () {
      final c = PackingChallenge.generate(board(610, 318));
      final g = PackingEngine(c);
      expect(g.place(0, c.solution[0]), isTrue);
      expect(
        g.place(1, PuzzlePlacement(c.solution[0].x, c.solution[0].y, 0)),
        isFalse,
      );
      expect(g.placements[1], isNull);
      expect(g.place(1, const PuzzlePlacement(-1, 0, 0)), isFalse);
      expect(g.mistakes, 2);
      g.select(1);
      g.rotate();
      expect(g.turns(1), 1);
      g.undo();
      expect(g.turns(1), 0);
      g.returnToTray(0);
      expect(g.placed, 0);
      g.undo();
      expect(g.placed, 1);
      expect(g.placements[0], c.solution[0]);
    },
  );
  test(
    'hint frees occupied solution position, is undoable, and never counts as clean record',
    () {
      final c = PackingChallenge.generate(board(610, 318));
      final g = PackingEngine(c);
      g.place(0, c.solution[0]);
      g.select(0);
      g.hint();
      expect(g.hints, 1);
      g.undo();
      expect(g.placements[0], c.solution[0]);
      expect(g.hints, 1);
      g.select(1);
      g.hint();
      while (!g.won) {
        g.hint();
      }
      expect(g.stars, 1);
      expect(g.placed, c.pedals.length);
      expect(g.canUndo, isFalse);
    },
  );
  test(
    'timer freezes on pause, expires, and completed games stop changing',
    () {
      final c = PackingChallenge.generate(board(610, 318));
      final g = PackingEngine(c, timed: true, limitSeconds: 10);
      g.advance(3);
      g.setPaused(true);
      g.advance(20);
      expect(g.remainingSeconds, 7);
      expect(g.place(0, c.solution[0]), isFalse);
      g.setPaused(false);
      g.advance(7);
      expect(g.expired, isTrue);
      expect(g.place(0, c.solution[0]), isFalse);
      final free = PackingEngine(c);
      free.advance(500);
      expect(free.expired, isFalse);
      for (var i = 0; i < c.pedals.length; i++) {
        free.place(i, c.solution[i]);
      }
      free.advance(10);
      expect(free.elapsed, 500);
    },
  );
  test('export creates an independent new board with body-only placements', () {
    final source = board(610, 318);
    final c = PackingChallenge.generate(source);
    final g = PackingEngine(c);
    for (var i = 0; i < c.pedals.length; i++) {
      g.place(i, c.solution[i]);
    }
    final result = g.exportBoard();
    expect(result.id, isNot(source.id));
    expect(result.pedals.length, 8);
    expect(source.pedals, isEmpty);
    expect(result.pedals.every((p) => p.leftMm == 0 && p.rightMm == 0), isTrue);
    result.pedals.first.x = 999;
    expect(g.placements.first!.x, isNot(999));
  });
}
