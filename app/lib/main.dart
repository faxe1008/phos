import 'package:flutter/material.dart';

import 'screens/library_screen.dart';
import 'state/app_model.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(PhosApp(model: AppModel()));
}

class PhosApp extends StatelessWidget {
  const PhosApp({super.key, required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: LibraryScreen(model: model),
    );
  }
}