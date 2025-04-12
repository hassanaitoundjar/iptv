import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  String _loginType = 'xtream';
  bool _isLoading = true;
  String _lastUpdated = '';
  List<dynamic> _categories = [];
  List<dynamic> _liveChannels = [];
  List<dynamic> _vodContent = [];
  List<dynamic> _seriesContent = [];
  List<dynamic> _featuredContent = [];
  int _selectedIndex = 0;
  bool _showSearchBar = false;
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
      
      // Get last updated timestamp
      final lastUpdated = await _secureStorage.read(key: 'content_last_updated') ?? '';
      final lastUpdatedDate = lastUpdated.isNotEmpty 
          ? DateTime.parse(lastUpdated) 
          : null;
      
      // Format last updated time
      final formattedDate = lastUpdatedDate != null
          ? '${lastUpdatedDate.day}/${lastUpdatedDate.month}/${lastUpdatedDate.year} ${lastUpdatedDate.hour.toString().padLeft(2, '0')}:${lastUpdatedDate.minute.toString().padLeft(2, '0')}'
          : 'Unknown';
      
      // Load categories based on login type
      await _loadContentBasedOnLoginType(loginType);
      
      setState(() {
        _loginType = loginType;
        _lastUpdated = formattedDate;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: ${e.toString()}')),
        );
      }
    }
  }
  
  Future<void> _loadContentBasedOnLoginType(String loginType) async {
    if (loginType == 'xtream') {
      await _loadXtreamContent();
    } else if (loginType == 'm3u') {
      await _loadM3UContent();
    }
  }
  
  Future<void> _loadXtreamContent() async {
    // Load categories
    final liveCategories = await _secureStorage.read(key: 'live_categories');
    if (liveCategories != null) {
      _categories = json.decode(liveCategories);
    }
    
    // Load live channels
    final liveChannels = await _secureStorage.read(key: 'live_channels');
    if (liveChannels != null) {
      _liveChannels = json.decode(liveChannels);
    }
    
    // Load VOD content
    final vodContent = await _secureStorage.read(key: 'vod_content');
    if (vodContent != null) {
      _vodContent = json.decode(vodContent);
    }
    
    // Load series categories
    final seriesCategories = await _secureStorage.read(key: 'series_categories');
    if (seriesCategories != null) {
      final seriesCat = json.decode(seriesCategories);
      _seriesContent = seriesCat;
    }
    
    // Create featured content by selecting random items from VOD
    _createFeaturedContent();
  }
  
  Future<void> _loadM3UContent() async {
    // Load channel groups
    final channelGroups = await _secureStorage.read(key: 'channel_groups');
    if (channelGroups != null) {
      final groups = json.decode(channelGroups) as Map<String, dynamic>;
      _categories = groups.keys.map((key) => {
        'category_id': key,
        'category_name': key,
        'parent_id': 0,
      }).toList();
      
      // Flatten all channels into a single list
      List<dynamic> allChannels = [];
      groups.forEach((key, value) {
        allChannels.addAll(value);
      });
      
      // Set live channels to all channels
      _liveChannels = allChannels;
      
      // For M3U, we'll use the same channels as VOD and series content
      // for demo purposes
      _vodContent = allChannels;
      _seriesContent = allChannels;
      
      // Create featured content
      _createFeaturedContent();
    }
  }
  
  void _createFeaturedContent() {
    // Create a list of featured content from VOD and live channels
    final random = Random();
    final List<dynamic> featured = [];
    
    // Add some VOD items if available
    if (_vodContent.isNotEmpty) {
      final int count = min(5, _vodContent.length);
      final List<int> indices = [];
      
      while (indices.length < count) {
        final int index = random.nextInt(_vodContent.length);
        if (!indices.contains(index)) {
          indices.add(index);
          final item = _vodContent[index];
          featured.add(item);
        }
      }
    }
    
    // Add some live items if available and if we need more items
    if (_liveChannels.isNotEmpty && featured.length < 5) {
      final int count = min(5 - featured.length, _liveChannels.length);
      final List<int> indices = [];
      
      while (indices.length < count) {
        final int index = random.nextInt(_liveChannels.length);
        if (!indices.contains(index)) {
          indices.add(index);
          final item = _liveChannels[index];
          featured.add(item);
        }
      }
    }
    
    _featuredContent = featured;
  }
  
  String _getItemName(dynamic item) {
    if (item is Map) {
      if (_loginType == 'xtream') {
        return item['name'] ?? item['title'] ?? item['stream_display_name'] ?? 'Unknown';
      } else {
        return item['name'] ?? 'Unknown';
      }
    }
    return 'Unknown';
  }
  
  String _getItemLogo(dynamic item) {
    if (item is Map) {
      if (_loginType == 'xtream') {
        return item['stream_icon'] ?? item['cover'] ?? '';
      } else {
        return item['logo'] ?? '';
      }
    }
    return '';
  }
  
  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }
  
  Future<void> _refreshContent() async {
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/loading');
    }
  }
  
  void _toggleSearch() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) {
        _searchController.clear();
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: _showSearchBar 
            ? Colors.black.withOpacity(0.9) 
            : Colors.transparent,
        elevation: _showSearchBar ? 0 : 0,
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
                            hintText: 'Search movies, series, channels...',
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
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
            : null,
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
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'Logout',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _buildNetflixStyleHome(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          
          // Navigate based on the selected index
          if (index == 1) {
            // Live TV
            Navigator.of(context).pushNamed('/live_tv');
          }
          
          // TODO: Implement navigation for other sections
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF121212),
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.live_tv),
            label: 'Live TV',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.movie),
            label: 'Movies',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tv),
            label: 'Series',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
  
  Widget _buildNetflixStyleHome() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Featured content carousel at the top
          if (_featuredContent.isNotEmpty)
            _buildFeaturedCarousel(),
          
          // Connection info bar
          // Container(
          //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          //   color: Colors.grey[900],
          //   child: Row(
          //     children: [
          //       Icon(
          //         _loginType == 'xtream' ? Icons.cloud : Icons.playlist_play,
          //         color: const Color.fromARGB(255, 161, 135, 133),
          //         size: 18,
          //       ),
          //       const SizedBox(width: 8),
          //       Text(
          //         _loginType == 'xtream' ? 'Xtream Connection' : 'M3U Playlist',
          //         style: const TextStyle(
          //           color: Colors.white,
          //           fontWeight: FontWeight.bold,
          //         ),
          //       ),
          //       const Spacer(),
          //       Text(
          //         'Last updated: $_lastUpdated',
          //         style: TextStyle(
          //           color: Colors.white.withOpacity(0.7),
          //           fontSize: 12,
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
          
          // Continue watching section with progress bars
          _buildContinueWatchingSection(),
          
          // Live TV section
          if (_liveChannels.isNotEmpty)
            _buildContentSection(title: 'Live TV', items: _liveChannels),
          
          // Movies section
          if (_vodContent.isNotEmpty)
            _buildContentSection(title: 'Movies', items: _vodContent),
          
          // Series section
          if (_seriesContent.isNotEmpty)
            _buildContentSection(title: 'Series', items: _seriesContent),
          
          // Recently watched section
          _buildContentSection(title: 'Recently Watched', items: _featuredContent),
          
          // Bottom spacing
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  
  Widget _buildFeaturedCarousel() {
    return Container(
      height: 400,
      child: PageView.builder(
        itemCount: _featuredContent.length,
        itemBuilder: (context, index) {
          final item = _featuredContent[index];
          final imageUrl = _getItemLogo(item);
          final title = _getItemName(item);
          
          return Stack(
            fit: StackFit.expand,
            children: [
              // Featured image
              imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[900],
                        child: const Center(child: CircularProgressIndicator(color: Colors.red)),
                      ),
                      errorWidget: (context, url, error) {
                        print('Error loading featured image $url: $error');
                        return Container(
                          color: Colors.grey[900],
                          child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 50),
                        );
                      },
                      memCacheWidth: 1280,
                      maxWidthDiskCache: 1280,
                    )
                  : Container(
                      color: Colors.grey[900],
                      child: const Icon(Icons.movie, color: Colors.grey),
                    ),
              
              // Gradient overlay for better text visibility
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.5),
                      Colors.black.withOpacity(0.8),
                      Colors.black,
                    ],
                  ),
                ),
              ),
              
              // Content info
              Positioned(
                left: 16,
                right: 16,
                bottom: 48,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            // Play the content
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Playing: $title')),
                            );
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Play'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            // Add to watch list
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Added to My List: $title')),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('My List'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildContentSection({required String title, required List<dynamic> items}) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () {
                  // View all
                },
                child: const Text(
                  'View All',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: min(items.length, 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final imageUrl = _getItemLogo(item);
              final name = _getItemName(item);
              
              return GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Selected: $name')),
                  );
                },
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumbnail
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  width: 120,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[800],
                                    child: const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) {
                                    print('Error loading content image $url: $error');
                                    return Container(
                                      color: Colors.grey[800],
                                      child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                    );
                                  },
                                  memCacheHeight: 180,
                                  fadeInDuration: const Duration(milliseconds: 200),
                                )
                              : Container(
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.movie, color: Colors.grey),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Title
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildContinueWatchingSection() {
    // Create a list of random items from content with progress bars
    final random = Random();
    final List<Map<String, dynamic>> continueWatching = [];
    
    if (_vodContent.isNotEmpty) {
      final int count = min(5, _vodContent.length);
      final List<int> indices = [];
      
      while (indices.length < count) {
        final int index = random.nextInt(_vodContent.length);
        if (!indices.contains(index)) {
          indices.add(index);
          final item = _vodContent[index];
          final progress = 0.1 + random.nextDouble() * 0.8; // Random progress between 10% and 90%
          
          continueWatching.add({
            'item': item,
            'progress': progress,
          });
        }
      }
    }
    
    if (continueWatching.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            'Continue Watching',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: continueWatching.length,
            itemBuilder: (context, index) {
              final Map<String, dynamic> watchItem = continueWatching[index];
              final item = watchItem['item'];
              final double progress = watchItem['progress'];
              final imageUrl = _getItemLogo(item);
              final name = _getItemName(item);
              
              return Container(
                width: 140,
                margin: const EdgeInsets.only(left: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stack for the image and play icon
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  height: 140,
                                  width: 140,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[800],
                                    child: const Center(child: CircularProgressIndicator(color: Colors.red)),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: Colors.grey[800],
                                    child: const Icon(Icons.movie, color: Colors.grey),
                                  ),
                                )
                              : Container(
                                  height: 140,
                                  width: 140,
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.movie, color: Colors.grey),
                                ),
                        ),
                        Positioned.fill(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Progress bar
                    const SizedBox(height: 2),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[800],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                      minHeight: 3,
                    ),
                    const SizedBox(height: 6),
                    // Title
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
} 