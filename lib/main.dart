import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'core/di/bootstrap.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('Flutter error: ${details.exception}');
    debugPrint('Stack: ${details.stack}');
    FlutterError.presentError(details);
  };

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final cubit = await AppBootstrap.initialize();
    runApp(MezanyaApp(cubit: cubit));
  } catch (e, st) {
    debugPrint('App startup error: $e');
    debugPrint('Stack: $st');
    runApp(_ErrorApp(error: e.toString()));
  }
}

class _ErrorApp extends StatelessWidget {
  const _ErrorApp({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Startup error:\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
