import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class ChatPage extends StatefulWidget {
  final Map<String, dynamic> receiver;
  const ChatPage({super.key, required this.receiver});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final api = ApiService("https://ciws.in/flutter_api/");
  final _msgCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _msgCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final u = prefs.getString("user");
    if (u != null) {
      _user = jsonDecode(u);
      await _loadMessages();
      _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
        await _loadMessages();
      });
    }
    setState(() => _loading = false);
  }

  Future<void> _loadMessages() async {
    if (_user == null) return;
    try {
      final data = await api.getMessages(
        _user!['id'].toString(),
        widget.receiver['id'].toString(),
      );
      setState(() => _messages = data);

      if (_scrollController.hasClients) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        });
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    if (_msgCtrl.text.trim().isEmpty || _user == null) return;

    final msgText = _msgCtrl.text.trim();
    _msgCtrl.clear();

    final res = await api.sendChatMessage(
      senderId: _user!['id'].toString(),
      receiverId: widget.receiver['id'].toString(),
      message: msgText,
    );

    if (res['success'] == true) {
      await _loadMessages();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? "Failed to send message")),
      );
    }
  }

  Future<void> _sendFile() async {
    if (_user == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null) return;

    File? file;
    Uint8List? webBytes;
    String? webFileName;

    if (kIsWeb) {
      webBytes = result.files.single.bytes;
      webFileName = result.files.single.name;
      if (webBytes == null || webBytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No file selected or empty file")),
        );
        return;
      }
    } else {
      final path = result.files.single.path;
      if (path != null && path.isNotEmpty) {
        file = File(path);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No file selected")),
        );
        return;
      }
    }

    final res = await api.sendChatMessage(
      senderId: _user!['id'].toString(),
      receiverId: widget.receiver['id'].toString(),
      file: file,
      webBytes: webBytes,
      webFileName: webFileName,
    );

    if (res['success'] == true) {
      await _loadMessages();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? "Failed to send file")),
      );
    }
  }

  String formatMessageTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return "";
    final dt = DateTime.tryParse(dateTimeStr);
    if (dt == null) return dateTimeStr;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(dt.year, dt.month, dt.day);

    if (msgDate == today) {
      return DateFormat.jm().format(dt);
    } else if (msgDate == today.subtract(const Duration(days: 1))) {
      return "Yesterday, ${DateFormat.jm().format(dt)}";
    } else if (now.difference(dt).inDays < 7) {
      return "${DateFormat.E().format(dt)}, ${DateFormat.jm().format(dt)}";
    } else {
      return DateFormat('dd/MM/yyyy, hh:mm a').format(dt);
    }
  }

  bool _isImage(String? url) {
    if (url == null) return false;
    final lower = url.toLowerCase();
    return lower.endsWith(".png") ||
        lower.endsWith(".jpg") ||
        lower.endsWith(".jpeg") ||
        lower.endsWith(".gif") ||
        lower.endsWith(".webp");
  }

  String _fullFileUrl(String? fileUrl) {
    if (fileUrl == null) return "";
    if (fileUrl.startsWith("http")) return fileUrl;
    return "https://ciws.in/flutter_api/$fileUrl";
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(_fullFileUrl(url));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot open file")),
      );
    }
  }

  Widget _chatFileWidget(String? fileUrl) {
  if (fileUrl == null || fileUrl.isEmpty) return const SizedBox.shrink();

  final fullUrl = _fullFileUrl(fileUrl);
  final isImageFile = _isImage(fullUrl);
  final fileName = Uri.parse(fullUrl).pathSegments.last;

  if (isImageFile) {
    // WhatsApp-style image message (no download icon)
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            child: InteractiveViewer(
              child: Image.network(
                fullUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image, size: 50),
              ),
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
          child: Image.network(
            fullUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image, size: 50),
          ),
        ),
      ),
    );
  } else {
    // Non-image file (show download icon)
    return GestureDetector(
      onTap: () => _openFile(fileUrl),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file, color: Colors.black54),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                fileName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.download, color: Colors.blueAccent),
          ],
        ),
      ),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return const Scaffold(
        body: Center(child: Text("User not found")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 64, 73, 230),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                widget.receiver['name'][0].toUpperCase(),
                style: const TextStyle(color: Color.fromARGB(255, 17, 76, 177)),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.receiver['name'],
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text("No messages yet"))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = _messages[i];
                      final isMe = msg['sender_id'].toString() == _user!['id'].toString();
                      final isRead = msg['read_status'] == 1 || msg['is_read'] == 1;
                      final fileUrl = msg['file_url'];
                      final hasFile = fileUrl != null && fileUrl != "";

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            gradient: isMe
                                ? const LinearGradient(
                                    colors: [Colors.blueAccent, Colors.lightBlueAccent])
                                : const LinearGradient(
                                    colors: [Color(0xFFBAF2CF), Color(0xFFCFFFD2)]),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(isMe ? 16 : 0),
                              topRight: Radius.circular(isMe ? 0 : 16),
                              bottomLeft: const Radius.circular(16),
                              bottomRight: const Radius.circular(16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hasFile) _chatFileWidget(fileUrl),
                              if (msg['message'] != null && msg['message'] != "")
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    msg['message'] ?? "",
                                    style: TextStyle(
                                      color: isMe ? Colors.white : Colors.black87,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    formatMessageTime(msg['created_at']),
                                    style: TextStyle(
                                      color: isMe ? Colors.white70 : Colors.black54,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  if (isMe)
                                    Icon(
                                      isRead ? Icons.done_all : Icons.done,
                                      size: 14,
                                      color: isRead ? Colors.lightBlue : Colors.white70,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _sendFile,
                    icon: const Icon(Icons.attach_file, color: Colors.blueAccent),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TextField(
                        controller: _msgCtrl,
                        decoration: const InputDecoration(
                          hintText: "Type a message",
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
