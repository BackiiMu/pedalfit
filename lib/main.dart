import 'package:flutter/material.dart';
import 'screens/my_boards_screen.dart';
import 'data/board_repository.dart';
import 'design/app_design.dart';

void main() => runApp(const PedalboardApp());

class PedalboardApp extends StatelessWidget {
  const PedalboardApp({super.key, this.repository});
  final BoardRepository? repository;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pedalboard',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: MyBoardsScreen(repository: repository),
  );
}
