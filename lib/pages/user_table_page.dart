import 'package:flutter/material.dart';
import '../services/api_service.dart';

class UserTablePage extends StatefulWidget {
  const UserTablePage({super.key});

  @override
  State<UserTablePage> createState() => _UserTablePageState();
}

class _UserTablePageState extends State<UserTablePage> {
  final api = ApiService("https://ciws.in/flutter_api/");
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _loading = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _loading = true);
    final list = await api.getUsers();
    setState(() {
      _users = list;
      _filteredUsers = list; // initially show all
      _loading = false;
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        final name = (user['name'] ?? '').toString().toLowerCase();
        final phone = (user['phone'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();

        return name.contains(query) || phone.contains(query) || email.contains(query);
      }).toList();
    });
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    (user['name'] ?? '-').isNotEmpty
                        ? (user['name'][0]).toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  user['name'] ?? '-',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              runSpacing: 8,
              spacing: 16,
              children: [
                _infoItem("ID", user['id'].toString()),
                _infoItem("Email", user['email'] ?? "-"),
                _infoItem("Phone", user['phone'] ?? "-"),
                _infoItem("Age", user['age']?.toString() ?? "-"),
                _infoItem("Gender", user['gender'] ?? "-"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(String title, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "$title: ",
          style:
              const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        Text(value, style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Users List"),
        backgroundColor: const Color.fromARGB(255, 64, 73, 230),
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 🔍 Search bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search by name, phone, or email...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? const Center(child: Text("No users found"))
                    : RefreshIndicator(
                        onRefresh: _fetchUsers,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            return _buildUserCard(_filteredUsers[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
