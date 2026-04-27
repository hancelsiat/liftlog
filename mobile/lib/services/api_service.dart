
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

  static void setBaseUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      _baseUrl = '$url/api';
    } else {
      _baseUrl = 'http://$url:5000/api';
    }
  }

  static String getCurrentBaseUrl() {
    return _baseUrl;
  }

  static void updatePCIP(String newIP) {
    CURRENT_PC_IP = newIP;
    _networkConfigs['pc'] = newIP;
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

  Future<dynamic> _get(String endpoint) async {
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

  Future<Map<String, dynamic>> _deleteWithBody(String endpoint, Map<String, dynamic> body) async {
    final token = await getToken();
    final request = http.Request('DELETE', Uri.parse('$baseUrl$endpoint'));
    request.headers.addAll({
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    });
    request.body = jsonEncode(body);
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
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
  
  Future<List<Workout>> getWorkouts() async {
    final response = await _get('/workouts');
    final List<dynamic> workoutsJson = response['workouts'];
    return workoutsJson.map((json) => Workout.fromJson(json)).toList();
  }

  Future<Workout> createWorkout(String name, String description, List<String> exercises) async {
    final response = await _post('/workouts', {
      'name': name,
      'description': description,
      'exercises': exercises,
    });
    return Workout.fromJson(response['workout'] as Map<String, dynamic>);
  }

  Future<Workout> updateWorkout(String id, String name, String description, List<Map<String, dynamic>> exercises) async {
    final response = await _patch('/workouts/$id', {
      'name': name,
      'description': description,
      'exercises': exercises,
    });
    return Workout.fromJson(response['workout'] as Map<String, dynamic>);
  }

  Future<void> deleteWorkout(String workoutId) async {
    await _delete('/workouts/$workoutId');
  }

  Future<void> deleteWorkouts(List<String> workoutIds) async {
    await _deleteWithBody('/workouts', {'workoutIds': workoutIds});
  }

  Future<List<Map<String, dynamic>>> getAvailableTrainers() async {
    final response = await _get('/workouts/trainers/available');
    final List<dynamic> trainersJson = response['trainers'];
    return trainersJson.map((json) => json as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> getWorkoutsByTrainer(String trainerId) async {
    final response = await _get('/workouts/trainer/$trainerId');
    final List<dynamic> workoutsJson = response['workouts'];
    return workoutsJson.map((json) => json as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> canUpdateProgress() async {
    return await _get('/progress/can-update') as Map<String, dynamic>;
  }

  Future<List<Progress>> getProgressHistory() async {
    final response = await _get('/progress');
    final List<dynamic> progressJson = response['progress'];
    return progressJson.map((json) => Progress.fromJson(json)).toList();
  }

  Future<Progress> createProgressPartial({
    double? bmi,
    double? caloriesIntake,
    double? calorieDeficit,
  }) async {
    final Map<String, dynamic> body = {};
    if (bmi != null) body['bmi'] = bmi;
    if (caloriesIntake != null) body['caloriesIntake'] = caloriesIntake;
    if (calorieDeficit != null) body['calorieDeficit'] = calorieDeficit;
    final response = await _post('/progress', body);
    return Progress.fromJson(response['progress']);
  }

  Future<List<ExerciseVideo>> getExerciseVideos() async {
    final response = await _get('/videos');
    final List<dynamic> videosJson = response['videos'];
    return videosJson.map((json) => ExerciseVideo.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>> uploadVideo({
    required String jwt,
    required String title,
    required String exerciseType,
    String? description,
    bool isPublic = true,
  }) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video, withData: true);
    if (result == null || result.files.isEmpty) {
      return {'success': false, 'message': 'No file selected'};
    }
    final file = result.files.first;
    final filename = file.name.isNotEmpty ? file.name : 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final bytes = file.bytes;
    final path = file.path;
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
      'exerciseType': exerciseType.trim().toLowerCase(),
      if (description != null) 'description': description.trim(),
      'isPublic': isPublic.toString(),
      'video': mpFile,
    });
    final dio = Dio();
    dio.options.headers['Authorization'] = 'Bearer $jwt';
    final response = await dio.post('$baseUrl/videos', data: form);
    return {'success': true, 'data': response.data};
  }

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
    return ExerciseVideo.fromJson(responseBody['video']);
  }

  Future<List<ExerciseVideo>> getTrainerVideos() async {
    final response = await _get('/videos/trainer');
    final List<dynamic> videosJson = response['videos'];
    return videosJson.map((json) => ExerciseVideo.fromJson(json)).toList();
  }

  Future<void> deleteVideo(String videoId) async {
    await _delete('/videos/$videoId');
  }

  Future<Map<String, dynamic>> getUsers({String? role, String? search, int page = 1, int limit = 10}) async {
    final queryParams = <String, String>{};
    if (role != null) queryParams['role'] = role;
    if (search != null) queryParams['search'] = search;
    queryParams['page'] = page.toString();
    queryParams['limit'] = limit.toString();
    final uri = Uri.parse('$baseUrl/auth/users').replace(queryParameters: queryParams);
    return await _getUri(uri.toString()) as Map<String, dynamic>;
  }

  Future<User> updateUser(String userId, Map<String, dynamic> updates) async {
    final response = await _patch('/auth/users/$userId', updates);
    return User.fromJson(response);
  }

  Future<void> deleteUser(String userId) async {
    await _delete('/auth/users/$userId');
  }

  Future<Workout> createWorkoutTemplate({
    required String title,
    required String description,
    required List<Map<String, dynamic>> exercises,
    String? category,
    String? intensity,
    int? duration,
    int? caloriesBurned,
    String? trainerId,
  }) async {
    final response = await _post('/workouts/template', {
      'title': title,
      'description': description,
      'exercises': exercises,
      'category': category ?? 'mixed',
      'intensity': intensity ?? 'moderate',
      'duration': duration,
      'caloriesBurned': caloriesBurned,
      'isPublic': true,
      if (trainerId != null) 'trainer': trainerId,
    });
    return Workout.fromJson(response['workout'] as Map<String, dynamic>);
  }

  Future<List<Workout>> getTrainerWorkouts() async {
    final response = await _get('/workouts/trainer');
    final List<dynamic> workoutsJson = response['workouts'];
    return workoutsJson.map((json) => Workout.fromJson(json)).toList();
  }

  Future<dynamic> _getUri(String url) async {
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

  Future<User> approveTrainer(String userId, bool isApproved, {String? rejectionReason}) async {
    final body = {
      'isApproved': isApproved,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
    };
    final response = await _patch('/auth/users/$userId/approve', body);
    return User.fromJson(response['user']);
  }

  Future<List<dynamic>> getClients() async {
    final response = await _get('/clients');
    return response as List<dynamic>;
  }

  Future<List<dynamic>> getClientProgress(String clientId) async {
    final response = await _get('/clients/$clientId/progress');
    return response as List<dynamic>;
  }

  Future<void> saveClientNotes(String clientId, String notes) async {
    await _post('/clients/$clientId/notes', {'notes': notes});
  }

  Future<void> markWorkoutAsComplete(String workoutId) async {
    await _post('/workouts/$workoutId/complete', {});
  }

  Future<List<dynamic>> getAssignedWorkouts() async {
    final response = await _get('/workouts/my-plan');
    return response as List<dynamic>;
  }

  Future<void> selectTrainer(String trainerId) async {
    await _post('/auth/select-trainer', {'trainerId': trainerId});
  }

  Future<void> assignWorkoutToClient(String memberId, String workoutId) async {
    await _post('/clients/$memberId/assign-workout', {'workoutId': workoutId});
  }

  Future<void> removeClient(String memberId) async {
    await _delete('/clients/$memberId/remove');
  }
}
