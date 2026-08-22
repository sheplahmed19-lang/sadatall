import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sadat_delivery_merged/app_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../screens/complaints/complaints_screen.dart';
import '../profile/profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Notification settings management removed as users manage notifications outside the app
  }

  Future<void> _deleteAccount() async {
    final confirmed = await _showConfirmDialog(
      'حذف الحساب',
      'هل أنت متأكد؟ سيتم حذف جميع بياناتك نهائياً ولا يمكن التراجع عن هذا الإجراء.',
    );

    if (confirmed) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.deleteAccount();

      if (!mounted) return;

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authProvider.errorMessage ?? 'تعذر حذف الحساب')),
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selected_app_mode');

      appModeNotifier.value = null;
    }
  }

  Future<void> _logout() async {
    final confirmed = await _showConfirmDialog(
      'تسجيل الخروج',
      'هل أنت متأكد من تسجيل الخروج من الحساب؟',
    );

    if (confirmed) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selected_app_mode');
      
      appModeNotifier.value = null;
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await _showConfirmDialog(
      'مسح التخزين المؤقت',
      'هل تريد مسح جميع البيانات المؤقتة؟ قد يؤدي هذا إلى إبطاء التطبيق مؤقتاً.',
    );

    if (confirmed) {
      // Clear cache implementation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم مسح التخزين المؤقت بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('تأكيد'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _navigateToComplaints() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ComplaintsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الإعدادات',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileSection(),
            const SizedBox(height: 16),
            _buildAppearanceSection(),
            const SizedBox(height: 16),
            _buildDataSection(),
            const SizedBox(height: 16),
            _buildSupportSection(),
            const SizedBox(height: 16),
            _buildAboutSection(),
            const SizedBox(height: 16),
            _buildDangerZone(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الملف الشخصي',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSettingTile(
              icon: Icons.person,
              title: 'عرض الملف الشخصي',
              subtitle: 'إدارة معلومات الحساب',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  //   final authProvider = Provider.of<AuthProvider>(context);
  //   final vendor = authProvider.vendor;

  //   return Card(
  //     elevation: 2,
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //     child: Padding(
  //       padding: const EdgeInsets.all(16),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           const Text('الملف الشخصي',
  //               style: TextStyle(
  //                 fontSize: 18,
  //                 fontWeight: FontWeight.bold,
  //               )),
  //           const SizedBox(height: 16),
  //           Row(
  //             children: [
  //               CircleAvatar(
  //                 radius: 30,
  //                 backgroundColor: Colors.blue[100],
  //                 backgroundImage: vendor?.image != null
  //                     ? NetworkImage(vendor!.image!)
  //                     : null,
  //                 child: vendor?.image == null
  //                     ? Icon(Icons.store, size: 30, color: Colors.blue[700])
  //                     : null,
  //               ),
  //               const SizedBox(width: 16),
  //               Expanded(
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text(vendor?.vendorName ?? 'اسم المطعم',
  //                         style: const TextStyle(
  //                           fontSize: 16,
  //                           fontWeight: FontWeight.bold,
  //                         )),
  //                     const SizedBox(height: 4),
  //                     Text(
  //                       vendor?.contactNumber ?? 'رقم الهاتف',
  //                       style: TextStyle(
  //                         fontSize: 14,
  //                         color: Colors.grey[600],
  //                       ),
  //                       textDirection: TextDirection.ltr,
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //               IconButton(
  //                 icon: const Icon(Icons.edit),
  //                 onPressed: () {
  //                   Navigator.push(
  //                     context,
  //                     MaterialPageRoute(
  //                       builder: (context) => const EditProfileScreen(),
  //                     ),
  //                   );
  //                 },
  //               ),
  //             ],
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildAppearanceSection() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المظهر',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                // grey[700] is near-black — the dark-mode toggle's own icon
                // was the hardest thing to see once dark mode was on.
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              title: const Text(
                'الوضع الليلي',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                'تفعيل المظهر الداكن للتطبيق',
                style: TextStyle(fontSize: 14),
              ),
              value: themeProvider.isDarkMode,
              onChanged: (value) => themeProvider.setDarkMode(value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'البيانات والتخزين',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSettingTile(
              icon: Icons.cached,
              title: 'مسح التخزين المؤقت',
              subtitle: 'مسح البيانات المؤقتة لتحرير مساحة',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _clearCache,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الدعم',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSettingTile(
              icon: Icons.feedback,
              title: 'الشكاوى والاقتراحات',
              subtitle: 'إرسال شكوى أو اقتراح',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _navigateToComplaints,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'حول التطبيق',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSettingTile(
              icon: Icons.info,
              title: 'معلومات التطبيق',
              subtitle: 'الإصدار 1.0.0',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showAppInfo(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZone() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المنطقة الخطرة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingTile(
              icon: Icons.logout,
              title: 'تسجيل الخروج',
              subtitle: 'تسجيل الخروج من الحساب الحالي',
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.red,
              ),
              onTap: _logout,
              titleColor: Colors.red,
            ),
            const Divider(),
            _buildSettingTile(
              icon: Icons.delete_forever,
              title: 'حذف الحساب',
              subtitle: 'حذف حسابك وجميع بياناتك نهائياً',
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.red,
              ),
              onTap: _deleteAccount,
              titleColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: titleColor ?? Colors.grey[700]),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: titleColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
      ),
      trailing: trailing,
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  void _showAppInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('معلومات التطبيق'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تعالالي لخدمات التوصيل',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('الإصدار: 1.0.0'),
            SizedBox(height: 8),
            Text('تطبيق تعالالي لخدمات التوصيل '),
            SizedBox(height: 16),
            Text(
              '© 2026 جميع الحقوق محفوظة',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}
