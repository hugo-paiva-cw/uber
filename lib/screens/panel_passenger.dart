import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uber/model/user.dart' as new_user;
import 'package:uber/model/Marker.dart' as pin;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:io';
import 'package:uber/model/destiny.dart';
import 'package:uber/model/requisition.dart';
import 'package:uber/utils/firebase_user.dart';
import 'package:uber/utils/status_requisition.dart';

class PanelPassenger extends StatefulWidget {
  const PanelPassenger({Key? key}) : super(key: key);

  @override
  State<PanelPassenger> createState() => _PanelPassengerState();
}

class _PanelPassengerState extends State<PanelPassenger> {
  final TextEditingController _controllerDestiny = TextEditingController(text: 'av. paulista');
  List<String> menuItems = ['Configurações', 'Deslogar'];
  final Completer<GoogleMapController> _controller = Completer();
  late CameraPosition _cameraPosition = const CameraPosition(
    target: LatLng(-23.563999, -46.653256),
  );
  Set<Marker> _markers = {};
  String? _idRequisition = '';
  Position _passengerLocation = Position(
      longitude: -16,
      latitude: -48,
      timestamp: DateTime.now(),
      accuracy: 0.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0);
  Map<String, dynamic> _requisitionData = {};
  // late Map _requisitionData;
  StreamSubscription<DocumentSnapshot>? _streamSubscriptionRequisitions;

  // Controls for screen exibition
  bool _showDestinyAddressBox = true;
  String _textButton = 'Chamar Uber';
  Color _buttonColor = const Color(0xff1ebbd8);
  VoidCallback _buttonFunction = () {};

  _signOutUser() {
    FirebaseAuth auth = FirebaseAuth.instance;

    auth.signOut();
    Navigator.pushReplacementNamed(context, '/');
  }

  _chooseMenuItem(String choice) {
    switch (choice) {
      case 'Deslogar':
        _signOutUser();
        break;
      case 'Configurações':
        // A little bit of settings
        break;
    }
  }

  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  _addLocationListener() {
    const locationSettings =
        LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      if (_idRequisition != null && _idRequisition!.isNotEmpty) {
        // Update passenger location
        FirebaseUser.updateLocationData(
            _idRequisition!, position.latitude, position.longitude);
      } else {
        print('to posicionando');
        setState(() {
          _passengerLocation = position;
        });
        _statusUberNotCalled();
      }

    });
  }

  _getLastLocationKnown() async {
    Position? position = await Geolocator.getLastKnownPosition();

    if (position != null) {}
  }

  void _getLocationPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
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
            '/assets/images/marker_pin.png')
        .then((BitmapDescriptor iconLocation) {
      Marker passengerMarker = Marker(
          markerId: const MarkerId('marcador-passageiro'),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: const InfoWindow(title: 'Meu local'),
          icon: iconLocation);

      setState(() {
        _markers.add(passengerMarker);
      });
    });
  }

  _callUber() async {
    String addressDestiny = _controllerDestiny.text;

    if (addressDestiny.isNotEmpty) {
      List<Location> listOfLocations =
          await locationFromAddress(addressDestiny);

      if (listOfLocations.isNotEmpty) {
        Location position = listOfLocations[0];

        List<Placemark> addresses = await placemarkFromCoordinates(
            position.latitude, position.longitude);

        if (addresses.isNotEmpty) {
          Placemark address = addresses[0];
          print('chamou uber');

          Destiny destiny = Destiny();
          destiny.city = address.administrativeArea ?? '';
          destiny.cep = address.postalCode ?? '';
          destiny.neighborhood = address.subLocality ?? '';
          destiny.street = address.thoroughfare ?? '';
          destiny.number = address.subThoroughfare ?? '';
          destiny.city = address.administrativeArea ?? '';

          destiny.latitude = position.latitude;
          destiny.longitude = position.longitude;

          late String confirmationAddress;
          confirmationAddress = '\n Cidade: ${destiny.city}';
          confirmationAddress += '\n Rua: ${destiny.street}';
          confirmationAddress += '\n Bairro: ${destiny.neighborhood}';
          confirmationAddress += '\n CEP: ${destiny.cep}';

          showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text('Confirmação de endereço'),
                  content: Text(confirmationAddress),
                  contentPadding: const EdgeInsets.all(16),
                  actions: [
                    FlatButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Canelar',
                          style: TextStyle(color: Colors.red),
                        )),
                    FlatButton(
                        onPressed: () {
                          _saveRequisition(destiny);

                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Confirmar',
                          style: TextStyle(color: Colors.green),
                        ))
                  ],
                );
              });
        }
      }
    }
  }

  _saveRequisition(Destiny destiny) async {
    new_user.User? passenger = await FirebaseUser.getLoggedUserData();
    passenger?.latitude = _passengerLocation.latitude;
    passenger?.longitude = _passengerLocation.longitude;

    Requisition requisition = Requisition();
    requisition.destiny = destiny;
    requisition.passenger = passenger!;
    requisition.status = StatusRequisition.WAITING;

    FirebaseFirestore db = FirebaseFirestore.instance;

    await db.collection('requisitions').doc(requisition.id).set(requisition.toMap());

    // save active requisition
    Map<String, dynamic> activeRequisitionData = {};
    activeRequisitionData['id_requisition'] = requisition.id;
    activeRequisitionData['id_user'] = passenger.idUser;
    activeRequisitionData['status'] = StatusRequisition.WAITING;

    await db
        .collection('active_requisition')
        .doc(passenger.idUser)
        .set(activeRequisitionData);

    if (_streamSubscriptionRequisitions == null) {
      _addRequisitionListener(requisition.id);
    }
  }

  _setMainButton(String text, Color color, VoidCallback function) {
    setState(() {
      _textButton = text;
      _buttonColor = color;
      _buttonFunction = function;
    });
  }

  _statusUberNotCalled() {
    _showDestinyAddressBox = true;

    _setMainButton('Chamar Uber', const Color(0xff1ebbd8), () {
      _callUber();
    });

    if (_passengerLocation != null ) {

      Position position = Position(
          longitude: _passengerLocation.longitude,
          latitude: _passengerLocation.latitude,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0);
      _showPassengerMarker(position);
      CameraPosition cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 19);
      _moveCamera(cameraPosition);

    }

  }

  _statusWaiting() {
    _showDestinyAddressBox = false;

    _setMainButton('Cancelar', Colors.red, () {
      _cancelUber();
    });

    print('o requisition é $_requisitionData');
    double passengerLatitude = _requisitionData['passenger']['latitude'];
    double passengerLongitude = _requisitionData['passenger']['longitude'];

    Position position = Position(
        longitude: passengerLatitude,
        latitude: passengerLongitude,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0);
    _showPassengerMarker(position);
    CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 19);
    _moveCamera(cameraPosition);
    print('movi a camera no waiting');
  }

  _statusOnTheWay() {
    _showDestinyAddressBox = false;

    _setMainButton('Motorista a caminho', Colors.grey, () {});

    double passengerLatitude = _requisitionData['passenger']['latitude'];
    double passengerLongitude = _requisitionData['passenger']['longitude'];

    double driverLatitude = _requisitionData['driver']['latitude'];
    double driverLongitude = _requisitionData['driver']['longitude'];

    pin.Marker originMarker = pin.Marker(
        LatLng(driverLatitude, driverLongitude),
        '/assets/images/motorista.png',
        'Local Motorista'
    );

    pin.Marker destinyMarker = pin.Marker(
        LatLng(passengerLatitude, passengerLongitude),
        '/assets/images/passageiro.png',
        'Local Passageiro'
    );

    _showCentralizedTwoMarkers(originMarker, destinyMarker);
  }

  _statusOnTrip() {
    _showDestinyAddressBox = false;

    _setMainButton('Em viagem', Colors.grey, () {});

    double destinyLatitude = _requisitionData['destiny']['latitude'];
    double destinyLongitude = _requisitionData['destiny']['longitude'];

    double originLatitude = _requisitionData['driver']['latitude'];
    double originLongitude = _requisitionData['driver']['longitude'];

    pin.Marker originMarker = pin.Marker(
        LatLng(originLatitude, originLongitude),
        '/assets/images/motorista.png',
        'Local Motorista'
    );

    pin.Marker destinyMarker = pin.Marker(
        LatLng(destinyLatitude, destinyLongitude),
        '/assets/images/destino.png',
        'Local Destino'
    );

    _showCentralizedTwoMarkers(originMarker, destinyMarker);
  }

  _showCentralizedTwoMarkers(pin.Marker originMarker, pin.Marker destinyMarker ) {

    double originLatitude = originMarker.local.latitude;
    double originLongitude = originMarker.local.longitude;

    double destinyLatitude = originMarker.local.latitude;
    double destinyLongitude = originMarker.local.longitude;

    _showTwoMarkers(
        originMarker,
        destinyMarker
    );

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

  _moveCameraUsingBounds(LatLngBounds latLngBounds) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newLatLngBounds(latLngBounds, 100));
  }

  _showTwoMarkers(pin.Marker originMarker, pin.Marker destinyMarker ) {

    LatLng latLngOrigin = originMarker.local;
    LatLng latLngDestiny = destinyMarker.local;

    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    Set<Marker> listMarkers = {};

    // Driver pin location
    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        originMarker.imagePath)
        .then((BitmapDescriptor iconLocation) {
      Marker oMarker = Marker(
          markerId: MarkerId(originMarker.imagePath),
          position: LatLng(latLngOrigin.latitude, latLngDestiny.longitude),
          infoWindow: InfoWindow(title: originMarker.title),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
        // icon: iconLocation
      );
      listMarkers.add(oMarker);
    });

    // Passenger pin location
    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        destinyMarker.imagePath)
        .then((BitmapDescriptor iconLocation) {
      Marker dMarker = Marker(
          markerId: MarkerId(destinyMarker.imagePath),
          position:
          LatLng(latLngDestiny.latitude, latLngDestiny.longitude),
          infoWindow: InfoWindow(title: destinyMarker.title),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)
        // icon: iconLocation
      );
      listMarkers.add(dMarker);
    });

    setState(() {
      _markers = listMarkers;
    });
  }

  _cancelUber() {
    User firebaseUser = FirebaseUser.getCurrentUsser();
    print('O id da requisiçao é ${_idRequisition}');

    FirebaseFirestore db = FirebaseFirestore.instance;
    db
        .collection('requisitions')
        .doc(_idRequisition)
        .update({'status': StatusRequisition.CANCELED}).then((_) {
          print('FirebaseUser uid ${firebaseUser.uid}');
      db.collection('active_requisition').doc(firebaseUser.uid).delete();
    });
  }

  _getActiveRequisition() async {
    User firebaseUser = FirebaseUser.getCurrentUsser();

    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentSnapshot<Map<String, dynamic>> documentSnapshot =
        await db.collection('active_requisition').doc(firebaseUser.uid).get();

    if (documentSnapshot.data() != null) {
      Map<String, dynamic> data = documentSnapshot.data()!;
      setState(() {
        _idRequisition = data['id_requisition'];
      });
      print('Numero um ${_idRequisition}');
      _addRequisitionListener(_idRequisition!);
    } else {
      _statusUberNotCalled();
    }
  }

  _addRequisitionListener(String idRequisition) async {
    print('stream foi criado');
    FirebaseFirestore db = FirebaseFirestore.instance;
    _streamSubscriptionRequisitions = db
        .collection('requisitions')
        .doc(idRequisition)
        .snapshots()
        .listen((snapshot) {
      /*
    Caso tenha uma requisicao ativa
      -> Alterar interface de acordo com status
    Caso não tenha
      -> Exibe interface padrão para chamar uber
     */

      if (snapshot.data() != null) {
        Map<String, dynamic> data = snapshot.data()!;
        _requisitionData = data;
        print('dados de requisicao sao ${_requisitionData}');
        String status = data['status'];
        _idRequisition = data['id'];

        switch (status) {
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
            break;
          case StatusRequisition.CANCELED:
            break;
        }
      }
    });
  }

  @override
  initState() {
    super.initState();
    //User for requesting permission for location services
    _getLocationPermissions();

    _getActiveRequisition();
    _addLocationListener();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel passageiro'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _chooseMenuItem,
            itemBuilder: (context) {
              return menuItems.map((String item) {
                return PopupMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList();
            },
          )
        ],
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
          Visibility(
            visible: _showDestinyAddressBox,
            child: Stack(
              children: [
                Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(3),
                            color: Colors.white),
                        child: TextField(
                          readOnly: true,
                          decoration: InputDecoration(
                              icon: Container(
                                margin: const EdgeInsets.only(left: 20),
                                child: const Icon(Icons.location_on),
                              ),
                              hintText: 'Meu local',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.only(left: 15)),
                        ),
                      ),
                    )),
                Positioned(
                    top: 55,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(3),
                            color: Colors.white),
                        child: TextField(
                          controller: _controllerDestiny,
                          decoration: InputDecoration(
                              icon: Container(
                                margin: const EdgeInsets.only(left: 20),
                                child: const Icon(
                                  Icons.local_taxi,
                                  color: Colors.green,
                                ),
                              ),
                              hintText: 'Digite o destino',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.only(left: 15)),
                        ),
                      ),
                    ))
              ],
            ),
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
  @override
  void dispose() {
    super.dispose();
    _streamSubscriptionRequisitions?.cancel();
  }
}
