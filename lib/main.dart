import 'package:material_ui/material_ui.dart';

import 'ui/screens/home_screen.dart';

void main() {
  runApp(const AndroidFileManagerApp());
}

class AndroidFileManagerApp extends StatelessWidget {
  const AndroidFileManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Android File Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0A84FF),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0A84FF),
        brightness: Brightness.dark,
      ),
      home: const HomeScreen(),
    );
  }
}
