import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../providers/purchase_provider.dart';
import '../services/app_device_info_service.dart';

class LegalDocumentScreen extends StatefulWidget {
  final String title;
  final String? assetPath;
  final String? initialUrl;
  final bool showTitleBar;
  final bool showBackButton;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    this.assetPath,
    this.initialUrl,
    this.showTitleBar = true,
    this.showBackButton = true,
  }) : assert(
         (assetPath == null) != (initialUrl == null),
         'Provide exactly one of assetPath or initialUrl.',
       );

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  static const String _windowOpenChannelName = 'LegalWindowOpen';
  static const String _closeChannelName = 'close';
  static const String _browserChannelName = 'browser';
  static const String _systemChannelName = 'system';
  static const String _productChannelName = 'product';

  late final WebViewController _controller;
  bool _isLoading = true;

  Map<String, String>? _decodeProductMessage(String rawMessage) {
    try {
      final dynamic decoded = jsonDecode(rawMessage);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
        );
      }
    } catch (_) {
      // Fall back to the loose `{key: value}` payload format emitted by web content.
    }

    final String trimmed = rawMessage.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
      return null;
    }

    final String body = trimmed.substring(1, trimmed.length - 1).trim();
    if (body.isEmpty) {
      return <String, String>{};
    }

    final Map<String, String> data = <String, String>{};
    for (final String entry in body.split(',')) {
      final int separatorIndex = entry.indexOf(':');
      if (separatorIndex <= 0) {
        continue;
      }

      final String key = entry.substring(0, separatorIndex).trim();
      final String value = entry.substring(separatorIndex + 1).trim();
      if (key.isNotEmpty) {
        data[key] = value;
      }
    }

    return data.isEmpty ? null : data;
  }

  @override
  void initState() {
    super.initState();
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller =
        WebViewController.fromPlatformCreationParams(
            params,
            onPermissionRequest: (WebViewPermissionRequest request) {
              request.grant();
            },
          )
          ..addJavaScriptChannel(
            _windowOpenChannelName,
            onMessageReceived: (JavaScriptMessage message) {
              _openChildDocument(message.message);
            },
          )
          ..addJavaScriptChannel(
            _closeChannelName,
            onMessageReceived: (_) {
              if (mounted) {
                Navigator.maybePop(context);
              }
            },
          )
          ..addJavaScriptChannel(
            _browserChannelName,
            onMessageReceived: (JavaScriptMessage message) {
              _openInSystemBrowser(message.message);
            },
          )
          ..addJavaScriptChannel(
            _systemChannelName,
            onMessageReceived: (JavaScriptMessage message) async {
              final info = await AppDeviceInfoService.instance.getInfo();
              final payload = info.toSystemPayload();
              final payloadJson = jsonEncode(payload);
              final cbName = message.message;
              await _controller.runJavaScript(
                'window.$cbName?.($payloadJson);',
              );
            },
          )
          ..addJavaScriptChannel(
            _productChannelName,
            onMessageReceived: (JavaScriptMessage message) async {
              try {
                final data = _decodeProductMessage(message.message);
                final productId = data?['productId'];
                final outTradeNo = data?['outTradeNo'];
                if (productId != null && outTradeNo != null && mounted) {
                  final provider = Provider.of<PurchaseProvider>(
                    context,
                    listen: false,
                  );
                  await provider.purchaseProduct(
                    productId,
                    applicationUserName: outTradeNo,
                  );
                }
              } catch (e) {
                debugPrint('Product channel error: $e');
              }
            },
          )
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (_) {
                if (mounted) {
                  setState(() => _isLoading = true);
                }
              },
              onPageFinished: (_) async {
                await _injectWindowOpenBridge();
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              },
            ),
          )
          ..setHorizontalScrollBarEnabled(false)
          ..setOverScrollMode(WebViewOverScrollMode.never);

    if (_controller.platform is WebKitWebViewController) {
      final WebKitWebViewController webKitController =
          _controller.platform as WebKitWebViewController;
      webKitController.setAllowsBackForwardNavigationGestures(false);
    }

    _loadInitialContent();
  }

  Future<void> _loadInitialContent() async {
    if (widget.initialUrl != null) {
      await _controller.loadRequest(Uri.parse(widget.initialUrl!));
      return;
    }

    await _controller.loadFlutterAsset(widget.assetPath!);
  }

  Future<void> _injectWindowOpenBridge() {
    return _controller.runJavaScript('''
      (function() {
        if (window.__legalDocumentWindowOpenPatched) {
          return;
        }
        window.__legalDocumentWindowOpenPatched = true;
        const originalOpen =
          typeof window.open === 'function' ? window.open.bind(window) : null;
        window.open = function(url) {
          if (url) {
            try {
              const resolvedUrl = String(new URL(String(url), window.location.href));
              $_windowOpenChannelName.postMessage(resolvedUrl);
              return null;
            } catch (_) {}
          }
          if (originalOpen) {
            return originalOpen.apply(window, arguments);
          }
          return null;
        };
      })();
    ''');
  }

  void _openChildDocument(String rawUrl) {
    final String url = rawUrl.trim();
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(
          title: widget.title,
          initialUrl: uri.toString(),
          showTitleBar: widget.showTitleBar,
          showBackButton: widget.showBackButton,
        ),
      ),
    );
  }

  Future<void> _openInSystemBrowser(String rawUrl) async {
    final String url = rawUrl.trim();
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final bool showAppBar = widget.showTitleBar || widget.showBackButton;
    final bool isFullScreen = !widget.showTitleBar && !widget.showBackButton;
    final PreferredSizeWidget? appBar = showAppBar
        ? AppBar(
            automaticallyImplyLeading: widget.showBackButton,
            leading: widget.showBackButton ? null : const SizedBox.shrink(),
            title: widget.showTitleBar ? Text(widget.title) : null,
          )
        : null;
    final Widget content = Stack(
      children: [
        Positioned.fill(child: WebViewWidget(controller: _controller)),
        if (_isLoading) const Center(child: CircularProgressIndicator()),
      ],
    );

    return Scaffold(
      extendBodyBehindAppBar: isFullScreen,
      appBar: appBar,
      body: isFullScreen ? content : SafeArea(top: false, child: content),
    );
  }
}
