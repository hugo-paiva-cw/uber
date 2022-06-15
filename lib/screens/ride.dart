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
import 'package:intl/intl.dart';

class Ride extends StatefulWidget {
  final String idRequisition;

  Ride({required this.idRequisition, Key? key}) : super(key: key);

  @override
  State<Ride> createState() => _RideState();
}

class _RideState extends State<Ride> {
  final Completer<GoogleMapController> _controller = Completer();
  CameraPosition _cameraPosition = CameraPosition(target: LatLng(-23.5, -46.6));
  Set<Marker> _markers = {};
  Map? _requisitionData = {};
  String? _idRequisition;
  Position? _driverLocation;
  String _statusRequisition = StatusRequisition.WAITING;

  // Controls for screen exibition
  String _textButton = 'Aceitar corrida';
  Color _buttonColor = const Color(0xff1ebbd8);
  VoidCallback _buttonFunction = () {};
  String _statusMessage = '';

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

  _addLocationListener() async {
    const locationSettings =
        LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);

    Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
        if (_idRequisition != null && _idRequisition!.isNotEmpty) {
          if (_statusRequisition != StatusRequisition.WAITING) {
            // Update driver location
            FirebaseUser.updateLocationData(
                _idRequisition!, position.latitude, position.longitude, 'driver');
          } else {
            print('to posicionando');
            setState(() {
              _driverLocation = position;
            });
            _statusWaiting();
          }
        }
    });
  }

  _getLastLocationKnown() async {
    await Geolocator.requestPermission();
    Position? position = await Geolocator.getLastKnownPosition();

    if (position != null) {
      _driverLocation = position;
    }
  }

  _moveCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  _showMarker(Position local, String icon, String infoWindow) async {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio), icon)
        .then((BitmapDescriptor bitmapDescriptor) {
      Marker passengerMarker = Marker(
          markerId: MarkerId(icon),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(title: infoWindow),
          icon: bitmapDescriptor);

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

    _requisitionData = documentSnapshot.data();
    _addRequisitionListener();
  }

  _addRequisitionListener() async {
    await Geolocator.requestPermission();
    FirebaseFirestore db = FirebaseFirestore.instance;
    db
        .collection('requisitions')
        .doc(_idRequisition)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.data() != null) {
        _requisitionData = snapshot.data();

        Map<String, dynamic> data = snapshot.data()!;
        _statusRequisition = data['status'];

        switch (_statusRequisition) {
          case StatusRequisition.WAITING:
            _statusWaiting();
            break;
          case StatusRequisition.ONTHEWAY:
            _statusOnTheWay();
            break;
          case StatusRequisition.TRIP:
            _statusOnTrip();
            break;
          case StatusRequisition.FINALIZED:
            _statusFinished();
            break;
          case StatusRequisition.CONFIRMED:
            _statusConfirmed();
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

    print('before');
    if (_driverLocation != null ) {
      print('after');
      double driverLatitude = _driverLocation!.latitude;
      double driverLongitude = _driverLocation!.longitude;

      Position position = Position(
          longitude: driverLongitude,
          latitude: driverLatitude,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0);
      _showMarker(position, '/assets/images/motorista.png', 'Motorista');

      CameraPosition cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 19);
      _moveCamera(cameraPosition);
    }

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

  _finishRide() {

    FirebaseFirestore db = FirebaseFirestore.instance;
    db.collection('requisitions')
    .doc( _idRequisition )
    .update({
      'status': StatusRequisition.FINALIZED
    });

    String idPassenger = _requisitionData?['passenger']['idUser'];
    db
        .collection('active_requisition')
        .doc(idPassenger)
        .update({'status': StatusRequisition.FINALIZED});
    print('teste status finalized user');

    String idDriver = _requisitionData?['driver']['idUser'];
    db
        .collection('active_requisition_driver')
        .doc(idDriver)
        .update({'status': StatusRequisition.FINALIZED});
    print('teste status finalized user');

  }

  _statusFinished() async {

    // Calculating ride cost
    double destinyLatitude = _requisitionData?['destiny']['latitude'];
    double destinyLongitude = _requisitionData?['destiny']['longitude'];

    double originLatitude = _requisitionData?['origin']['latitude'];
    double originLongitude = _requisitionData?['origin']['longitude'];

    double distanceInMeters = Geolocator.distanceBetween(
        originLatitude,
        originLongitude,
        destinyLatitude,
        destinyLongitude
    );

    double distanceKm = distanceInMeters / 1000;

    double priceTrip = distanceKm * 8;

    var formater = NumberFormat('#,###0.00', 'pt_BR');
    var priceTripFormated = formater.format( priceTrip );

    _statusMessage = 'Viagem finalizada';

    _setMainButton('Confirmar --R\$ $priceTripFormated', const Color(0xff1ebbd8), () {
      _confirmRide();
    });

    _markers = {};
    Position position = Position(
        longitude: destinyLongitude,
        latitude: destinyLatitude,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0);
    _showMarker(position, '/assets/images/destino.png', 'Destino');

    CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 19);
    _moveCamera(cameraPosition);

  }

  _statusConfirmed() {

    Navigator.pushReplacementNamed(context, '/panel-driver');

  }

  _confirmRide() {
    FirebaseFirestore db = FirebaseFirestore.instance;
    db.collection('requisitions').doc(_idRequisition).update({
      'status': StatusRequisition.CONFIRMED
    });

    String idPassenger = _requisitionData?['passenger']['idUser'];
    db
        .collection('active_requisition')
        .doc(idPassenger)
        .delete();

    String idDriver = _requisitionData?['driver']['idUser'];
    db
        .collection('active_requisition_driver')
        .doc(idDriver)
        .delete();

  }

  _statusOnTrip() {
    _statusMessage = 'Em viagem';

    _setMainButton('Finalizar Corrida', const Color(0xff1ebbd8), () {
      _finishRide();
    });

    double destinyLatitude = _requisitionData?['destiny']['latitude'];
    double destinyLongitude = _requisitionData?['destiny']['longitude'];

    double originLatitude = _requisitionData?['driver']['latitude'];
    double originLongitude = _requisitionData?['driver']['longitude'];

    _showTwoMarkers(LatLng(originLatitude, originLongitude),
        LatLng(destinyLatitude, destinyLongitude));

    late double northEastLatitude,
        northEastLongitude,
        southWestLatitude,
        southWestLongitude;

    if (originLatitude <= destinyLatitude) {
      southWestLatitude = originLatitude;
      northEastLatitude = destinyLatitude;
    } else {
      southWestLatitude = destinyLatitude;
      northEastLatitude = originLatitude;
    }

    if (originLongitude <= destinyLongitude) {
      southWestLongitude = originLongitude;
      northEastLongitude = destinyLongitude;
    } else {
      southWestLongitude = originLongitude;
      northEastLongitude = destinyLongitude;
    }

    _moveCameraUsingBounds(LatLngBounds(
        southwest: LatLng(southWestLatitude, southWestLongitude),
        northeast: LatLng(northEastLatitude, northEastLongitude)));
  }

  _startRide() {
    FirebaseFirestore db = FirebaseFirestore.instance;
    db.collection('requisitions').doc(_idRequisition).update({
      'origin': {
        'latitude': _requisitionData!['driver']['latitude'],
        'longitude': _requisitionData!['driver']['longitude'],
      },
      'status': StatusRequisition.TRIP
    });


    print('antes da req trip');
    String idPassenger = _requisitionData?['passenger']['idUser'];
    db
        .collection('active_requisition')
        .doc(idPassenger)
        .update({'status': StatusRequisition.TRIP}).then((value) =>
        print('teste status trip user')
);

    String idDriver = _requisitionData?['driver']['idUser'];
    db
        .collection('active_requisition_driver')
        .doc(idDriver)
        .update({'status': StatusRequisition.TRIP});
    print('errei sera');
  }

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
    if (_driverLocation != null) {

      driver?.latitude = _driverLocation!.latitude;
      driver?.longitude = _driverLocation!.longitude;

      FirebaseFirestore db = FirebaseFirestore.instance;
      String idRequisition = _requisitionData?['id'];

      db.collection('requisitions').doc(idRequisition).update({
        'driver': driver!.toMap(),
        'status': StatusRequisition.ONTHEWAY
      }).then((_) {
        String idPassenger = _requisitionData?['passenger']['idUser'];
        print('a id do passageiro é $idPassenger');
        db
            .collection('active_requisition')
            .doc(idPassenger)
            .update({'status': StatusRequisition.ONTHEWAY});

        String idDriver = driver.idUser;
        print('id motora $idDriver');
        db.collection('active_requisition_driver').doc(idDriver).set({
          'id_requisition': idRequisition,
          'id_user': idDriver,
          'status': StatusRequisition.ONTHEWAY
        });
      });
    }
  }

  @override
  initState() {
    super.initState();

    _idRequisition = widget.idRequisition;
    _addRequisitionListener();

    _getLastLocationKnown();
    _addLocationListener();

    // _getRequisition();
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
