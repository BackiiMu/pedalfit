import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalboard/game/tetris_engine.dart';
import 'package:pedalboard/game/tetris_skin.dart';

void main() {
  testWidgets('render all seven pedal skins', (tester) async {
    if (!const bool.fromEnvironment('CAPTURE_SKINS')) return;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFF101A14), BlendMode.src);
    for (var i = 0; i < Tetromino.values.length; i++) {
      final kind = Tetromino.values[i],
          cells = shapeCells(Tetromino.values[i], 0);
      paintPedalPiece(canvas, cells, kind, 28, 28, Offset(i * 130 + 8, 35));
    }
    final picture = recorder.endRecording();
    await tester.runAsync(() async {
      final image = await picture.toImage(920, 145);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'docs/implementation/tetris-pedal-skins.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    picture.dispose();
  });
  test(
    'I and O are single pedals; all other pieces use two, with exact cell coverage',
    () {
      for (final kind in Tetromino.values) {
        for (var r = 0; r < 4; r++) {
          final cells = shapeCells(kind, r),
              parts = pedalSegments(shapeCells(kind, r));
          expect(
            parts.length,
            kind == Tetromino.i || kind == Tetromino.o ? 1 : 2,
          );
          final covered = <Cell>[];
          for (final rect in parts) {
            for (var y = rect.top; y < rect.bottom; y++) {
              for (var x = rect.left; x < rect.right; x++) {
                covered.add(Cell(x, y));
              }
            }
          }
          expect(covered.length, 4);
          expect(covered.toSet(), cells.toSet());
        }
      }
    },
  );
  test(
    'pedal identity survives line clear and separate touching pieces stay separate',
    () {
      final g = TetrisEngine();
      g.grid[15][0] = Tetromino.s;
      g.pieceIds[15][0] = 91;
      for (var y = 16; y < 20; y++) {
        for (var x = 0; x < 10; x++) {
          if (x != 5) {
            g.grid[y][x] = Tetromino.o;
            g.pieceIds[y][x] = 92;
          }
        }
      }
      g.active = const FallingPiece(Tetromino.i, x: 3, y: 16, rotation: 1);
      g.hardDrop();
      expect(g.lastClear, 4);
      expect(g.pieceIds[19][0], 91);
      expect(g.pieceIds.expand((r) => r).whereType<int>().toList(), [91]);
      g.active = const FallingPiece(Tetromino.o, x: 3, y: 16);
      g.hardDrop();
      final firstId = g.pieceIds[19][4];
      g.active = const FallingPiece(Tetromino.o, x: 5, y: 16);
      g.hardDrop();
      expect(g.pieceIds[19][6], isNot(firstId));
    },
  );
}
