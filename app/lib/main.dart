import 'package:flutter/material.dart';

import 'core/auth.dart';
import 'core/duck.dart';
import 'core/theme.dart';
import 'core/widgets.dart';
import 'home/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Auth.instance.restore();
  runApp(const VivDuckApp());
}

class VivDuckApp extends StatelessWidget {
  const VivDuckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: themeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'VivDuck',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: mode,
        home: const SplashScreen(),
        // Track the cursor app-wide so ducks can watch it.
        builder: (context, child) => Listener(
          behavior: HitTestBehavior.translucent,
          onPointerHover: (e) => pointerPosition.value = e.position,
          onPointerMove: (e) => pointerPosition.value = e.position,
          onPointerDown: (e) => pointerPosition.value = e.position,
          child: child,
        ),
      ),
    );
  }
}
