import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Payment Methods', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildMethodCard('Cash on Delivery', 'Default Method', Icons.money_rounded, true),
          const SizedBox(height: 16),
          _buildMethodCard('JazzCash', 'Add your account', Icons.account_balance_wallet_rounded, false),
          const SizedBox(height: 16),
          _buildMethodCard('Credit/Debit Card', 'Add a new card', Icons.credit_card_rounded, false),
        ],
      ),
    );
  }

  Widget _buildMethodCard(String title, String subtitle, IconData icon, bool selected) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardNavy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? AppTheme.primaryNeon : Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: selected ? AppTheme.primaryNeon : Colors.white70, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(subtitle, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14)),
              ],
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle_rounded, color: AppTheme.primaryNeon),
        ],
      ),
    );
  }
}
