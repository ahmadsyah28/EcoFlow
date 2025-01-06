class WaterQuality {
  final double ph;
  final double saturation;
  final double salinity;
  final DateTime lastUpdated;

  WaterQuality({
    required this.ph,
    required this.saturation,
    required this.salinity,
    required this.lastUpdated,
  });

  factory WaterQuality.fromJson(Map<String, dynamic> json) {
    return WaterQuality(
      ph: json['ph'].toDouble(),
      saturation: json['saturation'].toDouble(),
      salinity: json['salinity'].toDouble(),
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }
}