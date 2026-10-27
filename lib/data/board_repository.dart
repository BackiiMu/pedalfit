import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/board_project.dart';

class BoardRepository {
  static const storageKey = 'pedalboard.projects.v1';
  Future<List<BoardPreset>> presets() async {
    final j =
        jsonDecode(
              await rootBundle.loadString(
                'assets/catalog/pedaltrain_boards.json',
              ),
            )
            as Map<String, dynamic>;
    return (j['presets'] as List)
        .map((p) => BoardPreset.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();
  }

  Future<List<BoardProject>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return [];
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['version'] != 1) throw const FormatException('지원하지 않는 저장 형식');
    return (j['boards'] as List)
        .map((b) => BoardProject.fromJson(Map<String, dynamic>.from(b as Map)))
        .toList();
  }

  Future<void> save(List<BoardProject> boards) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      storageKey,
      jsonEncode({
        'version': 1,
        'boards': boards.map((b) => b.toJson()).toList(),
      }),
    )) {
      throw StateError('기기에 저장하지 못했습니다.');
    }
  }
}
