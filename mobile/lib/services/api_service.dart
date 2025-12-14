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
  // Configurable base URL with debugging
  static String _baseUrl = '';
  static String get baseUrl => _baseUrl;

  // Predefined network configurations with dynamic detection
  static final Map<String, String> _networkConfigs = {
    'pc': '192.168.1.16',     // PC IP (update this when IP changes)
    'phone': '192.168.100.192', // Phone IP
    'emulator': '10.0.2.2'    // Android emulator
  };

  // Current PC IP address (UPDATE THIS WHEN YOUR IP CHANGES)
  static String CURRENT_PC_IP = '192.168.1.16';

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
    String? networkType,
    String? renderUrl
  }) async {
    try {
      // Render URL takes highest priority for production
      if (renderUrl != null) {
        _baseUrl = '$renderUrl/api';
        print('Using Render URL: $_baseUrl');
        return;
      }

      // Manual IP takes highest priority for development
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
    if (key == 'pc') {
      CURRENT_PC_IP = ip; // Update the PC IP constant when changed
    }
    print('Updated network configuration: $key = $ip');
  }

  // Quick method to update PC IP when network changes
  static void updatePCIP(String newIP) {
    CURRENT_PC_IP = newIP;
    _networkConfigs['pc'] = newIP;
    print('PC IP updated to: $newIP');
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
  static void setBaseUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      // Full URL provided (for production/Render)
      _baseUrl = '$url/api';
    } else {
      // IP address provided (for development)
      _baseUrl = 'http://$url:5000/api';
    }
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
    final token = await getToken();
    final fullUrl = '$baseUrl$endpoint';
    print('Making POST request to: $fullUrl');
    
    try {
      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Please check your internet connection or try again later.');
        },
      );
      return _handleResponse(response);
    } catch (e) {
      print('POST request error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _get(String endpoint) async {
    final token = await getToken();
    final fullUrl = '$baseUrl$endpoint';
    print('Making GET request to: $fullUrl');
    final response = await http.get(
      Uri.parse(fullUrl),
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
    final fullUrl = '$baseUrl$endpoint';
    print('Making DELETE request to: $fullUrl');
    final response = await http.delete(
      Uri.parse(fullUrl),
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
    } else if (response.statusCode == 401) {
      // Token is invalid/expired, clear it and throw specific error
      removeToken();
      throw Exception('Authentication required. Please log in again.');
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
    final response = await _post('/auth/register', {
      'email': email,
      'password': password,
      'username': username,
      'role': role.toString().split('.').last, // Convert enum to string
    });
    if (response.containsKey('token')) {
      await setToken(response['token']);
    }
    return response;
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
    return Workout.fromJson(response['workout'] as Map<String, dynamic>);
  }

  // Create workout template (Trainer only)
  Future<Workout> createWorkoutTemplate({
    required String title,
    required String description,
    required List<Map<String, dynamic>> exercises,
    String? category,
    String? intensity,
    int? duration,
    int? caloriesBurned,
  }) async {
    final response = await _post('/workouts/template', {
      'title': title,
      'description': description,
      'exercises': exercises,
      'category': category ?? 'mixed',
      'intensity': intensity ?? 'moderate',
      'duration': duration,
      'caloriesBurned': caloriesBurned,
    });
    return Workout.fromJson(response['workout'] as Map<String, dynamic>);
  }

  Future<Workout> updateWorkout(String id, String name, String description, List<String> exercises) async {
    final response = await _patch('/workouts/$id', {
      'name': name,
      'description': description,
      'exercises': exercises,
    });
    return Workout.fromJson(response['workout'] as Map<String, dynamic>);
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
    print('DEBUG api raw video json: ${response['videos']}');
    final List<dynamic> videosJson = response['videos'];
    return videosJson.map((json) => ExerciseVideo.fromJson(json)).toList();
  }

  // Delete a video
  Future<void> deleteVideo(String videoId) async {
    await _delete('/videos/$videoId');
  }

  // Get available trainers for members
  Future<List<Map<String, dynamic>>> getAvailableTrainers() async {
    final response = await _get('/workouts/trainers/available');
    final List<dynamic> trainersJson = response['trainers'];
    return trainersJson.map((json) => json as Map<String, dynamic>).toList();
  }

  // Get workouts by trainer
  Future<List<Map<String, dynamic>>> getWorkoutsByTrainer(String trainerId) async {
    final response = await _get('/workouts/trainer/$trainerId');
    final List<dynamic> workoutsJson = response['workouts'];
    return workoutsJson.map((json) => json as Map<String, dynamic>).toList();
  }

  // Video upload method for trainers
  Future<Map<String, dynamic>> uploadVideo({
    required String jwt,
    required String title,
    required String exerciseType,
    String? description,
    bool isPublic = true,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: true, // IMPORTANT for Google Drive picks
      );

      if (result == null || result.files.isEmpty) {
        return {'success': false, 'message': 'No file selected'};
      }

      final file = result.files.first;
      final filename = file.name.isNotEmpty ? file.name : 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final bytes = file.bytes; // may be null on some platforms if withData not supported
      final path = file.path; // may be null for Drive

      final mimeType = lookupMimeType(filename) ?? 'video/mp4';
      final parts = mimeType.split('/');
      final contentType = MediaType(parts[0], parts.length > 1 ? parts[1] : 'mp4');

      MultipartFile mpFile;
      if (bytes != null) {
        mpFile = MultipartFile.fromBytes(bytes, filename: filename, contentType: contentType);
      } else if (path != null) {
        mpFile = await MultipartFile.fromFile(path, filename: filename, contentType: contentType);
      } else {
        return {'success': false, 'message': 'Unable to read file bytes or path'};
      }

      final form = FormData.fromMap({
        'title': title.trim(),
        'exerciseType': exerciseType.trim(),
        if (description != null) 'description': description.trim(),
        'isPublic': isPublic.toString(),
        'video': mpFile,
      });

      final dio = Dio();
      dio.options.headers['Authorization'] = 'Bearer $jwt';
      dio.options.connectTimeout = const Duration(seconds: 60);
      dio.options.receiveTimeout = const Duration(seconds: 600);

      print('DEBUG upload URL: ${ApiService.baseUrl}/videos');

      final response = await dio.post(
        '${ApiService.baseUrl}/videos',
        data: form,
        options: Options(
          headers: {'Authorization': 'Bearer $jwt'},
          contentType: 'multipart/form-data',
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            final pct = (sent / total * 100).toStringAsFixed(0);
            print('Upload progress: $pct%');
          }
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': response.data};
      } else {
        return {'success': false, 'status': response.statusCode, 'data': response.data};
      }
    } on DioException catch (e) {
      print('UPLOAD ERROR status=${e.response?.statusCode} data=${e.response?.data}');
      return {'success': false, 'message': e.response?.data ?? e.message};
    } catch (e) {
      print('uploadVideo exception: $e');
      return {'success': false, 'message': e.toString()};
    }
  }



  // Admin: Get all users
  Future<Map<String, dynamic>> getUsers({
    String? role,
    String? search,
    int page = 1,
    int limit = 10,
  }) async {
    final queryParams = <String, String>{};
    if (role != null) queryParams['role'] = role;
    if (search != null) queryParams['search'] = search;
    queryParams['page'] = page.toString();
    queryParams['limit'] = limit.toString();

    final uri = Uri.parse('$baseUrl/auth/users').replace(queryParameters: queryParams);
    return _getUri(uri.toString());
  }

  // Admin: Update user
  Future<User> updateUser(String userId, Map<String, dynamic> updates) async {
    final response = await _patch('/auth/users/$userId', updates);
    return User.fromJson(response);
  }

  // Admin: Delete user
  Future<void> deleteUser(String userId) async {
    await _delete('/auth/users/$userId');
  }

  // Check if user can update progress
  Future<Map<String, dynamic>> canUpdateProgress() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/progress/can-update'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to check update status');
    }
  }

  // Upload video from Google Drive
  Future<ExerciseVideo> uploadVideoFromDrive({
    required String fileId,
    required String accessToken,
    required Map<String, dynamic> metadata,
    String? userId,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/videos/upload-drive'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'fileId': fileId,
        'accessToken': accessToken,
        'userId': userId,
        ...metadata,
      }),
    );

    final responseBody = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ExerciseVideo.fromJson(responseBody['video']);
    } else {
      throw Exception('Video upload failed: ${responseBody['error'] ?? responseBody['details'] ?? response.body}');
    }
  }

  Future<Map<String, dynamic>> _getUri(String url) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    return _handleResponse(response);
  }
}
