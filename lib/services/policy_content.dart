import 'policy_pages.g.dart';

Uri policyDocumentUri(String path) =>
    Uri(scheme: 'frame-policy', path: '/$path');

String? policyPath(Uri uri) {
  if ((uri.hasScheme && uri.scheme != 'frame-policy') ||
      uri.hasAuthority ||
      uri.hasQuery) {
    return null;
  }
  final parts = uri.pathSegments.where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return 'index';
  return parts.length == 1 && policyPages.containsKey(parts.single)
      ? parts.single
      : null;
}

bool isPolicyExternalLink(Uri uri) =>
    uri.scheme == 'mailto' ||
    (uri.scheme == 'https' && uri.host == 'github.com' && uri.userInfo.isEmpty);

class PolicyContent {
  PolicyContent(this.path) {
    if (!policyPages.containsKey(path)) {
      throw ArgumentError.value(path, 'path', 'Unknown policy document');
    }
  }

  final String path;
  String get html => policyPages[path]!;
  Uri get uri => policyDocumentUri(path);
}
