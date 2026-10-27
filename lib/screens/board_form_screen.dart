import '../design/app_design.dart';
import 'package:flutter/material.dart';
import '../models/board_project.dart';
import '../widgets/board_canvas.dart';

const boardColors = [0xFF252D29, 0xFF121714, 0xFFB4B9B5, 0xFFC4A27D];
String? dimensionError(String? text, {double min = 50, double max = 3000}) {
  final n = double.tryParse(text ?? '');
  if (n == null || !n.isFinite) return '숫자를 입력하세요';
  if (n < min || n > max) return '${mm(min)}–${mm(max)} mm';
  return null;
}

class BoardFormScreen extends StatefulWidget {
  const BoardFormScreen({super.key, required this.presets, this.existing});
  final List<BoardPreset> presets;
  final BoardProject? existing;
  @override
  State<BoardFormScreen> createState() => _BoardFormScreenState();
}

class _BoardFormScreenState extends State<BoardFormScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, width, depth;
  late BoardPreset preset;
  late bool custom;
  String? originPresetId;
  bool locked = false;
  double ratio = 1;
  int color = boardColors.first;
  @override
  void initState() {
    super.initState();
    final old = widget.existing;
    preset =
        widget.presets
            .where((p) => p.id == (old?.presetId ?? 'pedaltrain_classic_2'))
            .firstOrNull ??
        widget.presets.first;
    originPresetId = old?.presetId ?? old?.originPresetId;
    custom = old != null && old.presetId == null;
    color = old?.colorValue ?? boardColors.first;
    name = TextEditingController(text: old?.name ?? '새 페달보드');
    width = TextEditingController(text: mm(old?.widthMm ?? 600));
    depth = TextEditingController(text: mm(old?.depthMm ?? 320));
  }

  @override
  void dispose() {
    name.dispose();
    width.dispose();
    depth.dispose();
    super.dispose();
  }

  BoardProject get preview => BoardProject(
    id: widget.existing?.id ?? newId(),
    name: name.text.trim(),
    widthMm: custom
        ? (double.tryParse(width.text) ?? 600).clamp(50, 3000)
        : preset.widthMm,
    depthMm: custom
        ? (double.tryParse(depth.text) ?? 320).clamp(50, 3000)
        : preset.depthMm,
    presetId: custom ? null : preset.id,
    presetName: custom ? null : preset.model,
    series: custom ? null : preset.series,
    colorValue: color,
  );
  void _submit() {
    if (!form.currentState!.validate()) return;
    final p = preview;
    p.originPresetId = custom ? originPresetId : preset.id;
    Navigator.pop(context, p);
  }

  void _customTab(bool value) {
    if (value == custom) return;
    if (value && !custom) {
      originPresetId = preset.id;
      width.text = mm(preset.widthMm);
      depth.text = mm(preset.depthMm);
    }
    setState(() => custom = value);
  }

  void _dimensionChanged(bool isWidth) {
    if (locked) {
      final n = double.tryParse(isWidth ? width.text : depth.text);
      if (n != null && n.isFinite && n > 0) {
        if (isWidth) {
          depth.text = mm(n / ratio);
        } else {
          width.text = mm(n * ratio);
        }
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.existing == null ? '새 보드' : '보드 설정')),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: FilledButton(
          onPressed: _submit,
          child: Text(widget.existing == null ? '이 보드로 시작' : '변경 적용'),
        ),
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('제품 프리셋')),
                  ButtonSegment(value: true, label: Text('커스텀')),
                ],
                selected: {custom},
                onSelectionChanged: (s) => _customTab(s.first),
              ),
              const SizedBox(height: 24),
              if (!custom) ...[
                const Text('제조사', style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 8),
                const InputDecorator(
                  decoration: InputDecoration(),
                  child: Text('Pedaltrain'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final series in [
                        'Nano',
                        'Metro',
                        'Classic',
                        'Novo',
                        'XD',
                        'Terra',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(series),
                            selected: preset.series == series,
                            onSelected: (_) => setState(
                              () => preset = widget.presets.firstWhere(
                                (p) => p.series == series,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _preview(),
                const SizedBox(height: 12),
                for (final p in widget.presets.where(
                  (p) => p.series == preset.series,
                ))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: p.id == preset.id
                          ? mint.withValues(alpha: .08)
                          : AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: p.id == preset.id ? mint : AppColors.line,
                        ),
                      ),
                      child: ListTile(
                        onTap: () => setState(() => preset = p),
                        leading: Icon(
                          p.id == preset.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: p.id == preset.id ? mint : AppColors.faint,
                        ),
                        title: Text(p.model),
                        subtitle: Text(
                          '${mm(p.widthMm)} × ${mm(p.depthMm)} mm',
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: '보드 이름'),
                textInputAction: TextInputAction.next,
                maxLength: 60,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? '이름을 입력하세요' : null,
              ),
              if (custom) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('board-width'),
                        controller: width,
                        decoration: const InputDecoration(
                          labelText: '가로',
                          suffixText: 'mm',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: dimensionError,
                        onChanged: (_) => _dimensionChanged(true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('board-depth'),
                        controller: depth,
                        decoration: const InputDecoration(
                          labelText: '깊이',
                          suffixText: 'mm',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: dimensionError,
                        onChanged: (_) => _dimensionChanged(false),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('비율 잠금'),
                  secondary: const Icon(Icons.link),
                  value: locked,
                  onChanged: (v) => setState(() {
                    locked = v;
                    ratio = preview.widthMm / preview.depthMm;
                  }),
                ),
                const SizedBox(height: 16),
                _preview(),
                const SizedBox(height: 20),
                const Text('보드 색상'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: [
                    for (final c in boardColors)
                      Semantics(
                        label: '보드 색상 ${boardColors.indexOf(c) + 1}',
                        selected: color == c,
                        button: true,
                        child: InkWell(
                          onTap: () => setState(() => color = c),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Color(c),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: color == c ? mint : AppColors.line,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                '가로 × 깊이 · mm  /  페달 크기는 보드 크기와 같은 비율로 표시됩니다.',
                style: TextStyle(fontSize: 12, color: AppColors.faint),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _preview() => Container(
    height: 210,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      children: [
        Expanded(child: BoardCanvas(project: preview)),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            '${custom ? '커스텀' : preset.model} · ${preview.sizeLabel}',
            style: const TextStyle(color: AppColors.muted),
          ),
        ),
      ],
    ),
  );
}
