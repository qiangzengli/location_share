/// 应用配置（高德 Key、后端 API 等）。
abstract final class Env {
  static const String amapAndroidKey = '1aa7896b7dcd7e06e5636eeb80899065';
  static const String amapIosKey = '085624778cf85f5ebec0951a31e7a26e';

  /// Spring Boot 根 URL，例如 `http://10.0.2.2:8080`（Android 模拟器访问本机）。
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// 可选：调试时在命令行注入；持久化 token 见 [LocalPrefs]。
  static const String apiAccessToken = String.fromEnvironment(
    'API_ACCESS_TOKEN',
    defaultValue: '',
  );

  static bool get hasHttpBackend => apiBaseUrl.isNotEmpty;
}
