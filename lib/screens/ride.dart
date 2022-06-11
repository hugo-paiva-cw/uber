import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uber/utils/firebase_user.dart';
import 'package:uber/utils/status_requisition.dart';
import 'package:uber/model/user.dart' as new_user;

class Ride extends StatefulWidget {
  final String idRequisition;

  Ride({required this.idRequisition, Key? key}) : super(key: key);

  @override
  State<Ride> createState() => _RideState();
}

class _RideState extends State<Ride> {
  final Completer<GoogleMapController> _controller = Completer();
  late CameraPosition _cameraPosition = const CameraPosition(
    target: LatLng(-23.563999, -46.653256),
  );
  late Set<Marker> _markers = {};
  late Map? _requisitionData;
  late Position _driversLocal;

  // Controls for screen exibition
  String _textButton = 'Aceitar corrida';
  Color _buttonColor = const Color(0xff1ebbd8);
  VoidCallback _buttonFunction = () {};
  late String _statusMessage;

  _setMainButton(String text, Color color, VoidCallback function) {
    setState(() {
      _textButton = text;
      _buttonColor = color;
      _buttonFunction = function;
    });
  }

  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  _addLocationListener() {
    const locationSettings =
        LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      setState(() {
        _driversLocal = position;
      });
    });
  }

  _getLastLocationKnown() async {
    Position? position = await Geolocator.getLastKnownPosition();

    setState(() {
      if (position != null) {
        _showPassengerMarker(position);

        _cameraPosition = CameraPosition(
            target: LatLng(position.latitude, position.longitude), zoom: 19);
        // _moveCamera(_cameraPosition);
        _driversLocal = position;
      }
    });
  }

  _moveCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  _showPassengerMarker(Position local) async {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            '/assets/images/motorista.png')
        .then((BitmapDescriptor iconLocation) {
      Marker passengerMarker = Marker(
          markerId: const MarkerId('marcador-motorista'),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: const InfoWindow(title: 'Meu local'),
          icon: iconLocation);

      setState(() {
        _markers.add(passengerMarker);
      });
    });
  }

  _getRequisition() async {
    String idRequisition = widget.idRequisition;

    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentSnapshot<Map> documentSnapshot =
        await db.collection('requisitions').doc(idRequisition).get();
  }

  _addRequisitionListener() async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    String idRequisition = _requisitionData?['id'];
    db
        .collection('requisitions')
        .doc(idRequisition)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.data() != null) {
        _requisitionData = snapshot.data();

        Map<String, dynamic> data = snapshot.data()!;
        String status = data['status'];

        switch (status) {
          case StatusRequisition.WAITING:
            _statusWaiting();
            break;
          case StatusRequisition.ONTHEWAY:
            _statusOnTheWay();
            break;
          case StatusRequisition.TRIP:
            break;
          case StatusRequisition.FINALIZED:
            break;
          case StatusRequisition.CANCELED:
            break;
        }
      }
    });
  }

  _statusWaiting() {
    _setMainButton('Aceitar corrida', const Color(0xff1ebbd8), () {
      print('olha eu aqui ${widget.idRequisition}');
      _acceptRide();
    });

    double driverLatitude = _requisitionData?['driver']['latitude'];
    double driverLongitude = _requisitionData?['driver']['longitude'];

    Position position = Position(
        longitude: driverLongitude,
        latitude: driverLatitude,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0);
    _showPassengerMarker(position);

    _cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 19);
    // _moveCamera(_cameraPosition);
  }

  _statusOnTheWay() {
    _statusMessage = 'A caminho do passageiro';

    _setMainButton('Iniciar corrida', const Color(0xff1ebbd8), () {
      _startRide();
    });

    double passengerLatitude = _requisitionData?['passenger']['latitude'];
    double passengerLongitude = _requisitionData?['passenger']['longitude'];

    double driverLatitude = _requisitionData?['driver']['latitude'];
    double driverLongitude = _requisitionData?['driver']['longitude'];

    _showTwoMarkers(LatLng(driverLatitude, driverLongitude),
        LatLng(passengerLatitude, passengerLongitude));

    late double northEastLatitude,
        northEastLongitude,
        southWestLatitude,
        southWestLongitude;

    if (driverLatitude <= passengerLatitude) {
      southWestLatitude = driverLatitude;
      northEastLatitude = passengerLatitude;
    } else {
      southWestLatitude = passengerLatitude;
      northEastLatitude = driverLatitude;
    }

    if (driverLongitude <= passengerLongitude) {
      southWestLongitude = driverLongitude;
      northEastLongitude = passengerLongitude;
    } else {
      southWestLongitude = driverLongitude;
      northEastLongitude = passengerLongitude;
    }

    _moveCameraUsingBounds(LatLngBounds(
        southwest: LatLng(southWestLatitude, southWestLongitude),
        northeast: LatLng(northEastLatitude, northEastLongitude)));
  }

  _startRide() {}

  _moveCameraUsingBounds(LatLngBounds latLngBounds) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newLatLngBounds(latLngBounds, 100));
  }

  _showTwoMarkers(LatLng driverPosition, LatLng passengerPosition) {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    Set<Marker> listMarkers = {};

    // Driver pin location
    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            '/assets/images/motorista.png')
        .then((BitmapDescriptor iconLocation) {
      Marker driverMarker = Marker(
          markerId: const MarkerId('marcador-motorista'),
          position: LatLng(driverPosition.latitude, driverPosition.longitude),
          infoWindow: const InfoWindow(title: 'Meu local'),
          // icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
          icon: iconLocation);
      listMarkers.add(driverMarker);
    });

    // Passenger pin location
    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            '/assets/images/passageiro.png')
        .then((BitmapDescriptor iconLocation) {
      Marker passengerMarker = Marker(
          markerId: const MarkerId('marcador-passageiro'),
          position:
              LatLng(passengerPosition.latitude, passengerPosition.longitude),
          infoWindow: const InfoWindow(title: 'Meu local'),
          // icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)
          icon: iconLocation);
      listMarkers.add(passengerMarker);
    });

    setState(() {
      _markers = listMarkers;
    });
  }

  _acceptRide() async {
    // Get driver's data
    new_user.User? driver = await FirebaseUser.getLoggedUserData();
    driver?.latitude = _driversLocal.latitude;
    driver?.longitude = _driversLocal.longitude;

    String idRequisition = _requisitionData?['id'];

    FirebaseFirestore db = FirebaseFirestore.instance;

    db.collection('requisitions').doc(idRequisition).update({
      'driver': driver!.toMap(),
      'status': StatusRequisition.ONTHEWAY
    }).then((_) {
      String idPassenger = _requisitionData?['passenger']['idUser'];
      db
          .collection('active_requisition')
          .doc(idPassenger)
          .update({'status': StatusRequisition.ONTHEWAY});

      String idDriver = driver.idUser;
      db.collection('active_requisition_driver').doc(idDriver).set({
        'id_requisition': idRequisition,
        'id_user': idDriver,
        'status': StatusRequisition.ONTHEWAY
      });
    });
  }

  @override
  initState() {
    super.initState();
    _getLastLocationKnown();
    _addLocationListener();

    _getRequisition();
    _addRequisitionListener();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Painel corrida -- $_statusMessage'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _cameraPosition,
            mapType: MapType.normal,
            onMapCreated: _onMapCreated,
            // myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _markers,
          ),
          Positioned(
              right: 0,
              left: 0,
              bottom: 0,
              child: Padding(
                padding: Platform.isIOS
                    ? const EdgeInsets.fromLTRB(20, 10, 20, 25)
                    : const EdgeInsets.all(10),
                child: RaisedButton(
                  color: _buttonColor,
                  onPressed: _buttonFunction,
                  padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
                  child: Text(
                    _textButton,
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
              ))
        ],
      ),
    );
  }
}
