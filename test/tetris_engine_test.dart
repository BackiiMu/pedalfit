import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalboard/game/tetris_engine.dart';

void main() {
  test(
    'seven-bag deals every shape once and all rotations contain four cells',
    () {
      final g = TetrisEngine(random: Random(42));
      final first = <Tetromino>{};
      for (var i = 0; i < 7; i++) {
        first.add(g.active.kind);
        g.hardDrop();
      }
      expect(first.length, 7);
      for (final k in Tetromino.values) {
        for (var r = 0; r < 4; r++) {
          expect(shapeCells(k, r).toSet().length, 4);
        }
      }
    },
  );
  test(
    'left wall, floor, ghost and immediate hard drop have valid collisions',
    () {
      final g = TetrisEngine(random: Random(1));
      g.active = const FallingPiece(Tetromino.t, y: 3);
      for (var i = 0; i < 20; i++) {
        g.move(-1);
      }
      expect(g.active.cells.map((p) => p.x).reduce(min), 0);
      expect(g.move(-1), isFalse);
      final ghost = g.ghost;
      expect(g.fits(ghost), isTrue);
      expect(g.fits(ghost.moved(0, 1)), isFalse);
      final distance = ghost.y - g.active.y;
      g.hardDrop();
      expect(g.pieces, 1);
      expect(g.score, distance * 2);
      expect(g.grid.expand((r) => r).whereType<Tetromino>().length, 4);
    },
  );
  test(
    'I and T use wall and floor kicks instead of clipping through walls',
    () {
      final g = TetrisEngine();
      g.active = const FallingPiece(Tetromino.i, x: -2, y: 5, rotation: 1);
      expect(g.fits(g.active), isTrue);
      expect(g.rotate(), isTrue);
      expect(g.active.rotation, 2);
      expect(g.fits(g.active), isTrue);
      g.active = const FallingPiece(Tetromino.t, x: 3, y: 18);
      expect(g.rotate(), isTrue);
      expect(g.fits(g.active), isTrue);
      expect(g.active.y, lessThan(18));
    },
  );
  test('blocked rotations do not change state', () {
    final g = TetrisEngine();
    for (final row in g.grid) {
      row.fillRange(0, 10, Tetromino.o);
    }
    g.active = const FallingPiece(Tetromino.t, x: 3, y: 8);
    for (final c in g.active.cells) {
      g.grid[c.y][c.x] = null;
    }
    expect(g.rotate(), isFalse);
    expect(g.active.rotation, 0);
  });
  test('hold swaps once per piece and resets rotation and position', () {
    final g = TetrisEngine();
    final original = g.active.kind;
    final next = g.next.first;
    g.hold();
    expect(g.held, original);
    expect(g.active.kind, next);
    g.hold();
    expect(g.active.kind, next);
    g.hardDrop();
    g.move(-1);
    g.rotate();
    g.hold();
    expect(g.active.kind, original);
    expect(g.active.x, 3);
    expect(g.active.rotation, 0);
  });
  test(
    'four-line clear scores on previous level and compacts surviving rows',
    () {
      final g = TetrisEngine();
      g.lines = 9;
      g.grid[15][0] = Tetromino.s;
      for (var y = 16; y < 20; y++) {
        for (var x = 0; x < 10; x++) {
          if (x != 5) g.grid[y][x] = Tetromino.o;
        }
      }
      g.active = const FallingPiece(Tetromino.i, x: 3, y: 16, rotation: 1);
      g.hardDrop();
      expect(g.lastClear, 4);
      expect(g.lines, 13);
      expect(g.level, 2);
      expect(g.score, 800);
      expect(g.grid[19][0], Tetromino.s);
      expect(g.grid.expand((r) => r).whereType<Tetromino>().length, 1);
    },
  );
  test(
    'pause freezes gravity and controls; landing has a 500ms lock delay',
    () {
      final g = TetrisEngine();
      final before = g.active;
      g.paused = true;
      g.advance(3);
      g.hardDrop();
      g.hold();
      g.move(1);
      g.rotate();
      g.softDrop();
      expect(g.active, before);
      expect(g.score, 0);
      g.paused = false;
      g.advance(.9);
      expect(g.active.y, greaterThan(before.y));
      g.active = g.ghost;
      g.advance(.45);
      expect(g.pieces, 0);
      g.advance(.06);
      expect(g.pieces, 1);
    },
  );
  test('lock resets are capped so grounded movement cannot stall forever', () {
    final g = TetrisEngine();
    g.active = const FallingPiece(Tetromino.o, x: 3, y: 18);
    for (var i = 0; i < 16; i++) {
      g.advance(.1);
      g.move(i.isEven ? -1 : 1);
    }
    g.advance(.5);
    expect(g.pieces, greaterThanOrEqualTo(1));
  });
  test('blocked spawn and above-top locking end the game', () {
    final g = TetrisEngine();
    for (var x = 3; x < 7; x++) {
      g.grid[0][x] = Tetromino.z;
    }
    g.active = const FallingPiece(Tetromino.o, x: 0, y: 18);
    g.hardDrop();
    expect(g.gameOver, isTrue);
    final score = g.score;
    g.advance(5);
    g.hardDrop();
    expect(g.score, score);
    final other = TetrisEngine();
    other.active = const FallingPiece(Tetromino.o, x: 3, y: -1);
    other.grid[1][4] = Tetromino.z;
    other.hardDrop();
    expect(other.gameOver, isTrue);
  });
}
