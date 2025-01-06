import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/water_quality.dart';

class WaterQualityService {
  final String baseUrl;
  
  WaterQualityService({required this.baseUrl});

  Future<WaterQuality> getCurrentReadings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/sensor-readings'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return WaterQuality.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load sensor data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error connecting to sensor: $e');
    }
  }
}