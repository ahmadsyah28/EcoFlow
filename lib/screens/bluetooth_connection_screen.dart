import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ble_service.dart';
import '../models/ble_models.dart';

class BluetoothConnectionScreen extends StatefulWidget {
  const BluetoothConnectionScreen({Key? key}) : super(key: key);

  @override
  State<BluetoothConnectionScreen> createState() =>
      _BluetoothConnectionScreenState();
}

class _BluetoothConnectionScreenState extends State<BluetoothConnectionScreen> {
  late WaterQualityBLEService bleService;
  BleConnectionState connectionState = BleConnectionState.disconnected;
  String errorMessage = '';
  List<ScanResult> devicesList = [];
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    _initBLE();
  }

  Future<void> _initBLE() async {
    bleService = WaterQualityBLEService(
      onDataReceived: (data) {
        print('Data received: $data');
      },
    );

    bleService.stateStream.listen((state) {
      setState(() {
        connectionState = state;
        if (state == BleConnectionState.error) {
          errorMessage = 'Terjadi kesalahan saat menghubungkan';
        } else {
          errorMessage = '';
        }
      });

      if (state == BleConnectionState.connected) {
        Navigator.pop(context, bleService);
      }
    });
  }

Future<void> _startScan() async {
  if (isScanning) return;

  setState(() {
    errorMessage = '';
    isScanning = true;
    devicesList.clear();
  });

  try {
    // Cek permissions
    var locationStatus = await Permission.location.request();
    var bluetoothStatus = await Permission.bluetooth.request();
    var bluetoothScanStatus = await Permission.bluetoothScan.request();
    var bluetoothConnectStatus = await Permission.bluetoothConnect.request();

    if (!locationStatus.isGranted ||
        !bluetoothStatus.isGranted ||
        !bluetoothScanStatus.isGranted ||
        !bluetoothConnectStatus.isGranted) {
      throw BleException(
          'Mohon izinkan akses yang diperlukan', BleErrorType.permissionDenied);
    }

    // Setup scan subscription
    FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      setState(() {
        devicesList = results.where((result) {
          final name = result.device.platformName;
          return name.isNotEmpty && (
            name == WaterQualityBLEService.ESP32_DEVICE_NAME || // Gunakan static getter
            name.contains('ESP32') || 
            result.advertisementData.serviceUuids.contains(WaterQualityBLEService.SERVICE_UUID) // Gunakan static getter
          );
        }).toList();
      });
    });

    // Start scanning
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 10),
      androidUsesFineLocation: true,
    );

    // Wait for scan to complete
    await Future.delayed(const Duration(seconds: 10));

  } catch (e) {
    if (!mounted) return;
    setState(() {
      errorMessage = e is BleException ? e.message : e.toString();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
        action: e is BleException && e.type == BleErrorType.permissionDenied
            ? SnackBarAction(
                label: 'Settings',
                onPressed: () => openAppSettings(),
              )
            : null,
      ),
    );
  } finally {
    if (!mounted) return;
    setState(() {
      isScanning = false;
    });
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      print('Error stopping scan: $e');
    }
  }
}
 Future<void> _connectToDevice(BluetoothDevice device) async {
  setState(() {
    connectionState = BleConnectionState.connecting;
    errorMessage = '';
  });

  try {
    await bleService.startScan();
  } catch (e) {
    if (!mounted) return;
    setState(() {
      connectionState = BleConnectionState.error;
      errorMessage = e is BleException ? e.message : e.toString();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
  @override
  void dispose() {
    if (connectionState != BleConnectionState.connected) {
      bleService.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Koneksi Bluetooth',
          style: TextStyle(color: Color(0xFF2196F3)),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.grey),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFF5F9FF)],
          ),
        ),
        child: Column(
          children: [
            // Status dan tombol scan
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  if (isScanning)
                    const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text('Mencari perangkat...'),
                      ],
                    )
                  else
                    ElevatedButton.icon(
                      onPressed:
                          connectionState != BleConnectionState.connecting &&
                                  !isScanning
                              ? _startScan
                              : null,
                      icon: const Icon(Icons.bluetooth_searching),
                      label: const Text('Scan Perangkat'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Daftar perangkat
            Expanded(
              child: devicesList.isEmpty
                  ? Center(
                      child: Text(
                        isScanning
                            ? 'Mencari perangkat...'
                            : 'Tidak ada perangkat\nTekan tombol scan untuk memulai',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: devicesList.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final result = devicesList[index];
                        final device = result.device;
                        final name = device.platformName.isEmpty
                            ? 'Unknown Device'
                            : device.platformName;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.bluetooth,
                                color: Colors.blue,
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Signal Strength: ${result.rssi} dBm',
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                            trailing: ElevatedButton(
                              onPressed: connectionState ==
                                          BleConnectionState.connecting ||
                                      isScanning
                                  ? null
                                  : () => _connectToDevice(device),
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(
                                connectionState == BleConnectionState.connecting
                                    ? 'Menghubungkan...'
                                    : 'Hubungkan',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Error message
            if (errorMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}