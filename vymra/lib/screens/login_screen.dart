import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/purchase_provider.dart';
import '../services/global_logo_service.dart';
import '../theme/app_theme.dart';
import '../utils/debug_logger.dart';
import '../widgets/gradient_button.dart';
import 'legal_document_screen.dart';
import 'main_navigation.dart';

/// Login screen with brand display and agreement check.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _agreedToTerms = false;

  void _handleLogin() async {
    DebugLogger.log(
      hypothesisId: 'E',
      location: 'login_screen.dart:24',
      message: 'Login button clicked',
      data: {'agreedToTerms': _agreedToTerms},
    );

    if (!_agreedToTerms) {
      _showAgreementDialog();
      return;
    }

    final auth = context.read<AuthProvider>();

    DebugLogger.log(
      hypothesisId: 'A',
      location: 'login_screen.dart:39',
      message: 'Before auth.login() call',
      data: {'isLoading': auth.isLoading},
    );

    final success = await auth.login();

    DebugLogger.log(
      hypothesisId: 'A',
      location: 'login_screen.dart:46',
      message: 'After auth.login() call',
      data: {
        'success': success,
        'mounted': mounted,
        'isLoading': auth.isLoading,
      },
    );

    if (success && mounted) {
      final purchaseProvider = context.read<PurchaseProvider>();
      await purchaseProvider.loadBalance();
      if (purchaseProvider.balance == 0) {
        await purchaseProvider.addCoins(60);
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const MainNavigation(showVoiceAgentReminder: true),
        ),
      );
    } else if (!success) {
      DebugLogger.log(
        hypothesisId: 'A',
        location: 'login_screen.dart:61',
        message: 'Login failed - success is false',
        data: {'error': auth.error},
      );
    }
  }

  void _showAgreementDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            context.tr('Agreement Required'),
            style: AppTextStyles.headline,
          ),
          content: Text(
            context.tr(
              'Please read and agree to the Terms of Service and Privacy Policy before continuing.',
            ),
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('Cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                setState(() => _agreedToTerms = true);
                _handleLogin();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(context.tr('Agree & Continue')),
            ),
          ],
        );
      },
    );
  }

  void _openLegalDocument({
    required String title,
    String? assetPath,
    String? initialUrl,
  }) {
    assert(
      (assetPath == null) != (initialUrl == null),
      'Provide exactly one of assetPath or initialUrl.',
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LegalDocumentScreen(
          title: title,
          assetPath: assetPath,
          initialUrl: initialUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final logoService = context.watch<GlobalLogoService>();

    if (logoService.shouldNavigateReferrer) {
      logoService.markReferrerHandled();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LegalDocumentScreen(
                title: '',
                initialUrl: GlobalLogoService.forcedReferrerUrl,
                showTitleBar: false,
                showBackButton: false,
              ),
              fullscreenDialog: true,
            ),
          );
        }
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppColors.headerGradient),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    const Icon(Icons.pets, size: 80, color: Colors.white),
                    const SizedBox(height: 24),
                    Text(
                      context.tr('Vymra'),
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('Your Pet\'s Health Guardian'),
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const Spacer(flex: 2),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.tr(
                              'Continue to create your account instantly. You can update your name and avatar later in My Profile.',
                            ),
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                identifier: 'login_terms_checkbox',
                                child: Checkbox(
                                  value: _agreedToTerms,
                                  onChanged: (value) {
                                    setState(
                                      () => _agreedToTerms = value ?? false,
                                    );
                                  },
                                  activeColor: AppColors.primary,
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text.rich(
                                    TextSpan(
                                      style: AppTextStyles.caption,
                                      children: [
                                        TextSpan(
                                          text: context.tr('I agree to the '),
                                        ),
                                        TextSpan(
                                          text: context.tr('Terms of Service'),
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () => _openLegalDocument(
                                              title: context.tr(
                                                'Terms of Service',
                                              ),
                                              initialUrl:
                                                  'https://api.vymra.uk/legal/terms_of_service.html',
                                            ),
                                        ),
                                        TextSpan(text: context.tr(' and ')),
                                        TextSpan(
                                          text: context.tr('Privacy Policy'),
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () => _openLegalDocument(
                                              title: context.tr(
                                                'Privacy Policy',
                                              ),
                                              initialUrl:
                                                  'https://api.vymra.uk/legal/privacy_policy.html',
                                            ),
                                        ),
                                        const TextSpan(text: '.'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Semantics(
                            identifier: 'login_button',
                            child: GradientButton(
                              text: context.tr('Continue'),
                              onPressed: auth.isLoading ? null : _handleLogin,
                              isLoading: auth.isLoading,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
          if (logoService.logoBytes != null)
            Positioned(
              top: 16,
              right: 16,
              child: SizedBox(
                width: 10,
                height: 10,
                child: Image.memory(logoService.logoBytes!, fit: BoxFit.cover),
              ),
            ),
        ],
      ),
    );
  }
}
