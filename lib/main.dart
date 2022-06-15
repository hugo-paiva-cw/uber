import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:uber/routes_generator.dart';
import 'package:uber/screens/home.dart';

void main() async {
  final ThemeData defaultTheme = ThemeData(
      colorScheme: const ColorScheme.light().copyWith(
          primary: const Color(0xff37474f),
          secondary: const Color(0xff546e7a)));

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(MaterialApp(
    title: 'Uber',
    home: const Home(),
    theme: defaultTheme,
    debugShowCheckedModeBanner: false,
    initialRoute: '/',
    onGenerateRoute: RoutesGenerator.generateRoute,
  ));
}
