import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Settings', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSwitch('Push Notifications', true),
          const Divider(color: Colors.white10),
          _buildSwitch('Email Notifications', false),
          const Divider(color: Colors.white10),
          _buildSwitch('Location Services', true),
          const Divider(color: Colors.white10),
          ListTile(
            title: Text('Language', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16)),
            trailing: Text('English / Urdu', style: GoogleFonts.outfit(color: AppTheme.primaryNeon, fontSize: 14)),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch(String title, bool value) {
    return SwitchListTile(
      title: Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16)),
      value: value,
      onChanged: (v) {},
      activeColor: AppTheme.primaryNeon,
      contentPadding: EdgeInsets.zero,
    );
  }
}
