import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/m3u_service.dart';
import '../models/user_model.dart';
import '../api/xtream_api.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class ContentLoadingScreen extends StatefulWidget {
  const ContentLoadingScreen({super.key});

  @override
  State<ContentLoadingScreen> createState() => _ContentLoadingScreenState();
}

class _ContentLoadingScreenState extends State<ContentLoadingScreen> {
  final AuthService _authService = AuthService();
  final M3UService _m3uService = M3UService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  String _statusMessage = 'Initializing...';
  double _progressValue = 0.0;
  bool _hasError = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadContent();
  }
  
  Future<void> _loadContent() async {
    try {
      // Check login type
      final loginType = await _authService.getLoginType();
      
      if (loginType == 'xtream') {
        await _loadXtreamContent();
      } else if (loginType == 'm3u') {
        await _loadM3UContent();
      } else {
        throw Exception('Unknown login type');
      }
      
      // Navigate to home screen after successful loading
      if (mounted) {
        // Add a small delay to show the completed progress bar
        await Future.delayed(const Duration(milliseconds: 500));
        
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }
  
  Future<void> _loadXtreamContent() async {
    try {
      // Get user data
      final XtreamUser? user = await _authService.getUserData();
      if (user == null) {
        throw Exception('User data not found');
      }
      
      // Create API client
      final api = XtreamAPI(user);
      
      // Update status
      _updateStatus('Loading live categories...', 0.1);
      
      // Load and cache live categories
      final liveCategories = await api.getLiveCategories();
      await _secureStorage.write(
        key: 'live_categories',
        value: json.encode(liveCategories),
      );
      
      _updateStatus('Loading live channels...', 0.3);
      
      // Load and cache live channels
      final liveChannels = await api.getLiveStreams();
      await _secureStorage.write(
        key: 'live_channels',
        value: json.encode(liveChannels),
      );
      
      _updateStatus('Loading VOD categories...', 0.5);
      
      // Load and cache VOD categories
      final vodCategories = await api.getVodCategories();
      await _secureStorage.write(
        key: 'vod_categories',
        value: json.encode(vodCategories),
      );
      
      _updateStatus('Loading VOD content...', 0.7);
      
      // Load and cache VOD content (sample of first 100 items to avoid long loading)
      final vodContent = await api.getVodStreams();
      await _secureStorage.write(
        key: 'vod_content',
        value: json.encode(vodContent.take(100).toList()),
      );
      
      _updateStatus('Loading series categories...', 0.9);
      
      // Load and cache series categories
      final seriesCategories = await api.getSeriesCategories();
      await _secureStorage.write(
        key: 'series_categories',
        value: json.encode(seriesCategories),
      );
      
      _updateStatus('Content loaded successfully!', 1.0);
      
      // Save a timestamp for the content
      await _secureStorage.write(
        key: 'content_last_updated',
        value: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      throw Exception('Failed to load Xtream content: ${e.toString()}');
    }
  }
  
  Future<void> _loadM3UContent() async {
    try {
      // Get playlist URL
      final playlistUrl = await _authService.getM3UPlaylistUrl();
      if (playlistUrl == null) {
        throw Exception('Playlist URL not found');
      }
      
      // Check if we have a cached playlist
      String? playlistContent = await _authService.getM3UPlaylistContent();
      
      _updateStatus('Loading M3U playlist...', 0.3);
      
      if (playlistContent == null) {
        // Fetch playlist if not cached
        final response = await _m3uService.fetchPlaylist(playlistUrl);
        
        // Save the channels to storage
        await _secureStorage.write(
          key: 'playlist_channels',
          value: json.encode(response.map((channel) => {
            'name': channel.name,
            'url': channel.url,
            'logo': channel.logo,
            'group': channel.group,
            'id': channel.id,
            'attributes': channel.attributes,
          }).toList()),
        );
      } else {
        // Parse the cached playlist
        final channels = _m3uService.parsePlaylist(playlistContent);
        
        // Save the channels to storage
        await _secureStorage.write(
          key: 'playlist_channels',
          value: json.encode(channels.map((channel) => {
            'name': channel.name,
            'url': channel.url,
            'logo': channel.logo,
            'group': channel.group,
            'id': channel.id,
            'attributes': channel.attributes,
          }).toList()),
        );
      }
      
      _updateStatus('Organizing content...', 0.7);
      
      // Also get grouped channels
      final rawChannels = await _secureStorage.read(key: 'playlist_channels');
      if (rawChannels != null) {
        final List<dynamic> channelList = json.decode(rawChannels);
        final List<M3UChannel> channels = channelList.map((item) => M3UChannel(
          name: item['name'],
          url: item['url'],
          logo: item['logo'],
          group: item['group'],
          id: item['id'],
          attributes: Map<String, String>.from(item['attributes'] ?? {}),
        )).toList();
        
        final groups = _m3uService.groupChannels(channels);
        
        // Save grouped channel structure
        await _secureStorage.write(
          key: 'channel_groups',
          value: json.encode(groups.map((key, value) => MapEntry(
            key,
            value.map((channel) => {
              'name': channel.name,
              'url': channel.url,
              'logo': channel.logo,
              'id': channel.id,
            }).toList()
          ))),
        );
      }
      
      _updateStatus('Content loaded successfully!', 1.0);
      
      // Save a timestamp for the content
      await _secureStorage.write(
        key: 'content_last_updated',
        value: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      throw Exception('Failed to load M3U content: ${e.toString()}');
    }
  }
  
  void _updateStatus(String message, double progress) {
    setState(() {
      _statusMessage = message;
      _progressValue = progress;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Colors.black.withOpacity(0.8),
              Colors.red.withOpacity(0.7),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App logo or title
                  const Text(
                    'IPTV PLAYER',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Loading animation - red Netflix-like spinner
                  if (!_hasError) ...[
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: _progressValue == 0 ? null : _progressValue,
                        color: Colors.red,
                        strokeWidth: 4,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Progress bar
                    LinearProgressIndicator(
                      value: _progressValue,
                      backgroundColor: Colors.grey[800],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                      minHeight: 6,
                    ),
                    const SizedBox(height: 24),
                    
                    // Status message
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please wait while we prepare your content...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                  
                  // Error message
                  if (_hasError) ...[
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 60,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Error Loading Content',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage ?? 'An unknown error occurred',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        // Retry loading content
                        setState(() {
                          _hasError = false;
                          _errorMessage = null;
                          _progressValue = 0.0;
                          _statusMessage = 'Initializing...';
                        });
                        _loadContent();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Retry'),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        // Go back to login screen
                        _authService.logout().then((_) {
                          Navigator.of(context).pushReplacementNamed('/login');
                        });
                      },
                      child: const Text(
                        'Back to Login',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 