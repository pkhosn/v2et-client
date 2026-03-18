import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/locale_extensions.dart';
import 'package:hiddify/core/localization/locale_preferences.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/profile/notifier/profile_notifier.dart';
import 'package:hiddify/v2et/config/v2et_bootstrap_config.dart';
import 'package:hiddify/v2et/data/v2et_data_providers.dart';
import 'package:hiddify/v2et/model/v2board_credentials.dart';
import 'package:hiddify/gen/translations.g.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class V2etLoginPage extends HookConsumerWidget {
  const V2etLoginPage({super.key});

  static const _buildMarker = 'UI-PATCH-B1';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zh = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('zh');
    String tr(String a, String b) => zh ? a : b;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 900;

    final savedCredentialsFuture = useMemoized(
      () => ref.read(v2etRepositoryProvider).readSavedCredentials(),
    );
    final savedCredentials = useFuture(savedCredentialsFuture).data;

    final formKey = useMemoized(GlobalKey<FormState>.new);
    final panelConfigUrl =
        savedCredentials?.baseUrl.toString() ?? V2etBootstrapConfig.defaultConfigUrl;
    final emailController = useTextEditingController(
      text: savedCredentials?.email ?? '',
    );
    final passwordController = useTextEditingController(
      text: savedCredentials?.password ?? '',
    );
    final loading = useState(false);
    final rememberPassword = useState(true);
    final autoLogin = useState(true);
    final obscurePassword = useState(true);
    final locale = ref.watch(localePreferencesProvider);

    void openRegister() {
      ref
          .read(inAppNotificationControllerProvider)
          .showInfoToast(tr('注册功能暂不可用', 'Register is not available yet'));
    }

    void openForgotPassword() {
      ref
          .read(inAppNotificationControllerProvider)
          .showInfoToast(tr('重置密码功能暂不可用', 'Password reset is not available yet'));
    }

    Future<void> submit() async {
      if (loading.value) return;
      if (!(formKey.currentState?.validate() ?? false)) return;
      loading.value = true;
      try {
        final resolvedBase = await ref
            .read(v2etEndpointResolverProvider)
            .resolveBaseUrl(Uri.parse(panelConfigUrl.trim()));
        final credentials = V2boardCredentials(
          baseUrl: resolvedBase,
          email: emailController.text.trim(),
          password: passwordController.text,
        );
        await ref.read(Preferences.enableV2etAdapter.notifier).update(true);
        final sub = await ref
            .read(v2etRepositoryProvider)
            .loginAndFetchSubscription(credentials);
        await ref
            .read(addProfileNotifierProvider.notifier)
            .addClipboard(sub.subscriptionUrl.toString());
        ref.read(v2etSessionUnlockedProvider.notifier).state = true;
        if (!context.mounted) return;
        ref
            .read(inAppNotificationControllerProvider)
            .showSuccessToast(tr('登录成功，正在进入客户端', 'Login success'));
        context.go('/home');
      } catch (e) {
        ref
            .read(inAppNotificationControllerProvider)
            .showErrorToast(tr('登录失败: ', 'Login failed: ') + e.toString());
      } finally {
        loading.value = false;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2F8),
      body: Row(
        children: [
          if (!compact)
            Expanded(
              flex: 5,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF211338), Color(0xFF3D2860)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          PopupMenuButton<AppLocale>(
                            initialValue: locale,
                            onSelected: (value) async {
                              await ref
                                  .read(localePreferencesProvider.notifier)
                                  .changeLocale(value);
                            },
                            itemBuilder: (_) => AppLocale.values
                                .map(
                                  (e) => PopupMenuItem<AppLocale>(
                                    value: e,
                                    child: Text(e.localeName),
                                  ),
                                )
                                .toList(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E2250),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.translate_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    locale.localeName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E2250),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.public_rounded, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 190,
                              height: 190,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF6E6294).withOpacity(0.35), width: 2),
                              ),
                              child: const Icon(Icons.shield_rounded, color: Color(0xFFF4F0FB), size: 74),
                            ),
                            const SizedBox(height: 30),
                            const Text(
                              'Pltea',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 72,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              tr('世界触手可得', 'Reach the world'),
                              style: const TextStyle(color: Color(0xFFD2CCE3), fontSize: 22),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        '© 2026 Pltea. All rights reserved.',
                        style: TextStyle(color: Color(0xFFC5BED7), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            flex: compact ? 1 : 7,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(compact ? 28 : 70, 24, compact ? 28 : 84, 24),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (compact)
                              PopupMenuButton<AppLocale>(
                                initialValue: locale,
                                onSelected: (value) async {
                                  await ref
                                      .read(localePreferencesProvider.notifier)
                                      .changeLocale(value);
                                },
                                itemBuilder: (_) => AppLocale.values
                                    .map(
                                      (e) => PopupMenuItem<AppLocale>(
                                        value: e,
                                        child: Text(e.localeName),
                                      ),
                                    )
                                    .toList(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: const Color(0xFFEDE7F4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.translate_rounded, size: 16),
                                      const SizedBox(width: 4),
                                      Text(locale.localeName),
                                    ],
                                  ),
                                ),
                              ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDE7F5),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                _buildMarker,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF4C347C),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(onPressed: () {}, icon: const Icon(Icons.public_rounded, size: 24)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          tr('登录', 'Login'),
                          style: const TextStyle(
                            fontSize: 48,
                            color: Color(0xFF4C347C),
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tr('欢迎回来，请登录您的账号', 'Welcome back, please login'),
                          style: const TextStyle(color: Color(0xFF5F5A67), fontSize: 16),
                        ),
                        const SizedBox(height: 56),
                        _V2etInputField(
                          label: tr('邮箱', 'Email'),
                          hint: tr('请输入邮箱', 'Enter email'),
                          icon: Icons.mail_outline_rounded,
                          controller: emailController,
                          validator: (value) => (value?.trim().isEmpty ?? true) ? tr('请输入邮箱', 'Enter email') : null,
                        ),
                        const SizedBox(height: 16),
                        _V2etInputField(
                          label: tr('密码', 'Password'),
                          hint: tr('请输入密码', 'Enter password'),
                          icon: Icons.lock_outline_rounded,
                          controller: passwordController,
                          obscureText: obscurePassword.value,
                          trailing: IconButton(
                            onPressed: () => obscurePassword.value = !obscurePassword.value,
                            icon: Icon(
                              obscurePassword.value ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: const Color(0xFF5C5966),
                            ),
                          ),
                          validator: (value) => (value?.isEmpty ?? true) ? tr('请输入密码', 'Enter password') : null,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _LabeledCheckbox(
                              label: tr('记住密码', 'Remember password'),
                              value: rememberPassword.value,
                              onChanged: (v) => rememberPassword.value = v ?? false,
                            ),
                            const Spacer(),
                            _LabeledCheckbox(
                              label: tr('自动登录', 'Auto Login'),
                              value: autoLogin.value,
                              onChanged: (v) => autoLogin.value = v ?? false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF573C87),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(56),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: loading.value ? null : submit,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  loading.value ? tr('登录中...', 'Logging in...') : tr('登录', 'Login'),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.login_rounded, size: 20),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: loading.value ? null : openRegister,
                              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                              label: Text(tr('注册', 'Register')),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: loading.value ? null : openForgotPassword,
                              icon: const Icon(Icons.help_outline_rounded, size: 18),
                              label: Text(tr('忘记密码？', 'Forgot Password?')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                    ),
                  ),
                ),
              ),
          ),
        ],
      ),
    );
  }
}

class _V2etInputField extends StatelessWidget {
  const _V2etInputField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    required this.validator,
    this.obscureText = false,
    this.trailing,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final bool obscureText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, color: Color(0xFF2D2A36))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          obscureText: obscureText,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF5C5966)),
            suffixIcon: trailing,
            filled: true,
            fillColor: const Color(0xFFF4F1F8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF94909E), width: 1.3),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF94909E), width: 1.3),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF573C87), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _LabeledCheckbox extends StatelessWidget {
  const _LabeledCheckbox({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF573C87),
          side: const BorderSide(color: Color(0xFF6D6878)),
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        ),
        Text(label, style: const TextStyle(fontSize: 15, color: Color(0xFF2D2A36))),
      ],
    );
  }
}
