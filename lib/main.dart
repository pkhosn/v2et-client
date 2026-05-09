import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:hiddify/bootstrap.dart';
import 'package:hiddify/core/model/environment.dart';

Future<void> main(List<String> args) async {
  if (runWebViewTitleBarWidget(args, builder: _buildWebviewTitleBar)) {
    return;
  }
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // final widgetsBinding = SentryWidgetsFlutterBinding.ensureInitialized();
  // debugPaintSizeEnabled = true;

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent, systemNavigationBarColor: Colors.transparent),
  );

  return await lazyBootstrap(widgetsBinding, Environment.dev);
}

Widget _buildWebviewTitleBar(BuildContext context) {
  final state = TitleBarWebViewState.of(context);
  final controller = TitleBarWebViewController.of(context);
  final isSupportWindow = (state.url ?? '').contains('crisp.chat') ||
      (state.url ?? '').contains('tawk.to') ||
      (state.url ?? '').contains('chatway.app');
  if (!isSupportWindow) {
    return const SizedBox.shrink();
  }
  return Container(
    color: const Color(0xFF0665D0),
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            state.url == null || state.url!.isEmpty ? 'Support' : 'Support',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          onPressed: controller.reload,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        ),
        IconButton(
          onPressed: controller.close,
          icon: const Icon(Icons.close_rounded, color: Colors.white),
        ),
      ],
    ),
  );
}
