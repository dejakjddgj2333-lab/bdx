// 应用全局接口配置
// 如需本地开发联调，把 USE_DEV_SERVER 改成 true 即可
const bool USE_DEV_SERVER = true;

const String DEV_BASE_URL = 'http://localhost:3002/api';
const String DEV_WS_URL = 'ws://localhost:3002/ws/voice-call';
const String DEV_UPLOAD_BASE_URL = 'http://localhost:3002';

const String PROD_BASE_URL = 'https://bdxapi.com/api';
const String PROD_WS_URL = 'wss://bdxapi.com/ws/voice-call';
const String PROD_UPLOAD_BASE_URL = 'https://bdxapi.com';

class ApiConstants {
  ApiConstants._();

  static String get baseUrl => USE_DEV_SERVER ? DEV_BASE_URL : PROD_BASE_URL;
  static String get wsUrl => USE_DEV_SERVER ? DEV_WS_URL : PROD_WS_URL;
  static String get uploadBaseUrl =>
      USE_DEV_SERVER ? DEV_UPLOAD_BASE_URL : PROD_UPLOAD_BASE_URL;

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
