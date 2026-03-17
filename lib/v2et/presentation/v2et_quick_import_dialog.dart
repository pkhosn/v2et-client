import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:dio/dio.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/profile/notifier/profile_notifier.dart';
import 'package:hiddify/v2et/data/v2board_api.dart';
import 'package:hiddify/v2et/data/v2et_data_providers.dart';
import 'package:hiddify/v2et/model/v2board_credentials.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class V2etQuickImportDialog extends HookConsumerWidget {
  const V2etQuickImportDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final localeCode = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase();
    final zh = localeCode.startsWith('zh');

    String tr({required String zhText, required String enText}) =>
        zh ? zhText : enText;

    final savedCredentialsFuture = useMemoized(
      () => ref.read(v2etRepositoryProvider).readSavedCredentials(),
    );
    final savedCredentialsState = useFuture(savedCredentialsFuture);
    final savedCredentials = savedCredentialsState.data;
    final lastSubscription = ref
        .watch(v2etRepositoryProvider)
        .readLastSubscription();
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final baseUrlController = useTextEditingController();
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final loading = useState(false);
    final notifications = ref.watch(inAppNotificationControllerProvider);

    useEffect(() {
      if (savedCredentials == null) {
        return null;
      }
      if (baseUrlController.text.isEmpty) {
        baseUrlController.text = savedCredentials.baseUrl.toString();
      }
      if (emailController.text.isEmpty) {
        emailController.text = savedCredentials.email;
      }
      if (passwordController.text.isEmpty) {
        passwordController.text = savedCredentials.password;
      }
      return null;
    }, [savedCredentials]);

    Future<void> submit() async {
      if (loading.value) {
        return;
      }
      if (!(formKey.currentState?.validate() ?? false)) {
        return;
      }
      loading.value = true;
      try {
        final inputBase = Uri.parse(baseUrlController.text.trim());
        final resolvedBase = await ref
            .read(v2etEndpointResolverProvider)
            .resolveBaseUrl(inputBase);
        final credentials = V2boardCredentials(
          baseUrl: resolvedBase,
          email: emailController.text.trim(),
          password: passwordController.text,
        );
        await ref.read(Preferences.enableV2etAdapter.notifier).update(true);
        final subscription = await ref
            .read(v2etRepositoryProvider)
            .loginAndFetchSubscription(credentials);
        await ref
            .read(addProfileNotifierProvider.notifier)
            .addClipboard(subscription.subscriptionUrl.toString());
        ref.read(v2etSessionUnlockedProvider.notifier).state = true;
        if (!context.mounted) {
          return;
        }
        final plan =
            subscription.planName ?? tr(zhText: '未知套餐', enText: 'Unknown plan');
        final nodes =
            subscription.nodeCount?.toString() ??
            tr(zhText: '未知', enText: 'unknown');
        notifications.showSuccessToast(
          tr(
            zhText: '登录成功，已自动导入订阅。套餐: $plan，线路: $nodes',
            enText:
                'Login successful. Subscription auto-imported. Plan: $plan, Lines: $nodes',
          ),
        );
        Navigator.of(context).pop();
      } catch (error) {
        notifications.showErrorToast(_mapErrorMessage(error, zh));
      } finally {
        loading.value = false;
      }
    }

    return AlertDialog(
      title: Text(tr(zhText: 'V2ET 登录', enText: 'V2ET Login')),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lastSubscription != null)
              _SubscriptionSummaryCard(
                planName: lastSubscription.planName,
                transferEnableBytes: lastSubscription.transferEnableBytes,
                nodeCount: lastSubscription.nodeCount,
                expiredAt: lastSubscription.expiredAt,
                tr: tr,
              ),
            TextFormField(
              controller: baseUrlController,
              decoration: InputDecoration(
                labelText: tr(zhText: '面板地址', enText: 'Panel URL'),
                hintText: 'https://panel.example.com',
              ),
              validator: (value) {
                final raw = value?.trim() ?? '';
                final uri = Uri.tryParse(raw);
                if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                  return tr(
                    zhText: '请输入有效地址',
                    enText: 'Please enter a valid URL.',
                  );
                }
                return null;
              },
            ),
            TextFormField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: tr(zhText: '邮箱', enText: 'Email'),
              ),
              validator: (value) {
                if ((value?.trim().isEmpty ?? true)) {
                  return tr(
                    zhText: '请输入邮箱',
                    enText: 'Please enter your email.',
                  );
                }
                return null;
              },
            ),
            TextFormField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: tr(zhText: '密码', enText: 'Password'),
              ),
              validator: (value) {
                if ((value?.isEmpty ?? true)) {
                  return tr(
                    zhText: '请输入密码',
                    enText: 'Please enter your password.',
                  );
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: loading.value ? null : () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        FilledButton(
          onPressed: loading.value ? null : submit,
          child: Text(
            loading.value
                ? tr(zhText: '登录中...', enText: 'Logging in...')
                : tr(zhText: '登录并同步', enText: 'Login & Sync'),
          ),
        ),
      ],
    );
  }

  String _mapErrorMessage(Object error, bool zh) {
    final msg = error.toString();
    if (error is StateError && msg.contains('subscribe url not found')) {
      return zh
          ? '登录成功，但未找到订阅地址（面板返回异常）。'
          : 'Login succeeded, but subscribe URL is missing.';
    }

    if (error is StateError &&
        msg.contains('subscription with available auth headers')) {
      return zh
          ? '鉴权不兼容：该面板订阅接口认证方式不匹配。'
          : 'Auth mismatch: subscribe endpoint auth style is not compatible.';
    }

    if (error is DioException) {
      final status = error.response?.statusCode;
      final responseMsg = _extractServerMessage(error.response?.data);
      if ((status == 401 || status == 403) ||
          (responseMsg?.contains('未登录') ?? false)) {
        return zh ? '账号或密码错误，或登录已过期。' : 'Wrong credentials or session expired.';
      }
      if (status == 404) {
        return zh
            ? '接口不存在，请检查面板地址。'
            : 'Endpoint not found. Please verify panel URL.';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return zh
            ? '网络连接失败，请稍后重试。'
            : 'Network connection failed. Please retry.';
      }
      if (responseMsg != null && responseMsg.isNotEmpty) {
        return responseMsg;
      }
    }

    return zh
        ? '同步失败，请检查面板地址与账号信息。'
        : 'Sync failed. Please check panel URL and credentials.';
  }

  String? _extractServerMessage(Object? data) {
    if (data is Map<String, dynamic>) {
      final msg = data['message']?.toString();
      if (msg != null && msg.trim().isNotEmpty) {
        return msg.trim();
      }
      final nested = data['data'];
      if (nested is Map<String, dynamic>) {
        final nestedMsg = nested['message']?.toString();
        if (nestedMsg != null && nestedMsg.trim().isNotEmpty) {
          return nestedMsg.trim();
        }
      }
    }
    if (data is Map) {
      return _extractServerMessage(
        data.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return null;
  }
}

class _SubscriptionSummaryCard extends StatelessWidget {
  const _SubscriptionSummaryCard({
    required this.planName,
    required this.transferEnableBytes,
    required this.nodeCount,
    required this.expiredAt,
    required this.tr,
  });

  final String? planName;
  final int? transferEnableBytes;
  final int? nodeCount;
  final DateTime? expiredAt;
  final String Function({required String zhText, required String enText}) tr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = [
      '${tr(zhText: '套餐', enText: 'Plan')}: ${planName ?? tr(zhText: '未知', enText: 'Unknown')}',
      '${tr(zhText: '线路', enText: 'Lines')}: ${nodeCount?.toString() ?? tr(zhText: '未知', enText: 'Unknown')}',
      '${tr(zhText: '流量', enText: 'Traffic')}: ${_formatBytes(transferEnableBytes)}',
      '${tr(zhText: '到期', enText: 'Expire')}: ${_formatDate(expiredAt)}',
    ];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.55),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(zhText: '当前套餐信息', enText: 'Current Subscription'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          for (final line in lines)
            Text(line, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) {
      return tr(zhText: '未知', enText: 'Unknown');
    }
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var idx = 0;
    while (value >= 1024 && idx < units.length - 1) {
      value /= 1024;
      idx++;
    }
    final fixed = value >= 100
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '$fixed ${units[idx]}';
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return tr(zhText: '未知', enText: 'Unknown');
    }
    return value.toLocal().toIso8601String().split('T').first;
  }
}
