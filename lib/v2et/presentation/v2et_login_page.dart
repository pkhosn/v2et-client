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
import 'package:hiddify/utils/uri_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class V2etLoginPage extends HookConsumerWidget {
  const V2etLoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zh = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('zh');
    String tr(String a, String b) => zh ? a : b;

    final savedCredentialsFuture = useMemoized(
      () => ref.read(v2etRepositoryProvider).readSavedCredentials(),
    );
    final savedCredentials = useFuture(savedCredentialsFuture).data;

    final formKey = useMemoized(GlobalKey<FormState>.new);
    final baseUrlController = useTextEditingController(
      text:
          savedCredentials?.baseUrl.toString() ??
          V2etBootstrapConfig.defaultConfigUrl,
    );
    final emailController = useTextEditingController(
      text: savedCredentials?.email ?? '',
    );
    final passwordController = useTextEditingController(
      text: savedCredentials?.password ?? '',
    );
    final loading = useState(false);
    final showAdvanced = useState(false);
    final locale = ref.watch(localePreferencesProvider);

    Future<Uri> resolvePanelBase() async {
      final input = Uri.parse(baseUrlController.text.trim());
      return ref.read(v2etEndpointResolverProvider).resolveBaseUrl(input);
    }

    Future<void> openRegister() async {
      try {
        final base = await resolvePanelBase();
        final candidates = [
          base.replace(path: '/#/register'),
          base.replace(path: '/register'),
          base.replace(path: '/auth/register'),
        ];
        for (final uri in candidates) {
          if (await UriUtils.tryLaunch(uri)) {
            return;
          }
        }
      } catch (_) {}
    }

    Future<void> openForgotPassword() async {
      try {
        final base = await resolvePanelBase();
        final candidates = [
          base.replace(path: '/#/forget'),
          base.replace(path: '/#/reset'),
          base.replace(path: '/forget'),
          base.replace(path: '/password/reset'),
        ];
        for (final uri in candidates) {
          if (await UriUtils.tryLaunch(uri)) {
            return;
          }
        }
      } catch (_) {}
    }

    Future<void> submit() async {
      if (loading.value) return;
      if (!(formKey.currentState?.validate() ?? false)) return;
      loading.value = true;
      try {
        final resolvedBase = await ref
            .read(v2etEndpointResolverProvider)
            .resolveBaseUrl(Uri.parse(baseUrlController.text.trim()));
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
      body: Row(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              color: const Color(0xFF2C1E4D),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 74,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'V2ET',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('世界触手可得', 'Reach the world'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 7,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: PopupMenuButton<AppLocale>(
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.language_rounded, size: 18),
                                  const SizedBox(width: 6),
                                  Text(locale.localeName),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          tr('登录', 'Login'),
                          style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(tr('欢迎回来，请登录您的账号', 'Welcome back, please login')),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () =>
                                showAdvanced.value = !showAdvanced.value,
                            icon: Icon(
                              showAdvanced.value
                                  ? Icons.expand_less_rounded
                                  : Icons.tune_rounded,
                            ),
                            label: Text(
                              tr('高级网络设置', 'Advanced Network Settings'),
                            ),
                          ),
                        ),
                        if (showAdvanced.value) ...[
                          TextFormField(
                            controller: baseUrlController,
                            decoration: InputDecoration(
                              labelText: tr('配置地址（OSS）', 'Config URL (OSS)'),
                            ),
                            validator: (value) {
                              final uri = Uri.tryParse(value?.trim() ?? '');
                              if (uri == null ||
                                  !uri.hasScheme ||
                                  !uri.hasAuthority) {
                                return tr(
                                  '请输入有效配置地址',
                                  'Enter valid config URL',
                                );
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: emailController,
                          decoration: InputDecoration(
                            labelText: tr('邮箱', 'Email'),
                          ),
                          validator: (value) => (value?.trim().isEmpty ?? true)
                              ? tr('请输入邮箱', 'Enter email')
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: tr('密码', 'Password'),
                          ),
                          validator: (value) => (value?.isEmpty ?? true)
                              ? tr('请输入密码', 'Enter password')
                              : null,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: loading.value ? null : submit,
                            child: Text(
                              loading.value
                                  ? tr('登录中...', 'Logging in...')
                                  : tr('登录', 'Login'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: loading.value ? null : openRegister,
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              label: Text(tr('注册', 'Register')),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: loading.value
                                  ? null
                                  : openForgotPassword,
                              icon: const Icon(Icons.help_outline_rounded),
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
        ],
      ),
    );
  }
}
