import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'chat_page.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final api = ApiService("https://ciws.in/flutter_api/");
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  Map<String, dynamic>? _currentUser;
  bool _loading = false;

  /// chat status: outgoing_pending, incoming_pending, accepted, rejected
  final Map<String, String> _chatStatus = {};

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredUsers = List.from(_users));
    } else {
      setState(() {
        _filteredUsers = _users
            .where((u) => (u['name'] ?? "").toString().toLowerCase().contains(query))
            .toList();
      });
    }
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final u = prefs.getString("user");
    if (u != null) {
      _currentUser = jsonDecode(u);
      _fetchUsers();
    }
  }

  Future<void> _fetchUsers() async {
    if (_currentUser == null) return;
    setState(() => _loading = true);

    final list = await api.getUsers();

    // Remove self from list
    _users = list.where((u) => u['id'].toString() != _currentUser!['id'].toString()).toList();
    _filteredUsers = List.from(_users);

    final myId = _currentUser!['id'].toString();

    // Check chat status for each user
    for (var user in _users) {
      final userId = user['id'].toString();
      final result = await api.checkChatStatus(myId, userId);

      // Ensure Map<String,dynamic>
      final Map<String, dynamic> statusMap = Map<String, dynamic>.from(result);

      final status = statusMap['status']?.toString() ?? 'none';
      final senderId = statusMap['sender_id']?.toString();

      if (status == 'accepted') {
        _chatStatus[userId] = 'accepted';
      } else if (status == 'pending') {
        if (senderId == myId) {
          _chatStatus[userId] = 'outgoing_pending'; // I sent request
        } else {
          _chatStatus[userId] = 'incoming_pending'; // They sent request
        }
      } else {
        _chatStatus[userId] = 'rejected';
      }
    }

    setState(() => _loading = false);
  }

  Future<void> _handleChat(Map<String, dynamic> user) async {
    if (_currentUser == null) return;

    final senderId = _currentUser!['id'].toString();
    final receiverId = user['id'].toString();
    final status = _chatStatus[receiverId] ?? 'rejected';

    if (status == 'accepted') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatPage(receiver: user)),
      );
    } else if (status == 'outgoing_pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chat request pending")),
      );
    } else {
      final res = await api.sendChatRequest(senderId, receiverId);
      if (res['success'] == true) {
        _chatStatus[receiverId] = 'outgoing_pending';
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Chat request sent")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? "Failed to send request")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Users & Chat"),
        foregroundColor: Colors.white,
        backgroundColor: const Color.fromARGB(255, 64, 73, 230),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search by name...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? const Center(child: Text("No users found"))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (ctx, i) {
                          final user = _filteredUsers[i];
                          final userId = user['id'].toString();
                          final status = _chatStatus[userId] ?? 'rejected';

                          String imageUrl = '';
                          if (user['image'] != null && user['image'].toString().isNotEmpty) {
                            imageUrl = 'https://ciws.in/flutter_api/uploads/${user['image']}';
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 3,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                radius: 28,
                                backgroundImage: imageUrl.isNotEmpty
                                    ? NetworkImage(imageUrl)
                                    : const AssetImage("assets/default_user.png") as ImageProvider,
                              ),
                              title: Text(user['name'] ?? "Unknown",
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(user['email'] ?? ""),
                              trailing: Builder(builder: (_) {
                                if (status == 'incoming_pending') {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () async {
                                          await api.respondChatRequest(userId, true);
                                          _chatStatus[userId] = 'accepted';
                                          setState(() {});
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        ),
                                        child: const Text("Accept", style: TextStyle(color: Colors.white)),
                                      ),
                                      const SizedBox(width: 6),
                                      ElevatedButton(
                                        onPressed: () async {
                                          await api.respondChatRequest(userId, false);
                                          _chatStatus[userId] = 'rejected';
                                          setState(() {});
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        ),
                                        child: const Text("Reject", style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  );
                                } else if (status == 'accepted') {
                                  return ElevatedButton(
                                    onPressed: () => _handleChat(user),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueAccent,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                                    child: const Text("Chat", style: TextStyle(color: Colors.white)),
                                  );
                                } else if (status == 'outgoing_pending') {
                                  return ElevatedButton(
                                    onPressed: null,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                                    child: const Text("Pending", style: TextStyle(color: Colors.white)),
                                  );
                                } else {
                                  return ElevatedButton(
                                    onPressed: () => _handleChat(user),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color.fromARGB(255, 24, 174, 239),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                                    child: const Text("Send Request", style: TextStyle(color: Colors.white)),
                                  );
                                }
                              }),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
