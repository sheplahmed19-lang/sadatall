import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadat_delivery_merged/app_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Load profile data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileProvider.notifier).loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final profileState = ref.watch(profileProvider);

    // Use auth state captain data as fallback
    final captain = profileState.captain ?? authState.captain;

    if (captain == null && !profileState.isLoading) {
      return const Center(child: Text('لا توجد بيانات الملف الشخصي'));
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(profileProvider.notifier).loadProfile();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (captain != null) ...[
              _buildProfilePhoto(context, captain),
              const SizedBox(height: 24),
              _buildStatsSection(context, profileState),
              const SizedBox(height: 24),
              _buildInfoSection(context, captain),
              const SizedBox(height: 24),
            ],
            _buildActionsSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePhoto(BuildContext context, captain) {
    return GestureDetector(
      onTap: captain.photoUrl != null
          ? () => _showFullScreenImage(context, captain.photoUrl!)
          : null,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 3),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.2),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 60,
          backgroundColor: AppColors.primary.withOpacity(0.1),
          backgroundImage: captain.photoUrl != null
              ? NetworkImage(captain.photoUrl!)
              : null,
          child: captain.photoUrl == null
              ? const Icon(Icons.person, size: 70, color: AppColors.primary)
              : null,
        ),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, ProfileState profileState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                'الإحصائيات',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            if (profileState.isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  _buildStatItem(
                    context,
                    'الطلبات المكتملة',
                    profileState.stats?.totalOrders.toString() ?? '0',
                    Icons.check_circle,
                    AppColors.success,
                  ),
                  _buildStatItem(
                    context,
                    'إجمالي الأرباح',
                    profileState.stats?.totalEarnings.toString() ?? '0',
                    Icons.assignment,
                    AppColors.primary,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, captain) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'المعلومات الشخصية',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (context) =>
                            EditProfileScreen(captain: captain),
                      ),
                    );
                    if (result == true) {
                      ref.read(profileProvider.notifier).loadProfile();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('اسم المستخدم:', captain.userName),
            _buildInfoRow('البريد الإلكتروني:', captain.email),
            _buildInfoRow('رقم الهاتف:', captain.phoneNumber),
            if (captain.nationalId != null)
              _buildInfoRow('رقم الهوية:', captain.nationalId!),
            if (captain.workingHoursStart != null ||
                captain.workingHoursEnd != null)
              _buildInfoRow(
                'ساعات العمل:',
                captain.workingHoursStart != null &&
                        captain.workingHoursEnd != null
                    ? '${captain.workingHoursStart} - ${captain.workingHoursEnd}'
                    : captain.workingHoursStart ??
                          captain.workingHoursEnd ??
                          'غير محدد',
              ),
            if (captain.currentNumberOfOrders != null)
              _buildInfoRow(
                'الطلبات الحالية:',
                '${captain.currentNumberOfOrders}',
              ),
            if (captain.maxCurrentOrders != null)
              _buildInfoRow(
                'الحد الأقصى للطلبات:',
                '${captain.maxCurrentOrders}',
              ),
            if (captain.earningSinceLastActivation != null)
              _buildInfoRow(
                'الأرباح منذ آخر تفعيل:',
                AppUtils.formatPrice(captain.earningSinceLastActivation!),
              ),
            if (captain.maxEarningsSinceLastActivation != null)
              _buildInfoRow(
                'الحد الأقصى للأرباح:',
                AppUtils.formatPrice(captain.maxEarningsSinceLastActivation!),
              ),
            _buildInfoRow(
              'تاريخ التسجيل:',
              AppUtils.formatDateTime(captain.createdAt.toLocal()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                'الإعدادات',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                ref.watch(themeModeProvider) == ThemeMode.dark
                    ? Icons.dark_mode
                    : Icons.light_mode,
                color: AppColors.onSurfaceVariant,
              ),
              title: const Text(
                'الوضع الليلي',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                'تفعيل المظهر الداكن للتطبيق',
                style: TextStyle(fontSize: 14),
              ),
              value: ref.watch(themeModeProvider) == ThemeMode.dark,
              onChanged: (value) =>
                  ref.read(themeModeProvider.notifier).setDarkMode(value),
            ),
            const SizedBox(height: 12),
            CustomButton(
              text: 'تسجيل الخروج',
              onPressed: () => _showLogoutDialog(context),
              type: ButtonType.outlined,
              icon: Icons.logout,
              textColor: AppColors.error,
            ),
            const SizedBox(height: 12),
            CustomButton(
              text: 'حذف الحساب',
              onPressed: () => _showDeleteAccountDialog(context),
              type: ButtonType.outlined,
              icon: Icons.delete_forever,
              textColor: AppColors.error,
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('حذف الحساب'),
          content: const Text(
            'هل أنت متأكد؟ سيتم حذف جميع بياناتك نهائياً ولا يمكن التراجع عن هذا الإجراء.',
          ),
          actions: [
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('حذف'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                await ref.read(authStateProvider.notifier).deleteAccount();

                final error = ref.read(authStateProvider).error;
                if (error != null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error)));
                  }
                  return;
                }

                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('selected_app_mode');

                appModeNotifier.value = null;
              },
            ),
          ],
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل تريد تسجيل الخروج من التطبيق؟'),
          actions: [
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('تأكيد'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                await ref.read(authStateProvider.notifier).logout();

                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('selected_app_mode');

                appModeNotifier.value = null;
              },
            ),
          ],
        );
      },
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 48,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
