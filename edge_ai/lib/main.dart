import 'package:edge_ai/widgets/detector_widget.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Edge-AI Camera',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const DetectorWidget(),
    );
  }
}
