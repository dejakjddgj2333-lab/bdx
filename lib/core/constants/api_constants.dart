// 应用全局接口配置
// 如需本地开发联调，把 useDevServer 改成 true 即可
const bool useDevServer = false;

const String devBaseUrl = 'http://localhost:3002/api';
const String devWsUrl = 'ws://localhost:3002/ws/voice-call';
const String devUploadBaseUrl = 'http://localhost:3002';

const String prodBaseUrl = 'https://bdxapi.com/api';
const String prodWsUrl = 'wss://bdxapi.com/ws/voice-call';
const String prodUploadBaseUrl = 'https://bdxapi.com';

class ApiConstants {
  ApiConstants._();

  static String get baseUrl => useDevServer ? devBaseUrl : prodBaseUrl;
  static String get wsUrl => useDevServer ? devWsUrl : prodWsUrl;
  static String get uploadBaseUrl =>
      useDevServer ? devUploadBaseUrl : prodUploadBaseUrl;

  // 接口路径
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refreshToken = '/auth/refresh';
  static const String userProfile = '/user/profile';
  static const String userSettings = '/user/settings';

  static const String models = '/models';
  static const String uploadImage = '/chat/upload-image';
  static const String promptSuggestions = '/prompt-suggestions';
  static const String conversations = '/conversations';
  static const String sendMessage = '/chat/send';
  static const String streamChat = '/chat/stream';

  static const String agents = '/agents';
  static const String voiceProvider = '/voice-call/provider';
}
