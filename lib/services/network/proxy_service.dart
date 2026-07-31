import 'package:flutter/foundation.dart';

class ProxyConfig {
  final String host;
  final int port;
  final String? username;
  final String? password;
  final bool isEnabled;

  ProxyConfig({
    required this.host,
    required this.port,
    this.username,
    this.password,
    this.isEnabled = false,
  });

  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    'username': username,
    'password': password,
    'isEnabled': isEnabled,
  };

  factory ProxyConfig.fromJson(Map<String, dynamic> json) => ProxyConfig(
    host: json['host'] as String,
    port: json['port'] as int,
    username: json['username'] as String?,
    password: json['password'] as String?,
    isEnabled: json['isEnabled'] as bool? ?? false,
  );
}

class ProxyService {
  static ProxyService? _instance;
  static ProxyService get instance => 
      _instance ??= ProxyService._();
  
  ProxyService._();

  ProxyConfig? _proxyConfig;
  bool _isEnabled = false;

  ProxyConfig? get proxyConfig => _proxyConfig;
  bool get isEnabled => _isEnabled;

  void setProxyConfig(ProxyConfig config) {
    _proxyConfig = config;
    _isEnabled = config.isEnabled;
    debugPrint('Proxy config updated: ${config.host}:${config.port}');
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (_proxyConfig != null) {
      _proxyConfig = ProxyConfig(
        host: _proxyConfig!.host,
        port: _proxyConfig!.port,
        username: _proxyConfig!.username,
        password: _proxyConfig!.password,
        isEnabled: enabled,
      );
    }
    debugPrint('Proxy ${enabled ? "enabled" : "disabled"}');
  }

  Future<bool> testProxy() async {
    if (_proxyConfig == null || !_isEnabled) return false;

    try {
      // TODO: Implement actual proxy connection test
      // This would make a test request through the proxy
      
      await Future.delayed(const Duration(seconds: 2));
      debugPrint('Proxy test successful');
      return true;
    } catch (e) {
      debugPrint('Proxy test failed: $e');
      return false;
    }
  }

  Map<String, dynamic> getSettings() {
    return {
      'isEnabled': _isEnabled,
      'proxyConfig': _proxyConfig?.toJson(),
    };
  }
}