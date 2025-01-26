// water_quality_service.dart
import 'dart:convert';
import 'package:web_socket_channel/io.dart';

class WaterQualityService {
 final _channel = IOWebSocketChannel.connect('ws://192.168.4.1:81');
 Function(Map<String, dynamic>)? onDataReceived;
 bool _isConnected = false;

 bool isConnected() => _isConnected;

 void connect() {
   _channel.stream.listen(
     (message) {
       _isConnected = true;
       final data = jsonDecode(message);
       onDataReceived?.call(data);
     },
     onError: (error) {
       print('Error: $error');
       _isConnected = false;
     },
     onDone: () {
       print('Connection closed');
       _isConnected = false;
     },
   );
 }

 void dispose() {
   _channel.sink.close();
 }
}