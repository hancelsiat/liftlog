import 'dart:io';
import 'package:liftlog_mobile/services/api_service.dart';

void main() async {
  print('Setting base URL...');
  ApiService.setBaseUrl('https://liftlog-7.onrender.com');
  
  final api = ApiService();
  print('Registering...');
  try {
    final result = await api.register('test_dart_script@gmail.com', 'password123', 'dart_test_user');
    print('Result: $result');
  } catch (e) {
    print('Error: $e');
  }
}
