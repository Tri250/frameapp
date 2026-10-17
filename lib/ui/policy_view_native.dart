import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/policy_content.dart';
import '../services/privacy.dart';
import 'policy_loading.dart';

class PolicyView extends StatefulWidget {
  const PolicyView({super.key, required this.document, this.onPageChanged});
  final PolicyDocument document;
  final ValueChanged<String>? onPageChanged;
  @override
  State<PolicyView> createState() => _PolicyViewState();
}

class _PolicyViewState extends State<PolicyView> {
  late String _path = widget.document.path;

  void _navigate(String path) {
    if (_path == path) return;
    setState(() => _path = path);
    widget.onPageChanged?.call(path);
  }

  @override
  Widget build(BuildContext context) => _NativeDocument(
    key: ValueKey(_path),
    content: PolicyContent(_path),
    onNavigate: _navigate,
  );
}

class _NativeDocument extends StatefulWidget {
  const _NativeDocument({
    super.key,
    required this.content,
    required this.onNavigate,
  });
  final PolicyContent content;
  final ValueChanged<String> onNavigate;
  @override
  State<_NativeDocument> createState() => _NativeDocumentState();
}

class _NativeDocumentState extends State<_NativeDocument> {
  WebViewController? _controller;
  Timer? _timeout;
  bool _loading = true, _textOnly = false;

  @override
  void initState() {
    super.initState();
    if (WebViewPlatform.instance == null) {
      _textOnly = true;
      _loading = false;
      return;
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(policyPaper)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!mounted) return;
            _timeout?.cancel();
            setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame != false) _failed();
          },
          onNavigationRequest: (request) {
            if (!mounted) return NavigationDecision.prevent;
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            if (uri.toString() == 'about:blank') {
              return NavigationDecision.navigate;
            }
            final path = policyPath(uri);
            if (path != null) {
              if (path == widget.content.path &&
                  (_loading || uri.hasFragment)) {
                return NavigationDecision.navigate;
              }
              widget.onNavigate(path);
            } else if (isPolicyExternalLink(uri)) {
              unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
            }
            return NavigationDecision.prevent;
          },
        ),
      );
    _timeout = Timer(const Duration(seconds: 8), _failed);
    unawaited(_render());
  }

  Future<void> _render() async {
    try {
      await _controller!.loadHtmlString(
        widget.content.html,
        baseUrl: widget.content.uri.toString(),
      );
    } catch (_) {
      _failed();
    }
  }

  void _failed() {
    if (!mounted) return;
    _timeout?.cancel();
    setState(() {
      _textOnly = true;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_textOnly) return PolicyText(html: widget.content.html);
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _controller!),
        if (_loading) const PolicyLoading(),
      ],
    );
  }
}
