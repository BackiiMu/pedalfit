import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/pedal.dart';

class PedalArt extends StatelessWidget {
  const PedalArt({super.key, required this.pedal});
  final Pedal pedal;
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: pedal.widthMm / pedal.depthMm,
    child: CustomPaint(
      painter: PedalPainter(
        pedal,
        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
      ),
    ),
  );
}

class PedalPainter extends CustomPainter {
  PedalPainter(this.pedal, {this.fontFamily});
  final String? fontFamily;
  final Pedal pedal;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, u = math.min(w, h);
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, w - 2, h - 2),
      Radius.circular(u * .09),
    );
    canvas.drawShadow(Path()..addRRect(r), Colors.black, .08 * u, true);
    canvas.drawRRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(pedal.color, Colors.white, .16)!,
            pedal.color,
            Color.lerp(pedal.color, Colors.black, .22)!,
          ],
        ).createShader(r.outerRect),
    );
    canvas.drawRRect(
      r.deflate(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white30
        ..strokeWidth = 1,
    );
    for (final x in [w * .1, w * .9]) {
      for (final y in [h * .05, h * .95]) {
        canvas.drawCircle(
          Offset(x, y),
          u * .018,
          Paint()..color = Colors.black38,
        );
      }
    }
    if (pedal.category == PedalCategory.wah) {
      final tread = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .15, h * .07, w * .7, h * .84),
        Radius.circular(u * .08),
      );
      canvas.drawRRect(tread, Paint()..color = const Color(0xFF222825));
      canvas.drawRRect(
        tread,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white30,
      );
      for (double y = h * .12; y < h * .86; y += math.max(3, h * .022)) {
        canvas.drawLine(
          Offset(w * .22, y),
          Offset(w * .78, y),
          Paint()
            ..color = Colors.white12
            ..strokeWidth = 1,
        );
      }
      return;
    }
    if (pedal.artwork == 'screen' || pedal.artwork == 'triple') {
      final screen = Rect.fromLTWH(w * .12, h * .12, w * .76, h * .42);
      canvas.drawRRect(
        RRect.fromRectAndRadius(screen, Radius.circular(u * .035)),
        Paint()..color = const Color(0xFF15201D),
      );
      final label = TextPainter(
        text: TextSpan(
          text: pedal.name,
          style: TextStyle(
            fontFamily: fontFamily,
            color: Colors.white,
            fontSize: u * .09,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: screen.width * .9);
      label.paint(
        canvas,
        Offset((w - label.width) / 2, screen.center.dy - label.height / 2),
      );
      final switches = pedal.artwork == 'screen' ? 4 : 3;
      for (var i = 0; i < switches; i++) {
        final center = Offset(w * (.15 + i * .7 / (switches - 1)), h * .79);
        canvas.drawCircle(
          center,
          u * .065,
          Paint()..color = const Color(0xFFD8DEDA),
        );
        canvas.drawCircle(
          center,
          u * .043,
          Paint()..color = const Color(0xFF9BA6A0),
        );
      }
      return;
    }
    final count = math.min(pedal.controls.length, 3);
    for (int i = 0; i < count; i++) {
      final x = count == 1 ? w * .5 : w * (.23 + i * .27);
      final y = h * .18 + (i == 2 && count == 3 ? h * .14 : 0);
      final c = Offset(x, y), radius = u * .105;
      canvas.drawShadow(
        Path()..addOval(Rect.fromCircle(center: c, radius: radius)),
        Colors.black,
        2,
        true,
      );
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF414B45), Color(0xFF111713)],
          ).createShader(Rect.fromCircle(center: c, radius: radius)),
      );
      canvas.drawLine(
        c - Offset(0, radius * .8),
        c - Offset(0, radius * .22),
        Paint()
          ..color = Colors.white70
          ..strokeWidth = math.max(1, u * .018),
      );
    }
    if (w > 28 && h > 50) {
      final label = TextPainter(
        text: TextSpan(
          text: pedal.name.toUpperCase(),
          style: TextStyle(
            fontFamily: fontFamily,
            color: pedal.color.computeLuminance() < .25
                ? Colors.white
                : const Color(0xFF17211B),
            fontSize: math.min(10, u * .105),
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: w * .84);
      label.paint(canvas, Offset((w - label.width) / 2, h * .48));
    }
    canvas.drawCircle(
      Offset(w * .5, h * .7),
      u * .025,
      Paint()..color = const Color(0xFFEEF4C4),
    );
    final c = Offset(w * .5, h * .83);
    canvas.drawCircle(c, u * .12, Paint()..color = const Color(0xFF68736B));
    canvas.drawCircle(
      c,
      u * .09,
      Paint()
        ..shader = const LinearGradient(
          colors: [Colors.white, Color(0xFFB1BBB4)],
        ).createShader(Rect.fromCircle(center: c, radius: u * .09)),
    );
  }

  @override
  bool shouldRepaint(PedalPainter old) =>
      old.pedal != pedal || old.fontFamily != fontFamily;
}
