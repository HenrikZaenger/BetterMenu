import 'package:flutter/material.dart';
import 'package:better_menu/restopolis_menu.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MLG App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: .fromSeed(seedColor: Colors.cyan, brightness: Brightness.light),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: .fromSeed(seedColor: Colors.cyan, brightness: Brightness.dark),
      ),
      home: RestopolisMenu(),
    );
  }
}