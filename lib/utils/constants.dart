const String deepLinkScheme = 'foodchoose';
const String deepLinkHost = 'join';

// TODO: Firebase 프로젝트 ID로 교체 (예: foodchoose-12345.web.app)
const String webDomain = 'foodchoose-4f82e.web.app';

/// 초대 공유 링크 생성 (HTTPS — 앱 미설치 시 웹으로 이동)
String buildInviteLink(String code) => 'https://$webDomain/join?code=$code';
