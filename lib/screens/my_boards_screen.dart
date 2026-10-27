import '../design/app_design.dart';
import 'package:flutter/material.dart';
import '../data/board_repository.dart';
import '../models/board_project.dart';
import '../widgets/board_canvas.dart';
import 'board_form_screen.dart';
import 'board_screen.dart';
import '../game/tetris_screen.dart';
import '../game/packing_screen.dart';

class MyBoardsScreen extends StatefulWidget {
  const MyBoardsScreen({super.key, this.repository});
  final BoardRepository? repository;
  @override
  State<MyBoardsScreen> createState() => _MyBoardsScreenState();
}

class _MyBoardsScreenState extends State<MyBoardsScreen> {
  late final BoardRepository repository;
  List<BoardProject> boards = [];
  List<BoardPreset> presets = [];
  bool loading = true, busy = false;
  String? error;
  String query = '', filter = '전체';
  @override
  void initState() {
    super.initState();
    repository = widget.repository ?? BoardRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        repository.load(),
        repository.presets(),
      ]);
      if (mounted) {
        setState(() {
          boards = results[0] as List<BoardProject>;
          presets = results[1] as List<BoardPreset>;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = '보드 데이터를 읽지 못했습니다. 기존 저장 데이터는 유지됩니다.';
        });
      }
    }
  }

  Future<void> _saveProject(BoardProject p) async {
    final next = [p.copy(), ...boards.where((b) => b.id != p.id)]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await repository.save(next);
    if (mounted) setState(() => boards = next);
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _create() async {
    final p = await Navigator.push<BoardProject>(
      context,
      MaterialPageRoute(builder: (_) => BoardFormScreen(presets: presets)),
    );
    if (p == null || !mounted) return;
    setState(() => busy = true);
    try {
      await _saveProject(p);
      if (mounted) {
        setState(() => busy = false);
        await _open(p);
      }
    } catch (_) {
      _message('보드를 만들지 못했습니다. 저장 공간을 확인하고 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _open(BoardProject p) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) =>
          BoardScreen(project: p, presets: presets, onSave: _saveProject),
    ),
  );
  Future<void> _duplicate(BoardProject source) async {
    setState(() => busy = true);
    try {
      final j = source.toJson()
        ..['id'] = newId()
        ..['name'] = '${source.name} 복사본'
        ..['updatedAt'] = DateTime.now().toIso8601String();
      await _saveProject(BoardProject.fromJson(j));
      _message('보드를 복제했습니다.');
    } catch (_) {
      _message('복제한 보드를 저장하지 못했습니다.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _delete(BoardProject p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('보드를 삭제할까요?'),
        content: Text('“${p.name}”의 저장된 배치가 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      final next = boards.where((b) => b.id != p.id).toList();
      await repository.save(next);
      if (mounted) setState(() => boards = next);
    } catch (_) {
      _message('삭제 내용을 저장하지 못했습니다. 보드는 유지됩니다.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _games() async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '페달 게임',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.grid_view, color: mint),
              title: const Text('클래식 테트리스'),
              subtitle: const Text('하늘에서 떨어지는 페달 블록으로 줄 채우기'),
              onTap: () => Navigator.pop(context, 'tetris'),
            ),
            ListTile(
              leading: const Icon(
                Icons.dashboard_customize_outlined,
                color: mint,
              ),
              title: const Text('페달 맞추기'),
              subtitle: const Text('내 보드 안에 페달 모두 넣기 · 자유 / 시간 도전'),
              onTap: () => Navigator.pop(context, 'packing'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || mode == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => mode == 'tetris'
            ? TetrisScreen(boards: boards)
            : PackingScreen(
                boards: boards,
                presets: presets,
                onSave: _saveProject,
              ),
      ),
    );
  }

  void _info() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => const SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '페달보드 테트리스',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Text(
            '실제 크기에 맞춰 페달을 배치하고 보드 안에 들어가는지 확인하세요. 보드는 이 기기에 저장됩니다. 삭제·앱 제거 시 복구할 수 없으니 주의하세요.',
          ),
          SizedBox(height: 16),
          Text('배치 안내', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            '빨강: 본체 겹침 또는 보드 밖 배치\n주황: 잭 여유 공간의 겹침·경계 이탈\n스냅: 5mm 간격\n레일 그림은 개략도이며 실물 고정 가능성을 보장하지 않습니다.',
          ),
          SizedBox(height: 16),
          Text('제품 및 이미지', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            'Pedaltrain 프리셋 19종은 공식 명목 제원을 mm로 환산했습니다. 실제 모델 프리셋 8종과 가상 페달 14종을 제공합니다. 실제 모델은 제조사 명목 치수를 사용한 개략도입니다. 케이블·돌출부와 실측 크기를 확인하세요. 외부 제조사 사진과 로고는 포함하지 않습니다.',
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final filtered = boards
        .where(
          (b) =>
              '${b.name} ${b.typeLabel}'.toLowerCase().contains(
                query.toLowerCase(),
              ) &&
              (filter == '전체' ||
                  (filter == '커스텀' ? b.presetId == null : b.presetId != null)),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.view_week_outlined, color: AppColors.ink),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'pedalboard',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('open-tetris'),
            tooltip: '페달 게임',
            onPressed: loading || error != null ? null : _games,
            icon: const Icon(Icons.sports_esports_outlined),
          ),
          IconButton(
            onPressed: _info,
            tooltip: '사용 안내 및 이미지 정보',
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      bottomNavigationBar: loading || error != null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton.icon(
                  key: const ValueKey('create-board'),
                  onPressed: busy ? null : _create,
                  icon: const Icon(Icons.add),
                  label: Text(busy ? '저장 중…' : '새 보드 만들기'),
                ),
              ),
            ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            )
          : AbsorbPointer(
              absorbing: busy,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '내 보드',
                                style: TextStyle(
                                  fontSize: 32,
                                  letterSpacing: -1,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                '보드별 페달 배치를 관리하세요.',
                                style: TextStyle(color: AppColors.muted),
                              ),
                              const SizedBox(height: 24),
                              TextField(
                                decoration: const InputDecoration(
                                  hintText: '보드 검색',
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onChanged: (v) =>
                                    setState(() => query = v.trim()),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 44,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    for (final f in ['전체', '제품 프리셋', '커스텀'])
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: ChoiceChip(
                                          label: Text(f),
                                          selected: filter == f,
                                          onSelected: (_) =>
                                              setState(() => filter = f),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (filtered.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  boards.isEmpty
                                      ? Icons.dashboard_customize_outlined
                                      : Icons.search_off,
                                  size: 52,
                                  color: AppColors.line,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  boards.isEmpty
                                      ? '첫 페달보드를 만들어 보세요.'
                                      : '조건에 맞는 보드가 없습니다.',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                                if (boards.isEmpty) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    '제품 프리셋을 고르거나 크기를 직접 입력하세요.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.faint,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          sliver: SliverLayoutBuilder(
                            builder: (context, c) => SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: c.crossAxisExtent >= 700
                                        ? 2
                                        : 1,
                                    mainAxisExtent: 278,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                              delegate: SliverChildBuilderDelegate(
                                (context, i) => _card(filtered[i]),
                                childCount: filtered.length,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _card(BoardProject p) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: () => _open(p),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: BoardCanvas(project: p, showGrid: false),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.typeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.sizeLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.faint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '페달 ${p.pedals.length}개',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: '보드 메뉴',
                    onSelected: (v) {
                      if (v == 'copy') _duplicate(p);
                      if (v == 'delete') _delete(p);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'copy', child: Text('보드 복제')),
                      PopupMenuItem(value: 'delete', child: Text('보드 삭제')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
