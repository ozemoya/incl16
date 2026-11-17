import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      await Directory('evidence').create(recursive: true);
      await File('evidence/$name.png').writeAsBytes(bytes);
      return true;
    },
  );
}
