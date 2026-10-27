import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'tetris_engine.dart';

/// Cover occupied cells with the fewest large axis-aligned pedal enclosures.
/// I/O become one pedal, bent tetrominoes become two. Never fills an empty cell.
List<math.Rectangle<int>> pedalSegments(List<Cell> cells) {
  List<math.Rectangle<int>> cover(Set<Cell> remaining) {
    if (remaining.isEmpty) return [];
    final sorted = remaining.toList()
      ..sort((a, b) => a.y == b.y ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
    final first = sorted.first;
    final maxX = remaining.map((c) => c.x).reduce(math.max),
        maxY = remaining.map((c) => c.y).reduce(math.max);
    List<math.Rectangle<int>>? best;
    for (var w = maxX - first.x + 1; w >= 1; w--) {
      for (var h = maxY - first.y + 1; h >= 1; h--) {
        final covered = <Cell>{
          for (var y = first.y; y < first.y + h; y++)
            for (var x = first.x; x < first.x + w; x++) Cell(x, y),
        };
        if (!remaining.containsAll(covered)) continue;
        final candidate = [
          math.Rectangle(first.x, first.y, w, h),
          ...cover(remaining.difference(covered)),
        ];
        if (best == null || candidate.length < best.length) best = candidate;
        if (best.length == 1) return best;
      }
    }
    return best!;
  }

  return cover(cells.toSet());
}

void paintPedalPiece(
  Canvas canvas,
  List<Cell> cells,
  Tetromino kind,
  double cw,
  double ch,
  Offset origin, {
  bool ghost = false,
}) {
  const colors = [
    Color(0xFF76B7D8),
    Color(0xFFE5C86F),
    Color(0xFF88C994),
    Color(0xFFAB92D0),
    Color(0xFFD07873),
    Color(0xFF9EAFB5),
    Color(0xFFDE9C62),
  ];
  final color = colors[kind.index];
  for (final segment in pedalSegments(cells)) {
    final rect = Rect.fromLTWH(
      origin.dx + segment.left * cw,
      origin.dy + segment.top * ch,
      segment.width * cw,
      segment.height * ch,
    ).deflate(.7);
    final u = math.min(rect.width, rect.height);
    final r = RRect.fromRectAndRadius(rect, Radius.circular(u * .15));
    if (ghost) {
      canvas.drawRRect(
        r,
        Paint()..color = const Color(0xFFB9E4C1).withValues(alpha: .15),
      );
      canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFFB9E4C1).withValues(alpha: .7),
      );
      continue;
    }
    canvas.drawRRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, .2)!,
            color,
            Color.lerp(color, Colors.black, .3)!,
          ],
        ).createShader(rect),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..color = Colors.white30
        ..style = PaintingStyle.stroke,
    );
    final horizontal = rect.width > rect.height;
    final knob = horizontal
        ? Offset(rect.left + rect.width * .25, rect.center.dy)
        : Offset(rect.center.dx, rect.top + rect.height * .25);
    final foot = horizontal
        ? Offset(rect.left + rect.width * .76, rect.center.dy)
        : Offset(rect.center.dx, rect.top + rect.height * .77);
    canvas.drawCircle(knob, u * .19, Paint()..color = const Color(0xFF202925));
    canvas.drawLine(
      knob - Offset(0, u * .14),
      knob - Offset(0, u * .03),
      Paint()
        ..color = Colors.white70
        ..strokeWidth = math.max(.7, u * .04),
    );
    canvas.drawCircle(foot, u * .13, Paint()..color = const Color(0xFFD7DFD8));
    canvas.drawCircle(foot, u * .085, Paint()..color = const Color(0xFF9BA89F));
  }
}
