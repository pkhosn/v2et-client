import 'dart:convert';
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hiddify/v2et/data/v2et_runtime_config_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:win32/win32.dart';

String? _activeSupportWindowTitle;
DateTime? _activeSupportWindowOpenedAt;
int _mainWindowHandle = 0;
bool _supportWindowHidden = false;
Timer? _supportWindowWatchdog;
int _supportMarginRightPx = 0;
int _supportMarginTopPx = 0;
int _supportWidthPx = 380;
int _supportHeightPx = 518;
int _lastMainClientWidthPx = 0;
int _lastMainClientHeightPx = 0;
int _anchorMarginRightPx = 0;
int _anchorTopPx = 0;
int _anchorWidthPx = 0;
int _lastForegroundHwnd = 0;
bool _supportWasForegroundOnce = false;
bool _supportOpeningInProgress = false;
DateTime? _supportHideEnabledAfter;
bool _supportWindowActionInProgress = false;
DateTime? _lastSupportWindowActionAt;

Uri? buildV2etSupportUri(V2etRuntimeConfig? config) {
  if (config == null) return null;

  final provider = _normalizeProvider(config.supportProvider);
  final crispId = (config.crispWebsiteId ?? '').trim();
  final tawkPropertyId = (config.tawktoPropertyId ?? '').trim();
  final tawkWidgetId = (config.tawktoWidgetId ?? '').trim();
  final chatwayWidgetId = (config.chatwayWidgetId ?? '').trim();

  if (provider == 'crisp' && crispId.isNotEmpty) {
    return Uri.parse('https://go.crisp.chat/chat/embed/?website_id=$crispId');
  }
  if ((provider == 'tawkto' || provider == 'tawk') && tawkPropertyId.isNotEmpty && tawkWidgetId.isNotEmpty) {
    return Uri.parse('https://tawk.to/chat/$tawkPropertyId/$tawkWidgetId');
  }
  if (provider == 'chatway' && chatwayWidgetId.isNotEmpty) {
    return Uri.parse('https://go.chatway.app/chat/$chatwayWidgetId');
  }

  final direct = _parseUri(config.supportUrl);
  if (direct != null) {
    return direct;
  }

  final supportPayload = (config.supportUrl ?? '').trim();
  final payloadUri = _buildEmbedFromRaw(supportPayload);
  if (payloadUri != null) {
    return payloadUri;
  }

  if (crispId.isNotEmpty) {
    return Uri.parse('https://go.crisp.chat/chat/embed/?website_id=$crispId');
  }
  if (tawkPropertyId.isNotEmpty && tawkWidgetId.isNotEmpty) {
    return Uri.parse('https://tawk.to/chat/$tawkPropertyId/$tawkWidgetId');
  }
  if (chatwayWidgetId.isNotEmpty) {
    return Uri.parse('https://go.chatway.app/chat/$chatwayWidgetId');
  }

  final scriptUrl = (config.supportScriptUrl ?? '').trim();
  final embedHtml = (config.supportEmbedHtml ?? '').trim();
  if (embedHtml.isNotEmpty) {
    return Uri.parse('data:text/html;charset=utf-8,${Uri.encodeComponent(embedHtml)}');
  }
  final scriptPayloadUri = _buildEmbedFromRaw(scriptUrl);
  if (scriptPayloadUri != null) {
    return scriptPayloadUri;
  }
  if (scriptUrl.isNotEmpty) {
    final html =
        '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>V2ET Support</title>
</head>
<body>
  <script src="$scriptUrl"></script>
</body>
</html>
''';
    return Uri.parse('data:text/html;charset=utf-8,${Uri.encodeComponent(html)}');
  }

  return null;
}

Future<bool> openV2etSupport(
  BuildContext context,
  Uri uri, {
  String title = 'Support',
  GlobalKey? anchorKey,
}) async {
  final url = uri.toString().trim();
  if (url.isEmpty) return false;

  final isWindowsDesktop = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  if (isWindowsDesktop) {
    final isServer2022 = Platform.operatingSystemVersion.contains('20348');
    final anchorBox = anchorKey?.currentContext?.findRenderObject() as RenderBox?;
    final anchorTopLeft = anchorBox?.localToGlobal(Offset.zero);
    final anchorSize = anchorBox?.size;
    final viewport = MediaQuery.sizeOf(context);
    final dialogWidth = min(380.0, viewport.width - 16);
    final dialogHeight = min(518.0, viewport.height - 16);
    final defaultX = ((viewport.width - dialogWidth) / 2).clamp(8.0, max(8.0, viewport.width - dialogWidth - 8));
    final defaultY = ((viewport.height - dialogHeight) / 2).clamp(8.0, max(8.0, viewport.height - dialogHeight - 8));
    final rawX = anchorTopLeft == null || anchorSize == null ? defaultX : anchorTopLeft.dx + anchorSize.width - dialogWidth;
    final rawY = anchorTopLeft == null || anchorSize == null ? defaultY : anchorTopLeft.dy - dialogHeight - 10;
    final posX = rawX.clamp(8.0, max(8.0, viewport.width - dialogWidth - 8));
    final posY = rawY.clamp(8.0, max(8.0, viewport.height - dialogHeight - 8));

    if (isServer2022) {
      final anchorLogicalX = anchorTopLeft?.dx ?? ((posX + dialogWidth) - 28);
      final anchorLogicalY = anchorTopLeft?.dy ?? (posY + dialogHeight + 10);
      final anchorLogicalW = anchorSize?.width ?? 28.0;
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final screenRect = _resolveScreenRectFromClientRect(
        context: context,
        x: posX.toDouble(),
        y: posY.toDouble(),
        width: dialogWidth,
        height: dialogHeight,
      );
      final toggled = _toggleExistingSupportWindow(
        posX: screenRect.$1,
        posY: screenRect.$2,
        width: screenRect.$3,
        height: screenRect.$4,
        anchorLogicalX: anchorLogicalX,
        anchorLogicalY: anchorLogicalY,
        anchorLogicalWidth: anchorLogicalW,
        dpr: dpr,
      );
      if (toggled != null) return toggled;
      final reused = _repositionAndShowExistingSupportWindow(
        posX: screenRect.$1,
        posY: screenRect.$2,
        width: screenRect.$3,
        height: screenRect.$4,
        anchorLogicalX: anchorLogicalX,
        anchorLogicalY: anchorLogicalY,
        anchorLogicalWidth: anchorLogicalW,
        dpr: dpr,
      );
      if (reused) return true;
      if (_supportOpeningInProgress) return true;
      _supportOpeningInProgress = true;
      bool opened = false;
      try {
        opened = await _openSupportIsolatedWindow(
          uri: uri,
          title: title,
          posX: screenRect.$1,
          posY: screenRect.$2,
          width: screenRect.$3,
          height: screenRect.$4,
          anchorLogicalX: anchorLogicalX,
          anchorLogicalY: anchorLogicalY,
          anchorLogicalWidth: anchorLogicalW,
          dpr: dpr,
        );
      } finally {
        _supportOpeningInProgress = false;
      }
      if (opened) return true;
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Support',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (_, __, ___) => Stack(
        children: [
          Positioned(
            left: posX.toDouble(),
            top: posY.toDouble(),
            width: dialogWidth,
            height: dialogHeight,
            child: _InAppSupportDialog(title: title, uri: uri),
          ),
        ],
      ),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        return FadeTransition(opacity: anim, child: child);
      },
    );
    return true;
  }

  var opened = await launchUrl(uri, mode: LaunchMode.inAppWebView);
  if (!opened) {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return opened;
}

Future<void> closeV2etSupportWindowIfAny() async {
  final title = _activeSupportWindowTitle;
  if (title == null || title.isEmpty) return;
  final titlePtr = title.toNativeUtf16();
  try {
    final hwnd = FindWindow(nullptr, titlePtr);
    if (hwnd != 0) {
      ShowWindow(hwnd, SW_HIDE);
    }
  } finally {
    calloc.free(titlePtr);
    _activeSupportWindowTitle = null;
    _activeSupportWindowOpenedAt = null;
    _supportWindowHidden = false;
    _supportOpeningInProgress = false;
    _supportWindowActionInProgress = false;
    _supportWindowWatchdog?.cancel();
    _supportWindowWatchdog = null;
  }
}

Future<bool> _openSupportIsolatedWindow({
  required Uri uri,
  required String title,
  required int posX,
  required int posY,
  required int width,
  required int height,
  required double anchorLogicalX,
  required double anchorLogicalY,
  required double anchorLogicalWidth,
  required double dpr,
}) async {
  try {
    _mainWindowHandle = GetForegroundWindow();
    if (_focusExistingSupportWindowIfAlive()) {
      return true;
    }

    final available = await WebviewWindow.isWebviewAvailable();
    if (!available) return false;

    final localAppData = Platform.environment['LOCALAPPDATA'] ?? Platform.environment['APPDATA'] ?? '';
    final userDataFolder = localAppData.isEmpty ? 'V2ET_Support_WebView2' : '$localAppData\\V2ET\\SupportWebView2Window';

    final windowTitle = '$title #V2ET_SUPPORT#';
    _activeSupportWindowTitle = windowTitle;
    _activeSupportWindowOpenedAt = DateTime.now();
    _supportWasForegroundOnce = false;
    _lastForegroundHwnd = 0;
    _supportHideEnabledAfter = DateTime.now().add(const Duration(milliseconds: 900));
    final webview = await WebviewWindow.create(
      configuration: CreateConfiguration(
        title: windowTitle,
        windowWidth: width,
        windowHeight: height,
        windowPosX: posX,
        windowPosY: posY,
        titleBarTopPadding: 0,
        titleBarHeight: 40,
        useWindowPositionAndSize: true,
        userDataFolderWindows: userDataFolder,
      ),
    );
    webview.launch(uri.toString());
    _cacheSupportLayoutMetrics(
      posX,
      posY,
      width,
      height,
      anchorLogicalX: anchorLogicalX,
      anchorLogicalY: anchorLogicalY,
      anchorLogicalWidth: anchorLogicalWidth,
      dpr: dpr,
    );
    unawaited(_hardenSupportWindowLook(windowTitle, posX, posY, width, height));
    _supportWindowWatchdog?.cancel();
    return true;
  } catch (_) {
    return false;
  }
}

bool? _toggleExistingSupportWindow({
  required int posX,
  required int posY,
  required int width,
  required int height,
  required double anchorLogicalX,
  required double anchorLogicalY,
  required double anchorLogicalWidth,
  required double dpr,
}) {
  final now = DateTime.now();
  if (_supportWindowActionInProgress) return true;
  if (_lastSupportWindowActionAt != null &&
      now.difference(_lastSupportWindowActionAt!).inMilliseconds < 260) {
    return true;
  }
  _supportWindowActionInProgress = true;
  _lastSupportWindowActionAt = now;
  final title = _activeSupportWindowTitle;
  if (title == null || title.isEmpty) {
    _supportWindowActionInProgress = false;
    return null;
  }
  final titlePtr = title.toNativeUtf16();
  try {
    final hwnd = FindWindow(nullptr, titlePtr);
    if (hwnd == 0) {
      _activeSupportWindowTitle = null;
      _activeSupportWindowOpenedAt = null;
      return null;
    }
    if (IsWindow(hwnd) == 0) {
      _activeSupportWindowTitle = null;
      _activeSupportWindowOpenedAt = null;
      return null;
    }
    final visible = IsWindowVisible(hwnd) != 0;
    if (visible) {
      ShowWindow(hwnd, SW_HIDE);
      _supportWindowHidden = true;
      return true;
    }
    _cacheSupportLayoutMetrics(
      posX,
      posY,
      width,
      height,
      anchorLogicalX: anchorLogicalX,
      anchorLogicalY: anchorLogicalY,
      anchorLogicalWidth: anchorLogicalWidth,
      dpr: dpr,
    );
    SetWindowPos(
      hwnd,
      HWND_TOPMOST,
      posX,
      posY,
      width,
      height,
      SWP_NOACTIVATE | SWP_FRAMECHANGED | SWP_SHOWWINDOW,
    );
    ShowWindow(hwnd, SW_SHOWNORMAL);
    _supportWindowHidden = false;
    return true;
  } finally {
    _supportWindowActionInProgress = false;
    calloc.free(titlePtr);
  }
}

bool _focusExistingSupportWindowIfAlive() {
  final title = _activeSupportWindowTitle;
  if (title == null || title.isEmpty) return false;
  final titlePtr = title.toNativeUtf16();
  try {
    final hwnd = FindWindow(nullptr, titlePtr);
    if (hwnd == 0) {
      _activeSupportWindowTitle = null;
      _activeSupportWindowOpenedAt = null;
      return false;
    }
    _supportWindowHidden = false;
    ShowWindow(hwnd, SW_SHOWNORMAL);
    SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
    SetForegroundWindow(hwnd);
    return true;
  } finally {
    calloc.free(titlePtr);
  }
}

bool _repositionAndShowExistingSupportWindow({
  required int posX,
  required int posY,
  required int width,
  required int height,
  required double anchorLogicalX,
  required double anchorLogicalY,
  required double anchorLogicalWidth,
  required double dpr,
}) {
  final title = _activeSupportWindowTitle;
  if (title == null || title.isEmpty) return false;
  final titlePtr = title.toNativeUtf16();
  try {
    final hwnd = FindWindow(nullptr, titlePtr);
    if (hwnd == 0) {
      _activeSupportWindowTitle = null;
      _activeSupportWindowOpenedAt = null;
      return false;
    }
    _cacheSupportLayoutMetrics(
      posX,
      posY,
      width,
      height,
      anchorLogicalX: anchorLogicalX,
      anchorLogicalY: anchorLogicalY,
      anchorLogicalWidth: anchorLogicalWidth,
      dpr: dpr,
    );
    SetWindowPos(
      hwnd,
      HWND_TOPMOST,
      posX,
      posY,
      width,
      height,
      SWP_NOACTIVATE | SWP_FRAMECHANGED | SWP_SHOWWINDOW,
    );
    ShowWindow(hwnd, SW_SHOWNORMAL);
    _supportWindowHidden = false;
    return true;
  } finally {
    calloc.free(titlePtr);
  }
}

(int, int, int, int) _resolveScreenRectFromClientRect({
  required BuildContext context,
  required double x,
  required double y,
  required double width,
  required double height,
}) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  final pxX = (x * dpr).round();
  final pxY = (y * dpr).round();
  final pxW = (width * dpr).round();
  final pxH = (height * dpr).round();

  final hwnd = GetForegroundWindow();
  if (hwnd == 0) {
    return (pxX, pxY, pxW, pxH);
  }

  final point = calloc<POINT>();
  try {
    point.ref.x = 0;
    point.ref.y = 0;
    final ok = ClientToScreen(hwnd, point) != 0;
    if (!ok) {
      return (pxX, pxY, pxW, pxH);
    }
    return (point.ref.x + pxX, point.ref.y + pxY, pxW, pxH);
  } finally {
    calloc.free(point);
  }
}

Future<void> _hardenSupportWindowLook(String windowTitle, int posX, int posY, int width, int height) async {
  if (!Platform.isWindows) return;
  for (var i = 0; i < 60; i++) {
    final titlePtr = windowTitle.toNativeUtf16();
    try {
      final hwnd = FindWindow(nullptr, titlePtr);
      if (hwnd != 0) {
        ShowWindow(hwnd, SW_HIDE);
        final style = GetWindowLongPtr(hwnd, GWL_STYLE);
        var newStyle = style;
        newStyle &= ~WS_CAPTION;
        newStyle &= ~WS_THICKFRAME;
        newStyle &= ~WS_MINIMIZEBOX;
        newStyle &= ~WS_MAXIMIZEBOX;
        newStyle &= ~WS_SYSMENU;
        SetWindowLongPtr(hwnd, GWL_STYLE, newStyle);
        SetWindowPos(
          hwnd,
          HWND_TOPMOST,
          posX,
          posY,
          width,
          height,
          SWP_NOACTIVATE | SWP_FRAMECHANGED | SWP_SHOWWINDOW,
        );
        ShowWindow(hwnd, SW_SHOWNORMAL);
        _supportWindowHidden = false;
        return;
      }
    } finally {
      calloc.free(titlePtr);
    }
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }
}

void _startSupportWindowWatchdog() {
  // Disabled: auto-hide behavior caused regressions on Server 2022.
  _supportWindowWatchdog?.cancel();
}

void _cacheSupportLayoutMetrics(
  int screenX,
  int screenY,
  int width,
  int height, {
  required double anchorLogicalX,
  required double anchorLogicalY,
  required double anchorLogicalWidth,
  required double dpr,
}) {
  _supportWidthPx = width;
  _supportHeightPx = height;
  if (_mainWindowHandle == 0) return;

  final pt = calloc<POINT>();
  final rect = calloc<RECT>();
  try {
    pt.ref.x = 0;
    pt.ref.y = 0;
    if (ClientToScreen(_mainWindowHandle, pt) == 0) return;
    if (GetClientRect(_mainWindowHandle, rect) == 0) return;
    final clientW = rect.ref.right - rect.ref.left;
    final clientH = rect.ref.bottom - rect.ref.top;
    _lastMainClientWidthPx = clientW;
    _lastMainClientHeightPx = clientH;
    final anchorX = (anchorLogicalX * dpr).round();
    final anchorY = (anchorLogicalY * dpr).round();
    _anchorWidthPx = (anchorLogicalWidth * dpr).round();
    _anchorMarginRightPx = clientW - (anchorX + _anchorWidthPx);
    _anchorTopPx = anchorY;
    final localX = screenX - pt.ref.x;
    final localY = screenY - pt.ref.y;
    _supportMarginRightPx = clientW - (localX + width);
    _supportMarginTopPx = localY;
  } finally {
    calloc.free(pt);
    calloc.free(rect);
  }
}

void _repositionSupportWindowToMainClient(int supportHwnd) {
  if (_mainWindowHandle == 0 || supportHwnd == 0) return;
  final pt = calloc<POINT>();
  final rect = calloc<RECT>();
  try {
    pt.ref.x = 0;
    pt.ref.y = 0;
    if (ClientToScreen(_mainWindowHandle, pt) == 0) return;
    if (GetClientRect(_mainWindowHandle, rect) == 0) return;
    final clientW = rect.ref.right - rect.ref.left;
    final clientH = rect.ref.bottom - rect.ref.top;
    if (clientW <= 0 || clientH <= 0) return;
    if (clientW == _lastMainClientWidthPx && clientH == _lastMainClientHeightPx) return;

    _lastMainClientWidthPx = clientW;
    _lastMainClientHeightPx = clientH;

    var anchorX = clientW - _anchorMarginRightPx - _anchorWidthPx;
    var anchorY = _anchorTopPx;
    anchorX = anchorX.clamp(8, clientW - _anchorWidthPx - 8);
    anchorY = anchorY.clamp(8, clientH - 8);
    var localX = anchorX + _anchorWidthPx - _supportWidthPx;
    var localY = anchorY - _supportHeightPx - 10;
    localX = localX.clamp(8, clientW - _supportWidthPx - 8);
    localY = localY.clamp(8, clientH - _supportHeightPx - 8);

    final targetX = pt.ref.x + localX;
    final targetY = pt.ref.y + localY;
    SetWindowPos(
      supportHwnd,
      HWND_TOPMOST,
      targetX,
      targetY,
      _supportWidthPx,
      _supportHeightPx,
      SWP_NOACTIVATE | SWP_FRAMECHANGED,
    );
  } finally {
    calloc.free(pt);
    calloc.free(rect);
  }
}


Uri? _parseUri(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme) return null;
  return uri;
}

Uri? _buildEmbedFromRaw(String raw) {
  if (raw.isEmpty) return null;

  final asUri = _parseUri(raw);
  if (asUri != null) {
    return asUri;
  }

  if (raw.startsWith('{') && raw.endsWith('}')) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final map = decoded.map((k, v) => MapEntry(k.toString(), v));
        final direct = _parseUri(map['url']?.toString());
        if (direct != null) return direct;
        final tawkPropertyId =
            map['tawkto_property_id']?.toString().trim() ??
            map['tawk_property_id']?.toString().trim() ??
            map['tawktoPropertyId']?.toString().trim() ??
            '';
        final tawkWidgetId =
            map['tawkto_widget_id']?.toString().trim() ??
            map['tawk_widget_id']?.toString().trim() ??
            map['tawktoWidgetId']?.toString().trim() ??
            '';
        if (tawkPropertyId.isNotEmpty && tawkWidgetId.isNotEmpty) {
          return Uri.parse('https://tawk.to/chat/$tawkPropertyId/$tawkWidgetId');
        }
        final chatwayWidgetId =
            map['chatway_widget_id']?.toString().trim() ?? map['chatwayWidgetId']?.toString().trim() ?? '';
        if (chatwayWidgetId.isNotEmpty) {
          return Uri.parse('https://go.chatway.app/chat/$chatwayWidgetId');
        }
        final crispId =
            map['crisp_website_id']?.toString().trim() ??
            map['crispid']?.toString().trim() ??
            map['website_id']?.toString().trim() ??
            '';
        if (crispId.isNotEmpty) {
          return Uri.parse('https://go.crisp.chat/chat/embed/?website_id=$crispId');
        }
        final scriptUrl = map['script_url']?.toString().trim() ?? '';
        if (scriptUrl.isNotEmpty) {
          return _buildEmbedFromRaw(scriptUrl);
        }
        final embedHtml = map['embed_html']?.toString().trim() ?? '';
        if (embedHtml.isNotEmpty) {
          return Uri.parse('data:text/html;charset=utf-8,${Uri.encodeComponent(embedHtml)}');
        }
      }
    } catch (_) {}
  }

  final lower = raw.toLowerCase();
  if (lower.contains('<html') || lower.contains('<script') || lower.contains('<iframe')) {
    return Uri.parse('data:text/html;charset=utf-8,${Uri.encodeComponent(raw)}');
  }

  if (lower.endsWith('.js') && (lower.startsWith('http://') || lower.startsWith('https://'))) {
    final html =
        '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>V2ET Support</title>
</head>
<body>
  <script src="$raw"></script>
</body>
</html>
''';
    return Uri.parse('data:text/html;charset=utf-8,${Uri.encodeComponent(html)}');
  }

  return null;
}

String _normalizeProvider(String? raw) {
  final value = (raw ?? '').trim().toLowerCase();
  if (value.isEmpty) return '';
  if (value.contains('crisp')) return 'crisp';
  if (value.contains('tawk')) return 'tawkto';
  if (value.contains('chatway')) return 'chatway';
  return value;
}

class _InAppSupportDialog extends StatefulWidget {
  const _InAppSupportDialog({required this.title, required this.uri});

  final String title;
  final Uri uri;

  @override
  State<_InAppSupportDialog> createState() => _InAppSupportDialogState();
}

class _InAppSupportDialogState extends State<_InAppSupportDialog> {
  InAppWebViewController? _controller;
  bool _created = false;
  bool _loaded = false;
  bool _reloading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _supportLog('dialog_init uri=${widget.uri}');
  }

  Future<void> _reloadSupportPage() async {
    final controller = _controller;
    if (controller == null || _reloading) return;
    setState(() {
      _reloading = true;
      _loaded = false;
      _error = null;
    });
    await _supportLog('manual_reload_click uri=${widget.uri}');
    try {
      await controller.loadData(
        data: '<!doctype html><html><body style="margin:0;background:#fff"></body></html>',
        mimeType: 'text/html',
        encoding: 'utf-8',
      );
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await controller.loadUrl(urlRequest: URLRequest(url: WebUri.uri(widget.uri)));
      await _supportLog('manual_reload_load_url uri=${widget.uri}');
    } catch (e) {
      await _supportLog('manual_reload_error $e uri=${widget.uri}');
      if (!mounted) return;
      setState(() {
        _error = 'Reload failed: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _reloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: Colors.white,
        child: Column(
          children: [
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: const Color(0xFF0665D0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: _created && !_reloading ? _reloadSupportPage : null,
                    icon: _reloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.refresh_rounded, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    initialData: InAppWebViewInitialData(
                      data: '<!doctype html><html><body style="margin:0;background:#fff"></body></html>',
                      mimeType: 'text/html',
                      encoding: 'utf-8',
                    ),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      supportMultipleWindows: false,
                    ),
                    onWebViewCreated: (controller) async {
                      _controller = controller;
                      if (!mounted) return;
                      setState(() => _created = true);
                      await _supportLog('onWebViewCreated uri=${widget.uri}');
                      Future<void>.delayed(const Duration(milliseconds: 350), () async {
                        if (!mounted || _controller == null) return;
                        await _supportLog('delayed_load_start uri=${widget.uri}');
                        await _controller!.loadUrl(urlRequest: URLRequest(url: WebUri.uri(widget.uri)));
                      });
                    },
                    onCreateWindow: (controller, createWindowRequest) async {
                      await _supportLog('onCreateWindow blocked target=${createWindowRequest.request.url}');
                      return false;
                    },
                    onLoadStop: (controller, _) {
                      _supportLog('onLoadStop uri=${widget.uri}');
                      if (!mounted) return;
                      setState(() {
                        _loaded = true;
                        _reloading = false;
                      });
                    },
                    onReceivedError: (controller, _, error) {
                      _supportLog('onReceivedError type=${error.type} desc=${error.description}');
                      if (!mounted) return;
                      setState(() {
                        _error = error.description;
                        _reloading = false;
                      });
                    },
                    onWebContentProcessDidTerminate: (controller) {
                      _supportLog('onWebContentProcessDidTerminate uri=${widget.uri}');
                      if (!mounted) return;
                      setState(() {
                        _error = 'WebView process terminated unexpectedly';
                        _reloading = false;
                      });
                    },
                    onLoadStart: (controller, req) {
                      _supportLog('onLoadStart uri=$req');
                    },
                    onConsoleMessage: (controller, msg) {
                      _supportLog('onConsoleMessage level=${msg.messageLevel} text=${msg.message}');
                    },
                  ),
                  if (!_created && _error == null)
                    const Center(child: CircularProgressIndicator()),
                  if (_created && !_loaded && _error == null)
                    const Center(child: CircularProgressIndicator()),
                  if (_error != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Support failed to load.\n$_error', textAlign: TextAlign.center),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _supportLog('dialog_dispose uri=${widget.uri}');
    _controller = null;
    super.dispose();
  }
}

Future<void> _supportLog(String message) async {
  try {
    final localAppData = Platform.environment['LOCALAPPDATA'] ?? Platform.environment['APPDATA'] ?? '';
    if (localAppData.isEmpty) return;
    final logDir = Directory('$localAppData\\V2ET\\logs');
    if (!logDir.existsSync()) {
      logDir.createSync(recursive: true);
    }
    final logFile = File('${logDir.path}\\support_webview.log');
    final now = DateTime.now().toIso8601String();
    await logFile.writeAsString('[$now] $message\n', mode: FileMode.append, flush: true);
  } catch (_) {}
}
