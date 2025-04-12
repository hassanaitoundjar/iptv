import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import '../player/video_player_screen.dart';
import 'dart:convert';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';

class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key});

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> {
  final AuthService _authService = AuthService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // UI state
  bool _isLoading = true;
  bool _showSearchBar = false;
  
  // Content state
  String _loginType = 'xtream';
  List<dynamic> _categories = [];
  List<dynamic> _liveChannels = [];
  String _selectedCategory = 'All';
  List<dynamic> _filteredChannels = [];
  int _selectedChannelIndex = -1;
  
  // Search
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get login type
      final loginType = await _authService.getLoginType();
      _loginType = loginType;
      
      // Load content based on login type
      if (loginType == 'xtream') {
        await _loadXtreamContent();
      } else if (loginType == 'm3u') {
        await _loadM3UContent();
      }
      
      setState(() {
        _isLoading = false;
        _filterChannelsByCategory(_selectedCategory);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: ${e.toString()}')),
        );
      }
    }
  }
  
  Future<void> _loadXtreamContent() async {
    // Load categories
    final liveCategories = await _secureStorage.read(key: 'live_categories');
    if (liveCategories != null) {
      final categories = json.decode(liveCategories);
      setState(() {
        _categories = categories;
      });
    }
    
    // Load live channels
    final liveChannels = await _secureStorage.read(key: 'live_channels');
    if (liveChannels != null) {
      final channels = json.decode(liveChannels);
      setState(() {
        _liveChannels = channels;
        _filteredChannels = channels;
      });
    }
  }
  
  Future<void> _loadM3UContent() async {
    // Load channel groups
    final channelGroups = await _secureStorage.read(key: 'channel_groups');
    if (channelGroups != null) {
      final groups = json.decode(channelGroups) as Map<String, dynamic>;
      setState(() {
        _categories = groups.keys.map((key) => {
          'category_id': key,
          'category_name': key,
          'parent_id': 0,
        }).toList();
      });
      
      // Flatten all channels into a single list
      List<dynamic> allChannels = [];
      groups.forEach((key, value) {
        allChannels.addAll(value);
      });
      
      setState(() {
        _liveChannels = allChannels;
        _filteredChannels = allChannels;
      });
    }
  }
  
  void _filterChannelsByCategory(String category) {
    setState(() {
      if (category == 'All') {
        _filteredChannels = _liveChannels;
      } else {
        if (_loginType == 'xtream') {
          final categoryId = _categories.firstWhere(
            (cat) => cat['category_name'] == category, 
            orElse: () => {'category_id': '0'})['category_id'];
          
          _filteredChannels = _liveChannels.where(
            (channel) => channel['category_id'].toString() == categoryId.toString()
          ).toList();
        } else {
          // For M3U
          _filteredChannels = _liveChannels.where(
            (channel) => channel['group'] == category
          ).toList();
        }
      }
      _selectedCategory = category;
    });
  }
  
  void _playChannel(int index) {
    if (index < 0 || index >= _filteredChannels.length) return;
    
    final channel = _filteredChannels[index];
    
    // Update selection
    setState(() {
      _selectedChannelIndex = index;
    });
    
    try {
      if (_loginType == 'xtream') {
        // Get server info and play
        _playXtreamChannel(channel);
      } else {
        // M3U stream
        String streamUrl = channel['url'] ?? '';
        if (streamUrl.isEmpty) {
          _showErrorSnackBar('Channel URL is empty');
          return;
        }
        
        _navigateToPlayer(streamUrl, _getChannelName(channel), _getChannelLogo(channel));
      }
    } catch (e) {
      _showErrorSnackBar('Error playing channel: ${e.toString()}');
    }
  }
  
  Future<void> _playXtreamChannel(dynamic channel) async {
    try {
      // Get server info
      final serverInfo = await _authService.getXtreamServerInfo();
      if (serverInfo == null) {
        _showErrorSnackBar('Server information not found');
        return;
      }
      
      final username = serverInfo['username'];
      final password = serverInfo['password'];
      final serverUrl = serverInfo['server_url'];
      
      if (username == null || password == null || serverUrl == null) {
        _showErrorSnackBar('Missing server credentials');
        return;
      }
      
      final streamId = channel['stream_id'];
      if (streamId == null) {
        _showErrorSnackBar('Channel has no stream ID');
        return;
      }
      
      // Build stream URL
      String streamUrl = '$serverUrl/live/$username/$password/$streamId.ts';
      
      // Log the URL for debugging (remove in production)
      print('Playing URL: $streamUrl');
      
      // Navigate to player
      _navigateToPlayer(streamUrl, _getChannelName(channel), _getChannelLogo(channel));
    } catch (e) {
      _showErrorSnackBar('Error setting up stream: ${e.toString()}');
    }
  }
  
  void _navigateToPlayer(String url, String title, String? logoUrl) {
    Navigator.pushNamed(
      context,
      '/player',
      arguments: {
        'streamUrl': url,
        'title': title,
        'logoUrl': logoUrl,
      },
    );
  }
  
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: _showSearchBar
            ? AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.grey, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search channels...',
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: _performSearch,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _toggleSearch,
                      ),
                    ],
                  ),
                ),
              )
            : const Text('Live TV', style: TextStyle(color: Colors.white)),
        actions: [
          if (!_showSearchBar) ...[
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.grey[900]!.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.search, size: 20),
                onPressed: _toggleSearch,
                tooltip: 'Search',
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshContent,
              tooltip: 'Refresh content',
            ),
          ],
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.red)) 
          : _buildContent(),
    );
  }
  
  Widget _buildContent() {
    return Column(
      children: [
        _buildCategoriesList(),
        
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'All Channels',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              // Back to Home button
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/home');
                },
                icon: const Icon(Icons.home, color: Colors.red, size: 16),
                label: const Text('Back to Home', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: _buildChannelsList(),
        ),
      ],
    );
  }
  
  Widget _buildCategoriesList() {
    // Add 'All' category
    final allCategories = <Map<String, dynamic>>[
      {'category_id': 'all', 'category_name': 'All'}
    ];
    
    // Add the rest of categories
    for (var category in _categories) {
      if (category is Map) {
        allCategories.add(Map<String, dynamic>.from(category));
      }
    }
    
    return Container(
      height: 50,
      color: Colors.black,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: allCategories.length,
        itemBuilder: (context, index) {
          final category = allCategories[index];
          final categoryName = category['category_name'] ?? 'Unknown';
          final isSelected = categoryName == _selectedCategory;
          
          return GestureDetector(
            onTap: () => _filterChannelsByCategory(categoryName),
            child: Container(
              margin: EdgeInsets.only(
                left: index == 0 ? 16 : 8,
                right: index == allCategories.length - 1 ? 16 : 0,
                top: 8,
                bottom: 8,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.red : Colors.grey[900],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  categoryName,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[300],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildChannelsList() {
    if (_filteredChannels.isEmpty) {
      return const Center(
        child: Text(
          'No channels found',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine number of columns based on available width
        int crossAxisCount = constraints.maxWidth ~/ 200; // ~/ is integer division
        // Ensure at least 2 columns, at most 5
        crossAxisCount = crossAxisCount.clamp(2, 5);
        
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 16 / 9,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _filteredChannels.length,
          itemBuilder: (context, index) {
            final channel = _filteredChannels[index];
            final isSelected = index == _selectedChannelIndex;
            final name = _getChannelName(channel);
            final logo = _getChannelLogo(channel);
            
            return GestureDetector(
              onTap: () => _playChannel(index),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(color: Colors.red, width: 2)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (logo.isNotEmpty)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: CachedNetworkImage(
                            imageUrl: logo,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) {
                              print('Error loading image $url: $error');
                              return const Icon(
                                Icons.live_tv,
                                color: Colors.grey,
                                size: 40,
                              );
                            },
                            fadeInDuration: const Duration(milliseconds: 300),
                            imageBuilder: (context, imageProvider) => Container(
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: imageProvider,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      const Expanded(
                        child: Icon(
                          Icons.live_tv,
                          color: Colors.grey,
                          size: 40,
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      width: double.infinity,
                      color: Colors.black.withOpacity(0.7),
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    );
  }
  
  void _toggleSearch() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) {
        _searchController.clear();
        _filterChannelsByCategory(_selectedCategory);
      }
    });
  }
  
  void _performSearch(String query) {
    if (query.isEmpty) {
      _filterChannelsByCategory(_selectedCategory);
      return;
    }
    
    setState(() {
      _filteredChannels = _liveChannels
          .where((channel) => _getChannelName(channel)
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    });
  }
  
  Future<void> _refreshContent() async {
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/loading');
    }
  }
  
  String _getChannelName(dynamic channel) {
    if (_loginType == 'xtream') {
      return channel['name'] ?? channel['stream_display_name'] ?? 'Unknown';
    } else {
      return channel['name'] ?? 'Unknown';
    }
  }
  
  String _getChannelLogo(dynamic channel) {
    if (_loginType == 'xtream') {
      return channel['stream_icon'] ?? '';
    } else {
      return channel['logo'] ?? '';
    }
  }
} 