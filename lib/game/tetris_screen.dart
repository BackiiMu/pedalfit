import '../design/app_design.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/board_project.dart';
import 'tetris_engine.dart';
import 'tetris_skin.dart';

const _mint = AppColors.blue;

class TetrisScreen extends StatefulWidget {
  const TetrisScreen({super.key, required this.boards, this.engineFactory});
  final List<BoardProject> boards;
  final TetrisEngine Function()? engineFactory;
  @override
  State<TetrisScreen> createState() => _TetrisScreenState();
}

class _TetrisScreenState extends State<TetrisScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const bestKey = 'pedalboard.tetris.best.v1';
  late final Ticker _ticker;
  final _focus = FocusNode();
  TetrisEngine? game;
  Duration? _previous;
  int skin = 0, best = 0;
  bool started = false, record = false;
  String? storageError;
  Color get boardColor => widget.boards.isEmpty
      ? const Color(0xFF303B34)
      : Color(widget.boards[skin].colorValue);
  String get skinName =>
      widget.boards.isEmpty ? '기본 페달보드' : widget.boards[skin].name;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_tick);
    _loadBest();
  }

  Future<void> _loadBest() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() => best = math.max(best, p.getInt(bestKey) ?? 0));
      }
    } catch (_) {
      if (mounted) setState(() => storageError = '최고 기록을 읽지 못했습니다.');
    }
  }

  Future<void> _saveBest(int score) async {
    if (score <= best) return;
    setState(() {
      best = score;
      record = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(bestKey) ?? 0;
      if (score > saved && !await prefs.setInt(bestKey, score)) {
        throw StateError('save');
      }
    } catch (_) {
      if (mounted) setState(() => storageError = '최고 기록을 기기에 저장하지 못했습니다.');
    }
  }

  void _tick(Duration elapsed) {
    final previous = _previous;
    _previous = elapsed;
    final g = game;
    if (previous == null || g == null || !g.running) return;
    _act(
      () => g.advance(
        math.min(.1, (elapsed - previous).inMicroseconds / 1000000),
      ),
    );
  }

  void _act(VoidCallback action) {
    final wasOver = game?.gameOver ?? false;
    setState(action);
    if (!wasOver && game!.gameOver) {
      _ticker.stop();
      _saveBest(game!.score);
    }
  }

  void _start() {
    setState(() {
      game = widget.engineFactory?.call() ?? TetrisEngine();
      started = true;
      record = false;
    });
    _previous = null;
    if (!_ticker.isActive) _ticker.start();
    _focus.requestFocus();
  }

  void _setPaused(bool value) {
    setState(() => game!.paused = value);
    _previous = null;
    if (value) {
      _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
    _focus.requestFocus();
  }

  void _pause() {
    if (game?.running ?? false) _setPaused(true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
    _previous = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (!started || event is KeyUpEvent) return KeyEventResult.ignored;
    final g = game!;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyP) {
      if (event is! KeyRepeatEvent && !g.gameOver) {
        _setPaused(!g.paused);
      }
    } else if (g.running) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        _act(() => g.move(-1));
      } else if (key == LogicalKeyboardKey.arrowRight) {
        _act(() => g.move(1));
      } else if (key == LogicalKeyboardKey.arrowDown) {
        _act(g.softDrop);
      } else if (key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.keyX) {
        if (event is! KeyRepeatEvent) _act(g.rotate);
      } else if (key == LogicalKeyboardKey.space) {
        if (event is! KeyRepeatEvent) _act(g.hardDrop);
      } else if (key == LogicalKeyboardKey.keyC ||
          key == LogicalKeyboardKey.shiftLeft) {
        if (event is! KeyRepeatEvent) _act(g.hold);
      } else {
        return KeyEventResult.ignored;
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _help() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('조작 방법'),
      content: const SingleChildScrollView(
        child: Text(
          '페달 블록을 쌓아 가로 한 줄을 채우면 줄이 사라집니다.\n\n'
          '← → : 좌우 이동 (길게 누르면 반복)\n회전 : 시계 방향 90° 회전\n↓ : 빠르게 내리기\n드롭 : 바닥까지 즉시 내리기\n홀드 : 현재 블록 보관 (고정 전 1회)\n\n'
          '키보드: 방향키, ↑/X 회전, Space 드롭, C/왼쪽 Shift 홀드, P/Esc 일시정지.\n\n'
          '10줄마다 레벨과 낙하 속도가 올라갑니다. 줄 삭제 점수는 1/2/3/4줄 = 100/300/500/800 × 레벨입니다. 소프트 드롭은 칸당 1점, 하드 드롭은 칸당 2점입니다.\n\n'
          '게임판은 10 × 20칸입니다. 보드 선택은 배경만 바꾸며 실제 크기와 저장된 페달 배치는 게임에 영향을 주지 않습니다.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !started,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _pause();
    },
    child: Focus(
      autofocus: true,
      focusNode: _focus,
      onKeyEvent: _key,
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () {
              if (started) {
                _pause();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: const Text(
            '페달 테트리스',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          actions: [
            if (started && !game!.gameOver)
              IconButton(
                tooltip: game!.paused ? '계속하기' : '일시정지',
                onPressed: () => _setPaused(!game!.paused),
                icon: Icon(game!.paused ? Icons.play_arrow : Icons.pause),
              ),
          ],
        ),
        body: SafeArea(top: false, child: started ? _play() : _menu()),
      ),
    ),
  );
  Widget _menu() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(
            Icons.sports_esports_outlined,
            color: AppColors.ink,
            size: 28,
          ),
          const SizedBox(height: 12),
          const Text(
            '클래식 테트리스',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '최고 기록  $best',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 100,
              height: 180,
              child: CustomPaint(
                painter: _WellPainter(null, boardColor, demo: true),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '보드 스킨',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (widget.boards.isEmpty)
            const ListTile(
              leading: Icon(Icons.view_week),
              title: Text('기본 페달보드'),
              subtitle: Text('보드를 등록하면 스킨으로 선택할 수 있어요.'),
            ),
          for (var i = 0; i < widget.boards.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                selected: skin == i,
                selectedTileColor: AppColors.blueSoft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () => setState(() => skin = i),
                trailing: Icon(
                  skin == i
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: _mint,
                ),
                title: Text(widget.boards[i].name),
                subtitle: Text(widget.boards[i].typeLabel),
                leading: Container(
                  width: 32,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(widget.boards[i].colorValue),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Icon(Icons.view_week, size: 24),
                ),
              ),
            ),
          const Text(
            '보드 모양만 바뀌어요 · 규칙은 그대로',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('tetris-start'),
            onPressed: _start,
            icon: const Icon(Icons.play_arrow),
            label: const Text('게임 시작'),
          ),
          TextButton.icon(
            onPressed: _help,
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('조작 방법'),
          ),
          if (storageError != null)
            Text(
              storageError!,
              style: const TextStyle(color: AppColors.warning),
            ),
        ],
      ),
    ),
  );
  Widget _play() {
    final g = game!;
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  _metric('점수', '${g.score}'),
                  _metric('레벨', '${g.level}'),
                  _metric('지운 줄', '${g.lines}'),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cell = math.min(
                    (constraints.maxWidth - 116) / 10,
                    (constraints.maxHeight - 12) / 20,
                  );
                  return Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 52,
                          child: Column(
                            children: [
                              const Text(
                                '홀드',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                              Semantics(
                                button: true,
                                label: '블록 홀드',
                                enabled: !g.holdUsed && g.running,
                                child: GestureDetector(
                                  excludeFromSemantics: true,
                                  onTap: () => _act(g.hold),
                                  child: Opacity(
                                    opacity: g.holdUsed ? .35 : 1,
                                    child: SizedBox(
                                      width: 48,
                                      height: 56,
                                      child: CustomPaint(
                                        painter: _PreviewPainter(g.held),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: cell * 10,
                          height: cell * 20,
                          child: Semantics(
                            label: '게임판, 점수 ${g.score}, 지운 줄 ${g.lines}',
                            child: ClipRect(
                              child: CustomPaint(
                                painter: _WellPainter(g, boardColor),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 52,
                          child: Column(
                            children: [
                              const Text(
                                '다음',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                              for (final kind in g.next.take(
                                constraints.maxHeight < 290 ? 3 : 5,
                              ))
                                SizedBox(
                                  width: 46,
                                  height: math.min(
                                    52,
                                    constraints.maxHeight / 6,
                                  ),
                                  child: CustomPaint(
                                    painter: _PreviewPainter(kind),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '$skinName · 최고 $best',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AppColors.faint),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: Row(
                children: [
                  _control(
                    '왼쪽',
                    Icons.arrow_back,
                    () => g.move(-1),
                    repeat: true,
                  ),
                  _control('회전', Icons.rotate_right, g.rotate),
                  _control(
                    '오른쪽',
                    Icons.arrow_forward,
                    () => g.move(1),
                    repeat: true,
                  ),
                  _control(
                    '아래로',
                    Icons.arrow_downward,
                    g.softDrop,
                    repeat: true,
                  ),
                  _control(
                    '드롭',
                    Icons.vertical_align_bottom,
                    g.hardDrop,
                    primary: true,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (g.paused || g.gameOver)
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.paper.withValues(alpha: .97),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          g.gameOver
                              ? Icons.emoji_events_outlined
                              : Icons.pause_circle_outline,
                          color: _mint,
                          size: 48,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          g.gameOver ? '게임 종료' : '잠시 쉬어가기',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (g.gameOver) ...[
                          const Text(
                            '최종 점수',
                            style: TextStyle(color: AppColors.muted),
                          ),
                          Text(
                            '${g.score}',
                            style: const TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          if (record)
                            const Text(
                              '최고 기록 갱신!',
                              style: TextStyle(color: _mint),
                            ),
                          Text('레벨 ${g.level}  ·  지운 줄 ${g.lines}'),
                          if (storageError != null)
                            Text(
                              storageError!,
                              style: const TextStyle(color: AppColors.warning),
                            ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _start,
                              icon: const Icon(Icons.replay),
                              label: const Text('다시 시작'),
                            ),
                          ),
                        ] else ...[
                          const Text(
                            '앱을 벗어나도 자동으로 일시정지돼요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () {
                                _setPaused(false);
                                _focus.requestFocus();
                              },
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('계속하기'),
                            ),
                          ),
                          TextButton(
                            onPressed: _help,
                            child: const Text('조작 방법'),
                          ),
                        ],
                        TextButton(
                          onPressed: () => setState(() {
                            _ticker.stop();
                            started = false;
                            game = null;
                          }),
                          child: Text(g.gameOver ? '메인으로' : '이번 게임 종료'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _metric(String label, String value) => Expanded(
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
  Widget _control(
    String label,
    IconData icon,
    VoidCallback action, {
    bool repeat = false,
    bool primary = false,
  }) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: _RepeatButton(
        label: label,
        icon: icon,
        primary: primary,
        repeat: repeat,
        enabled: game!.running,
        onAction: () {
          if (game?.running ?? false) _act(action);
        },
      ),
    ),
  );
}

class _RepeatButton extends StatefulWidget {
  const _RepeatButton({
    required this.label,
    required this.icon,
    required this.onAction,
    required this.enabled,
    this.repeat = false,
    this.primary = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onAction;
  final bool repeat, primary, enabled;
  @override
  State<_RepeatButton> createState() => _RepeatButtonState();
}

class _RepeatButtonState extends State<_RepeatButton>
    with SingleTickerProviderStateMixin {
  late final Ticker ticker;
  bool pressed = false;
  int last = 0;
  @override
  void initState() {
    super.initState();
    ticker = createTicker((elapsed) {
      final ms = elapsed.inMilliseconds;
      if (ms >= 200 && ms - last >= 65) {
        last = ms;
        if (widget.enabled) widget.onAction();
      }
    });
  }

  void stop() {
    ticker.stop();
    if (pressed && mounted) setState(() => pressed = false);
  }

  @override
  void didUpdateWidget(covariant _RepeatButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      ticker.stop();
      pressed = false;
    }
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.label,
    enabled: widget.enabled,
    onTap: widget.enabled ? widget.onAction : null,
    child: GestureDetector(
      excludeFromSemantics: true,
      onTapDown: widget.enabled
          ? (_) {
              setState(() => pressed = true);
              widget.onAction();
              if (widget.repeat && widget.enabled) {
                last = 0;
                ticker.start();
              }
            }
          : null,
      onTapUp: (_) => stop(),
      onTapCancel: stop,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: pressed
              ? (widget.primary ? AppColors.blue : AppColors.blueSoft)
              : widget.primary
              ? _mint
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.icon,
              color: widget.primary ? Colors.white : _mint,
              size: 23,
            ),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 9,
                color: widget.primary ? Colors.white : AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.kind);
  final Tetromino? kind;
  @override
  void paint(Canvas canvas, Size size) {
    if (kind == null) return;
    final cells = shapeCells(kind!, 0);
    final minX = cells.map((p) => p.x).reduce(math.min),
        maxX = cells.map((p) => p.x).reduce(math.max);
    final minY = cells.map((p) => p.y).reduce(math.min),
        maxY = cells.map((p) => p.y).reduce(math.max);
    final u = math.min(
      (size.width - 4) / (maxX - minX + 1),
      (size.height - 8) / (maxY - minY + 1),
    );
    final dx = (size.width - u * (maxX - minX + 1)) / 2,
        dy = (size.height - u * (maxY - minY + 1)) / 2;
    paintPedalPiece(
      canvas,
      cells,
      kind!,
      u,
      u,
      Offset(dx - minX * u, dy - minY * u),
    );
  }

  @override
  bool shouldRepaint(_PreviewPainter oldDelegate) => oldDelegate.kind != kind;
}

class _WellPainter extends CustomPainter {
  _WellPainter(this.game, this.color, {this.demo = false});
  final TetrisEngine? game;
  final Color color;
  final bool demo;
  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / 10, ch = size.height / 20;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF080F0B),
    );
    for (var x = 0; x < 10; x++) {
      final rect = Rect.fromLTWH(x * cw + 1, 0, cw * .76, size.height);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Color.lerp(color, Colors.black, .15)!,
              Color.lerp(color, Colors.black, .65)!,
            ],
          ).createShader(rect),
      );
    }
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: .09)
      ..strokeWidth = .5;
    for (var x = 0; x <= 10; x++) {
      canvas.drawLine(
        Offset(x * cw, 0),
        Offset(x * cw, size.height),
        gridPaint,
      );
    }
    for (var y = 0; y <= 20; y++) {
      canvas.drawLine(Offset(0, y * ch), Offset(size.width, y * ch), gridPaint);
    }
    void draw(List<Cell> cells, Tetromino k, {bool ghost = false}) =>
        paintPedalPiece(canvas, cells, k, cw, ch, Offset.zero, ghost: ghost);
    if (demo) {
      for (final p in const [
        FallingPiece(Tetromino.i, x: -2, y: 16, rotation: 1),
        FallingPiece(Tetromino.o, x: 0, y: 18),
        FallingPiece(Tetromino.l, x: 3, y: 18),
        FallingPiece(Tetromino.o, x: 5, y: 18),
        FallingPiece(Tetromino.i, x: 7, y: 16, rotation: 1),
        FallingPiece(Tetromino.t, x: 2, y: 15),
        FallingPiece(Tetromino.t, y: 4),
      ]) {
        draw(p.cells, p.kind);
      }
    }
    final g = game;
    if (g != null) {
      final groups = <int, List<Cell>>{};
      final kinds = <int, Tetromino>{};
      for (var y = 0; y < 20; y++) {
        for (var x = 0; x < 10; x++) {
          final k = g.grid[y][x];
          if (k == null) continue;
          final id = g.pieceIds[y][x] ?? -(y * 10 + x + 1);
          (groups[id] ??= []).add(Cell(x, y));
          kinds[id] = k;
        }
      }
      for (final entry in groups.entries) {
        draw(entry.value, kinds[entry.key]!);
      }
      if (!g.gameOver) {
        draw(g.ghost.cells, g.active.kind, ghost: true);
        draw(g.active.cells, g.active.kind);
      }
    }
    canvas.drawRect(
      (Offset.zero & size).deflate(.75),
      Paint()
        ..color = Colors.white30
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    for (final x in [cw * .25, size.width - cw * .25]) {
      for (final y in [ch * .3, size.height - ch * .3]) {
        canvas.drawCircle(
          Offset(x, y),
          cw * .06,
          Paint()..color = Colors.white38,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WellPainter oldDelegate) => true;
}
