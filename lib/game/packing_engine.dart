import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../data/pedal_catalog.dart';
import '../models/board_project.dart';
import '../models/pedal.dart';

class PuzzlePlacement {
  const PuzzlePlacement(this.x, this.y, this.turns);
  final double x, y;
  final int turns;
}

class PackingChallenge {
  PackingChallenge(this.board, this.pedals, this.solution);
  final BoardProject board;
  final List<Pedal> pedals;
  final List<PuzzlePlacement> solution;

  /// Every problem is built from a real, non-overlapping witness layout.
  static PackingChallenge generate(
    BoardProject source, {
    int count = 8,
    int seed = 0,
  }) {
    final random = math.Random(seed);
    final board = source.copy()..pedals.clear();
    var bestPedals = <Pedal>[];
    var bestSolution = <PuzzlePlacement>[];
    for (var attempt = 0; attempt < 64; attempt++) {
      final candidates = pedalCatalog.toList()..shuffle(random);
      final free = [
        math.Rectangle<double>(
          6,
          6,
          math.max(0, board.widthMm - 12),
          math.max(0, board.depthMm - 12),
        ),
      ];
      final pedals = <Pedal>[];
      final solution = <PuzzlePlacement>[];
      for (final pedal in candidates) {
        var added = false;
        for (var r = 0; r < free.length && !added; r++) {
          for (var turn = 0; turn < 2; turn++) {
            final w = (turn == 0 ? pedal.widthMm : pedal.depthMm) + 6;
            final h = (turn == 0 ? pedal.depthMm : pedal.widthMm) + 6;
            final area = free[r];
            if (w > area.width || h > area.height) continue;
            free.removeAt(r);
            free.add(
              math.Rectangle(area.left + w, area.top, area.width - w, h),
            );
            free.add(
              math.Rectangle(
                area.left,
                area.top + h,
                area.width,
                area.height - h,
              ),
            );
            pedals.add(pedal);
            solution.add(PuzzlePlacement(area.left, area.top, turn));
            added = true;
            break;
          }
        }
        if (pedals.length == count) break;
      }
      if (pedals.length > bestPedals.length) {
        bestPedals = pedals;
        bestSolution = solution;
      }
      if (bestPedals.length == count) break;
    }
    return PackingChallenge(board, bestPedals, bestSolution);
  }
}

class PackingEngine extends ChangeNotifier {
  PackingEngine(this.challenge, {this.timed = false, this.limitSeconds = 120})
    : placements = List.filled(challenge.pedals.length, null),
      trayTurns = List.filled(challenge.pedals.length, 0);
  final PackingChallenge challenge;
  final bool timed;
  final int limitSeconds;
  List<PuzzlePlacement?> placements;
  List<int> trayTurns;
  final List<(List<PuzzlePlacement?>, List<int>)> _undo = [];
  int? selected;
  int hints = 0, mistakes = 0;
  double elapsed = 0;
  bool paused = false;
  String? message;
  int get placed => placements.whereType<PuzzlePlacement>().length;
  int get remainingSeconds => math.max(0, (limitSeconds - elapsed).ceil());
  bool get won => placements.isNotEmpty && placed == placements.length;
  bool get expired => timed && elapsed >= limitSeconds && !won;
  bool get finished => won || expired;
  bool get canUndo => _undo.isNotEmpty && !finished && !paused;
  int get stars => hints == 0 && mistakes == 0
      ? 3
      : hints <= 2
      ? 2
      : 1;
  int turns(int index) => placements[index]?.turns ?? trayTurns[index];
  math.Rectangle<double> rect(int index, PuzzlePlacement p) {
    final pedal = challenge.pedals[index];
    return math.Rectangle(
      p.x,
      p.y,
      p.turns.isOdd ? pedal.depthMm : pedal.widthMm,
      p.turns.isOdd ? pedal.widthMm : pedal.depthMm,
    );
  }

  bool fits(int index, PuzzlePlacement p) {
    if (index < 0 ||
        index >= placements.length ||
        !p.x.isFinite ||
        !p.y.isFinite) {
      return false;
    }
    final area = rect(index, p), board = challenge.board;
    if (area.left < 0 ||
        area.top < 0 ||
        area.right > board.widthMm + .0001 ||
        area.bottom > board.depthMm + .0001) {
      return false;
    }
    for (var i = 0; i < placements.length; i++) {
      if (i == index || placements[i] == null) continue;
      final other = rect(i, placements[i]!);
      if (area.left < other.right - .001 &&
          area.right > other.left + .001 &&
          area.top < other.bottom - .001 &&
          area.bottom > other.top + .001) {
        return false;
      }
    }
    return true;
  }

  void select(int i) {
    if (!finished && !paused) {
      selected = i;
      notifyListeners();
    }
  }

  void _snapshot() {
    _undo.add((placements.toList(), trayTurns.toList()));
    if (_undo.length > 80) _undo.removeAt(0);
  }

  bool place(int i, PuzzlePlacement p) {
    if (finished || paused) return false;
    selected = i;
    if (!fits(i, p)) {
      mistakes++;
      message = '겹치거나 보드 밖으로 나갔어요. 다른 위치에 놓아보세요.';
      notifyListeners();
      return false;
    }
    _snapshot();
    placements[i] = p;
    trayTurns[i] = p.turns;
    message = null;
    notifyListeners();
    return true;
  }

  void rotate() {
    final i = selected;
    if (i == null || finished || paused) return;
    final turn = (turns(i) + 1) % 4, old = placements[i];
    if (old != null) {
      place(i, PuzzlePlacement(old.x, old.y, turn));
    } else {
      _snapshot();
      trayTurns[i] = turn;
      message = null;
      notifyListeners();
    }
  }

  void returnToTray(int i) {
    if (finished || paused || placements[i] == null) return;
    _snapshot();
    placements[i] = null;
    message = null;
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    final previous = _undo.removeLast();
    placements = previous.$1;
    trayTurns = previous.$2;
    message = null;
    notifyListeners();
  }

  void hint() {
    if (finished || paused) return;
    final i = selected ?? placements.indexOf(null);
    if (i < 0) return;
    _snapshot();
    final target = challenge.solution[i], area = rect(i, challenge.solution[i]);
    var returned = 0;
    for (var j = 0; j < placements.length; j++) {
      if (j == i || placements[j] == null) continue;
      final other = rect(j, placements[j]!);
      if (area.left < other.right &&
          area.right > other.left &&
          area.top < other.bottom &&
          area.bottom > other.top) {
        placements[j] = null;
        returned++;
      }
    }
    placements[i] = target;
    trayTurns[i] = target.turns;
    hints++;
    selected = placements.indexOf(null);
    if (selected == -1) selected = null;
    message = returned == 0
        ? '힌트 위치에 페달 하나를 배치했어요.'
        : '힌트 위치를 비우고 겹친 페달 $returned개를 대기로 돌렸어요.';
    notifyListeners();
  }

  void advance(double seconds) {
    if (finished || paused || seconds <= 0 || !seconds.isFinite) return;
    elapsed += seconds;
    notifyListeners();
  }

  void setPaused(bool value) {
    if (!finished) {
      paused = value;
      notifyListeners();
    }
  }

  BoardProject exportBoard() {
    final board = challenge.board.copy();
    return BoardProject(
      id: newId(),
      name: '${board.name} · 퍼즐 결과',
      widthMm: board.widthMm,
      depthMm: board.depthMm,
      presetId: board.presetId,
      presetName: board.presetName,
      originPresetId: board.originPresetId,
      series: board.series,
      colorValue: board.colorValue,
      pedals: [
        for (var i = 0; i < placements.length; i++)
          if (placements[i] != null)
            PlacedPedal(
              id: newId(),
              pedal: challenge.pedals[i],
              x: placements[i]!.x,
              y: placements[i]!.y,
              turns: placements[i]!.turns,
              leftMm: 0,
              rightMm: 0,
            ),
      ],
    );
  }
}
