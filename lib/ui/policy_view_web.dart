import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
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
  Widget build(BuildContext context) => _BrowserDocument(
    key: ValueKey(_path),
    content: PolicyContent(_path),
    title: _path == 'index'
        ? '隐私与帮助'
        : PolicyDocument.values.firstWhere((doc) => doc.path == _path).title,
    onNavigate: _navigate,
  );
}

class _BrowserDocument extends StatefulWidget {
  const _BrowserDocument({
    super.key,
    required this.content,
    required this.title,
    required this.onNavigate,
  });
  final PolicyContent content;
  final String title;
  final ValueChanged<String> onNavigate;
  @override
  State<_BrowserDocument> createState() => _BrowserDocumentState();
}

class _BrowserDocumentState extends State<_BrowserDocument> {
  static int _next = 0;
  late final String _type;
  late final web.HTMLIFrameElement _frame;
  late final JSFunction _onLoad, _onError;
  Timer? _timeout;
  bool _loading = true, _textOnly = false;

  @override
  void initState() {
    super.initState();
    _type = 'frame-policy-${_next++}';
    _frame = web.HTMLIFrameElement()
      ..title = widget.title
      ..referrerPolicy = 'no-referrer';
    // The page itself cannot run scripts. The parent app handles link navigation.
    _frame.setAttribute('sandbox', 'allow-same-origin allow-popups');
    _frame.style
      ..width = '100%'
      ..height = '100%'
      ..border = '0'
      ..backgroundColor = '#f5f5ef'
      ..visibility = 'hidden';
    _onLoad = ((web.Event _) {
      if (!mounted || _frame.contentDocument?.body == null) return;
      final document = _frame.contentDocument!;
      final links = document.querySelectorAll('a[href]');
      for (var i = 0; i < links.length; i++) {
        final link = links.item(i) as web.HTMLAnchorElement;
        link.addEventListener(
          'click',
          ((web.Event event) {
            if (!mounted) return;
            event.preventDefault();
            final uri = widget.content.uri.resolve(link.getAttribute('href')!);
            final path = policyPath(uri);
            if (path != null) {
              if (path == widget.content.path && uri.hasFragment) {
                document.getElementById(uri.fragment)?.scrollIntoView();
              } else {
                widget.onNavigate(path);
              }
            } else if (isPolicyExternalLink(uri)) {
              web.window.open(uri.toString(), '_blank', 'noopener,noreferrer');
            }
          }).toJS,
        );
      }
      _timeout?.cancel();
      _frame.style.visibility = 'visible';
      setState(() => _loading = false);
    }).toJS;
    _onError = ((web.Event _) => _failed()).toJS;
    _frame.addEventListener('load', _onLoad);
    _frame.addEventListener('error', _onError);
    _frame.srcdoc = widget.content.html.toJS;
    ui.platformViewRegistry.registerViewFactory(_type, (_) => _frame);
    _timeout = Timer(const Duration(seconds: 8), _failed);
  }

  void _failed() {
    if (!mounted) return;
    _timeout?.cancel();
    _frame.style.visibility = 'hidden';
    setState(() {
      _loading = false;
      _textOnly = true;
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _frame.removeEventListener('load', _onLoad);
    _frame.removeEventListener('error', _onError);
    _frame.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _textOnly
      ? PolicyText(html: widget.content.html)
      : Stack(
          fit: StackFit.expand,
          children: [
            HtmlElementView(viewType: _type),
            if (_loading) const PolicyLoading(),
          ],
        );
}
