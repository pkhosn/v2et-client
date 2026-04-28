import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/locale_extensions.dart';
import 'package:hiddify/core/localization/locale_preferences.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/profile/notifier/profile_notifier.dart';
import 'package:hiddify/gen/translations.g.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hiddify/v2et/config/v2et_bootstrap_config.dart';
import 'package:hiddify/v2et/data/v2board_api.dart';
import 'package:hiddify/v2et/data/v2et_data_providers.dart';
import 'package:hiddify/v2et/data/v2et_portal_provider.dart';
import 'package:hiddify/v2et/data/v2et_runtime_config_provider.dart';
import 'package:hiddify/v2et/model/v2board_credentials.dart';
import 'package:hiddify/v2et/data/v2et_support_launcher.dart';
import 'package:hiddify/v2et/presentation/v2et_notice.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum _AuthMode { login, register, forgot }

String _readApiError(Object error) {
  if (error is StateError) {
    final text = error.message.toString().trim();
    if (text.isNotEmpty) return text;
  }
  final raw = error.toString();
  return raw.replaceFirst(RegExp(r'^Bad state:\s*'), '').trim();
}

String _friendlyLoginError(Object error, bool zh) {
  final raw = error.toString();
  final message = raw.toLowerCase();
  if (message.contains('不存在') || message.contains('not exist') || message.contains('not found')) {
    return zh ? '登录失败：账号不存在' : 'Login failed: account does not exist';
  }
  if (message.contains('密码') || message.contains('password') || message.contains('invalid credentials')) {
    return zh ? '登录失败：密码错误' : 'Login failed: incorrect password';
  }
  return (zh ? '登录失败：' : 'Login failed: ') + raw;
}

class V2etLoginPage extends HookConsumerWidget {
  const V2etLoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zh = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('zh');
    String tr(String a, String b) => zh ? a : b;

    final width = MediaQuery.sizeOf(context).width;
    final compact = PlatformUtils.isDesktop ? false : width < 900;

    final savedCredentialsFuture = useMemoized(() => ref.read(v2etRepositoryProvider).readSavedCredentials());
    final savedCredentials = useFuture(savedCredentialsFuture).data;

    final formKey = useMemoized(GlobalKey<FormState>.new);
    final panelConfigUrl = savedCredentials?.baseUrl.toString() ?? V2etBootstrapConfig.defaultConfigUrl;
    final emailController = useTextEditingController(text: savedCredentials?.email ?? '');
    final passwordController = useTextEditingController(text: savedCredentials?.password ?? '');
    useEffect(() {
      final savedEmail = savedCredentials?.email ?? '';
      final savedPassword = savedCredentials?.password ?? '';
      if (savedEmail.isNotEmpty && emailController.text != savedEmail) {
        emailController.text = savedEmail;
      }
      if (savedPassword.isNotEmpty && passwordController.text != savedPassword) {
        passwordController.text = savedPassword;
      }
      return null;
    }, [savedCredentials?.email, savedCredentials?.password]);
    final loading = useState(false);
    final authMode = useState(_AuthMode.login);
    final rememberPassword = useState(true);
    final autoLogin = useState(true);
    final obscurePassword = useState(true);
    final locale = ref.watch(localePreferencesProvider);

    Future<Uri> resolvedBaseUrl() {
      final resolver = ref.read(v2etEndpointResolverProvider);
      return resolver.resolveBaseUrl(Uri.parse(panelConfigUrl.trim()));
    }

    final authConfigFuture = useMemoized(() async {
      try {
        final baseUrl = await resolvedBaseUrl();
        return await ref.read(v2boardApiProvider).fetchAuthConfig(baseUrl);
      } catch (_) {
        return const V2boardAuthConfig(requireEmailVerify: false, requireInviteCode: false, emailWhitelistSuffixes: []);
      }
    });
    final authConfig =
        useFuture(authConfigFuture).data ??
        const V2boardAuthConfig(requireEmailVerify: false, requireInviteCode: false, emailWhitelistSuffixes: []);
    final runtimeConfigAsync = ref.watch(v2etRuntimeConfigProvider);
    final runtimeConfig = runtimeConfigAsync.valueOrNull;
    final supportUri = buildV2etSupportUri(runtimeConfig);
    final showSupportFab = supportUri != null || runtimeConfigAsync.isLoading;

    final modeTitle = switch (authMode.value) {
      _AuthMode.login => tr('登录', 'Login'),
      _AuthMode.register => tr('注册', 'Register'),
      _AuthMode.forgot => tr('找回密码', 'Reset password'),
    };
    final modeSubtitle = switch (authMode.value) {
      _AuthMode.login => tr('欢迎回来，请登录您的账号', 'Welcome back, please login'),
      _AuthMode.register => tr('创建新账号以开始使用', 'Create a new account to continue'),
      _AuthMode.forgot => tr('通过邮箱验证码重置密码', 'Reset your password via email verification'),
    };

    Future<void> submit() async {
      if (loading.value) return;
      if (!(formKey.currentState?.validate() ?? false)) return;
      loading.value = true;
      try {
        final baseUrl = await resolvedBaseUrl();
        final credentials = V2boardCredentials(
          baseUrl: baseUrl,
          email: emailController.text.trim(),
          password: passwordController.text,
        );

        await ref.read(Preferences.enableV2etAdapter.notifier).update(true);
        final sub = await ref.read(v2etRepositoryProvider).loginAndFetchSubscription(credentials);
        final noPlan =
            (sub.nodeCount != null && sub.nodeCount! <= 0) ||
            (sub.transferEnableBytes != null && sub.transferEnableBytes! <= 0);
        ref.read(v2etSessionUnlockedProvider.notifier).state = true;
        ref.invalidate(v2etSessionProvider);
        ref.invalidate(v2etNoticesProvider);
        ref.invalidate(v2etStoreOffersProvider);
        ref.invalidate(v2etCountersProvider);
        ref.invalidate(v2etOrdersProvider);
        ref.invalidate(v2etTrafficLogsProvider);
        ref.invalidate(v2etInviteInfoProvider);
        if (!noPlan) {
          unawaited(
            ref
                .read(addProfileNotifierProvider.notifier)
                .addClipboard(sub.subscriptionUrl.toString())
                .catchError((_) {}),
          );
        }
        if (!context.mounted) return;
        if (noPlan) {
          showV2etNotice(
            context,
            tr('当前账号暂无有效套餐，请先购买套餐', 'No active plan found. Please purchase a plan first.'),
            error: true,
            duration: const Duration(seconds: 2),
          );
          context.go('/store');
        } else {
          if (context.mounted) {
            showV2etNotice(context, tr('登录成功', 'Login success'), duration: const Duration(seconds: 1));
          }
          context.go('/home');
        }
      } catch (e) {
        ref.read(v2etSessionUnlockedProvider.notifier).state = false;
        ref.invalidate(v2etSessionProvider);
        final message = _friendlyLoginError(e, zh);
        if (context.mounted) {
          showV2etNotice(context, message, error: true);
        }
      } finally {
        loading.value = false;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2F8),
      floatingActionButton: !showSupportFab
          ? null
          : FloatingActionButton(
              mini: true,
              backgroundColor: const Color(0xFF5A3D89),
              foregroundColor: Colors.white,
              onPressed: () async {
                var uri = supportUri;
                if (uri == null) {
                  ref.invalidate(v2etRuntimeConfigProvider);
                  final refreshed = await ref.read(v2etRuntimeConfigProvider.future).catchError((_) => null);
                  uri = buildV2etSupportUri(refreshed);
                }
                if (uri == null) {
                  if (context.mounted) {
                    showV2etNotice(context, tr('未配置客服入口', 'Support is not configured'), error: true);
                  }
                  return;
                }
                await openV2etSupport(context, uri, title: tr('在线客服', 'Live Support'));
              },
              child: const Icon(Icons.support_agent_rounded),
            ),
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
                              await ref.read(localePreferencesProvider.notifier).changeLocale(value);
                            },
                            itemBuilder: (_) => AppLocale.values
                                .map((e) => PopupMenuItem<AppLocale>(value: e, child: Text(e.localeName)))
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
                                  const Text(
                                    '文',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                                  ),
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
                        ],
                      ),
                      const Spacer(),
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 170,
                              height: 170,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF6E6294).withOpacity(0.35), width: 2),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Image.asset('assets/images/tray_icon.png'),
                              ),
                            ),
                            const SizedBox(height: 30),
                            const Text(
                              'V2ET',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 66,
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
                        '© 2026 V2ET. All rights reserved.',
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
                                    await ref.read(localePreferencesProvider.notifier).changeLocale(value);
                                  },
                                  itemBuilder: (_) => AppLocale.values
                                      .map((e) => PopupMenuItem<AppLocale>(value: e, child: Text(e.localeName)))
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
                                        const Text('文', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                        const SizedBox(width: 4),
                                        Text(locale.localeName),
                                      ],
                                    ),
                                  ),
                                ),
                              const Spacer(),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            modeTitle,
                            style: const TextStyle(
                              fontSize: 48,
                              color: Color(0xFF4C347C),
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(modeSubtitle, style: const TextStyle(color: Color(0xFF5F5A67), fontSize: 16)),
                          const SizedBox(height: 56),
                          if (authMode.value == _AuthMode.login) ...[
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
                          ] else ...[
                            FutureBuilder<Uri>(
                              future: resolvedBaseUrl(),
                              builder: (context, snapshot) {
                                final baseUrl = snapshot.data;
                                if (baseUrl == null) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 24),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                final api = ref.read(v2boardApiProvider);
                                if (authMode.value == _AuthMode.register) {
                                  return _RegisterPanel(
                                    zh: zh,
                                    baseUrl: baseUrl,
                                    config: authConfig,
                                    api: api,
                                    onDone: () => authMode.value = _AuthMode.login,
                                  );
                                }
                                return _ForgotPasswordPanel(
                                  zh: zh,
                                  baseUrl: baseUrl,
                                  api: api,
                                  onDone: () => authMode.value = _AuthMode.login,
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: loading.value
                                    ? null
                                    : () => authMode.value = authMode.value == _AuthMode.register
                                          ? _AuthMode.login
                                          : _AuthMode.register,
                                icon: Icon(
                                  authMode.value == _AuthMode.register
                                      ? Icons.login_rounded
                                      : Icons.person_add_alt_1_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  authMode.value == _AuthMode.register
                                      ? tr('返回登录', 'Back to login')
                                      : tr('注册', 'Register'),
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: loading.value
                                    ? null
                                    : () => authMode.value = authMode.value == _AuthMode.forgot
                                          ? _AuthMode.login
                                          : _AuthMode.forgot,
                                icon: Icon(
                                  authMode.value == _AuthMode.forgot ? Icons.login_rounded : Icons.help_outline_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  authMode.value == _AuthMode.forgot
                                      ? tr('返回登录', 'Back to login')
                                      : tr('忘记密码？', 'Forgot Password?'),
                                ),
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

class _RegisterPanel extends StatefulWidget {
  const _RegisterPanel({
    required this.zh,
    required this.baseUrl,
    required this.config,
    required this.api,
    required this.onDone,
  });

  final bool zh;
  final Uri baseUrl;
  final V2boardAuthConfig config;
  final V2boardApi api;
  final VoidCallback onDone;

  @override
  State<_RegisterPanel> createState() => _RegisterPanelState();
}

class _RegisterPanelState extends State<_RegisterPanel> {
  final email = TextEditingController();
  final password = TextEditingController();
  final emailCode = TextEditingController();
  final inviteCode = TextEditingController();
  bool sendingCode = false;
  bool submitting = false;
  String? selectedSuffix;

  String tr(String a, String b) => widget.zh ? a : b;

  @override
  void initState() {
    super.initState();
    if (widget.config.emailWhitelistSuffixes.isNotEmpty) {
      selectedSuffix = widget.config.emailWhitelistSuffixes.first;
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    emailCode.dispose();
    inviteCode.dispose();
    super.dispose();
  }

  String _composeEmail() {
    final raw = email.text.trim();
    if (raw.isEmpty) return raw;
    final suffix = selectedSuffix;
    if (suffix != null && suffix.isNotEmpty && !raw.contains('@')) {
      return '$raw$suffix';
    }
    return raw;
  }

  bool _validateEmailWhitelist(String value) {
    final whitelist = widget.config.emailWhitelistSuffixes;
    if (whitelist.isEmpty) return true;
    return whitelist.any((suffix) => value.toLowerCase().endsWith(suffix.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    final suffixes = widget.config.emailWhitelistSuffixes;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE8F4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD3CBE0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('注册账号', 'Register account'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          const SizedBox(height: 10),
          if (suffixes.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: email,
                    decoration: InputDecoration(labelText: tr('邮箱用户名', 'Email username')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedSuffix,
                    items: suffixes
                        .map((suffix) => DropdownMenuItem<String>(value: suffix, child: Text(suffix)))
                        .toList(),
                    onChanged: (value) => setState(() => selectedSuffix = value),
                    decoration: InputDecoration(labelText: tr('后缀', 'Suffix')),
                  ),
                ),
              ],
            ),
          ] else ...[
            TextField(
              controller: email,
              decoration: InputDecoration(labelText: tr('邮箱', 'Email')),
            ),
          ],
          TextField(
            controller: password,
            decoration: InputDecoration(labelText: tr('密码', 'Password')),
            obscureText: true,
          ),
          TextField(
            controller: inviteCode,
            decoration: InputDecoration(
              labelText: widget.config.requireInviteCode
                  ? tr('邀请码（必填）', 'Invite code (required)')
                  : tr('邀请码（可选）', 'Invite code (optional)'),
            ),
          ),
          if (widget.config.requireEmailVerify)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: emailCode,
                    decoration: InputDecoration(labelText: tr('邮箱验证码', 'Email code')),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: sendingCode
                      ? null
                      : () async {
                          final builtEmail = _composeEmail();
                          if (builtEmail.isEmpty) return;
                          if (!_validateEmailWhitelist(builtEmail)) {
                            showV2etNotice(context, tr('邮箱后缀不在白名单中', 'Email suffix is not allowed'), error: true);
                            return;
                          }
                          setState(() => sendingCode = true);
                          try {
                            await widget.api.sendEmailVerifyCode(baseUrl: widget.baseUrl, email: builtEmail);
                            if (!mounted) return;
                            showV2etNotice(context, tr('验证码已发送', 'Verification code sent'));
                          } catch (e) {
                            if (!mounted) return;
                            showV2etNotice(context, tr('发送失败: ', 'Failed: ') + _readApiError(e), error: true);
                          } finally {
                            if (mounted) setState(() => sendingCode = false);
                          }
                        },
                  child: Text(tr('发送', 'Send')),
                ),
              ],
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final e = _composeEmail();
                      final p = password.text;
                      if (e.isEmpty || p.isEmpty) return;
                      if (!_validateEmailWhitelist(e)) {
                        showV2etNotice(context, tr('邮箱后缀不在白名单中', 'Email suffix is not allowed'), error: true);
                        return;
                      }
                      if (widget.config.requireEmailVerify && emailCode.text.trim().isEmpty) return;
                      if (widget.config.requireInviteCode && inviteCode.text.trim().isEmpty) return;
                      setState(() => submitting = true);
                      try {
                        await widget.api.register(
                          baseUrl: widget.baseUrl,
                          email: e,
                          password: p,
                          emailCode: emailCode.text.trim(),
                          inviteCode: inviteCode.text.trim(),
                        );
                        if (!mounted) return;
                        widget.onDone();
                        showV2etNotice(context, tr('注册成功，请登录', 'Register success, please login'));
                      } catch (e) {
                        if (!mounted) return;
                        showV2etNotice(context, tr('注册失败: ', 'Register failed: ') + _readApiError(e), error: true);
                      } finally {
                        if (mounted) setState(() => submitting = false);
                      }
                    },
              child: Text(tr('注册', 'Register')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForgotPasswordPanel extends StatefulWidget {
  const _ForgotPasswordPanel({required this.zh, required this.baseUrl, required this.api, required this.onDone});

  final bool zh;
  final Uri baseUrl;
  final V2boardApi api;
  final VoidCallback onDone;

  @override
  State<_ForgotPasswordPanel> createState() => _ForgotPasswordPanelState();
}

class _ForgotPasswordPanelState extends State<_ForgotPasswordPanel> {
  final email = TextEditingController();
  final password = TextEditingController();
  final emailCode = TextEditingController();
  bool sendingCode = false;
  bool submitting = false;

  String tr(String a, String b) => widget.zh ? a : b;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    emailCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE8F4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD3CBE0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('重置密码', 'Reset password'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          const SizedBox(height: 10),
          TextField(
            controller: email,
            decoration: InputDecoration(labelText: tr('邮箱', 'Email')),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: emailCode,
                  decoration: InputDecoration(labelText: tr('邮箱验证码', 'Email code')),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: sendingCode
                    ? null
                    : () async {
                        final e = email.text.trim();
                        if (e.isEmpty) return;
                        setState(() => sendingCode = true);
                        try {
                          await widget.api.sendEmailVerifyCode(baseUrl: widget.baseUrl, email: e);
                          if (!mounted) return;
                          showV2etNotice(context, tr('验证码已发送', 'Verification code sent'));
                        } catch (e) {
                          if (!mounted) return;
                          showV2etNotice(context, tr('发送失败: ', 'Failed: ') + _readApiError(e), error: true);
                        } finally {
                          if (mounted) setState(() => sendingCode = false);
                        }
                      },
                child: Text(tr('发送', 'Send')),
              ),
            ],
          ),
          TextField(
            controller: password,
            decoration: InputDecoration(labelText: tr('新密码', 'New password')),
            obscureText: true,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final e = email.text.trim();
                      final p = password.text;
                      final c = emailCode.text.trim();
                      if (e.isEmpty || p.isEmpty || c.isEmpty) return;
                      setState(() => submitting = true);
                      try {
                        await widget.api.resetPassword(baseUrl: widget.baseUrl, email: e, password: p, emailCode: c);
                        if (!mounted) return;
                        widget.onDone();
                        showV2etNotice(context, tr('重置成功，请登录', 'Reset success, please login'));
                      } catch (e) {
                        if (!mounted) return;
                        showV2etNotice(context, tr('重置失败: ', 'Reset failed: ') + _readApiError(e), error: true);
                      } finally {
                        if (mounted) setState(() => submitting = false);
                      }
                    },
              child: Text(tr('提交', 'Submit')),
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
