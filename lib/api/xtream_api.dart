import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

class XtreamAPI {
  final XtreamUser user;
  
  XtreamAPI(this.user);
  
  // Base URL for API requests
  String get _baseUrl => user.serverUrl;
  
  // Common query parameters for authentication
  Map<String, String> get _authParams => {
    'username': user.username,
    'password': user.password,
  };
  
  // Get live TV categories
  Future<List<dynamic>> getLiveCategories() async {
    final url = Uri.parse('$_baseUrl/player_api.php')
        .replace(queryParameters: {
      ..._authParams,
      'action': 'get_live_categories',
    });
    
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load live categories');
    }
  }
  
  // Get live TV channels
  Future<List<dynamic>> getLiveStreams({String? categoryId}) async {
    final queryParams = {
      ..._authParams,
      'action': 'get_live_streams',
    };
    
    if (categoryId != null) {
      queryParams['category_id'] = categoryId;
    }
    
    final url = Uri.parse('$_baseUrl/player_api.php')
        .replace(queryParameters: queryParams);
    
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load live streams');
    }
  }
  
  // Get VOD categories
  Future<List<dynamic>> getVodCategories() async {
    final url = Uri.parse('$_baseUrl/player_api.php')
        .replace(queryParameters: {
      ..._authParams,
      'action': 'get_vod_categories',
    });
    
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load VOD categories');
    }
  }
  
  // Get VOD streams (movies)
  Future<List<dynamic>> getVodStreams({String? categoryId}) async {
    final queryParams = {
      ..._authParams,
      'action': 'get_vod_streams',
    };
    
    if (categoryId != null) {
      queryParams['category_id'] = categoryId;
    }
    
    final url = Uri.parse('$_baseUrl/player_api.php')
        .replace(queryParameters: queryParams);
    
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load VOD streams');
    }
  }
  
  // Get series categories
  Future<List<dynamic>> getSeriesCategories() async {
    final url = Uri.parse('$_baseUrl/player_api.php')
        .replace(queryParameters: {
      ..._authParams,
      'action': 'get_series_categories',
    });
    
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load series categories');
    }
  }
  
  // Get all series
  Future<List<dynamic>> getSeries({String? categoryId}) async {
    final queryParams = {
      ..._authParams,
      'action': 'get_series',
    };
    
    if (categoryId != null) {
      queryParams['category_id'] = categoryId;
    }
    
    final url = Uri.parse('$_baseUrl/player_api.php')
        .replace(queryParameters: queryParams);
    
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load series');
    }
  }
  
  // Get series info (seasons and episodes)
  Future<Map<String, dynamic>> getSeriesInfo(String seriesId) async {
    final url = Uri.parse('$_baseUrl/player_api.php')
        .replace(queryParameters: {
      ..._authParams,
      'action': 'get_series_info',
      'series_id': seriesId,
    });
    
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load series info');
    }
  }
  
  // Get stream URL for live TV
  String getLiveStreamUrl(String streamId) {
    return '$_baseUrl/live/${user.username}/${user.password}/$streamId.ts';
  }
  
  // Get stream URL for VOD
  String getVodStreamUrl(String streamId) {
    return '$_baseUrl/movie/${user.username}/${user.password}/$streamId.mp4';
  }
  
  // Get stream URL for series episode
  String getSeriesStreamUrl(String id, String seriesId, String seasonNumber) {
    return '$_baseUrl/series/${user.username}/${user.password}/$id/$seriesId/$seasonNumber.mp4';
  }
} 