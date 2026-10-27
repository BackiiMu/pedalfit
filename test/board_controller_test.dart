import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalboard/models/pedal.dart';
import 'package:pedalboard/models/board_project.dart';
import 'package:pedalboard/state/board_controller.dart';

const pedal = Pedal(
  id: 'p',
  name: 'Test',
  category: PedalCategory.overdrive,
  color: Colors.amber,
  widthMm: 70,
  depthMm: 125,
);
BoardProject project() =>
    BoardProject(id: 'board', name: 'Test board', widthMm: 600, depthMm: 320);
void main() {
  test(
    'rotation changes physical footprint and rotates asymmetric plug clearance',
    () {
      final c = BoardController(project());
      addTearDown(c.dispose);
      c.add(pedal, leftMm: 10, rightMm: 20);
      c.setPosition(100, 100);
      final p = c.selected!;
      expect(p.body, const Rect.fromLTWH(100, 100, 70, 125));
      expect(p.clearance, const Rect.fromLTRB(90, 100, 190, 225));
      c.rotate();
      expect(p.width, 125);
      expect(p.depth, 70);
      expect(p.clearance, const Rect.fromLTRB(100, 90, 225, 190));
      c.rotate();
      expect(p.clearance, const Rect.fromLTRB(80, 100, 180, 225));
    },
  );
  test(
    'body overlap, edge touching, plug overlap and out of bounds are distinct',
    () {
      final c = BoardController(project());
      addTearDown(c.dispose);
      c.add(pedal);
      final a = c.selected!;
      c.setPosition(20, 20);
      c.add(pedal);
      final b = c.selected!;
      c.setPosition(90, 20);
      expect(c.bodyCollision(a), false);
      expect(c.clearanceCollision(a), true);
      c.setPosition(89, 20);
      expect(c.bodyCollision(a), true);
      c.setPosition(530, 20);
      expect(c.outside(b), false);
      expect(c.clearanceOutside(b), true);
      c.setPosition(531, 20);
      expect(c.outside(b), true);
    },
  );
  test(
    'one drag produces one undo step, snap is 5mm, redo and saved state work',
    () {
      final c = BoardController(project());
      addTearDown(c.dispose);
      c.add(pedal);
      c.markSaved();
      final id = c.selected!.id;
      final original = c.selected!.body;
      c.beginMove(id);
      c.moveTo(37, 28);
      c.moveTo(48, 44);
      c.endMove();
      expect(c.selected!.x, 50);
      expect(c.selected!.y, 45);
      expect(c.isDirty, true);
      c.undo();
      expect(c.project.pedals.single.body, original);
      expect(c.isDirty, false);
      c.redo();
      expect(c.project.pedals.single.x, 50);
      expect(c.isDirty, true);
    },
  );
  test('changing board size never scales or moves existing pedals', () {
    final c = BoardController(project());
    addTearDown(c.dispose);
    c.add(pedal);
    c.setPosition(400, 200);
    final before = c.selected!.body;
    c.changeBoard(
      BoardProject(id: 'board', name: 'Small', widthMm: 200, depthMm: 100),
    );
    expect(c.project.pedals.single.body, before);
    expect(c.outside(c.project.pedals.single), true);
    c.undo();
    expect(c.project.widthMm, 600);
  });
  test(
    'duplicate and delete preserve independent placements and can be undone',
    () {
      final c = BoardController(project());
      addTearDown(c.dispose);
      c.add(pedal);
      final first = c.selected!;
      c.duplicate();
      expect(c.project.pedals.length, 2);
      expect(c.selected!.id, isNot(first.id));
      c.setPosition(200, 20);
      expect(first.x, isNot(200));
      c.removeSelected();
      expect(c.project.pedals.length, 1);
      c.undo();
      expect(c.project.pedals.length, 2);
    },
  );
}
