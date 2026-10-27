import '../design/app_design.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/board_project.dart';
import '../widgets/board_canvas.dart';
import '../widgets/pedal_art.dart';
import 'packing_engine.dart';

class PackingScreen extends StatefulWidget {
  const PackingScreen({
    super.key,
    required this.boards,
    required this.presets,
    required this.onSave,
    this.engineFactory,
  });
  final List<BoardProject> boards;
  final List<BoardPreset> presets;
  final Future<void> Function(BoardProject) onSave;
  final PackingEngine Function(PackingChallenge, bool)? engineFactory;
  @override
  State<PackingScreen> createState() => _PackingScreenState();
}

class _PackingScreenState extends State<PackingScreen>
    with WidgetsBindingObserver {
  late final List<BoardProject> boards;
  late PackingChallenge challenge;
  PackingEngine? game;
  BoardProject? _resultBoard;
  int boardIndex = 0, target = 8, seed = 0;
  bool timed = false,
      handled = false,
      saving = false,
      saved = false,
      newRecord = false;
  String? storageError;
  int? bestMs;
  Timer? _timer;
  final _watch = Stopwatch();
  int _lastMs = 0;
  final _deckKey = GlobalKey();
  Offset? _ghost;
  int? _dragIndex;
  double _scale = 1;
  Offset _origin = Offset.zero;
  String get _recordKey =>
      'pedalboard.packing.best.v1.${challenge.board.widthMm}.${challenge.board.depthMm}.${challenge.pedals.length}.${timed ? 'timed' : 'free'}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    boards = widget.boards.isNotEmpty
        ? widget.boards.map((b) => b.copy()).toList()
        : [
            for (final p in widget.presets)
              BoardProject(
                id: 'puzzle_${p.id}',
                name: p.model,
                widthMm: p.widthMm,
                depthMm: p.depthMm,
                presetId: p.id,
                presetName: p.model,
                series: p.series,
              ),
          ];
    if (boards.isEmpty) {
      boards.add(
        BoardProject(
          id: 'puzzle_default',
          name: '기본 보드',
          widthMm: 610,
          depthMm: 318,
        ),
      );
    }
    challenge = PackingChallenge.generate(boards.first, count: target);
  }

  void _configure() {
    challenge = PackingChallenge.generate(
      boards[boardIndex],
      count: target,
      seed: seed,
    );
    setState(() {});
  }

  void _start() {
    game?.removeListener(_changed);
    game?.dispose();
    game =
        (widget.engineFactory?.call(challenge, timed) ??
              PackingEngine(challenge, timed: timed))
          ..addListener(_changed);
    _resultBoard = null;
    _ghost = null;
    _dragIndex = null;
    handled = saved = saving = newRecord = false;
    storageError = null;
    bestMs = null;
    _watch.reset();
    _watch.start();
    _lastMs = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final ms = _watch.elapsedMilliseconds;
      final dt = (ms - _lastMs) / 1000;
      _lastMs = ms;
      game?.advance(dt);
    });
    setState(() {});
  }

  void _changed() {
    final g = game!;
    if (g.finished && !handled) {
      handled = true;
      _resultBoard = g.exportBoard();
      _watch.stop();
      _timer?.cancel();
      if (g.won) _record(g);
    }
    if (mounted) setState(() {});
  }

  Future<void> _record(PackingEngine round) async {
    final key = _recordKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      final previous = prefs.getInt(key);
      final elapsedMs = (round.elapsed * 1000).round();
      final eligible =
          round.hints == 0 && (previous == null || elapsedMs < previous);
      if (eligible && !await prefs.setInt(key, elapsedMs)) {
        throw StateError('save');
      }
      if (mounted && game == round) {
        setState(() {
          newRecord = eligible;
          bestMs = eligible ? elapsedMs : previous;
        });
      }
    } catch (_) {
      if (mounted && game == round) {
        setState(() => storageError = '기록을 저장하지 못했습니다. 배치는 따로 저장할 수 있어요.');
      }
    }
  }

  void _pause(bool value) {
    final g = game;
    if (g == null || g.finished) return;
    if (value) {
      _watch.stop();
    } else {
      _watch.start();
    }
    g.setPaused(value);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause(true);
  }

  void _menu() {
    _timer?.cancel();
    _watch.stop();
    game?.removeListener(_changed);
    game?.dispose();
    game = null;
    _resultBoard = null;
    _ghost = null;
    _dragIndex = null;
    setState(() {});
  }

  Future<void> _save() async {
    final round = game, result = _resultBoard;
    if (saving || saved || round == null || !round.won || result == null) {
      return;
    }
    setState(() {
      saving = true;
      storageError = null;
    });
    try {
      await widget.onSave(result.copy());
      if (mounted && game == round) setState(() => saved = true);
    } catch (_) {
      if (mounted && game == round) {
        setState(() => storageError = '배치를 저장하지 못했습니다. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted && game == round) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _watch.stop();
    game?.removeListener(_changed);
    game?.dispose();
    super.dispose();
  }

  String _time(double seconds) {
    final n = seconds.ceil();
    return '${(n ~/ 60).toString().padLeft(2, '0')}:${(n % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: game == null && !saving,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !saving) {
        if (game?.finished ?? false) {
          _menu();
        } else {
          _pause(true);
        }
      }
    },
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: saving
              ? null
              : () {
                  if (game == null) {
                    Navigator.pop(context);
                  } else if (game!.finished) {
                    _menu();
                  } else {
                    _pause(true);
                  }
                },
        ),
        title: Text(
          game == null ? '페달 맞추기' : challenge.board.name,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (game != null && !game!.finished)
            IconButton(
              tooltip: '퍼즐 일시정지',
              onPressed: () => _pause(true),
              icon: const Icon(Icons.pause),
            ),
        ],
      ),
      body: SafeArea(top: false, child: game == null ? _setup() : _play()),
    ),
  );
  Widget _setup() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            '보드에 맞춰 배치하기',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            '실제 크기의 페달을 겹치지 않게 모두 넣어보세요.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 22),
          const Text(
            '보드 선택',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (widget.boards.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '등록된 보드가 없어 제품 프리셋으로 시작합니다.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: boardIndex,
            isExpanded: true,
            items: [
              for (var i = 0; i < boards.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    '${boards[i].name} · ${boards[i].sizeLabel}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (i) {
              boardIndex = i!;
              _configure();
            },
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 140,
            child: BoardCanvas(project: challenge.board, showGrid: false),
          ),
          const SizedBox(height: 18),
          const Text(
            '도전 과제',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              for (final n in [4, 6, 8])
                ChoiceChip(
                  label: Text('$n개 페달'),
                  selected: target == n,
                  onSelected: (_) {
                    target = n;
                    _configure();
                  },
                ),
            ],
          ),
          Text(
            '이번 문제: ${challenge.pedals.length}개 모두 넣기',
            style: const TextStyle(color: mint),
          ),
          if (challenge.pedals.length < target)
            const Text(
              '이 보드에서 확인된 배치 수량으로 조정했어요.',
              style: TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          const SizedBox(height: 20),
          const Text(
            '난이도 선택',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.spa_outlined),
                label: Text('여유롭게'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.timer_outlined),
                label: Text('시간 도전'),
              ),
            ],
            selected: {timed},
            onSelectionChanged: (v) => setState(() => timed = v.first),
          ),
          const SizedBox(height: 10),
          Text(timed ? '2분 안에 전부 배치하세요.' : '시간 제한 없이 천천히 맞춰보세요.'),
          const SizedBox(height: 8),
          const Text(
            '본체만 판정합니다. 케이블 공간은 포함하지 않습니다.\n힌트는 한 개를 정답 위치에 놓고 겹친 페달을 대기로 돌립니다. 힌트 없는 완료 시간만 최고 기록에 반영됩니다.',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            key: const ValueKey('packing-start'),
            onPressed: challenge.pedals.isEmpty ? null : _start,
            icon: const Icon(Icons.play_arrow),
            label: const Text('퍼즐 시작'),
          ),
          if (challenge.pedals.isEmpty)
            const Text('이 보드에는 준비된 페달이 들어가지 않아요. 더 큰 보드를 선택해 주세요.'),
        ],
      ),
    ),
  );
  Widget _play() {
    final g = game!;
    final ready = [
      for (var i = 0; i < g.placements.length; i++)
        if (g.placements[i] == null) i,
    ];
    final metrics = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _metric('배치', '${g.placed} / ${g.placements.length}'),
          _metric(
            timed ? '남은 시간' : '플레이 시간',
            timed ? _time(g.remainingSeconds.toDouble()) : _time(g.elapsed),
          ),
        ],
      ),
    );
    final notice = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        g.message ?? '끌어서 배치 · 선택 후 회전',
        maxLines: 2,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: g.message != null ? AppColors.warning : AppColors.muted,
        ),
      ),
    );
    final tray = Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '남은 페달 ${ready.length}개',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: ready.isEmpty
                ? const Center(child: Text('모든 페달을 배치했어요!'))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: ready.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, n) {
                      final i = ready[n], p = challenge.pedals[i];
                      return SizedBox(
                        width: 106,
                        child: _draggable(
                          i,
                          GestureDetector(
                            onTap: () => g.select(i),
                            child: Container(
                              key: ValueKey('packing-tray-$i'),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.paper,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: g.selected == i
                                      ? mint
                                      : Colors.transparent,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: RotatedBox(
                                        quarterTurns: g.turns(i),
                                        child: PedalArt(pedal: p),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  Text(
                                    '${mm(p.widthMm)} × ${mm(p.depthMm)} mm',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
    final buttons = Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: g.selected == null ? null : g.rotate,
              icon: const Icon(Icons.rotate_right),
              label: const Text('회전'),
            ),
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: g.canUndo ? g.undo : null,
              icon: const Icon(Icons.undo),
              label: const Text('되돌리기'),
            ),
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: g.hint,
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text('힌트'),
            ),
          ),
        ],
      ),
    );
    final returnButton =
        g.selected != null && g.placements[g.selected!] != null && !g.finished
        ? TextButton(
            onPressed: () => g.returnToTray(g.selected!),
            child: const Text('선택 페달 대기로 돌리기'),
          )
        : const SizedBox.shrink();
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth > 650 && c.maxHeight < 500) {
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        metrics,
                        Expanded(child: _deck()),
                        notice,
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: Column(
                      children: [
                        Expanded(child: tray),
                        buttons,
                        returnButton,
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                metrics,
                Expanded(flex: 5, child: _deck()),
                notice,
                const SizedBox(height: 6),
                Expanded(flex: 3, child: tray),
                buttons,
                returnButton,
              ],
            );
          },
        ),
        if (g.paused || g.finished)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xF7F6F5F4),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: _overlay(),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _metric(String title, String value) => Expanded(
    child: Column(
      children: [
        Text(
          title,
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
  Widget _draggable(int i, Widget child) {
    final g = game!, p = challenge.pedals[i];
    final turns = g.turns(i),
        w = (turns.isOdd ? p.depthMm : p.widthMm) * _scale,
        h = (turns.isOdd ? p.widthMm : p.depthMm) * _scale;
    if (g.paused || g.finished) return child;
    return Draggable<int>(
      data: i,
      maxSimultaneousDrags: 1,
      dragAnchorStrategy: (_, _, _) => Offset(w / 2, h / 2),
      feedback: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: w,
          height: h,
          child: Opacity(
            opacity: .85,
            child: RotatedBox(
              quarterTurns: turns,
              child: PedalArt(pedal: p),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: .25, child: child),
      onDragStarted: () {
        if (_validDrag(g, i)) g.select(i);
      },
      onDragEnd: (_) {
        if (mounted && game == g) {
          setState(() {
            _ghost = null;
            _dragIndex = null;
          });
        }
      },
      child: child,
    );
  }

  bool _validDrag(PackingEngine round, int i) =>
      mounted &&
      game == round &&
      !round.finished &&
      !round.paused &&
      i >= 0 &&
      i < round.placements.length;
  PuzzlePlacement? _drop(PackingEngine round, int i, Offset global) {
    if (!_validDrag(round, i) || _scale <= 0 || !_scale.isFinite) return null;
    final render = _deckKey.currentContext?.findRenderObject();
    if (render is! RenderBox || !render.attached || !render.hasSize) {
      return null;
    }
    final local = render.globalToLocal(global) - _origin;
    return PuzzlePlacement(
      (local.dx / _scale).roundToDouble(),
      (local.dy / _scale).roundToDouble(),
      round.turns(i),
    );
  }

  Widget _deck() => LayoutBuilder(
    builder: (context, c) {
      final b = challenge.board, g = game!;
      _scale = math.min(
        (c.maxWidth - 80) / b.widthMm,
        (c.maxHeight - 96) / b.depthMm,
      );
      _origin = Offset(
        (c.maxWidth - b.widthMm * _scale) / 2,
        (c.maxHeight - b.depthMm * _scale) / 2,
      );
      return DragTarget<int>(
        key: const ValueKey('packing-drop'),
        onWillAcceptWithDetails: (d) => _validDrag(g, d.data),
        onMove: (d) {
          final p = _drop(g, d.data, d.offset);
          if (p == null) return;
          setState(() {
            _dragIndex = d.data;
            _ghost = Offset(p.x, p.y);
          });
        },
        onLeave: (_) {
          if (mounted && game == g) {
            setState(() {
              _ghost = null;
              _dragIndex = null;
            });
          }
        },
        onAcceptWithDetails: (d) {
          final p = _drop(g, d.data, d.offset);
          if (p == null) return;
          g.place(d.data, p);
          setState(() {
            _ghost = null;
            _dragIndex = null;
          });
        },
        builder: (context, _, _) => SizedBox(
          key: _deckKey,
          width: c.maxWidth,
          height: c.maxHeight,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: DeckPainter(
                    b,
                    _origin,
                    _scale,
                    grid: false,
                    rulers: true,
                    fontFamily: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.fontFamily,
                  ),
                ),
              ),
              for (var i = 0; i < g.placements.length; i++)
                if (g.placements[i] != null) _positioned(i),
              if (_ghost != null && _dragIndex != null) _preview(),
            ],
          ),
        ),
      );
    },
  );
  Widget _positioned(int i) {
    final g = game!, p = g.placements[i]!, area = g.rect(i, p);
    return Positioned(
      left: _origin.dx + p.x * _scale,
      top: _origin.dy + p.y * _scale,
      width: area.width * _scale,
      height: area.height * _scale,
      child: _draggable(
        i,
        GestureDetector(
          onTap: () => g.select(i),
          child: Container(
            key: ValueKey('packing-placed-$i'),
            decoration: BoxDecoration(
              border: Border.all(
                color: g.selected == i ? mint : Colors.transparent,
                width: 2,
              ),
            ),
            child: RotatedBox(
              quarterTurns: p.turns,
              child: PedalArt(pedal: challenge.pedals[i]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _preview() {
    final g = game!,
        i = _dragIndex!,
        pos = PuzzlePlacement(_ghost!.dx, _ghost!.dy, g.turns(i)),
        area = g.rect(i, pos);
    final valid = g.fits(i, pos);
    return Positioned(
      left: _origin.dx + area.left * _scale,
      top: _origin.dy + area.top * _scale,
      width: area.width * _scale,
      height: area.height * _scale,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: (valid ? mint : Colors.redAccent).withValues(alpha: .2),
            border: Border.all(
              color: valid ? mint : Colors.redAccent,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlay() {
    final g = game!;
    if (g.paused) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pause_circle_outline, color: mint, size: 48),
          const SizedBox(height: 16),
          const Text(
            '잠시 쉬어가기',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => _pause(false),
            child: const Text('계속하기'),
          ),
          TextButton(onPressed: _menu, child: const Text('이번 도전 종료')),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          g.won ? Icons.celebration : Icons.timer_off_outlined,
          color: mint,
          size: 46,
        ),
        const SizedBox(height: 10),
        Text(
          g.won ? '배치 완료' : '도전 종료',
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
        ),
        if (g.won)
          Text(
            '★' * g.stars + '☆' * (3 - g.stars),
            style: const TextStyle(color: AppColors.ink, fontSize: 34),
          ),
        SizedBox(
          height: 140,
          child: BoardCanvas(project: _resultBoard!, showGrid: false),
        ),
        Text(
          '${g.placed} / ${g.placements.length} 배치  ·  ${_time(g.elapsed)} 소요',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text('힌트 ${g.hints}회 · 잘못 놓기 ${g.mistakes}회'),
        if (timed) Text('남은 시간 ${_time(g.remainingSeconds.toDouble())}'),
        if (newRecord)
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              '힌트 없는 최고 기록 갱신!',
              style: TextStyle(color: mint, fontWeight: FontWeight.bold),
            ),
          ),
        if (bestMs != null && !newRecord)
          Text('힌트 없는 최고 기록 ${_time(bestMs! / 1000)}'),
        if (storageError != null)
          Text(storageError!, style: const TextStyle(color: AppColors.warning)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: saving ? null : _start,
            icon: const Icon(Icons.replay),
            label: const Text('다시 도전'),
          ),
        ),
        if (g.won)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: saving || saved ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(
                saved
                    ? '내 보드에 저장했어요'
                    : saving
                    ? '저장 중…'
                    : '배치 저장',
              ),
            ),
          ),
        TextButton(
          onPressed: saving
              ? null
              : () {
                  seed++;
                  _configure();
                  _menu();
                },
          child: const Text('다른 보드 선택'),
        ),
      ],
    );
  }
}
