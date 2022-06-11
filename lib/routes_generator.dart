import 'package:flutter/material.dart';
import 'package:uber/screens/home.dart';
import 'package:uber/screens/panel_driver.dart';
import 'package:uber/screens/panel_passenger.dart';
import 'package:uber/screens/register.dart';
import 'package:uber/screens/ride.dart';

class RoutesGenerator {
  static Route<dynamic>? generateRoute(RouteSettings settings) {

    final args = settings.arguments;

    switch( settings.name ) {
      case '/':
        return MaterialPageRoute(
          builder: (_) => const Home()
        );
      case '/register':
        return MaterialPageRoute(
            builder: (_) => const Register()
        );
      case '/panel-driver':
        return MaterialPageRoute(
            builder: (_) => const PanelDriver()
        );
      case '/panel-passenger':
        return MaterialPageRoute(
            builder: (_) => const PanelPassenger()
        );
      case '/ride':
        return MaterialPageRoute(
            builder: (_) => Ride(idRequisition: args as String,)
        );
      default:
        _errorRoute();
    }
  }

  static Route<dynamic> _errorRoute() {

    return MaterialPageRoute(
      builder: (_) {
        return Scaffold(
          appBar: AppBar(title: const Text('Tela nao encontrada!'),),
          body: const Center(
            child: Text('Tela nao encontrada!'),
          ),
        );
      }
    );
  }
}