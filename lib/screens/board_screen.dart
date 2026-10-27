import '../design/app_design.dart';
import 'package:flutter/material.dart';
import '../models/board_project.dart';
import '../state/board_controller.dart';
import '../widgets/board_canvas.dart';
import '../widgets/pedal_art.dart';
import 'board_form_screen.dart';
import 'pedal_library.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({
    super.key,
    required this.project,
    required this.presets,
    required this.onSave,
  });
  final BoardProject project;
  final List<BoardPreset> presets;
  final Future<void> Function(BoardProject) onSave;
  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  late final BoardController board;
  final canvas = GlobalKey<BoardCanvasState>();
  bool clearance = false, grid = true, saving = false, exiting = false;
  double zoom = 1;
  @override
  void initState() {
    super.initState();
    board = BoardController(widget.project)..addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    board.removeListener(_changed);
    board.dispose();
    super.dispose();
  }

  Future<bool> _save() async {
    if (saving) return false;
    setState(() => saving = true);
    final oldDate = board.project.updatedAt;
    try {
      board.project.updatedAt = DateTime.now();
      await widget.onSave(board.project.copy());
      board.markSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('보드를 저장했습니다.'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return true;
    } catch (_) {
      board.project.updatedAt = oldDate;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장하지 못했습니다. 다시 시도해 주세요.')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _exit() async {
    if (saving) return;
    bool leave = !board.isDirty;
    if (!leave) {
      final answer = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('변경 사항을 저장할까요?'),
          content: const Text('저장하지 않으면 이번 변경 내용이 사라집니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('계속 편집'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'discard'),
              child: const Text('저장 안 함'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('저장'),
            ),
          ],
        ),
      );
      if (answer == 'save') {
        leave = await _save();
      } else {
        leave = answer == 'discard';
      }
    }
    if (leave && mounted) {
      setState(() => exiting = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> _settings() async {
    final result = await Navigator.push<BoardProject>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BoardFormScreen(presets: widget.presets, existing: board.project),
      ),
    );
    if (result != null && mounted) {
      board.changeBoard(result);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        canvas.currentState?.reset();
      });
    }
  }

  Future<void> _add() async {
    final result = await showPedalLibrary(context);
    if (result != null && mounted) {
      board.add(result.pedal, leftMm: result.leftMm, rightMm: result.rightMm);
      canvas.currentState?.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = board.project;
    final outside = p.pedals.where(board.outside).length;
    final collision = p.pedals.where(board.bodyCollision).length;
    final plugs = p.pedals
        .where((p) => board.clearanceCollision(p) || board.clearanceOutside(p))
        .length;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActionChip(
            avatar: const Icon(Icons.edit_outlined, size: 15),
            label: Text(
              '${p.presetName ?? '커스텀'} · ${p.sizeLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
            onPressed: _settings,
          ),
          const SizedBox(height: 6),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('배치'),
                icon: Icon(Icons.open_with, size: 16),
              ),
              ButtonSegment(
                value: true,
                label: Text('케이블 여유'),
                icon: Icon(Icons.space_bar, size: 16),
              ),
            ],
            selected: {clearance},
            onSelectionChanged: (s) => setState(() => clearance = s.first),
          ),
        ],
      ),
    );
    final canvasPanel = Expanded(
      child: Stack(
        children: [
          Positioned.fill(
            child: BoardCanvas(
              key: canvas,
              project: p,
              controller: board,
              showClearance: clearance,
              showGrid: grid,
              onZoom: (value) {
                if (mounted && zoom != value) {
                  setState(() => zoom = value);
                }
              },
            ),
          ),
          if (p.pedals.isEmpty)
            const Positioned(
              left: 24,
              right: 24,
              bottom: 20,
              child: IgnorePointer(
                child: Text(
                  '아래에서 페달을 추가한 뒤 드래그해 배치하세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.faint, fontSize: 12),
                ),
              ),
            ),
          if (outside + collision > 0 || (clearance && plugs > 0))
            Positioned(
              left: 12,
              right: 12,
              bottom: 8,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: .5),
                    ),
                  ),
                  child: Text(
                    [
                      if (outside > 0) '보드 밖 $outside개',
                      if (collision > 0) '본체 겹침 $collision개',
                      if (clearance && plugs > 0) '잭 여유 확인 $plugs개',
                    ].join(' · '),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    final tools = IconButtonTheme(
      data: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          padding: const EdgeInsets.all(8),
          visualDensity: VisualDensity.compact,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            IconButton(
              onPressed: () => canvas.currentState?.reset(),
              tooltip: '보드에 맞추기',
              icon: const Icon(Icons.fit_screen),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => canvas.currentState?.zoom(.8),
                  tooltip: '축소',
                  icon: const Icon(Icons.remove, size: 20),
                ),
                Text(
                  '${(zoom * 100).round()}%',
                  style: const TextStyle(fontSize: 12),
                ),
                IconButton(
                  onPressed: () => canvas.currentState?.zoom(1.25),
                  tooltip: '확대',
                  icon: const Icon(Icons.add, size: 20),
                ),
              ],
            ),
            FilterChip(
              label: const Text('스냅', style: TextStyle(fontSize: 11)),
              showCheckmark: false,
              selected: board.snap,
              onSelected: board.setSnap,
            ),
            PopupMenuButton<String>(
              tooltip: '보기 및 페달 목록',
              icon: const Icon(Icons.layers_outlined),
              enabled: true,
              onSelected: (id) {
                if (id == 'toggle-grid') {
                  setState(() => grid = !grid);
                  return;
                }
                board.select(id);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  canvas.currentState?.focusSelected();
                });
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'toggle-grid',
                  child: Text(grid ? '격자 숨기기' : '격자 표시'),
                ),
                if (p.pedals.isNotEmpty) const PopupMenuDivider(),
                for (final item in p.pedals)
                  PopupMenuItem(value: item.id, child: Text(item.pedal.name)),
              ],
            ),
          ],
        ),
      ),
    );
    final addButton = Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('페달 추가'),
        ),
      ),
    );
    return PopScope(
      canPop: exiting || (!board.isDirty && !saving),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _exit,
            tooltip: '내 보드로 돌아가기',
            icon: const Icon(Icons.arrow_back_ios_new, size: 19),
          ),
          title: Text(
            p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              onPressed: !saving && board.canUndo ? board.undo : null,
              tooltip: '실행 취소',
              icon: const Icon(Icons.undo, size: 22),
            ),
            IconButton(
              onPressed: !saving && board.canRedo ? board.redo : null,
              tooltip: '다시 실행',
              icon: const Icon(Icons.redo, size: 22),
            ),
            IconButton(
              onPressed: saving ? null : _save,
              tooltip: '보드 저장',
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      board.isDirty
                          ? Icons.save_outlined
                          : Icons.check_circle_outline,
                      color: board.isDirty ? mint : AppColors.faint,
                    ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: AbsorbPointer(
            absorbing: saving,
            child: LayoutBuilder(
              builder: (context, space) {
                if (space.maxWidth >= 650 && space.maxHeight < 550) {
                  return Column(
                    children: [
                      header,
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Column(children: [canvasPanel, tools]),
                            ),
                            SizedBox(
                              width: 260,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child: board.selected != null
                                          ? _inspector()
                                          : const Padding(
                                              padding: EdgeInsets.all(20),
                                              child: Text(
                                                '페달을 선택해 이동·회전하세요.',
                                                style: TextStyle(
                                                  color: AppColors.faint,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                  addButton,
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    header,
                    canvasPanel,
                    tools,
                    if (board.selected != null) _inspector(),
                    addButton,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _inspector() {
    final p = board.selected!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(width: 24, height: 43, child: PedalArt(pedal: p.pedal)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.pedal.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${mm(p.pedal.widthMm)} × ${mm(p.pedal.depthMm)} mm · ${p.turns * 90}°',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: board.rotate,
                tooltip: '90도 회전',
                icon: const Icon(Icons.rotate_right, size: 21),
              ),
              IconButton(
                onPressed: board.duplicate,
                tooltip: '페달 복제',
                icon: const Icon(Icons.copy_outlined, size: 20),
              ),
              IconButton(
                onPressed: board.removeSelected,
                tooltip: '페달 삭제',
                icon: const Icon(Icons.delete_outline, size: 21),
              ),
            ],
          ),
          const Divider(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 0,
            alignment: WrapAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => _position(p),
                child: Text(
                  'X ${mm(p.x)} · Y ${mm(p.y)} mm',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              TextButton(
                onPressed: () => _clearance(p),
                child: Text(
                  '잭 좌 ${mm(p.leftMm)} / 우 ${mm(p.rightMm)} mm',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _position(PlacedPedal p) async {
    final result = await _numbers('페달 위치', 'X', 'Y', p.x, p.y, -3000, 6000);
    if (result != null && mounted) {
      board.setPosition(result.$1, result.$2);
      canvas.currentState?.focusSelected();
    }
  }

  Future<void> _clearance(PlacedPedal p) async {
    final result = await _numbers(
      '잭 여유 공간',
      '좌',
      '우',
      p.leftMm,
      p.rightMm,
      0,
      100,
    );
    if (result != null && mounted) board.setClearance(result.$1, result.$2);
  }

  Future<(double, double)?> _numbers(
    String title,
    String a,
    String b,
    double av,
    double bv,
    double min,
    double max,
  ) async {
    final ac = TextEditingController(text: mm(av)),
        bc = TextEditingController(text: mm(bv));
    final form = GlobalKey<FormState>();
    final result = await showDialog<(double, double)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final pair in [(a, ac), (b, bc)])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: pair.$2,
                    decoration: InputDecoration(
                      labelText: pair.$1,
                      suffixText: 'mm',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (v) => dimensionError(v, min: min, max: max),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, (
                  double.parse(ac.text),
                  double.parse(bc.text),
                ));
              }
            },
            child: const Text('적용'),
          ),
        ],
      ),
    );
    // Wait for the dialog route's reverse transition before disposing field controllers.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    ac.dispose();
    bc.dispose();
    return result;
  }
}
