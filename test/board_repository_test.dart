import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pedalboard/data/board_repository.dart';
import 'package:pedalboard/data/pedal_catalog.dart';
import 'package:pedalboard/models/pedal.dart';
import 'package:pedalboard/models/board_project.dart';
import 'package:pedalboard/state/board_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    '19 source-linked board presets load with nominal millimeter dimensions',
    () async {
      final presets = await BoardRepository().presets();
      expect(presets.length, 19);
      final classic = presets.singleWhere((p) => p.model == 'Classic 2');
      expect(classic.widthMm, 609.6);
      expect(classic.depthMm, 317.5);
    },
  );
  test(
    'projects, custom pedals, rotation and clearance survive storage round trip',
    () async {
      final repository = BoardRepository();
      final c = BoardController(
        BoardProject(id: 'b', name: 'Local', widthMm: 600, depthMm: 320),
      );
      addTearDown(c.dispose);
      c.add(
        Pedal.fromJson(
          pedalCatalog.first.toJson()
            ..['isCustom'] = true
            ..['name'] = 'My Fuzz',
        ),
        leftMm: 9,
        rightMm: 21,
      );
      c.setPosition(100, 50);
      c.rotate();
      await repository.save([c.project]);
      final loaded = await BoardRepository().load();
      expect(loaded.single.toJson(), c.project.toJson());
    },
  );
  test(
    'damaged stored data fails visibly without overwriting the original',
    () async {
      SharedPreferences.setMockInitialValues({
        BoardRepository.storageKey: 'broken',
      });
      await expectLater(BoardRepository().load(), throwsFormatException);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(BoardRepository.storageKey), 'broken');
    },
  );
}
