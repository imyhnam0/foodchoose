import 'package:app_links/app_links.dart';
import 'constants.dart';

class DeepLinkHandler {
  final AppLinks _appLinks = AppLinks();

  /// 앱이 실행 중일 때 들어오는 딥링크 스트림
  Stream<String?> get onDeepLink {
    return _appLinks.uriLinkStream.map(_extractCode);
  }

  /// 앱이 종료 상태에서 딥링크로 실행될 때의 초기 링크
  Future<String?> getInitialCode() async {
    final uri = await _appLinks.getInitialLink();
    return _extractCode(uri);
  }

  /// 커스텀 스킴(foodchoose://join?code=XXX) 및
  /// HTTPS Universal/App Link(https://domain/join?code=XXX) 모두 처리
  String? _extractCode(Uri? uri) {
    if (uri == null) return null;

    final isCustomScheme =
        uri.scheme == deepLinkScheme && uri.host == deepLinkHost;
    final isHttpLink = (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host == webDomain &&
        uri.path.startsWith('/join');

    if (!isCustomScheme && !isHttpLink) return null;
    return uri.queryParameters['code'];
  }
}
