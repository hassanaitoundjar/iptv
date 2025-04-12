import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

class AuthService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  /// Attempts to authenticate with an Xtream IPTV server
  /// 
  /// Returns a Map with user information on success
  /// Throws an exception on failure
  Future<Map<String, dynamic>> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    try {
      // Format the URL properly, ensuring it ends with /player_api.php
      final baseUrl = _formatServerUrl(serverUrl);
      final url = Uri.parse('$baseUrl/player_api.php?username=$username&password=$password');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        
        // Check if the response contains an error
        if (jsonResponse is Map && jsonResponse.containsKey('user_info')) {
          // Authentication successful
          return Map<String, dynamic>.from(jsonResponse);
        } else if (jsonResponse is Map && jsonResponse.containsKey('message')) {
          // API returned an error message
          throw Exception(jsonResponse['message']);
        } else {
          throw Exception('Invalid server response');
        }
      } else {
        throw Exception('Failed to authenticate: Status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Authentication failed: ${e.toString()}');
    }
  }
  
  /// Authenticate using an M3U playlist URL
  Future<void> loginWithM3U({required String playlistUrl}) async {
    try {
      // Validate the M3U URL
      final formattedUrl = _formatM3UUrl(playlistUrl);
      
      // Try to fetch the playlist to validate it
      final response = await http.get(Uri.parse(formattedUrl));
      
      if (response.statusCode == 200) {
        final content = response.body;
        
        // Basic validation of M3U content - should start with #EXTM3U
        if (content.trim().startsWith('#EXTM3U')) {
          // Store the M3U playlist URL
          await _secureStorage.write(key: 'playlist_url', value: formattedUrl);
          await _secureStorage.write(key: 'login_type', value: 'm3u');
          await _secureStorage.write(key: 'is_logged_in', value: 'true');
          
          // Cache playlist content
          await _secureStorage.write(key: 'playlist_content', value: content);
          
          return;
        } else {
          throw Exception('Invalid M3U playlist format');
        }
      } else {
        throw Exception('Failed to fetch playlist: Status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('M3U authentication failed: ${e.toString()}');
    }
  }
  
  /// Format the server URL to ensure it's properly structured
  String _formatServerUrl(String url) {
    String formattedUrl = url.trim();
    
    // Remove trailing slashes
    while (formattedUrl.endsWith('/')) {
      formattedUrl = formattedUrl.substring(0, formattedUrl.length - 1);
    }
    
    // Ensure URL has http:// or https:// prefix
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'http://$formattedUrl';
    }
    
    return formattedUrl;
  }
  
  /// Format the M3U URL to ensure it's properly structured
  String _formatM3UUrl(String url) {
    String formattedUrl = url.trim();
    
    // Ensure URL has http:// or https:// prefix
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'http://$formattedUrl';
    }
    
    return formattedUrl;
  }
  
  /// Stores user credentials and session data
  Future<void> saveUserSession(Map<String, dynamic> userData, String serverUrl) async {
    final user = XtreamUser.fromJson(userData, serverUrl);
    await _secureStorage.write(key: 'user_data', value: json.encode(user.toJson()));
    await _secureStorage.write(key: 'login_type', value: 'xtream');
    await _secureStorage.write(key: 'is_logged_in', value: 'true');
    
    // Store server info separately for easier access in live TV screens
    final serverInfo = {
      'username': user.username,
      'password': user.password,
      'server_url': user.serverUrl,
    };
    await _secureStorage.write(key: 'xtream_server_info', value: json.encode(serverInfo));
  }
  
  /// Retrieve stored user data
  Future<XtreamUser?> getUserData() async {
    final userDataString = await _secureStorage.read(key: 'user_data');
    if (userDataString != null) {
      final userData = json.decode(userDataString) as Map<String, dynamic>;
      final serverUrl = userData['server_url'] as String;
      return XtreamUser.fromJson({'user_info': userData}, serverUrl);
    }
    return null;
  }
  
  /// Get the login type (xtream or m3u)
  Future<String> getLoginType() async {
    return await _secureStorage.read(key: 'login_type') ?? 'xtream';
  }
  
  /// Get M3U playlist URL if available
  Future<String?> getM3UPlaylistUrl() async {
    return await _secureStorage.read(key: 'playlist_url');
  }
  
  /// Get cached M3U playlist content if available
  Future<String?> getM3UPlaylistContent() async {
    return await _secureStorage.read(key: 'playlist_content');
  }
  
  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final value = await _secureStorage.read(key: 'is_logged_in');
    return value == 'true';
  }
  
  /// Clears stored user data on logout
  Future<void> logout() async {
    await _secureStorage.delete(key: 'user_data');
    await _secureStorage.delete(key: 'is_logged_in');
    await _secureStorage.delete(key: 'login_type');
    await _secureStorage.delete(key: 'playlist_url');
    await _secureStorage.delete(key: 'playlist_content');
  }
  
  /// Get Xtream server information
  Future<Map<String, dynamic>?> getXtreamServerInfo() async {
    final serverInfoJson = await _secureStorage.read(key: 'xtream_server_info');
    if (serverInfoJson != null) {
      return json.decode(serverInfoJson) as Map<String, dynamic>;
    }
    
    // Fallback: try to extract from user_data if xtream_server_info is not available
    final userDataJson = await _secureStorage.read(key: 'user_data');
    if (userDataJson != null) {
      final userData = json.decode(userDataJson) as Map<String, dynamic>;
      return {
        'username': userData['username'],
        'password': userData['password'],
        'server_url': userData['server_url'],
      };
    }
    
    return null;
  }
} 