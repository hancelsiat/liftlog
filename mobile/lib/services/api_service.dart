import 'dart:convert';
import 'dart:io' show Platform, File, NetworkInterface, InternetAddressType;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/workout.dart';
import '../models/progress.dart';
import '../models/exercise_video.dart';

class ApiService {
  // Configurable base URL with debugging
  static String _baseUrl = '';
  static String get baseUrl => _baseUrl;

  // Predefined network configurations with dynamic detection
  static final Map<String, String> _networkConfigs = {
    'pc': '192.168.1.16',     // PC IP
    'phone': '192.168.100.192', // Phone IP
    'emulator': '10.0.2.2'    // Android emulator
  };

  // Automatic network detection method
  static Future<String> _detectNetworkIP() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4
      );

      // Log all detected network interfaces for debugging
      print('Detected Network Interfaces:');
      for (var interface in interfaces) {
        print('Interface: ${interface.name}');
        for (var addr in interface.addresses) {
          print('  Address: ${addr.address} (Loopback: ${addr.isLoopback}, Link-local: ${addr.isLinkLocal})');
        }
      }

      // Find the first non-loopback, non-link-local IPv4 address
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && !addr.isLinkLocal) {
            print('Selected Network IP: ${addr.address}');
            return addr.address;
          }
        }
      }

      // Fallback to localhost if no suitable IP found
      return 'localhost';
    } catch (e) {
      print('Error detecting network IP: $e');
      return 'localhost';
    }
  }

  // Method to dynamically update network configurations
  static Future<void> updateNetworkConfigurationsAutomatically() async {
    try {
      final detectedIP = await _detectNetworkIP();
      _networkConfigs['detected'] = detectedIP;
      print('Automatically updated network configuration with detected IP: $detectedIP');
    } catch (e) {
      print('Failed to update network configurations automatically: $e');
    }
  }

  // Method to set base URL with advanced network configuration
  static Future<void> configureBaseUrl({
    String? manualIp, 
    String? networkType
  }) async {
    try {
      // Manual IP takes highest priority
      if (manualIp != null) {
        _baseUrl = 'http://$manualIp:5000/api';
        print('Manually set base URL to: $_baseUrl');
        return;
      }

      // Use predefined network configuration if specified
      if (networkType != null && _networkConfigs.containsKey(networkType)) {
        _baseUrl = 'http://${_networkConfigs[networkType]}:5000/api';
        print('Using predefined network config: $networkType');
        return;
      }

      // Platform-specific default configurations
      if (Platform.isAndroid) {
        _baseUrl = 'http://10.0.2.2:5000/api';  // Android emulator default
      }

      // Attempt to get network interfaces
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4
      );

      // Log all detected network interfaces for debugging
      print('Detected Network Interfaces:');
      for (var interface in interfaces) {
        print('Interface: ${interface.name}');
        for (var addr in interface.addresses) {
          print('  Address: ${addr.address} (Loopback: ${addr.isLoopback}, Link-local: ${addr.isLinkLocal})');
        }
      }

      // Find the first non-loopback, non-link-local IPv4 address
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && !addr.isLinkLocal) {
            _baseUrl = 'http://${addr.address}:5000/api';
            print('Selected Network IP: ${addr.address}');
            return;
          }
        }
      }

      // Fallback to localhost if no suitable IP found
      _baseUrl = 'http://localhost:5000/api';
      print('No suitable network interface found. Using localhost.');
    } catch (e) {
      // Extreme fallback
      _baseUrl = 'http://localhost:5000/api';
      print('Error detecting network IP: $e. Using localhost.');
    }
  }

  // Method to get available network configurations
  static Map<String, String> getNetworkConfigurations() {
    return Map.unmodifiable(_networkConfigs);
  }

  // Method to add or update network configuration
  static void updateNetworkConfiguration(String key, String ip) {
    _networkConfigs[key] = ip;
    print('Updated network configuration: $key = $ip');
  }

  // Method to get all detected network interfaces (useful for debugging)
  static Future<List<String>> getDetectedNetworkInterfaces() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4
      );

      return interfaces.expand((interface) => 
        interface.addresses
          .where((addr) => !addr.isLoopback && !addr.isLinkLocal)
          .map((addr) => addr.address)
      ).toList();
    } catch (e) {
      print('Error detecting network interfaces: $e');
      return [];
    }
  }

  // Helper method to manually set and log the current base URL
  static void setBaseUrl(String ip) {
    _baseUrl = 'http://$ip:5000/api';
    print('Base URL manually set to: $_baseUrl');
  }

  // Method to get the current base URL (useful for debugging)
  static String getCurrentBaseUrl() {
    return _baseUrl;
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
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _handleResponse(response);
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

  Future<Map<String, dynamic>> _delete(String endpoint) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
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

  // Auth methods
  Future<Map<String, dynamic>> register(
    String email, 
    String password, 
    String username, 
    {UserRole role = UserRole.member}
  ) async {
    return await _post('/auth/register', {
      'email': email,
      'password': password,
      'username': username,
      'role': role.toString().split('.').last, // Convert enum to string
    });
  }

  Future<Map<String, dynamic>> login(
    String email, 
    String password, 
    {UserRole role = UserRole.member}
  ) async {
    final response = await _post('/auth/login', {
      'email': email,
      'password': password,
      'role': role.toString().split('.').last, // Convert enum to string
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

  // Workout methods
  Future<List<Workout>> getWorkouts() async {
    final response = await _get('/workouts');
    final List<dynamic> workoutsJson = response['workouts'];
    return workoutsJson.map((json) => Workout.fromJson(json)).toList();
  }

  Future<Workout> getWorkout(String id) async {
    final response = await _get('/workouts/$id');
    return Workout.fromJson(response);
  }

  Future<Workout> createWorkout(String name, String description, List<String> exercises) async {
    final response = await _post('/workouts', {
      'name': name,
      'description': description,
      'exercises': exercises,
    });
    return Workout.fromJson(response);
  }

  Future<Workout> updateWorkout(String id, String name, String description, List<String> exercises) async {
    final response = await _patch('/workouts/$id', {
      'name': name,
      'description': description,
      'exercises': exercises,
    });
    return Workout.fromJson(response);
  }

  Future<void> deleteWorkout(String id) async {
    await _delete('/workouts/$id');
  }

  // Progress tracking methods
  Future<Progress> createProgress({
    required double bmi,
    required double caloriesIntake,
    required double calorieDeficit,
  }) async {
    final response = await _post('/progress', {
      'bmi': bmi,
      'caloriesIntake': caloriesIntake,
      'calorieDeficit': calorieDeficit,
    });
    return Progress.fromJson(response);
  }

  Future<List<Progress>> getProgressHistory() async {
    final response = await _get('/progress');
    final List<dynamic> progressJson = response['progress'];
    return progressJson.map((json) => Progress.fromJson(json)).toList();
  }

  // Exercise Videos methods
  Future<List<ExerciseVideo>> getExerciseVideos() async {
    final response = await _get('/videos');
    final List<dynamic> videosJson = response['videos'];
    return videosJson.map((json) => ExerciseVideo.fromJson(json)).toList();
  }

  Future<ExerciseVideo> getExerciseVideo(String id) async {
    final response = await _get('/videos/$id');
    return ExerciseVideo.fromJson(response);
  }

  // Get trainer's uploaded videos
  Future<List<ExerciseVideo>> getTrainerVideos() async {
    final response = await _get('/videos/trainer');
    final List<dynamic> videosJson = response['videos'];
    return videosJson.map((json) => ExerciseVideo.fromJson(json)).toList();
  }

  // Video upload method for trainers
  Future<ExerciseVideo> uploadVideo({
    required File videoFile, 
    required Map<String, dynamic> metadata
  }) async {
    // Prepare multipart request for file upload
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST', 
      Uri.parse('$baseUrl/videos/upload')
    );

    // Add authorization header
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    // Add video file
    request.files.add(
      await http.MultipartFile.fromPath(
        'video', 
        videoFile.path,
        filename: videoFile.path.split('/').last
      )
    );

    // Add metadata fields
    metadata.forEach((key, value) {
      request.fields[key] = value is List 
        ? jsonEncode(value) 
        : value.toString();
    });

    // Send request and handle response
    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseBody = jsonDecode(response.body);
        return ExerciseVideo.fromJson(responseBody);
      } else {
        throw Exception('Video upload failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error uploading video: $e');
    }
  }
}