import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/ble_models.dart';

class WaterQualityBLEService {
 static const String ESP32_DEVICE_NAME = "ESP32_Water_Quality";
  static const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  final _stateController = StreamController<BleConnectionState>.broadcast();
  Stream<BleConnectionState> get stateStream => _stateController.stream;

  final _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  final void Function(Map<String, dynamic>) onDataReceived;
  // List<ScanResult> _devicesList = [];
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription? _dataSubscription;
  bool _isConnecting = false;
  bool _isScanning = false;

  WaterQualityBLEService({required this.onDataReceived});

  void _updateState(BleConnectionState newState) {
    _stateController.add(newState);
  }

  Future<void> startScan() async {
    if (_isScanning) return;

    try {
      _updateState(BleConnectionState.scanning);
      // _devicesList = [];
      _isScanning = true;

      if (await FlutterBluePlus.isSupported == false) {
        throw const BleException(
          'Bluetooth tidak didukung pada perangkat ini',
          BleErrorType.unknown
        );
      }

      if (await FlutterBluePlus.isOn == false) {
        throw const BleException(
          'Bluetooth tidak aktif',
          BleErrorType.bluetoothOff
        );
      }

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: true,
      );

      FlutterBluePlus.scanResults.listen((results) async {
        // _devicesList = results;
        
        for (ScanResult r in results) {
          print('Device found: ${r.device.platformName} (${r.device.remoteId})');
          
          if (r.device.platformName == ESP32_DEVICE_NAME ||
              r.device.platformName.contains('ESP32') == true ||
              r.advertisementData.serviceUuids.contains(SERVICE_UUID)) {
            
            await FlutterBluePlus.stopScan();
            await _connectToDevice(r.device);
            return;
          }
        }
      });

      await Future.delayed(const Duration(seconds: 10));
      if (_device == null) {
        print('ESP32 tidak ditemukan dalam jangkauan');
        _updateState(BleConnectionState.disconnected);
      }

    } catch (e) {
      print('Scanning error: $e');
      _updateState(BleConnectionState.error);
    } finally {
      _isScanning = false;
      await FlutterBluePlus.stopScan();
    }
  }

  Future<void> connect(BluetoothDevice device) async {
  await _connectToDevice(device);
}

  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (_isConnecting) return;
    _isConnecting = true;

    try {
      _updateState(BleConnectionState.connecting);
      
      await device.connect(timeout: const Duration(seconds: 15));
      _device = device;
      
      print('Connected to ${device.platformName}');
      
      List<BluetoothService> services = await device.discoverServices();
      
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == CHARACTERISTIC_UUID.toLowerCase()) {
              _characteristic = characteristic;
              
              await characteristic.setNotifyValue(true);
              _dataSubscription = characteristic.lastValueStream.listen(
                (data) {
                  if (data.isNotEmpty) {
                    _processReceivedData(data);
                  }
                },
                onError: (error) {
                  print('Characteristic error: $error');
                  _updateState(BleConnectionState.error);
                },
              );
              
              _updateState(BleConnectionState.connected);
              _connectionStateController.add(true);
              return;
            }
          }
        }
      }
      
      throw const BleException(
        'Required BLE service not found',
        BleErrorType.serviceNotFound
      );

    } catch (e) {
      print('Connection error: $e');
      _device = null;
      _characteristic = null;
      _updateState(BleConnectionState.error);
      _connectionStateController.add(false);
      rethrow;
    } finally {
      _isConnecting = false;
    }
  }

  void _processReceivedData(List<int> data) {
    try {
      String stringData = utf8.decode(data);
      print('Received data: $stringData');

      Map<String, dynamic> jsonData = json.decode(stringData);
      
      if (jsonData.containsKey('ph') &&
          jsonData.containsKey('tds') &&
          jsonData.containsKey('turbidity') &&
          jsonData.containsKey('temperature') &&
          jsonData.containsKey('flow')) {
        onDataReceived(jsonData);
      } else {
        print('Invalid data format received');
      }
    } catch (e) {
      print('Error processing data: $e');
    }
  }

  bool isConnected() {
    return _device != null && _characteristic != null;
  }

  Future<void> disconnect() async {
    try {
      await _dataSubscription?.cancel();
      
      if (_device != null) {
        // await _device!.disconnect();
        _device = null;
        _characteristic = null;
      }
      
      _updateState(BleConnectionState.disconnected);
      _connectionStateController.add(false);
    } catch (e) {
      print('Error disconnecting: $e');
      _updateState(BleConnectionState.error);
    }
  }

  void dispose() {
    _dataSubscription?.cancel();
    _stateController.close();
    _connectionStateController.close();
    disconnect();
  }

  Future<void> reconnect() async {
    await disconnect();
    await startScan();
  }
}