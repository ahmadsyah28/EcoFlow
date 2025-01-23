// 1. Buat file baru: lib/models/sensor_data.dart
class SensorData {
  final double ph;
  final double tds;
  final double turbidity;
  final double temperature;
  final double flow;
  final DateTime timestamp;

  SensorData.fromJson(Map<String, dynamic> json)
      : ph = _validateRange(json['ph']?.toDouble() ?? 0, 0, 14),
        tds = _validateRange(json['tds']?.toDouble() ?? 0, 0, 1000),
        turbidity = _validateRange(json['turbidity']?.toDouble() ?? 0, 0, 100),
        temperature = _validateRange(json['temperature']?.toDouble() ?? 0, 0, 100),
        flow = _validateRange(json['flow']?.toDouble() ?? 0, 0, 100),
        timestamp = DateTime.now();

  static double _validateRange(double value, double min, double max) {
    return value.clamp(min, max);
  }
}