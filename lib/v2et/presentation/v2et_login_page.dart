import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/profile/notifier/profile_notifier.dart';
import 'package:hiddify/v2et/config/v2et_bootstrap_config.dart';
import 'package:hiddify/v2et/data/v2et_data_providers.dart';
import 'package:hiddify/v2et/model/v2board_credentials.dart';
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
                        TextFormField(
                          controller: baseUrlController,
                          decoration: InputDecoration(
                            labelText: tr('面板地址', 'Panel URL'),
                          ),
                          validator: (value) {
                            final uri = Uri.tryParse(value?.trim() ?? '');
                            if (uri == null ||
                                !uri.hasScheme ||
                                !uri.hasAuthority)
                              return tr('请输入有效面板地址', 'Enter valid panel URL');
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
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
