import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'pedal.dart';

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(1 << 32)}';
String mm(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

class BoardPreset {
  BoardPreset.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      model = j['model'] as String,
      series = j['series'] as String,
      widthMm = (j['width_mm'] as num).toDouble(),
      depthMm = (j['depth_mm'] as num).toDouble();
  final String id, model, series;
  final double widthMm, depthMm;
}

class PlacedPedal {
  PlacedPedal({
    required this.id,
    required this.pedal,
    this.x = 15,
    this.y = 15,
    this.turns = 0,
    this.leftMm = 12,
    this.rightMm = 12,
  });
  final String id;
  final Pedal pedal;
  double x, y, leftMm, rightMm;
  int turns;
  double get width => turns.isOdd ? pedal.depthMm : pedal.widthMm;
  double get depth => turns.isOdd ? pedal.widthMm : pedal.depthMm;
  Rect get body => Rect.fromLTWH(x, y, width, depth);
  Rect get clearance => switch (turns % 4) {
    0 => Rect.fromLTRB(x - leftMm, y, x + width + rightMm, y + depth),
    1 => Rect.fromLTRB(x, y - leftMm, x + width, y + depth + rightMm),
    2 => Rect.fromLTRB(x - rightMm, y, x + width + leftMm, y + depth),
    _ => Rect.fromLTRB(x, y - rightMm, x + width, y + depth + leftMm),
  };
  Map<String, dynamic> toJson() => {
    'id': id,
    'pedal': pedal.toJson(),
    'x': x,
    'y': y,
    'turns': turns,
    'leftMm': leftMm,
    'rightMm': rightMm,
  };
  factory PlacedPedal.fromJson(Map<String, dynamic> j) => PlacedPedal(
    id: j['id'] as String,
    pedal: Pedal.fromJson(Map<String, dynamic>.from(j['pedal'] as Map)),
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    turns: j['turns'] as int,
    leftMm: (j['leftMm'] as num).toDouble(),
    rightMm: (j['rightMm'] as num).toDouble(),
  );
}

class BoardProject {
  BoardProject({
    required this.id,
    required this.name,
    required this.widthMm,
    required this.depthMm,
    this.presetId,
    this.presetName,
    this.originPresetId,
    this.series,
    this.colorValue = 0xFF252D29,
    DateTime? updatedAt,
    List<PlacedPedal>? pedals,
  }) : updatedAt = updatedAt ?? DateTime.now(),
       pedals = pedals ?? [];
  final String id;
  String name;
  double widthMm, depthMm;
  String? presetId, presetName, originPresetId, series;
  int colorValue;
  DateTime updatedAt;
  final List<PlacedPedal> pedals;
  String get sizeLabel => '${mm(widthMm)} × ${mm(depthMm)} mm';
  String get typeLabel => presetName == null ? '커스텀' : 'Pedaltrain $presetName';
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'widthMm': widthMm,
    'depthMm': depthMm,
    'presetId': presetId,
    'presetName': presetName,
    'originPresetId': originPresetId,
    'series': series,
    'colorValue': colorValue,
    'updatedAt': updatedAt.toIso8601String(),
    'pedals': pedals.map((p) => p.toJson()).toList(),
  };
  factory BoardProject.fromJson(Map<String, dynamic> j) {
    final w = (j['widthMm'] as num).toDouble(),
        d = (j['depthMm'] as num).toDouble();
    if (!w.isFinite ||
        !d.isFinite ||
        w < 50 ||
        d < 50 ||
        w > 3000 ||
        d > 3000) {
      throw const FormatException('올바르지 않은 보드 크기');
    }
    final pedals = (j['pedals'] as List)
        .map((p) => PlacedPedal.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();
    for (final p in pedals) {
      if (![
            p.x,
            p.y,
            p.pedal.widthMm,
            p.pedal.depthMm,
            p.leftMm,
            p.rightMm,
          ].every((n) => n.isFinite) ||
          p.pedal.widthMm < 10 ||
          p.pedal.depthMm < 10 ||
          p.pedal.widthMm > 1500 ||
          p.pedal.depthMm > 1500 ||
          p.leftMm < 0 ||
          p.rightMm < 0 ||
          p.leftMm > 100 ||
          p.rightMm > 100 ||
          p.turns < 0 ||
          p.turns > 3) {
        throw const FormatException('올바르지 않은 페달 데이터');
      }
    }
    return BoardProject(
      id: j['id'] as String,
      name: j['name'] as String,
      widthMm: w,
      depthMm: d,
      presetId: j['presetId'] as String?,
      presetName: j['presetName'] as String?,
      originPresetId: j['originPresetId'] as String?,
      series: j['series'] as String?,
      colorValue: j['colorValue'] as int,
      updatedAt: DateTime.parse(j['updatedAt'] as String),
      pedals: pedals,
    );
  }
  BoardProject copy() => BoardProject.fromJson(toJson());
}
