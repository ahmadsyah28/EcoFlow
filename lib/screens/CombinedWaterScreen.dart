import 'dart:async';

import 'package:ecoflow/screens/bluetooth_connection_screen.dart';
import 'package:ecoflow/services/ble_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/bluetooth_service.dart';
import 'parameter_detail_screen.dart';
import '../models/ble_models.dart';

class CombinedWaterScreen extends StatefulWidget {
  const CombinedWaterScreen({super.key});

  @override
  State<CombinedWaterScreen> createState() => _CombinedWaterScreenState();
}

class _CombinedWaterScreenState extends State<CombinedWaterScreen> {
  static const String LAST_REPLACEMENT_KEY = 'last_replacement_date';
  static const String FILTER_DURATION_KEY = 'filter_duration_days';
  static const String TOTAL_FLOW_KEY = 'total_water_flow';
  StreamSubscription? _connectionSubscription;
  late WaterQualityBLEService bleService;
  late DateTime lastReplacementDate;
  late Duration filterDuration;
  late WaterQualityBluetoothService bluetoothService;
  bool isLoading = true;
  DateTime lastUpdatedTime = DateTime.now();

  bool isConnected = false;

  static const double MAX_WATER_FLOW =
      1000.0; // Tambahkan ini - 1000L sebagai batas
  double totalWaterFlow = 2002.0; // Tambahkan ini

  // Add water quality parameters
  final Map<String, Map<String, dynamic>> waterParameters = {
    'pH': {
      'value': 7.0,
      'minRange': 6.5,
      'maxRange': 7.5,
      'unit': '',
      'icon': Icons.science,
    },
    'TDS': {
      'value': 150.0,
      'minRange': 0,
      'maxRange': 500,
      'unit': 'ppm',
      'icon': Icons.opacity,
    },
    'Turbidity': {
      'value': 2.5,
      'minRange': 0,
      'maxRange': 5,
      'unit': 'NTU',
      'icon': Icons.water_drop,
    },
    'Temperature': {
      'value': 25.0,
      'minRange': 20,
      'maxRange': 30,
      'unit': '°C',
      'icon': Icons.thermostat,
    }
  };

  bool get isWaterSafe {
    return waterParameters.entries.every((param) {
      final value = param.value['value'];
      return value >= param.value['minRange'] &&
          value <= param.value['maxRange'];
    });
  }

  String get waterQualityStatus {
    if (isWaterSafe) {
      return 'Air Aman Digunakan';
    } else {
      return 'Air Tidak Aman Digunakan';
    }
  }

  Color get waterQualityColor {
    return isWaterSafe ? Colors.green : Colors.red;
  }

  @override
  void initState() {
    super.initState();
    _saveTotalFlow();
    _loadData();
    _initBLE();
  }

  Future<void> _initBLE() async {
    bleService = WaterQualityBLEService(
      onDataReceived: _updateSensorData,
    );

   _connectionSubscription =
    bleService.stateStream.listen((state) {
      setState(() {
        isConnected = state == BleConnectionState.connected;
      });

      if (state == BleConnectionState.disconnected) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Perangkat terputus. Mencoba menghubungkan kembali...'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        _reconnectBLE();
      }
    });

    try {
      await bleService.startScan();
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error koneksi Bluetooth';
        if (e.toString().contains('Permissions tidak diberikan')) {
          errorMessage =
              'Mohon izinkan akses lokasi dan bluetooth untuk menggunakan fitur ini';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () {
                openAppSettings();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _reconnectBLE() async {
    await Future.delayed(const Duration(seconds: 5)); // Tunggu 5 detik
    if (mounted && !bleService.isConnected()) {
      try {
        await bleService.reconnect();
      } catch (e) {
        print('Reconnection error: $e');
      }
    }
  }

  // // Ganti deklarasi bluetoothService
  // void _setupBluetooth() {
  //   bluetoothService = WaterQualityBluetoothService(
  //     // Update nama class
  //     targetDeviceName: 'ESP32_Water_Quality',
  //     onDataReceived: _updateSensorData,
  //   );
  //   _connectBluetooth();
  // }

  // Future<void> _connectBluetooth() async {
  //   await bluetoothService.connect();
  //   setState(() {
  //     isConnected = bluetoothService.isConnected();
  //   });
  // }

  void _updateSensorData(Map<String, dynamic> data) {
    setState(() {
      // Update nilai parameter
      waterParameters['pH']?['value'] = data['ph']?.toDouble() ?? 7.0;
      waterParameters['TDS']?['value'] = data['tds']?.toDouble() ?? 150.0;
      waterParameters['Turbidity']?['value'] =
          data['turbidity']?.toDouble() ?? 2.5;
      waterParameters['Temperature']?['value'] =
          data['temperature']?.toDouble() ?? 25.0;

      // Update total water flow
      final newFlow = data['flow']?.toDouble() ?? 0.0;
      totalWaterFlow += newFlow;
      _saveTotalFlow();

      // Update timestamp
      if (data['timestamp'] != null) {
        lastUpdatedTime = DateTime.parse(data['timestamp']);
      } else {
        lastUpdatedTime = DateTime.now();
      }
    });
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    bleService.dispose();
    super.dispose();
  }

  // ... (previous methods remain the same)

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final lastReplacementMillis = prefs.getInt(LAST_REPLACEMENT_KEY);
    final durationDays =
        prefs.getInt(FILTER_DURATION_KEY) ?? 90; // Default 90 hari
    // final savedTotalFlow = prefs.getDouble(TOTAL_FLOW_KEY) ?? 0.0;

    setState(() {
      if (lastReplacementMillis != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(lastReplacementMillis);
        lastReplacementDate = DateTime(date.year, date.month, date.day);
      } else {
        final now = DateTime.now();
        lastReplacementDate = DateTime(now.year, now.month, now.day);
      }
      filterDuration = Duration(days: durationDays);
      // totalWaterFlow = savedTotalFlow; // Tambahkan ini
      isLoading = false;
    });
  }

  Future<void> _saveLastReplacementDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(LAST_REPLACEMENT_KEY, date.millisecondsSinceEpoch);
  }

  Future<void> _updateFilterDuration(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(FILTER_DURATION_KEY, days);
    setState(() {
      filterDuration = Duration(days: days);
    });
  }

  Future<void> _saveTotalFlow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(TOTAL_FLOW_KEY, totalWaterFlow);
  }

  bool get isFlowExceeded {
    return totalWaterFlow >= MAX_WATER_FLOW;
  }

  DateTime get nextReplacementDate => lastReplacementDate.add(filterDuration);

  bool get isReplacementDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isDaysExceeded = nextReplacementDate.difference(today).inDays <= 7;
    return isDaysExceeded || isFlowExceeded;
  }

  String get filterStatus {
    if (isFlowExceeded) {
      return 'Filter Perlu Diganti (Batas Debit Air Terlampaui)';
    } else if (isReplacementDue) {
      return 'Segera Ganti Filter!';
    } else {
      return 'Filter dalam Kondisi Baik';
    }
  }

  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return nextReplacementDate.difference(today).inDays;
  }

  void updateFilterDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      lastReplacementDate = today;
      totalWaterFlow = 0.0;
    });

    await _saveLastReplacementDate(today);
    await _saveTotalFlow();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal penggantian filter berhasil diperbarui'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showDurationPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atur Durasi Filter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pilih durasi pergantian filter:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: filterDuration.inDays,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              items: const [
                DropdownMenuItem(value: 30, child: Text('1 Bulan (30 hari)')),
                DropdownMenuItem(value: 60, child: Text('2 Bulan (60 hari)')),
                DropdownMenuItem(value: 90, child: Text('3 Bulan (90 hari)')),
                DropdownMenuItem(value: 120, child: Text('4 Bulan (120 hari)')),
                DropdownMenuItem(value: 150, child: Text('5 Bulan (150 hari)')),
                DropdownMenuItem(value: 180, child: Text('6 Bulan (180 hari)')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _updateFilterDuration(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _connectBluetooth() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BluetoothConnectionScreen(),
      ),
    );

    if (result != null && result is WaterQualityBLEService) {
      setState(() {
        bleService = result;
        isConnected = bleService.isConnected();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        // leading: IconButton(
        //   icon: const Icon(Icons.arrow_back_ios, color: Colors.grey),
        //   onPressed: () => Navigator.pop(context),
        // ),
        title: const Text(
          'Monitor Kualitas Air',
          style: TextStyle(
            color: Color(0xFF2196F3),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Status Bluetooth
          InkWell(
            onTap: _connectBluetooth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isConnected
                    ? Colors.green.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                    color: isConnected ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isConnected ? 'Terhubung' : 'Hubungkan',
                    style: TextStyle(
                      color: isConnected ? Colors.green : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 8.0),
          //   child: Icon(
          //     isConnected
          //         ? Icons.bluetooth_connected
          //         : Icons.bluetooth_disabled,
          //     color: isConnected ? Colors.blue : Colors.grey,
          //   ),
          // ),

          IconButton(
            icon: const Icon(Icons.settings, color: Colors.grey),
            onPressed: _showDurationPicker,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFF5F9FF)],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWaterQualityStatus(),
                const SizedBox(height: 20),
                _buildStatusCard(),
                const SizedBox(height: 20),
                _buildWaterFlowInfo(),
                const SizedBox(height: 20),
                // _buildParametersGrid(),
                // const SizedBox(height: 20),
                _buildDateInfoCard(),
                const SizedBox(height: 20),
                _buildMaintenanceCard(),
                // const SizedBox(height: 20),
                // _buildTipsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaterQualityStatus() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            waterQualityColor.withOpacity(0.8),
            waterQualityColor,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: waterQualityColor.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Update: ${DateFormat('dd MMM yyyy HH:mm').format(lastUpdatedTime)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Icon(
              isWaterSafe ? Icons.check_circle : Icons.warning,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              waterQualityStatus,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isWaterSafe
                  ? 'Semua parameter dalam batas normal'
                  : 'Beberapa parameter di luar batas normal',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            // Container untuk parameter
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ParameterDetailScreen(
                      waterParameters: waterParameters,
                      lastUpdatedTime: lastUpdatedTime,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildParameterItem('pH',
                            waterParameters['pH']!['value'].toString(), ''),
                        _buildParameterItem('TDS',
                            waterParameters['TDS']!['value'].toString(), 'ppm'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildParameterItem(
                            'Turbidity',
                            waterParameters['Turbidity']!['value'].toString(),
                            'NTU'),
                        _buildParameterItem(
                            'Suhu',
                            waterParameters['Temperature']!['value'].toString(),
                            '°C'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Tekan untuk detail lengkap',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white70,
                          size: 12,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  } // Tambahkan widget helper untuk parameter item

  Widget _buildParameterItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                unit,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // Widget _buildParametersGrid() {
  //   return GridView.builder(
  //     shrinkWrap: true,
  //     physics: const NeverScrollableScrollPhysics(),
  //     gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
  //       crossAxisCount: 2,
  //       crossAxisSpacing: 16,
  //       mainAxisSpacing: 16,
  //       childAspectRatio: 1.1,
  //     ),
  //     itemCount: waterParameters.length,
  //     itemBuilder: (context, index) {
  //       final parameter = waterParameters.entries.elementAt(index);
  //       final value = parameter.value['value'];
  //       final isNormal = value >= parameter.value['minRange'] &&
  //           value <= parameter.value['maxRange'];

  //       return Container(
  //         decoration: BoxDecoration(
  //           color: Colors.white,
  //           borderRadius: BorderRadius.circular(16),
  //           boxShadow: [
  //             BoxShadow(
  //               color: Colors.blue.withOpacity(0.1),
  //               spreadRadius: 2,
  //               blurRadius: 10,
  //               offset: const Offset(0, 4),
  //             ),
  //           ],
  //         ),
  //         child: Padding(
  //           padding: const EdgeInsets.all(16.0),
  //           child: Column(
  //             mainAxisAlignment: MainAxisAlignment.center,
  //             children: [
  //               Icon(
  //                 parameter.value['icon'],
  //                 color: isNormal ? Colors.blue : Colors.red,
  //                 size: 32,
  //               ),
  //               const SizedBox(height: 8),
  //               Text(
  //                 parameter.key,
  //                 style: const TextStyle(
  //                   fontSize: 16,
  //                   fontWeight: FontWeight.bold,
  //                 ),
  //               ),
  //               const SizedBox(height: 4),
  //               Text(
  //                 '$value${parameter.value['unit']}',
  //                 style: TextStyle(
  //                   fontSize: 20,
  //                   fontWeight: FontWeight.bold,
  //                   color: isNormal ? Colors.blue : Colors.red,
  //                 ),
  //               ),
  //               Text(
  //                 'Normal: ${parameter.value['minRange']}-${parameter.value['maxRange']}${parameter.value['unit']}',
  //                 style: const TextStyle(
  //                   fontSize: 12,
  //                   color: Colors.grey,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

  // ... (other existing widget methods remain the same)

  Widget _buildDateInfoCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              _buildDateRow(
                'Penggantian Terakhir',
                lastReplacementDate,
                Icons.history,
                Colors.blue,
              ),
              const Divider(height: 32),
              _buildDateRow(
                'Penggantian Berikutnya',
                nextReplacementDate,
                Icons.event,
                Colors.green,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateRow(
      String label, DateTime date, IconData icon, Color iconColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                ),
              ),
              Text(
                DateFormat('dd MMMM yyyy').format(date),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B1B1B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMaintenanceCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Pemeliharaan Filter',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B1B1B),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: updateFilterDate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Perbarui Tanggal Filter',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget _buildTipsCard() {
  //   return Container(
  //     decoration: BoxDecoration(
  //       borderRadius: BorderRadius.circular(16),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.blue.withOpacity(0.1),
  //           spreadRadius: 2,
  //           blurRadius: 10,
  //           offset: const Offset(0, 4),
  //         ),
  //       ],
  //     ),
  //     child: Card(
  //       elevation: 0,
  //       shape: RoundedRectangleBorder(
  //         borderRadius: BorderRadius.circular(16),
  //       ),
  //       child: const Padding(
  //         padding: EdgeInsets.all(20.0),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Row(
  //               children: [
  //                 Icon(
  //                   Icons.tips_and_updates,
  //                   color: Colors.amber,
  //                   size: 24,
  //                 ),
  //                 SizedBox(width: 8),
  //                 Text(
  //                   'Tips Perawatan',
  //                   style: TextStyle(
  //                     fontSize: 18,
  //                     fontWeight: FontWeight.bold,
  //                     color: Color(0xFF1B1B1B),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             SizedBox(height: 12),
  //             Text(
  //               'Pastikan untuk memeriksa kualitas air secara rutin dan lakukan penggantian filter sesuai jadwal untuk menjaga kualitas air tetap optimal.',
  //               style: TextStyle(
  //                 fontSize: 14,
  //                 color: Color(0xFF666666),
  //                 height: 1.5,
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildStatusCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              _buildCircularProgress(),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: (isReplacementDue ? Colors.red : Colors.green)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isReplacementDue
                      ? 'Segera Ganti Filter!'
                      : 'Filter dalam Kondisi Baik',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isReplacementDue ? Colors.red : Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircularProgress() {
    final double progress = daysRemaining / filterDuration.inDays;
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: 180,
          width: 180,
          child: CircularProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            strokeWidth: 16,
            backgroundColor: Colors.grey.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              isReplacementDue ? Colors.red : Colors.blue,
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$daysRemaining',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B1B1B),
              ),
            ),
            const Text(
              'Hari Menuju\nPenggantian Filter',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF666666),
                height: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWaterFlowInfo() {
    final flowProgress = (totalWaterFlow / MAX_WATER_FLOW).clamp(0.0, 1.0);
    final remainingFlow = (MAX_WATER_FLOW - totalWaterFlow).toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.water_drop,
                color: isFlowExceeded ? Colors.red : Colors.blue,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Total Debit Air',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isFlowExceeded ? Colors.red : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: flowProgress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              isFlowExceeded ? Colors.red : Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Total: ${totalWaterFlow.toStringAsFixed(1)}L / ${MAX_WATER_FLOW.toStringAsFixed(1)}L',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          Text(
            'Sisa: $remainingFlow L',
            style: TextStyle(
              fontSize: 14,
              color: isFlowExceeded ? Colors.red : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
