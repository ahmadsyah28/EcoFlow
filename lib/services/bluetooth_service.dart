// lib/services/bluetooth_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

class WaterQualityBluetoothService {
  // UUID untuk service dan characteristic BLE
  final String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  
  fbp.BluetoothDevice? device;
  fbp.BluetoothCharacteristic? characteristic;
  final Function(Map<String, dynamic>) onDataReceived;
  final String targetDeviceName;
  bool _isConnected = false;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _characteristicSubscription;

  WaterQualityBluetoothService({
    required this.targetDeviceName,
    required this.onDataReceived,
  });

  Future<void> connect() async {
    try {
      if (await fbp.FlutterBluePlus.isSupported == false) {
        print("Bluetooth tidak didukung di perangkat ini");
        return;
      }

      if (await fbp.FlutterBluePlus.isOn == false) {
        await fbp.FlutterBluePlus.turnOn();
      }

      print("Memulai pencarian perangkat...");
      
      await fbp.FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 4),
        androidUsesFineLocation: false,
      );

      fbp.FlutterBluePlus.scanResults.listen((results) async {
        for (fbp.ScanResult result in results) {
          print("Ditemukan perangkat: ${result.device.platformName}");
          
          if (result.device.platformName == targetDeviceName) {
            print("Perangkat target ditemukan!");
            await fbp.FlutterBluePlus.stopScan();
            device = result.device;
            await _connectToDevice();
            break;
          }
        }
      });

    } catch (e) {
      print('Error saat scanning: $e');
      _isConnected = false;
    }
  }

  Future<void> _connectToDevice() async {
    if (device == null) return;

    try {
      print("Mencoba koneksi ke ${device!.platformName}...");
      
      await device!.connect(timeout: const Duration(seconds: 4));
      _isConnected = true;
      print("Berhasil terhubung!");

      print("Mencari services...");
      List<fbp.BluetoothService> services = await device!.discoverServices();
      
      for (fbp.BluetoothService service in services) {
        if (service.uuid.toString() == SERVICE_UUID) {
          for (fbp.BluetoothCharacteristic c in service.characteristics) {
            if (c.uuid.toString() == CHARACTERISTIC_UUID) {
              characteristic = c;
              await _setupNotifications();
              break;
            }
          }
        }
      }

      _connectionSubscription = device!.connectionState.listen((state) {
        _isConnected = state == fbp.BluetoothConnectionState.connected;
        if (!_isConnected) {
          print("Koneksi terputus!");
          Future.delayed(const Duration(seconds: 5), () {
            if (!_isConnected) {
              print("Mencoba koneksi ulang...");
              connect();
            }
          });
        }
      });

    } catch (e) {
      print('Error saat koneksi: $e');
      _isConnected = false;
    }
  }

  Future<void> _setupNotifications() async {
    if (characteristic == null) return;

    try {
      print("Setting up notifikasi...");
      await characteristic!.setNotifyValue(true);
      
      _characteristicSubscription = characteristic!.onValueReceived.listen((value) {
        String message = String.fromCharCodes(value);
        try {
          Map<String, dynamic> sensorData = json.decode(message);
          onDataReceived(sensorData);
        } catch (e) {
          print('Error parsing data: $e');
        }
      });
      
      print("Notifikasi berhasil diatur!");
    } catch (e) {
      print('Error setting up notifications: $e');
    }
  }

  Future<void> disconnect() async {
    print("Memutuskan koneksi...");
    _connectionSubscription?.cancel();
    _characteristicSubscription?.cancel();
    if (device != null && _isConnected) {
      await device!.disconnect();
    }
    _isConnected = false;
  }

  bool isConnected() {
    return _isConnected;
  }

  Future<void> sendMessage(String message) async {
    if (_isConnected && characteristic != null) {
      try {
        List<int> bytes = utf8.encode(message);
        await characteristic!.write(bytes);
        print("Pesan terkirim: $message");
      } catch (e) {
        print('Error mengirim pesan: $e');
      }
    } else {
      print('Tidak dapat mengirim pesan: perangkat tidak terhubung');
    }
  }

  Future<List<fbp.ScanResult>> scanDevices() async {
    List<fbp.ScanResult> results = [];
    try {
      await fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
      await for (final results in fbp.FlutterBluePlus.scanResults) {
        return results;
      }
    } catch (e) {
      print('Error scanning devices: $e');
    }
    return results;
  }
}