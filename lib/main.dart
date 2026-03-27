import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'injection_container.dart' as di;
import 'core/utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? initError;
  try {
    await dotenv.load(fileName: '.env');
    AppLogger.i('Variables de entorno cargadas');

    await di.init();
    AppLogger.i('Dependencias inicializadas');

    runApp(const SinapsisApp());
  } catch (e, stackTrace) {
    initError = e.toString();
    AppLogger.e('Error al inicializar la aplicación', e, stackTrace);
    runApp(ErrorApp(errorDetail: initError));
  }
}

class ErrorApp extends StatelessWidget {
  final String? errorDetail;
  const ErrorApp({super.key, this.errorDetail});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 80),
                  const SizedBox(height: 24),
                  const Text('Error al inicializar',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (errorDetail != null)
                    Text(errorDetail!, textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Colors.red)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
