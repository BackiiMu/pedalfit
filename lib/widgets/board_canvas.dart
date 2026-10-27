import 'dart:math' as math;
import '../design/app_design.dart';
import 'package:flutter/material.dart';
import '../models/board_project.dart';
import '../state/board_controller.dart';
import 'pedal_art.dart';

const mint = AppColors.blue;

class BoardCanvas extends StatefulWidget {
  const BoardCanvas({
    super.key,
    required this.project,
    this.controller,
    this.showClearance = false,
    this.showGrid = true,
    this.onZoom,
  });
  final BoardProject project;
  final BoardController? controller;
  final bool showClearance, showGrid;
  final ValueChanged<double>? onZoom;
  @override
  State<BoardCanvas> createState() => BoardCanvasState();
}

class BoardCanvasState extends State<BoardCanvas> {
  final transform = TransformationController();
  final viewport = GlobalKey();
  int? activePointer;
  bool canvasGestureActive = false;
  double gestureScale = 1;
  Offset gestureAnchor = Offset.zero;
  Size viewportSize = Size.zero;
  double fit = 1;
  Offset origin = Offset.zero,
      _startScene = Offset.zero,
      _startBody = Offset.zero;
  @override
  void initState() {
    super.initState();
    transform.addListener(_zoomChanged);
  }

  void _zoomChanged() =>
      widget.onZoom?.call(transform.value.getMaxScaleOnAxis());
  @override
  void dispose() {
    transform.removeListener(_zoomChanged);
    transform.dispose();
    super.dispose();
  }

  void reset() => transform.value = Matrix4.identity();
  void zoom(double multiplier) {
    final c = viewportSize.center(Offset.zero), scene = transform.toScene(c);
    final z = (transform.value.getMaxScaleOnAxis() * multiplier).clamp(.5, 6.0);
    transform.value = Matrix4.diagonal3Values(z, z, 1)
      ..setTranslationRaw(c.dx - scene.dx * z, c.dy - scene.dy * z, 0);
  }

  void focusSelected() {
    final p = widget.controller?.selected;
    if (p == null) return;
    final c = viewportSize.center(Offset.zero),
        target = origin + p.body.center * fit;
    transform.value = Matrix4.identity()
      ..setTranslationRaw(c.dx - target.dx, c.dy - target.dy, 0);
  }

  Offset _scene(Offset global) {
    final box = viewport.currentContext!.findRenderObject()! as RenderBox;
    return transform.toScene(box.globalToLocal(global));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      viewportSize = Size(c.maxWidth, c.maxHeight);
      fit = math.min(
        c.maxWidth / (widget.project.widthMm + 110),
        c.maxHeight / (widget.project.depthMm + 130),
      );
      origin = Offset(
        (c.maxWidth - widget.project.widthMm * fit) / 2,
        (c.maxHeight - widget.project.depthMm * fit) / 2,
      );
      final controller = widget.controller;
      final content = SizedBox(
        width: c.maxWidth,
        height: c.maxHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: controller == null
                    ? null
                    : () => controller.select(null),
                child: CustomPaint(
                  painter: DeckPainter(
                    widget.project,
                    origin,
                    fit,
                    grid: widget.showGrid,
                    rulers: controller != null,
                    fontFamily: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.fontFamily,
                  ),
                ),
              ),
            ),
            for (final p in widget.project.pedals)
              Positioned(
                left: origin.dx + p.x * fit,
                top: origin.dy + p.y * fit,
                width: p.width * fit,
                height: p.depth * fit,
                child: Semantics(
                  label: '${p.pedal.name}, ${mm(p.width)} × ${mm(p.depth)} mm',
                  button: controller != null,
                  onTap: controller == null
                      ? null
                      : () => controller.select(p.id),
                  child: Listener(
                    key: ValueKey('pedal-${p.id}'),
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: controller == null
                        ? null
                        : (d) {
                            if (activePointer != null) return;
                            setState(() => activePointer = d.pointer);
                            _startScene = _scene(d.position);
                            _startBody = Offset(p.x, p.y);
                            controller.beginMove(p.id);
                          },
                    onPointerMove: controller == null
                        ? null
                        : (d) {
                            if (activePointer != d.pointer) return;
                            final delta =
                                (_scene(d.position) - _startScene) / fit;
                            controller.moveTo(
                              _startBody.dx + delta.dx,
                              _startBody.dy + delta.dy,
                            );
                          },
                    onPointerUp: controller == null
                        ? null
                        : (d) {
                            if (activePointer != d.pointer) return;
                            controller.endMove();
                            setState(() => activePointer = null);
                          },
                    onPointerCancel: controller == null
                        ? null
                        : (d) {
                            if (activePointer != d.pointer) return;
                            controller.endMove();
                            setState(() => activePointer = null);
                          },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: RotatedBox(
                            quarterTurns: p.turns,
                            child: PedalArt(pedal: p.pedal),
                          ),
                        ),
                        if (widget.showClearance)
                          Positioned(
                            left: (p.clearance.left - p.x) * fit,
                            top: (p.clearance.top - p.y) * fit,
                            width: p.clearance.width * fit,
                            height: p.clearance.height * fit,
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: DashPainter(
                                  controller != null &&
                                          (controller.clearanceCollision(p) ||
                                              controller.clearanceOutside(p))
                                      ? Colors.orangeAccent
                                      : Colors.white38,
                                ),
                              ),
                            ),
                          ),
                        if (controller != null &&
                            (controller.selectedId == p.id ||
                                controller.outside(p) ||
                                controller.bodyCollision(p)))
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color:
                                        controller.outside(p) ||
                                            controller.bodyCollision(p)
                                        ? Colors.redAccent
                                        : mint,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (controller?.selectedId == p.id)
                          Positioned(
                            left: -6,
                            top: -28,
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  border: Border.all(color: mint),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  '${mm(p.width)} × ${mm(p.depth)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: mint,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
      if (controller == null) return ClipRect(child: content);
      return ClipRect(
        child: SizedBox(
          key: viewport,
          width: c.maxWidth,
          height: c.maxHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            trackpadScrollCausesScale: true,
            onScaleStart: (d) {
              canvasGestureActive = activePointer == null;
              if (!canvasGestureActive) return;
              gestureScale = transform.value.getMaxScaleOnAxis();
              gestureAnchor = transform.toScene(d.localFocalPoint);
            },
            onScaleUpdate: (d) {
              if (activePointer != null || !canvasGestureActive) return;
              final z = (gestureScale * d.scale).clamp(.5, 6.0);
              transform.value = Matrix4.diagonal3Values(z, z, 1)
                ..setTranslationRaw(
                  d.localFocalPoint.dx - gestureAnchor.dx * z,
                  d.localFocalPoint.dy - gestureAnchor.dy * z,
                  0,
                );
            },
            onScaleEnd: (_) => canvasGestureActive = false,
            child: AnimatedBuilder(
              animation: transform,
              builder: (context, child) => Transform(
                alignment: Alignment.topLeft,
                transform: transform.value,
                child: child,
              ),
              child: content,
            ),
          ),
        ),
      );
    },
  );
}

class DeckPainter extends CustomPainter {
  DeckPainter(
    this.project,
    this.origin,
    this.scale, {
    this.grid = false,
    this.rulers = false,
    this.fontFamily,
  });
  final BoardProject project;
  final Offset origin;
  final double scale;
  final bool grid, rulers;
  final String? fontFamily;
  @override
  void paint(Canvas canvas, Size size) {
    if (grid) {
      final step = math.max(12.0, 20 * scale);
      final paint = Paint()..color = AppColors.ink.withValues(alpha: .08);
      for (double x = origin.dx % step; x < size.width; x += step) {
        for (double y = origin.dy % step; y < size.height; y += step) {
          canvas.drawCircle(Offset(x, y), .65, paint);
        }
      }
    }
    final rect = Rect.fromLTWH(
      origin.dx,
      origin.dy,
      project.widthMm * scale,
      project.depthMm * scale,
    );
    final round = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawShadow(Path()..addRRect(round), Colors.black, 6, true);
    canvas.drawRRect(round, Paint()..color = Color(project.colorValue));
    if (project.presetId != null) {
      final count = switch (project.series) {
        'Nano' => 2,
        'Metro' => 3,
        'XD' => 6,
        'Novo' || 'Terra' => 5,
        _ => project.depthMm > 380 ? 5 : 4,
      };
      final inset = math.min(8.0, rect.width * .015),
          rail = rect.height / (count * 1.65);
      canvas.drawRect(
        rect.deflate(inset),
        Paint()..color = const Color(0xFF0D120F),
      );
      for (int i = 0; i < count; i++) {
        final y = rect.top + i * (rect.height - rail) / (count - 1);
        final r = Rect.fromLTWH(rect.left, y, rect.width, rail);
        canvas.drawRect(
          r,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3A423D), Color(0xFF202622)],
            ).createShader(r),
        );
        canvas.drawLine(r.topLeft, r.topRight, Paint()..color = Colors.white24);
      }
    }
    canvas.drawRRect(
      round,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white24,
    );
    for (final x in [rect.left + 6, rect.right - 6]) {
      for (final y in [rect.top + 6, rect.bottom - 6]) {
        canvas.drawCircle(Offset(x, y), 1.5, Paint()..color = Colors.black54);
      }
    }
    if (rulers) {
      final p = Paint()
        ..color = AppColors.line
        ..strokeWidth = 1;
      final y = rect.top - 25;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), p);
      for (final x in [rect.left, rect.right]) {
        canvas.drawLine(Offset(x, y - 4), Offset(x, y + 4), p);
      }
      _text(
        canvas,
        '${mm(project.widthMm)} mm',
        Offset(rect.center.dx, y - 18),
        center: true,
      );
      final x = rect.left - 22;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), p);
      for (final yy in [rect.top, rect.bottom]) {
        canvas.drawLine(Offset(x - 4, yy), Offset(x + 4, yy), p);
      }
      canvas.save();
      canvas.translate(x - 7, rect.center.dy);
      canvas.rotate(-math.pi / 2);
      _text(canvas, '${mm(project.depthMm)} mm', Offset.zero, center: true);
      canvas.restore();
    }
  }

  void _text(Canvas c, String s, Offset at, {bool center = false}) {
    final t = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: 10,
          color: AppColors.muted,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    t.paint(c, at - Offset(center ? t.width / 2 : 0, 0));
  }

  @override
  bool shouldRepaint(DeckPainter old) => true;
}

class DashPainter extends CustomPainter {
  DashPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(4)),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 8) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 4, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(DashPainter old) => old.color != color;
}
