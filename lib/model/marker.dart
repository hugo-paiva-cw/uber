import 'package:google_maps_flutter/google_maps_flutter.dart';

class Marker {
  late LatLng local;
  late String imagePath;
  late String title;

  Marker(this.local, this.imagePath, this.title);
}