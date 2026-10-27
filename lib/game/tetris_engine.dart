import 'dart:math';

enum Tetromino { i, o, t, s, z, j, l }

typedef Cell = Point<int>;

class FallingPiece {
  const FallingPiece(this.kind, {this.x = 3, this.y = -1, this.rotation = 0});
  final Tetromino kind;
  final int x, y, rotation;
  List<Cell> get cells =>
      shapeCells(kind, rotation).map((c) => Cell(c.x + x, c.y + y)).toList();
  FallingPiece moved(int dx, int dy, [int? turn]) =>
      FallingPiece(kind, x: x + dx, y: y + dy, rotation: turn ?? rotation);
}

List<Cell> shapeCells(Tetromino kind, int rotation) {
  var points = switch (kind) {
    Tetromino.i => [
      const Cell(0, 1),
      const Cell(1, 1),
      const Cell(2, 1),
      const Cell(3, 1),
    ],
    Tetromino.o => [
      const Cell(1, 0),
      const Cell(2, 0),
      const Cell(1, 1),
      const Cell(2, 1),
    ],
    Tetromino.t => [
      const Cell(1, 0),
      const Cell(0, 1),
      const Cell(1, 1),
      const Cell(2, 1),
    ],
    Tetromino.s => [
      const Cell(1, 0),
      const Cell(2, 0),
      const Cell(0, 1),
      const Cell(1, 1),
    ],
    Tetromino.z => [
      const Cell(0, 0),
      const Cell(1, 0),
      const Cell(1, 1),
      const Cell(2, 1),
    ],
    Tetromino.j => [
      const Cell(0, 0),
      const Cell(0, 1),
      const Cell(1, 1),
      const Cell(2, 1),
    ],
    Tetromino.l => [
      const Cell(2, 0),
      const Cell(0, 1),
      const Cell(1, 1),
      const Cell(2, 1),
    ],
  };
  if (kind == Tetromino.o) return points;
  final edge = kind == Tetromino.i ? 3 : 2;
  for (var r = 0; r < rotation % 4; r++) {
    points = points.map((p) => Cell(edge - p.y, p.x)).toList();
  }
  return points;
}

/// Game state is independent of Flutter, board dimensions and pedal artwork.
class TetrisEngine {
  TetrisEngine({Random? random}) : _random = random ?? Random() {
    _fillQueue();
    _spawn(_take());
  }
  static const columns = 10, rows = 20;
  final Random _random;
  final List<List<Tetromino?>> grid = List.generate(
    rows,
    (_) => List.filled(columns, null),
  );
  final List<List<int?>> pieceIds = List.generate(
    rows,
    (_) => List.filled(columns, null),
  );
  final List<Tetromino> _queue = [];
  late FallingPiece active;
  Tetromino? held;
  bool holdUsed = false, paused = false, gameOver = false;
  int score = 0, lines = 0, pieces = 0, lastClear = 0;
  int _lockResets = 0;
  double _gravity = 0, _lockTime = 0;
  int get level => lines ~/ 10 + 1;
  double get fallInterval => max(.06, .8 * pow(.82, level - 1));
  List<Tetromino> get next => List.unmodifiable(_queue.take(5));
  bool get running => !paused && !gameOver;
  bool get grounded => !fits(active.moved(0, 1));
  FallingPiece get ghost {
    var p = active;
    while (fits(p.moved(0, 1))) {
      p = p.moved(0, 1);
    }
    return p;
  }

  void _fillQueue() {
    while (_queue.length < 7) {
      _queue.addAll(Tetromino.values.toList()..shuffle(_random));
    }
  }

  Tetromino _take() {
    final kind = _queue.removeAt(0);
    _fillQueue();
    return kind;
  }

  bool fits(FallingPiece p) => p.cells.every(
    (c) =>
        c.x >= 0 &&
        c.x < columns &&
        c.y >= -4 &&
        c.y < rows &&
        (c.y < 0 || grid[c.y][c.x] == null),
  );
  void _spawn(Tetromino kind) {
    active = FallingPiece(kind);
    _gravity = _lockTime = 0;
    _lockResets = 0;
    if (!fits(active)) gameOver = true;
  }

  bool move(int dx) {
    if (!running || dx.abs() != 1) return false;
    return _manipulate(active.moved(dx, 0));
  }

  bool _manipulate(FallingPiece p) {
    if (!fits(p)) return false;
    final wasGrounded = grounded;
    active = p;
    if (wasGrounded && _lockResets < 15) {
      _lockTime = 0;
      _lockResets++;
    }
    return true;
  }

  bool rotate() {
    if (!running) return false;
    if (active.kind == Tetromino.o) return true;
    final r = active.rotation;
    final kicks = active.kind == Tetromino.i
        ? const [
            [Cell(0, 0), Cell(-2, 0), Cell(1, 0), Cell(-2, 1), Cell(1, -2)],
            [Cell(0, 0), Cell(-1, 0), Cell(2, 0), Cell(-1, -2), Cell(2, 1)],
            [Cell(0, 0), Cell(2, 0), Cell(-1, 0), Cell(2, -1), Cell(-1, 2)],
            [Cell(0, 0), Cell(1, 0), Cell(-2, 0), Cell(1, 2), Cell(-2, -1)],
          ]
        : const [
            [Cell(0, 0), Cell(-1, 0), Cell(-1, -1), Cell(0, 2), Cell(-1, 2)],
            [Cell(0, 0), Cell(1, 0), Cell(1, 1), Cell(0, -2), Cell(1, -2)],
            [Cell(0, 0), Cell(1, 0), Cell(1, -1), Cell(0, 2), Cell(1, 2)],
            [Cell(0, 0), Cell(-1, 0), Cell(-1, 1), Cell(0, -2), Cell(-1, -2)],
          ];
    for (final k in kicks[r]) {
      if (_manipulate(active.moved(k.x, k.y, (r + 1) % 4))) return true;
    }
    return false;
  }

  bool softDrop() {
    if (!running || !fits(active.moved(0, 1))) return false;
    active = active.moved(0, 1);
    score++;
    _gravity = 0;
    return true;
  }

  void hardDrop() {
    if (!running) return;
    final target = ghost;
    score += (target.y - active.y) * 2;
    active = target;
    _lock();
  }

  void hold() {
    if (!running || holdUsed) return;
    final previous = held;
    held = active.kind;
    _spawn(previous ?? _take());
    holdUsed = true;
  }

  void advance(double seconds) {
    if (!running || seconds <= 0 || !seconds.isFinite) return;
    // Small steps keep landing and lock delay deterministic at any frame rate.
    var remaining = min(seconds, 5.0);
    while (remaining > 0 && running) {
      final dt = min(remaining, .02);
      remaining -= dt;
      if (grounded) {
        _lockTime += dt;
        if (_lockTime >= .5) _lock();
      } else {
        _lockTime = 0;
        _gravity += dt;
        if (_gravity >= fallInterval) {
          _gravity -= fallInterval;
          active = active.moved(0, 1);
        }
      }
    }
  }

  void _lock() {
    if (active.cells.any((c) => c.y < 0)) {
      gameOver = true;
      return;
    }
    for (final c in active.cells) {
      grid[c.y][c.x] = active.kind;
      pieceIds[c.y][c.x] = pieces;
    }
    final oldLevel = level;
    final keptIndices = [
      for (var y = 0; y < rows; y++)
        if (grid[y].any((c) => c == null)) y,
    ];
    final kept = [for (final y in keptIndices) grid[y].toList()];
    final keptIds = [for (final y in keptIndices) pieceIds[y].toList()];
    lastClear = rows - kept.length;
    lines += lastClear;
    score += const [0, 100, 300, 500, 800][lastClear] * oldLevel;
    grid
      ..clear()
      ..addAll(
        List.generate(lastClear, (_) => List<Tetromino?>.filled(columns, null)),
      )
      ..addAll(kept);
    pieceIds
      ..clear()
      ..addAll(
        List.generate(lastClear, (_) => List<int?>.filled(columns, null)),
      )
      ..addAll(keptIds);
    pieces++;
    holdUsed = false;
    _spawn(_take());
  }
}
