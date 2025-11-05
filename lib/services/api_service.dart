import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' show basename;

class ApiService {
  final String base;
  ApiService(this.base);

  Duration timeout = const Duration(seconds: 20);

  /// -------------------- LOGIN --------------------
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$base/login.php');
    final resp = await http
        .post(url, body: {'email': email, 'password': password})
        .timeout(timeout);
    return _parseResponse(resp);
  }

  /// -------------------- SIGNUP --------------------
  Future<Map<String, dynamic>> signup(
      String name, String email, String password) async {
    final url = Uri.parse('$base/signup.php');
    final resp = await http
        .post(url, body: {'name': name, 'email': email, 'password': password})
        .timeout(timeout);
    return _parseResponse(resp);
  }

  /// -------------------- GET USERS --------------------
  Future<List<Map<String, dynamic>>> getUsers() async {
    final url = Uri.parse('$base/get_users.php');
    final resp = await http.get(url).timeout(timeout);
    final data = _parseResponse(resp);
    if (data['success'] == true && data['users'] != null) {
      return List<Map<String, dynamic>>.from(data['users']);
    }
    return [];
  }

  /// -------------------- SEND MESSAGE (TEXT OR FILE) --------------------
  Future<Map<String, dynamic>> sendChatMessage({
    required String senderId,
    required String receiverId,
    String? message,
    File? file,
    Uint8List? webBytes,
    String? webFileName,
  }) async {
    try {
      final uri = Uri.parse('$base/send_message.php');
      final request = http.MultipartRequest('POST', uri);

      // Required fields
      request.fields['sender_id'] = senderId;
      request.fields['receiver_id'] = receiverId;

      // Optional text message
      if (message != null && message.trim().isNotEmpty) {
        request.fields['message'] = message.trim();
      }

      // Optional file upload
      if (kIsWeb) {
        if (webBytes != null && webFileName != null && webBytes.isNotEmpty) {
          request.files.add(http.MultipartFile.fromBytes(
            'file',
            webBytes,
            filename: webFileName,
          ));
          print("Web file added: $webFileName, size: ${webBytes.length}");
        } else {
          print("No web file to upload.");
        }
      } else {
        if (file != null && file.path.isNotEmpty) {
          final multipartFile = await http.MultipartFile.fromPath(
            'file',
            file.path,
            filename: basename(file.path),
          );
          request.files.add(multipartFile);
          print("Mobile file added: ${file.path}, size: ${await file.length()}");
        } else {
          print("No mobile file to upload.");
        }
      }

      print("Request fields: ${request.fields}");
      print("Request files: ${request.files.map((f) => f.filename).toList()}");

      final streamed = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamed);

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      return _parseResponse(response);
    } catch (e) {
      print("sendChatMessage error: $e");
      return {"success": false, "message": "sendChatMessage error: $e"};
    }
  }

  /// -------------------- GET MESSAGES --------------------
  Future<List<Map<String, dynamic>>> getMessages(
      String senderId, String receiverId) async {
    final url = Uri.parse(
        '$base/get_messages.php?sender_id=$senderId&receiver_id=$receiverId');
    final resp = await http.get(url).timeout(timeout);
    final data = _parseResponse(resp);
    if (data['success'] == true && data['messages'] != null) {
      return List<Map<String, dynamic>>.from(data['messages']);
    }
    return [];
  }

  /// -------------------- UPDATE PROFILE --------------------
  Future<Map<String, dynamic>> updateProfile(
    String id,
    Map<String, String> data, {
    File? imageFile,
    Uint8List? webImage,
    String? webImageName,
  }) async {
    try {
      final url = Uri.parse('$base/update_profile.php');
      final request = http.MultipartRequest("POST", url);

      request.fields['id'] = id;
      request.fields.addAll(data);

      if (kIsWeb && webImage != null && webImageName != null) {
        request.files.add(
          http.MultipartFile.fromBytes('image', webImage,
              filename: webImageName),
        );
      } else if (!kIsWeb && imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          filename: basename(imageFile.path),
        ));
      }

      final streamed = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamed);
      return _parseResponse(response);
    } catch (e) {
      return {"success": false, "message": "Profile update failed: $e"};
    }
  }

  /// -------------------- CHAT REQUEST --------------------
  Future<Map<String, dynamic>> checkChatStatus(
      String myId, String otherId) async {
    try {
      final response = await http
          .get(Uri.parse(
              '$base/chat_status.php?sender_id=$myId&receiver_id=$otherId'))
          .timeout(timeout);
      return _parseResponse(response);
    } catch (e) {
      return {
        'status': 'none',
        'sender_id': null,
        'receiver_id': null,
        'error': e.toString()
      };
    }
  }

  Future<Map<String, dynamic>> sendChatRequest(
      String senderId, String receiverId) async {
    final url = Uri.parse('$base/chat_request.php');
    final resp = await http
        .post(url, body: {'sender_id': senderId, 'receiver_id': receiverId})
        .timeout(timeout);
    return _parseResponse(resp);
  }

  Future<Map<String, dynamic>> respondChatRequest(
      String senderId, bool accept) async {
    final url = Uri.parse('$base/chat_respond.php');
    final resp = await http
        .post(url, body: {'sender_id': senderId, 'accept': accept ? '1' : '0'})
        .timeout(timeout);
    return _parseResponse(resp);
  }

  /// -------------------- HELPER --------------------
  Map<String, dynamic> _parseResponse(http.Response resp) {
    if (resp.statusCode != 200) {
      return {
        'success': false,
        'message': 'Server error: ${resp.statusCode}',
        'body': resp.body
      };
    }
    try {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      return {
        'success': false,
        'message': 'Invalid JSON',
        'body': resp.body,
        'error': e.toString()
      };
    }
  }
}
