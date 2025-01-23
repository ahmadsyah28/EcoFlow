// 1. Buat file baru: lib/models/ble_models.dart
enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error
}

class BleException implements Exception {
  final String message;
  final BleErrorType type;
  const BleException(this.message, this.type);
}

enum BleErrorType {
  deviceNotFound,
  connectionFailed,
  serviceNotFound,
  permissionDenied,
  bluetoothOff,
  timeout,
  unknown
}

