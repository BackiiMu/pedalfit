import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/board_project.dart';
import '../models/pedal.dart';

class BoardController extends ChangeNotifier {
  BoardController(BoardProject source) : project = source.copy() {
    markSaved();
  }
  BoardProject project;
  String? selectedId;
  bool snap = true;
  final List<String> _undo = [], _redo = [];
  String? _gesture;
  late String _saved;
  String get _snapshot => jsonEncode(project.toJson());
  bool get isDirty => _snapshot != _saved;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  PlacedPedal? get selected =>
      project.pedals.where((p) => p.id == selectedId).firstOrNull;
  void markSaved() {
    _saved = _snapshot;
  }

  void select(String? id) {
    selectedId = id;
    notifyListeners();
  }

  void setSnap(bool value) {
    snap = value;
    notifyListeners();
  }

  void _push(String state) {
    _undo.add(state);
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
  }

  void _change(VoidCallback update) {
    final before = _snapshot;
    update();
    if (before != _snapshot) {
      _push(before);
      notifyListeners();
    }
  }

  void beginMove(String id) {
    selectedId = id;
    _gesture = _snapshot;
    notifyListeners();
  }

  void moveTo(double x, double y) {
    final p = selected;
    if (p == null || !x.isFinite || !y.isFinite) return;
    p.x = snap ? (x / 5).round() * 5.0 : x;
    p.y = snap ? (y / 5).round() * 5.0 : y;
    notifyListeners();
  }

  void endMove() {
    if (_gesture != null && _gesture != _snapshot) _push(_gesture!);
    _gesture = null;
    notifyListeners();
  }

  void setPosition(double x, double y) => _change(() {
    final p = selected;
    if (p != null && x.isFinite && y.isFinite) {
      p.x = x;
      p.y = y;
    }
  });
  void add(Pedal pedal, {double leftMm = 12, double rightMm = 12}) =>
      _change(() {
        double x = 15, y = 15;
        bool found = false;
        for (
          double py = 15;
          py + pedal.depthMm <= project.depthMm && !found;
          py += 10
        ) {
          for (
            double px = 15;
            px + pedal.widthMm + rightMm <= project.widthMm;
            px += 10
          ) {
            final area = Rect.fromLTWH(
              px - leftMm,
              py,
              pedal.widthMm + leftMm + rightMm,
              pedal.depthMm,
            );
            if (px - leftMm >= 0 &&
                project.pedals.every((p) => !p.clearance.overlaps(area))) {
              x = px;
              y = py;
              found = true;
              break;
            }
          }
        }
        final p = PlacedPedal(
          id: newId(),
          pedal: pedal,
          x: x,
          y: y,
          leftMm: leftMm,
          rightMm: rightMm,
        );
        project.pedals.add(p);
        selectedId = p.id;
      });
  void rotate() => _change(() {
    final p = selected;
    if (p != null) p.turns = (p.turns + 1) % 4;
  });
  void duplicate() => _change(() {
    final p = selected;
    if (p == null) return;
    final n = PlacedPedal(
      id: newId(),
      pedal: p.pedal,
      x: p.x + 20,
      y: p.y + 20,
      turns: p.turns,
      leftMm: p.leftMm,
      rightMm: p.rightMm,
    );
    project.pedals.add(n);
    selectedId = n.id;
  });
  void removeSelected() => _change(() {
    project.pedals.removeWhere((p) => p.id == selectedId);
    selectedId = null;
  });
  void setClearance(double left, double right) => _change(() {
    final p = selected;
    if (p != null) {
      p.leftMm = left;
      p.rightMm = right;
    }
  });
  void changeBoard(BoardProject settings) => _change(() {
    project.name = settings.name;
    project.widthMm = settings.widthMm;
    project.depthMm = settings.depthMm;
    project.presetId = settings.presetId;
    project.presetName = settings.presetName;
    project.series = settings.series;
    project.originPresetId = settings.originPresetId;
    project.colorValue = settings.colorValue;
  });
  void undo() {
    if (!canUndo) return;
    _redo.add(_snapshot);
    project = BoardProject.fromJson(
      jsonDecode(_undo.removeLast()) as Map<String, dynamic>,
    );
    selectedId = null;
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    _undo.add(_snapshot);
    project = BoardProject.fromJson(
      jsonDecode(_redo.removeLast()) as Map<String, dynamic>,
    );
    selectedId = null;
    notifyListeners();
  }

  bool outside(PlacedPedal p) =>
      p.body.left < 0 ||
      p.body.top < 0 ||
      p.body.right > project.widthMm ||
      p.body.bottom > project.depthMm;
  bool bodyCollision(PlacedPedal p) =>
      project.pedals.any((o) => o.id != p.id && p.body.overlaps(o.body));
  bool clearanceCollision(PlacedPedal p) => project.pedals.any(
    (o) => o.id != p.id && p.clearance.overlaps(o.clearance),
  );
  bool clearanceOutside(PlacedPedal p) =>
      p.clearance.left < 0 ||
      p.clearance.top < 0 ||
      p.clearance.right > project.widthMm ||
      p.clearance.bottom > project.depthMm;
}
