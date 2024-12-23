import 'package:universal_ble/universal_ble.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

class BleHandler {
  // Singleton pattern
  static final BleHandler _instance = BleHandler._internal();

  factory BleHandler() {
    return _instance;
  }

  BleHandler._internal();

  String deviceMacAddress = '44:17:93:E9:8A:DC';
  String connectedeviceId = '';
  String serviceUUID =
      BleUuidParser.string("12345678-1234-5678-1234-56789abcdef0");
  String rxCharUUID =
      BleUuidParser.string("12345678-1234-5678-1234-56789abcdef1");
  String txCharUUID =
      BleUuidParser.string("12345679-1234-5678-1234-56789abcdef1");

  final StreamController<String> _dataController =
      StreamController<String>.broadcast();

  Stream<String> get dataStream => _dataController.stream;

  Future<int> connectToDevice() async {
    Completer<int> completer = Completer<int>();

    AvailabilityState state =
        await UniversalBle.getBluetoothAvailabilityState();
    if (state == AvailabilityState.poweredOn) {
      developer.log("BLE on, start scanning");
      UniversalBle.startScan();
    } else {
      developer.log("BLE is not powered on: $state");
      completer.complete(1);
    }

    UniversalBle.onConnectionChange =
        (String deviceId, bool isConnected, String? error) {
      developer.log('OnConnectionChange $deviceId, $isConnected Error: $error');
      if (isConnected) {
        connectedeviceId = deviceId;
        developer.log('Connected to $connectedeviceId');
        discoverServices().then((_) {
          completer.complete(0);
        }).catchError((e) {
          developer.log('Error discovering services: $e');
          completer.complete(2);
        });
      } else if (error != null) {
        developer.log('Connection error: $error');
        connectedeviceId = '';
        completer.complete(2);
      }
    };

    UniversalBle.onScanResult = (bleDevice) async {
      developer.log(
          'Address: ${bleDevice.deviceId} Name: ${bleDevice.name ?? 'NoName'} Pairing status: ${bleDevice.isPaired}');
      // Connect to device if it matches name
      if (bleDevice.deviceId == deviceMacAddress) {
        await UniversalBle.stopScan();
        developer.log("Device found! Establishing connection");
        try {
          await UniversalBle.connect(bleDevice.deviceId);
          developer
              .log("Connection attempt to ${bleDevice.deviceId} initiated");
          connectedeviceId = bleDevice.deviceId; // Ensure this is set
        } catch (e) {
          developer
              .log("Connection attempt to ${bleDevice.deviceId} failed: $e");
          completer.complete(3);
        }
      }
    };
    return completer.future;
  }

  void disconnectFromDevice() {
    UniversalBle.disconnect(deviceMacAddress);
    connectedeviceId = '';
  }

  Future<int> discoverServices() async {
    Completer<int> completer = Completer<int>();
    await UniversalBle.discoverServices(connectedeviceId);
    UniversalBle.setNotifiable(connectedeviceId, serviceUUID, txCharUUID,
        BleInputProperty.notification);

    UniversalBle.onValueChange =
        (String connectedeviceId, String characteristicId, Uint8List value) {
      String readableValue = utf8.decode(value);
      _dataController.add(readableValue);
    };

    completer.complete(0);
    return completer.future;
  }

  void sendValue(Uint8List value) {
    if (connectedeviceId.isEmpty) {
      developer.log('Device ID is empty. Cannot send value.');
      return;
    }

    if (serviceUUID.isEmpty || rxCharUUID.isEmpty) {
      developer.log(
          'Service UUID or RX Characteristic UUID is empty. Cannot send value.');
      return;
    }

    try {
      UniversalBle.writeValue(connectedeviceId, serviceUUID, rxCharUUID, value,
          BleOutputProperty.withoutResponse);
      developer.log('Value sent: ${value.toString()}');
    } catch (e) {
      developer.log('Error sending value: $e');
    }
  }

  void dispose() {
    _dataController.close();
  }
}
