import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final bool showMenuIcon;
  final bool showProfileIcon;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final String? title;
  final VoidCallback? onProfileTap;

  const CustomAppBar(
      {super.key,
      this.showBackButton = false,
      this.showMenuIcon = true,
      this.showProfileIcon = true,
      this.actions,
      this.onBack,
      this.title,
      this.onProfileTap});

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(80);
}

class _CustomAppBarState extends State<CustomAppBar> {
  String? _profilePhotoPath;
  String? _profilePhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadProfilePhoto();
  }

  Future<void> _loadProfilePhoto() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _profilePhotoPath = prefs.getString('profile_photo_path');
      _profilePhotoUrl = prefs.getString('profile_photo_url');
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF212121),
      elevation: 0,
      centerTitle: true,
      leading: widget.showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: widget.onBack ?? () => Navigator.pop(context),
            )
          : (widget.showProfileIcon
              ? Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: GestureDetector(
                    onTap: widget.onProfileTap ?? () {
                      Navigator.pushNamed(context, '/profile');
                    },
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: _profilePhotoUrl != null
                          ? NetworkImage(_profilePhotoUrl!)
                          : (_profilePhotoPath != null
                              ? FileImage(File(_profilePhotoPath!)) as ImageProvider
                              : null),
                      child: (_profilePhotoUrl == null && _profilePhotoPath == null)
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                  ),
                )
              : null),
      title: Text(
        widget.title ?? 'CHOLA CABS',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      actions: widget.actions ??
          (widget.showMenuIcon
              ? [
                  Builder(
                    builder: (context) => GestureDetector(
                      onTap: () => Scaffold.of(context).openEndDrawer(),
                      child:
                          const Icon(Icons.menu, color: Colors.white, size: 28),
                    ),
                  ),
                  const SizedBox(width: 16),
                ]
              : null),
    );
  }
}
