import 'dart:io';

import 'package:elastic_dashboard/main.dart';
import 'package:elastic_dashboard/services/field_images.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setupMockOfflineNT4();

  testWidgets('Full app test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await FieldImages.loadFields('assets/fields/');

    String filePath =
        '${Directory.current.path}/test_resources/test-layout.json';

    String jsonString = File(filePath).readAsStringSync();

    SharedPreferences.setMockInitialValues({
      PrefKeys.layout: jsonString,
    });

    SharedPreferences preferences = await SharedPreferences.getInstance();

    await widgetTester.pumpWidget(
      Elastic(
        version: '0.0.0.0',
        preferences: preferences,
      ),
    );

    await widgetTester.pumpAndSettle();
  });
}
