import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../providers/achievement_provider.dart';
import '../providers/ai_chat_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/app_locale_controller.dart';
import '../providers/growth_progress_provider.dart';
import '../providers/health_data_provider.dart';
import '../providers/meal_analysis_provider.dart';
import '../providers/pet_profile_provider.dart';
import '../providers/purchase_provider.dart';
import '../providers/vaccine_reminder_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/entrance_motion.dart';
import '../widgets/paw_coin_badge.dart';
import '../widgets/sketch_app_bar.dart';
import '../widgets/user_avatar.dart';
import 'language_settings_screen.dart';
import 'legal_document_screen.dart';
import 'login_screen.dart';
import 'store_screen.dart';
import 'user_profile_screen.dart';

/// Settings screen with account summary, legal pages, and account management.
class SettingsScreen extends StatelessWidget {
  final int animationTrigger;

  const SettingsScreen({super.key, this.animationTrigger = 0});

  @override
  Widget build(BuildContext context) {
    final purchaseProvider = context.watch<PurchaseProvider>();
    final authProvider = context.watch<AuthProvider>();
    final localeController = context.watch<AppLocaleController>();
    final user = authProvider.user;

    return Scaffold(
      appBar: SketchAppBar(title: context.tr('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EntranceMotion(
            trigger: '${animationTrigger}_hero',
            child: _AccountHero(
              username: user?.username ?? context.tr('Pet Parent'),
              userId: user?.userId ?? context.tr('Unavailable'),
              avatarPath: user?.avatarPath ?? '',
              accountLabel: context.tr('Account'),
              editLabel: context.tr('Edit'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserProfileScreen()),
              ),
            ),
          ),
          const SizedBox(height: 20),
          EntranceMotion(
            trigger: '${animationTrigger}_account',
            delay: const Duration(milliseconds: 60),
            child: _SettingsSection(
              title: context.tr('Account'),
              items: [
                _SettingsItem(
                  icon: Icons.account_circle,
                  title: context.tr('My Profile'),
                  subtitle: context.tr('Update your username and avatar'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UserProfileScreen(),
                    ),
                  ),
                ),
                Semantics(
                  identifier: 'settings_store_item',
                  child: _SettingsItem(
                    icon: Icons.store,
                    title: context.tr('Store'),
                    subtitle: context.tr('Get more PawCoins'),
                    trailing: PawCoinBadge(
                      balance: purchaseProvider.balance,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StoreScreen()),
                      ),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StoreScreen()),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          EntranceMotion(
            trigger: '${animationTrigger}_preferences',
            delay: const Duration(milliseconds: 90),
            child: _SettingsSection(
              title: context.tr('App Preferences'),
              items: [
                _SettingsItem(
                  icon: Icons.language_rounded,
                  title: context.tr('Language'),
                  subtitle:
                      '${_nativeLanguageLabel(localeController.locale)} · ${context.tr('Switch the language used across the app')}',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LanguageSettingsScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          EntranceMotion(
            trigger: '${animationTrigger}_legal',
            delay: const Duration(milliseconds: 120),
            child: _SettingsSection(
              title: context.tr('Legal'),
              items: [
                _SettingsItem(
                  icon: Icons.description_outlined,
                  title: context.tr('Terms of Service'),
                  subtitle: context.tr('View the current agreement'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LegalDocumentScreen(
                        title: context.tr('Terms of Service'),
                        initialUrl:
                            'https://api.vymra.uk/legal/terms_of_service.html',
                      ),
                    ),
                  ),
                ),
                _SettingsItem(
                  icon: Icons.privacy_tip_outlined,
                  title: context.tr('Privacy Policy'),
                  subtitle: context.tr('Learn how your data is handled'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LegalDocumentScreen(
                        title: context.tr('Privacy Policy'),
                        initialUrl:
                            'https://api.vymra.uk/legal/privacy_policy.html',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          EntranceMotion(
            trigger: '${animationTrigger}_actions',
            delay: const Duration(milliseconds: 180),
            child: _SettingsSection(
              title: context.tr('Account Actions'),
              items: [
                _SettingsItem(
                  icon: Icons.logout,
                  title: context.tr('Log Out'),
                  titleColor: AppColors.error,
                  onTap: () => _confirmLogout(context),
                ),
                _SettingsItem(
                  icon: Icons.delete_forever,
                  title: context.tr('Delete Account'),
                  titleColor: AppColors.error,
                  onTap: () => _confirmDeleteAccount(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('Log Out?'), style: AppTextStyles.headline),
        content: Text(
          context.tr('Are you sure you want to log out?'),
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(context.tr('Log Out')),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          context.tr('Delete Account?'),
          style: AppTextStyles.headline,
        ),
        content: Text(
          context.tr(
            'This action cannot be undone. All your data will be permanently deleted.',
          ),
          style: AppTextStyles.body.copyWith(color: AppColors.error),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              debugPrint('[DELETE_ACCOUNT] User confirmed account deletion');
              final AuthProvider authProvider = context.read<AuthProvider>();
              final bool deleted = await authProvider.deleteAccount();
              debugPrint('[DELETE_ACCOUNT] deleteAccount returned: $deleted');

              if (context.mounted) {
                debugPrint('[DELETE_ACCOUNT] Resetting all providers...');
                context.read<PetProfileProvider>().reset();
                context.read<HealthDataProvider>().reset();
                context.read<VaccineReminderProvider>().reset();
                context.read<GrowthProgressProvider>().reset();
                context.read<MealAnalysisProvider>().reset();
                context.read<AiChatProvider>().reset();
                context.read<AchievementProvider>().reset();
                context.read<PurchaseProvider>().reset();
                debugPrint('[DELETE_ACCOUNT] All providers reset');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );
  }

  String _nativeLanguageLabel(Locale locale) {
    switch (locale.languageCode) {
      case 'hi':
        return 'हिन्दी';
      case 'es':
        return 'Español';
      case 'fr':
        return 'Français';
      case 'ar':
        return 'العربية';
      default:
        return 'English';
    }
  }
}

class _AccountHero extends StatelessWidget {
  final String username;
  final String userId;
  final String avatarPath;
  final String accountLabel;
  final String editLabel;
  final VoidCallback onTap;

  const _AccountHero({
    required this.username,
    required this.userId,
    required this.avatarPath,
    required this.accountLabel,
    required this.editLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              Colors.white.withValues(alpha: 0.98),
              AppColors.accent.withValues(alpha: 0.08),
              AppColors.sky.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.sketchInk.withValues(alpha: 0.12),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.secondary.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            UserAvatar(avatarPath: avatarPath, radius: 32, iconSize: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(accountLabel, style: AppTextStyles.label),
                  const SizedBox(height: 6),
                  Text(
                    username,
                    style: AppTextStyles.headline.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(userId, style: AppTextStyles.caption),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.sketchInk.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    editLabel,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: AppColors.primary, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> items;

  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.title),
        const SizedBox(height: 12),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.98),
                    AppColors.accent.withValues(alpha: 0.08),
                    AppColors.sky.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.sketchInk.withValues(alpha: 0.12),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(children: items),
            ),
            Positioned(
              top: -12,
              left: 20,
              child: Transform.rotate(
                angle: -0.18,
                child: Container(
                  width: 22,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.sketchInk.withValues(alpha: 0.2),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.sketchInk.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.attach_file_rounded,
                    size: 16,
                    color: AppColors.sketchInk,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.sketchInk.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.sketchInk.withValues(alpha: 0.08),
                ),
              ),
              child: Icon(icon, color: titleColor ?? AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: AppTextStyles.caption),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textDisabled,
                ),
          ],
        ),
      ),
    );
  }
}
