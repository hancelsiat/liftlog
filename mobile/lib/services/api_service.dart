
import 'dart:convert';
import 'dart:io' show Platform, File, NetworkInterface, InternetAddressType;
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../models/user.dart';
import '../models/workout.dart';
import '../models/progress.dart';
import '../models/exercise_video.dart';

class ApiService {
  static String _baseUrl = '';
  static String get baseUrl => _baseUrl;
  static final Map<String, String> _networkConfigs = {
    'pc': '192.168.1.16',
    'phone': '192.168.100.192',
    'emulator': '10.0.2.2'
  };
  static String CURRENT_PC_IP = '192.168.1.16';

  static Future<String> _detectNetworkIP() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4
      );
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && !addr.isLinkLocal) {
            return addr.address;
          }
        }
      }
      return 'localhost';
    } catch (e) {
      return 'localhost';
    }
  }

  static Future<void> configureBaseUrl({
    String? manualIp,
    String? networkType,
    String? renderUrl
  }) async {
    if (renderUrl != null) {
      _baseUrl = '$renderUrl/api';
      return;
    }
    if (manualIp != null) {
      _baseUrl = 'http://$manualIp:5000/api';
      return;
    }
    if (networkType != null && _networkConfigs.containsKey(networkType)) {
      _baseUrl = 'http://${_networkConfigs[networkType]}:5000/api';
      return;
    }
    if (Platform.isAndroid) {
      _baseUrl = 'http://10.0.2.2:5000/api';
      return;
    }
    final detectedIP = await _detectNetworkIP();
    _baseUrl = 'http://$detectedIP:5000/api';
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> body) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _patch(String endpoint, Map<String, dynamic> body) async {
    final token = await getToken();
    final response = await http.patch(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw Exception('API Error: ${response.statusCode} - ${response.body}');
    }
  }

  Future<Map<String, dynamic>> register(
    String email,
    String password,
    String username,
    {UserRole role = UserRole.member, File? credentialFile}
  ) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/auth/register'));
    request.fields['email'] = email;
    request.fields['password'] = password;
    request.fields['username'] = username;
    request.fields['role'] = role.toString().split('.').last;

    if (credentialFile != null) {
      request.files.add(await http.MultipartFile.fromPath('credential', credentialFile.path));
    }

    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
        final decodedResponse = jsonDecode(responseData);
        if (decodedResponse.containsKey('token')) {
            await setToken(decodedResponse['token']);
        }
        return decodedResponse;
    } else {
        throw Exception('API Error: ${response.statusCode} - $responseData');
    }
  }

  Future<void> resendVerificationEmail(String email) async {
    await _post('/auth/resend-verification', {'email': email});
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _post('/auth/login', {
      'email': email,
      'password': password,
    });
    if (response.containsKey('token')) {
      await setToken(response['token']);
    }
    return response;
  }

  Future<User> getProfile() async {
    final response = await _get('/auth/profile');
    return User.fromJson(response);
  }

  Future<Map<String, dynamic>> getUsers() async {
    return _get('/auth/users');
  }

  Future<User> approveTrainer(String userId, bool isApproved) async {
    final response = await _patch('/auth/users/$userId/approve', {
      'isApproved': isApproved,
    });
    return User.fromJson(response['user']);
  }

  Future<Map<String, dynamic>> _get(String endpoint) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    return _handleResponse(response);
  }
}
