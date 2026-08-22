import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../theme/app_theme.dart';

/// Guards actions that only make sense for a signed-in user (placing a
/// special order, sending a package, checking out a cart, ...).
///
/// Instead of dropping a guest into a form they can never submit, this asks
/// them to sign in first and returns whether they ended up authenticated.
class AuthGate {
  const AuthGate._();

  /// Returns true when the user is already signed in, or signed in through
  /// the sheet/login screen this call opened.
  ///
  /// [actionLabel] names what the user was trying to do, so the prompt can
  /// explain why the login is needed (e.g. 'لإرسال طرد').
  static Future<bool> ensureLoggedIn(
    BuildContext context, {
    String? actionLabel,
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.isAuthenticated) {
      return true;
    }

    final wantsLogin = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LoginRequiredSheet(actionLabel: actionLabel),
    );

    if (wantsLogin != true || !context.mounted) {
      return false;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );

    if (!context.mounted) {
      return false;
    }

    return authProvider.isAuthenticated;
  }
}

class _LoginRequiredSheet extends StatelessWidget {
  const _LoginRequiredSheet({this.actionLabel});

  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                color: AppTheme.primaryColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'تسجيل الدخول مطلوب',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              actionLabel == null
                  ? 'من فضلك سجل الدخول للمتابعة.'
                  : 'من فضلك سجل الدخول $actionLabel.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'تسجيل الدخول',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ليس الآن'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
