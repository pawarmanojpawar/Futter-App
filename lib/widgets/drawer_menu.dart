import 'package:flutter/material.dart';
import '../pages/home_page.dart';
import '../pages/user_list_page.dart';
import '../pages/user_table_page.dart';

class DrawerMenu extends StatelessWidget {
  final VoidCallback onLogout;
  final String userName;
  final String userImage; // URL or local asset
  const DrawerMenu({
    super.key,
    required this.onLogout,
    required this.userName,
    required this.userImage,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.grey[100],
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue, // solid color instead of gradient
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(0),
                bottomRight: Radius.circular(0),
              ),
            ),
            accountName: Text(
  userName.isNotEmpty
      ? '${userName[0].toUpperCase()}${userName.substring(1).toLowerCase()}'
      : '',
  style: const TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 18,
  ),
),
            accountEmail: null, // remove email if not needed
            currentAccountPicture: CircleAvatar(
              backgroundImage: NetworkImage(userImage),
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          _buildDrawerItem(
            context,
            icon: Icons.home,
            label: "Home",
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomePage()),
              );
            },
          ),
          _buildDrawerItem(
            context,
            icon: Icons.people,
            label: "User List & Chat",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserListPage()),
              );
            },
          ),
          _buildDrawerItem(
            context,
            icon: Icons.table_chart,
            label: "User Table",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserTablePage()),
              );
            },
          ),
          const Spacer(),
          Divider(color: Colors.grey.shade400),
          _buildDrawerItem(
            context,
            icon: Icons.logout,
            label: "Logout",
            iconColor: Colors.red,
            textColor: Colors.red,
            onTap: onLogout,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = Colors.blue,
    Color textColor = Colors.black87,
  }) {
    return ListTile(
      leading: Container(
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        label,
        style: TextStyle(fontSize: 16, color: textColor, fontWeight: FontWeight.w500),
      ),
      hoverColor: Colors.blue.shade50,
      onTap: onTap,
    );
  }
}
