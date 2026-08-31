import 'package:flutter/material.dart';
import 'shell.dart';
import 'fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FcmHandler.init();
  runApp(const ParkBanglaApp());
}
