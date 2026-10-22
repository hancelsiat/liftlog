import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
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
import '../models/rating_stats.dart';
import '../models/message.dart';

class ApiService {
  static String _baseUrl = '';
  static String get baseUrl => _baseUrl;
  static final Map<String, String> _networkConfigs = {
    'pc': '192.168.1.16',
    'phone': '192.168.100.192',
    'emulator': '10.0.2.2',
  };
  static String currentPcIp = '192.168.1.16';

  static Future<String> _detectNetworkIP() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
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
    String? renderUrl,
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
    currentPcIp = newIP;
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
    debugPrint('GET request to: $baseUrl$endpoint');
    debugPrint('Token: $token');
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final token = await getToken();
    final response = await http
        .post(
          Uri.parse('$baseUrl$endpoint'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _patch(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
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

  Future<Map<String, dynamic>> _deleteWithBody(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
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
    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response body: ${response.body}');
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      try {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        final errorMessage =
            errorData['error'] ??
            errorData['message'] ??
            'Something went wrong. Please try again later.';

        // Throw a structured exception with details
        throw ApiException(
          message: errorMessage,
          statusCode: response.statusCode,
          emailNotVerified: errorData['emailNotVerified'] ?? false,
          pendingApproval: errorData['pendingApproval'] ?? false,
        );
      } catch (e) {
        if (e is ApiException) rethrow;
        // Non-JSON body (e.g. Express "Cannot GET" HTML page or a proxy error).
        final String message;
        if (response.statusCode == 404) {
          message =
              'This feature is not available on the server yet (404). '
              'Please redeploy/update the backend.';
        } else if (response.statusCode >= 500) {
          message =
              'The server is having trouble (${response.statusCode}). '
              'It may be starting up — please try again in a minute.';
        } else {
          message =
              'We encountered an unexpected error (${response.statusCode}). '
              'Please check your connection and try again.';
        }
        throw ApiException(message: message, statusCode: response.statusCode);
      }
    }
  }

  Future<Map<String, dynamic>> register(
    String email,
    String password,
    String username, {
    UserRole role = UserRole.member,
    File? credentialFile,
    String? fullName,
  }) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/auth/register'),
    );
    request.fields['email'] = email;
    request.fields['password'] = password;
    request.fields['username'] = username;
    request.fields['role'] = role.toString().split('.').last;
    if (fullName != null && fullName.isNotEmpty) {
      request.fields['fullName'] = fullName;
    }

    if (credentialFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('credential', credentialFile.path),
      );
    }

    var response = await request.send().timeout(const Duration(seconds: 30));
    var responseData = await response.stream.bytesToString();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decodedResponse = jsonDecode(responseData);
      if (decodedResponse.containsKey('token')) {
        await setToken(decodedResponse['token']);
      }
      return decodedResponse;
    } else {
      dynamic errorData;
      try {
        errorData = jsonDecode(responseData);
      } catch (_) {}
      final errorMessage = errorData is Map
          ? (errorData['error'] ??
                errorData['message'] ??
                'We encountered an error. Please try again.')
          : 'We encountered an unexpected error. Please check your connection and try again.';
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> _postAnonymous(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl$endpoint'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    return _handleResponse(response);
  }

  Future<void> resendVerificationEmail(String email) async {
    await _postAnonymous('/auth/resend-verification', {'email': email});
  }

  // Forgot password: email → 6-digit code → one-time reset token → new password.

  /// Step 1: emails a 6-digit code to the address the account signed up with.
  Future<void> requestPasswordReset(String email) async {
    await _postAnonymous('/auth/forgot-password', {'email': email});
  }

  /// Step 2: checks the code and returns a short-lived reset token.
  Future<String> verifyPasswordResetOtp(String email, String otp) async {
    final response = await _postAnonymous('/auth/verify-reset-otp', {
      'email': email,
      'otp': otp,
    });
    return response['resetToken'] as String;
  }

  /// Step 3: sets the new password using the token from step 2.
  Future<void> resetPassword(
    String email,
    String resetToken,
    String password,
  ) async {
    await _postAnonymous('/auth/reset-password', {
      'email': email,
      'resetToken': resetToken,
      'password': password,
    });
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

  Future<Workout> createWorkout(
    String name,
    String description,
    List<String> exercises,
  ) async {
    final response = await _post('/workouts', {
      'name': name,
      'description': description,
      'exercises': exercises,
    });
    return Workout.fromJson(response['workout'] as Map<String, dynamic>);
  }

  Future<Workout> updateWorkout(
    String id,
    String name,
    String description,
    List<Map<String, dynamic>> exercises,
  ) async {
    final response = await _patch('/workouts/$id', {
      // The schema field is `title`; `name` is kept for older servers.
      'title': name,
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

  /// Trainer: own templates in "Recently deleted" (deleted by the trainer or
  /// removed by an admin, not yet deleted permanently).
  Future<List<Workout>> getDeletedTrainerWorkouts() async {
    final response = await _get('/workouts/trainer/deleted');
    final List<dynamic> workoutsJson = response['workouts'] ?? [];
    return workoutsJson.map((json) => Workout.fromJson(json)).toList();
  }

  /// Trainer: restore a template they deleted. Members can see it again.
  Future<void> restoreWorkout(String workoutId) async {
    await _post('/workouts/$workoutId/restore', {});
  }

  /// Trainer: remove a deleted template for good.
  Future<void> permanentlyDeleteWorkout(String workoutId) async {
    await _delete('/workouts/$workoutId/permanent');
  }

  Future<List<Map<String, dynamic>>> getAvailableTrainers() async {
    final response = await _get('/workouts/trainers/available');
    final List<dynamic> trainersJson = response['trainers'];
    return trainersJson.map((json) => json as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> getWorkoutsByTrainer(
    String trainerId,
  ) async {
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return {'success': false, 'message': 'No file selected'};
    }
    final file = result.files.first;
    final filename = file.name.isNotEmpty
        ? file.name
        : 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final bytes = file.bytes;
    final path = file.path;
    final mimeType = lookupMimeType(filename) ?? 'video/mp4';
    final parts = mimeType.split('/');
    final contentType = MediaType(
      parts[0],
      parts.length > 1 ? parts[1] : 'mp4',
    );
    MultipartFile mpFile;
    if (bytes != null) {
      mpFile = MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: contentType,
      );
    } else if (path != null) {
      mpFile = await MultipartFile.fromFile(
        path,
        filename: filename,
        contentType: contentType,
      );
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

  /// Moves the video to the trainer's "Recently deleted" (restorable).
  Future<void> deleteVideo(String videoId) async {
    await _delete('/videos/$videoId');
  }

  /// Trainer: own videos in "Recently deleted" (deleted by the trainer or
  /// removed by an admin, not yet deleted permanently).
  Future<List<ExerciseVideo>> getDeletedTrainerVideos() async {
    final response = await _get('/videos/trainer/deleted');
    final List<dynamic> videosJson = response['videos'] ?? [];
    return videosJson.map((json) => ExerciseVideo.fromJson(json)).toList();
  }

  /// Trainer: restore a video they deleted. Members can see it again.
  Future<void> restoreVideo(String videoId) async {
    await _post('/videos/$videoId/restore', {});
  }

  /// Trainer: erase a deleted video and its files for good.
  Future<void> permanentlyDeleteVideo(String videoId) async {
    await _delete('/videos/$videoId/permanent');
  }

  // ============ ADMIN CONTENT MODERATION ============

  /// Admin: all trainer-uploaded videos (public and private).
  /// [status] is 'active', 'deleted' or 'all'.
  Future<Map<String, dynamic>> getAdminVideos({
    String status = 'active',
    String? search,
  }) async {
    final uri = Uri.parse('$baseUrl/videos/admin/all').replace(
      queryParameters: {
        'status': status,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return await _getUri(uri.toString()) as Map<String, dynamic>;
  }

  /// Admin: all trainer-created workouts.
  /// [status] is 'active', 'deleted' or 'all'.
  Future<Map<String, dynamic>> getAdminWorkouts({
    String status = 'active',
    String? search,
  }) async {
    final uri = Uri.parse('$baseUrl/workouts/admin/all').replace(
      queryParameters: {
        'status': status,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return await _getUri(uri.toString()) as Map<String, dynamic>;
  }

  /// Admin: remove an inappropriate video. [reason] (min 10 chars) is
  /// emailed to the trainer.
  Future<Map<String, dynamic>> adminDeleteVideo(
    String videoId, {
    required String reason,
  }) async {
    return await _deleteWithBody('/videos/admin/$videoId', {'reason': reason});
  }

  /// Admin: remove an inappropriate workout. [reason] (min 10 chars) is
  /// emailed to the trainer. Copies assigned to members are hidden too.
  Future<Map<String, dynamic>> adminDeleteWorkout(
    String workoutId, {
    required String reason,
    bool removeAssignedCopies = true,
  }) async {
    return await _deleteWithBody('/workouts/admin/$workoutId', {
      'reason': reason,
      'removeAssignedCopies': removeAssignedCopies,
    });
  }

  /// Admin: undo a moderation removal (not allowed for trainer deletions).
  Future<Map<String, dynamic>> adminRestoreVideo(String videoId) async {
    return await _post('/videos/admin/$videoId/restore', {});
  }

  /// Admin: undo a moderation removal (not allowed for trainer deletions).
  /// Member copies hidden by that removal come back too.
  Future<Map<String, dynamic>> adminRestoreWorkout(String workoutId) async {
    return await _post('/workouts/admin/$workoutId/restore', {});
  }

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
    final uri = Uri.parse(
      '$baseUrl/auth/users',
    ).replace(queryParameters: queryParams);
    return await _getUri(uri.toString()) as Map<String, dynamic>;
  }

  Future<User> updateUser(String userId, Map<String, dynamic> updates) async {
    final response = await _patch('/auth/users/$userId', updates);
    return User.fromJson(response);
  }

  Future<void> deleteUser(String userId) async {
    await _delete('/auth/users/$userId');
  }

  /// Admin: current BMI / calorie cooldown status for a user.
  Future<Map<String, dynamic>> getUserCooldownStatus(String userId) async {
    return await _get('/progress/admin/$userId/cooldown-status')
        as Map<String, dynamic>;
  }

  /// Member: ask an admin to reset the BMI / calorie cooldown (e.g. misclick).
  /// A reset always covers both BMI and calories.
  Future<Map<String, dynamic>> requestCooldownReset({
    required String reason,
  }) async {
    return await _post('/progress/reset-requests', {
      'type': 'both',
      'reason': reason,
    });
  }

  /// Member: latest reset request (or null if none).
  Future<Map<String, dynamic>?> getMyCooldownResetRequest() async {
    final response =
        await _get('/progress/reset-requests/mine') as Map<String, dynamic>;
    return response['request'] as Map<String, dynamic>?;
  }

  /// Member: cancel the pending reset request.
  Future<void> cancelMyCooldownResetRequest() async {
    await _delete('/progress/reset-requests/mine');
  }

  /// Admin: list member reset requests.
  /// [status] is 'pending', 'approved', 'rejected' or 'all'.
  Future<Map<String, dynamic>> getCooldownResetRequests({
    String status = 'pending',
  }) async {
    return await _get('/progress/admin/reset-requests?status=$status')
        as Map<String, dynamic>;
  }

  /// Admin: approve or reject a member reset request.
  Future<Map<String, dynamic>> handleCooldownResetRequest(
    String requestId, {
    required bool approve,
    String? note,
  }) async {
    return await _patch('/progress/admin/reset-requests/$requestId', {
      'action': approve ? 'approve' : 'reject',
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  /// Admin: reset a user's BMI and calorie tracking cooldown. The mistaken
  /// entries are removed from the user's history.
  Future<Map<String, dynamic>> resetUserCooldown(
    String userId, {
    required String reason,
  }) async {
    return await _post('/progress/admin/$userId/reset-cooldown', {
      'type': 'both',
      'reason': reason,
    });
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

  /// Admin: approve or reject a pending trainer. Rejecting deletes the
  /// account, so older servers send no `user` back; that returns null.
  Future<User?> approveTrainer(
    String userId,
    bool isApproved, {
    String? rejectionReason,
  }) async {
    final body = {
      'isApproved': isApproved,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
    };
    final response = await _patch('/auth/users/$userId/approve', body);
    final user = response['user'];
    return user is Map<String, dynamic> ? User.fromJson(user) : null;
  }

  Future<List<dynamic>> getClients() async {
    final response = await _get('/clients');
    return response as List<dynamic>;
  }

  /// Fetches list of approved trainers with bio/feedback for member selection.
  /// New endpoint from admin moderation features. Returns User objects
  /// (bio field populated for visibility before choosing trainer).
  Future<List<User>> getTrainers() async {
    final response = await _get('/clients/trainers');
    final dynamic list = response is Map ? response['trainers'] : response;
    if (list is List) {
      return list
          .map((data) => User.fromJson(data as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<dynamic>> getClientProgress(String clientId) async {
    final response = await _get('/clients/$clientId/progress');
    return response as List<dynamic>;
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

  Future<void> leaveTrainer() async {
    await _post('/member/leave-trainer', {});
  }

  Future<void> submitRating(
    String trainerId,
    int rating,
    String feedback,
  ) async {
    await _post('/ratings', {
      'trainerId': trainerId,
      'rating': rating,
      'feedback': feedback,
    });
  }

  Future<RatingStats> getRatings() async {
    final response = await _get('/ratings');
    return RatingStats.fromJson(response);
  }

  Future<RatingStats> getTrainerRating(String trainerId) async {
    final response = await _get('/ratings/trainer/$trainerId');
    return RatingStats.fromJson(response);
  }

  // Chat methods
  Future<List<Message>> getChatHistory(String partnerId) async {
    final response = await _get('/chat/history/$partnerId');
    if (response is List) {
      return response
          .map((m) => Message.fromJson(m as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<void> markMessagesAsRead(String partnerId) async {
    await _post('/chat/mark-read/$partnerId', {});
  }

  Future<void> reportMessage(String messageId, String reason) async {
    await _post('/chat/$messageId/report', {'reason': reason});
  }

  Future<void> deleteMessage(String messageId) async {
    await _delete('/chat/$messageId');
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final bool emailNotVerified;
  final bool pendingApproval;

  ApiException({
    required this.message,
    required this.statusCode,
    this.emailNotVerified = false,
    this.pendingApproval = false,
  });

  @override
  String toString() {
    return message;
  }
}
