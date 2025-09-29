import 'package:firebase_core/firebase_core.dart';
import 'package:stellar_zoom/firebase_options.dart';
import 'package:stellar_zoom/home_page.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:stellar_zoom/lebel_adapter.dart';

void main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  Hive.registerAdapter(LebelAdapter());
  runApp(MaterialApp(home: HomePage()));
}
  