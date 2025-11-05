import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../widgets/info_row.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> user;
  const EditProfilePage({super.key, required this.user});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final api = ApiService("https://ciws.in/flutter_api/");

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _age = TextEditingController();
  final _address = TextEditingController();
  String _gender = "Male";

  File? _imageFile;
  Uint8List? _webImage;
  String? _webImageName;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _name.text = widget.user['name'] ?? "";
    _phone.text = widget.user['phone'] ?? "";
    _age.text = widget.user['age'] ?? "";
    _address.text = widget.user['address'] ?? "";
    _gender = widget.user['gender'] ?? "Male";
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _webImage = bytes;
          _webImageName = picked.name;
        });
      } else {
        setState(() {
          _imageFile = File(picked.path);
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _loading = true);

    final res = await api.updateProfile(
      widget.user['id'].toString(),
      {
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'age': _age.text.trim(),
        'address': _address.text.trim(),
        'gender': _gender,
      },
      imageFile: _imageFile,
      webImage: _webImage,
      webImageName: _webImageName,
    );

    setState(() => _loading = false);

    if (res['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(res['user']));

      if (mounted) {
        setState(() {
          // update widget.user image so avatar refreshes
          widget.user['image'] = res['user']['image'];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully")),
        );
        Navigator.pop(context, res['user']);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? "Update failed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.blue.shade400;
    final bgColor = Colors.grey.shade100;

    // Prepare image URL with cache-busting
    String imageUrl = '';
    if (widget.user['image'] != null &&
        widget.user['image'].toString().isNotEmpty) {
      imageUrl =
          'https://ciws.in/flutter_api/uploads/${widget.user['image']}?ts=${DateTime.now().millisecondsSinceEpoch}';
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Edit Profile"),
        foregroundColor: Colors.white,
        backgroundColor: themeColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 55,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: _webImage != null
                      ? MemoryImage(_webImage!)
                      : _imageFile != null
                          ? FileImage(_imageFile!)
                          : (imageUrl.isNotEmpty
                              ? NetworkImage(imageUrl)
                              : const AssetImage("assets/default_user.png")
                                  as ImageProvider),
                ),
              ),
            ),
            const SizedBox(height: 25),

            // Form Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _name,
                    decoration: InputDecoration(
                      labelText: "Name",
                      labelStyle: TextStyle(color: themeColor),
                      prefixIcon: Icon(Icons.person, color: themeColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: themeColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: "Phone",
                      labelStyle: TextStyle(color: themeColor),
                      prefixIcon: Icon(Icons.phone, color: themeColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: themeColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _age,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Age",
                      labelStyle: TextStyle(color: themeColor),
                      prefixIcon: Icon(Icons.calendar_today, color: themeColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: themeColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _address,
                    decoration: InputDecoration(
                      labelText: "Address",
                      labelStyle: TextStyle(color: themeColor),
                      prefixIcon: Icon(Icons.home, color: themeColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: themeColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    items: const [
                      DropdownMenuItem(value: "Male", child: Text("Male")),
                      DropdownMenuItem(value: "Female", child: Text("Female")),
                      DropdownMenuItem(value: "Other", child: Text("Other")),
                    ],
                    onChanged: (val) => setState(() => _gender = val!),
                    decoration: InputDecoration(
                      labelText: "Gender",
                      labelStyle: TextStyle(color: themeColor),
                      prefixIcon: Icon(Icons.wc, color: themeColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: themeColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  _loading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            onPressed: _saveProfile,
                            child: const Text(
                              "Save Profile",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Your Current Info",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 10),

            // Info Display
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  InfoRow(label: "Name", value: _name.text, icon: Icons.person),
                  InfoRow(label: "Phone", value: _phone.text, icon: Icons.phone),
                  InfoRow(
                      label: "Age", value: _age.text, icon: Icons.calendar_today),
                  InfoRow(
                      label: "Address", value: _address.text, icon: Icons.home),
                  InfoRow(label: "Gender", value: _gender, icon: Icons.wc),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
