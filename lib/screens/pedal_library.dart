import '../design/app_design.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/pedal.dart';
import '../models/board_project.dart';
import '../data/pedal_catalog.dart';
import '../widgets/pedal_art.dart';
import '../widgets/board_canvas.dart';
import 'board_form_screen.dart';

class PedalChoice {
  const PedalChoice(this.pedal, {this.leftMm = 12, this.rightMm = 12});
  final Pedal pedal;
  final double leftMm, rightMm;
}

Future<PedalChoice?> showPedalLibrary(BuildContext context) =>
    showModalBottomSheet<PedalChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => const PedalLibrary(),
    );

class PedalLibrary extends StatefulWidget {
  const PedalLibrary({super.key});
  @override
  State<PedalLibrary> createState() => _PedalLibraryState();
}

class _PedalLibraryState extends State<PedalLibrary> {
  String query = '', filter = '전체';
  @override
  Widget build(BuildContext context) {
    final list = pedalCatalog.where((p) {
      final matches = p.searchText.contains(query.trim().toLowerCase());
      final size =
          filter == '전체' ||
          (filter == '미니' && p.widthMm <= 45) ||
          (filter == '스탠다드' && p.widthMm > 45 && p.widthMm < 100) ||
          (filter == '와이드' && p.widthMm >= 100);
      return matches && size;
    }).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .83,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '페달 추가',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: '닫기',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            TextField(
              decoration: const InputDecoration(
                hintText: '모델·브랜드·한글 이름으로 검색',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final f in ['전체', '미니', '스탠다드', '와이드'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f),
                        selected: filter == f,
                        onSelected: (_) => setState(() => filter = f),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('조건에 맞는 페달이 없습니다.'))
                  : LayoutBuilder(
                      builder: (context, c) => GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: c.maxWidth > 620 ? 3 : 2,
                          mainAxisExtent: 215,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final p = list[i];
                          return Material(
                            color: AppColors.paper,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () =>
                                  Navigator.pop(context, PedalChoice(p)),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, c) {
                                          final factor = math.min(
                                            c.maxWidth / 228,
                                            c.maxHeight / 260,
                                          );
                                          return Center(
                                            child: SizedBox(
                                              width: p.widthMm * factor,
                                              height: p.depthMm * factor,
                                              child: PedalArt(pedal: p),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (p.id == 'ehx_big_muff_pi')
                                      const Text(
                                        '치수 방향 실측 확인 필요',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.amber,
                                        ),
                                      ),
                                    Text(
                                      p.brand.isEmpty ? '가상 페달' : p.brand,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                    Text(
                                      p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${mm(p.widthMm)} × ${mm(p.depthMm)} mm',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.muted,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.add_circle_outline,
                                          color: mint,
                                          size: 24,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('커스텀 페달 만들기'),
                  onPressed: () async {
                    final choice = await showModalBottomSheet<PedalChoice>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => const CustomPedalForm(),
                    );
                    if (context.mounted && choice != null) {
                      Navigator.pop(context, choice);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomPedalForm extends StatefulWidget {
  const CustomPedalForm({super.key});
  @override
  State<CustomPedalForm> createState() => _CustomPedalFormState();
}

class _CustomPedalFormState extends State<CustomPedalForm> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      width = TextEditingController(text: '70'),
      depth = TextEditingController(text: '125'),
      left = TextEditingController(text: '12'),
      right = TextEditingController(text: '12');
  final colors = const [
    0xFF83BBA6,
    0xFFE3B66F,
    0xFF86B9CB,
    0xFFC995A3,
    0xFF59675E,
    0xFFC2C9C5,
  ];
  int color = 0xFFC995A3;
  @override
  void dispose() {
    for (final c in [name, width, depth, left, right]) {
      c.dispose();
    }
    super.dispose();
  }

  Pedal get preview => Pedal(
    id: 'preview',
    name: name.text.trim().isEmpty ? 'My Pedal' : name.text.trim(),
    category: PedalCategory.multi,
    color: Color(color),
    isCustom: true,
    widthMm: (double.tryParse(width.text) ?? 70).clamp(10, 1500),
    depthMm: (double.tryParse(depth.text) ?? 125).clamp(10, 1500),
  );
  void _submit() {
    if (!form.currentState!.validate()) return;
    final p = preview;
    Navigator.pop(
      context,
      PedalChoice(
        Pedal(
          id: 'custom_${newId()}',
          name: p.name,
          category: p.category,
          color: p.color,
          isCustom: true,
          widthMm: p.widthMm,
          depthMm: p.depthMm,
        ),
        leftMm: double.parse(left.text),
        rightMm: double.parse(right.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .85,
      child: Form(
        key: form,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '커스텀 페달',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: '닫기',
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: '페달 이름'),
                    maxLength: 40,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? '이름을 입력하세요' : null,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _number(width, '가로', 10, 1500)),
                      const SizedBox(width: 12),
                      Expanded(child: _number(depth, '깊이', 10, 1500)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 170,
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: PedalArt(pedal: preview),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '본체 ${mm(preview.widthMm)} × ${mm(preview.depthMm)} mm',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('색상'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final c in colors)
                        Semantics(
                          label: '페달 색상 ${colors.indexOf(c) + 1}',
                          selected: color == c,
                          button: true,
                          child: InkWell(
                            onTap: () => setState(() => color = c),
                            customBorder: const CircleBorder(),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Color(c),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: color == c ? mint : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('잭 여유 공간'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _number(left, '좌', 0, 100)),
                      const SizedBox(width: 12),
                      Expanded(child: _number(right, '우', 0, 100)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '본체 크기와 잭 공간을 따로 계산해요.',
                    style: TextStyle(color: AppColors.faint, fontSize: 12),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('만들고 보드에 추가'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _number(
    TextEditingController c,
    String label,
    double min,
    double max,
  ) => TextFormField(
    controller: c,
    decoration: InputDecoration(labelText: label, suffixText: 'mm'),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    validator: (v) => dimensionError(v, min: min, max: max),
    onChanged: (_) => setState(() {}),
  );
}
