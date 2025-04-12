import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class VideoPlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;
  final String? logoUrl;

  const VideoPlayerScreen({
    super.key, 
    required this.streamUrl, 
    required this.title,
    this.logoUrl,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  // Player controller
  late VlcPlayerController _videoPlayerController;
  
  // UI state
  bool _isFullScreen = false;
  bool _isPlaying = true;
  bool _showControls = true;
  bool _isLoading = true;
  double _volume = 100;
  double _brightness = 70;
  bool _isWebError = false;
  
  @override
  void initState() {
    super.initState();
    _initializePlayer();
    
    // Auto-hide controls after a few seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
    
    // Set preferred device orientation
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }
  
  @override
  void dispose() {
    if (!_isWebError) {
      _videoPlayerController.dispose();
    }
    
    // Reset orientation
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      
      // Reset system UI mode
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    
    super.dispose();
  }
  
  void _initializePlayer() {
    try {
      // For web, handle streaming limitations differently
      if (kIsWeb) {
        // Check if the stream URL is HLS (m3u8) which works better in web
        if (!widget.streamUrl.endsWith('.m3u8') && !widget.streamUrl.contains('.m3u8?')) {
          setState(() {
            _isWebError = true;
            _isLoading = false;
          });
          _showErrorSnackBar('This stream format may not be supported in web browsers. Try using the Android app for better compatibility.');
          return;
        }
      }
      
      // Create a new controller
      _videoPlayerController = VlcPlayerController.network(
        widget.streamUrl,
        hwAcc: HwAcc.full,
        autoPlay: true,
        options: VlcPlayerOptions(
          advanced: VlcAdvancedOptions([
            VlcAdvancedOptions.networkCaching(2000),
          ]),
          rtp: VlcRtpOptions([
            VlcRtpOptions.rtpOverRtsp(true),
          ]),
          video: VlcVideoOptions([
            VlcVideoOptions.dropLateFrames(true),
            VlcVideoOptions.skipFrames(true),
          ]),
        ),
      );
      
      // Add initialization listener
      _videoPlayerController.addOnInitListener(() {
        setState(() {
          _isLoading = false;
        });
      });
      
      // Listen to playback events
      _videoPlayerController.addListener(() {
        // Check if player is in error state
        if (_videoPlayerController.value.hasError) {
          print('VLC Error: ${_videoPlayerController.value.errorDescription}');
          _showErrorSnackBar('Error playing channel');
          setState(() {
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isWebError = kIsWeb;
      });
      _showErrorSnackBar('Failed to initialize player: ${e.toString()}');
    }
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
  
  void _toggleFullScreen() {
    if (kIsWeb) {
      _showErrorSnackBar('Fullscreen mode might be limited in web browsers');
    }
    
    setState(() {
      _isFullScreen = !_isFullScreen;
      
      if (!kIsWeb) {
        if (_isFullScreen) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
      }
    });
  }
  
  void _togglePlayPause() {
    if (_isWebError) return;
    
    setState(() {
      if (_isPlaying) {
        _videoPlayerController.pause();
      } else {
        _videoPlayerController.play();
      }
      _isPlaying = !_isPlaying;
      _showControls = true;
    });
    
    // Auto-hide controls
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }
  
  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
    });
    
    // Auto-hide controls
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }
  
  void _setVolume(double value) {
    if (_isWebError) return;
    
    setState(() {
      _volume = value;
      // The VLC player volume is between 0 and 100
      _videoPlayerController.setVolume(_volume.toInt());
    });
  }
  
  void _setBrightness(double value) {
    setState(() {
      _brightness = value;
      // Actual implementation of brightness would depend on the platform
      // For this demo we'll just store the value
    });
  }
  
  void _onBackPressed() {
    Navigator.of(context).pop();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _isWebError
            ? _buildWebErrorView()
            : _buildPlayerView(),
    );
  }
  
  Widget _buildWebErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 20),
            Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'This stream format may not be supported in web browsers.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'For the best experience, please use the Android app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _onBackPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPlayerView() {
    return Stack(
      children: [
        // Player
        Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: VlcPlayer(
              controller: _videoPlayerController,
              aspectRatio: 16 / 9,
              placeholder: Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.red),
                ),
              ),
            ),
          ),
        ),
        
        // Loading indicator
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Loading stream...',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
        
        // Controls overlay
        if (_showControls)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Title bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: _onBackPressed,
                      ),
                      Flexible(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                          color: Colors.white,
                        ),
                        onPressed: _toggleFullScreen,
                      ),
                    ],
                  ),
                ),
                
                // Center play/pause button
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    color: Colors.white,
                    size: 60,
                  ),
                  onPressed: _togglePlayPause,
                ),
                
                // Bottom controls
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Volume control
                      Row(
                        children: [
                          const Icon(Icons.volume_up, color: Colors.white),
                          Expanded(
                            child: Slider(
                              value: _volume,
                              min: 0,
                              max: 100,
                              activeColor: Colors.red,
                              inactiveColor: Colors.grey.withOpacity(0.5),
                              onChanged: _setVolume,
                            ),
                          ),
                        ],
                      ),
                      
                      // Brightness control
                      Row(
                        children: [
                          const Icon(Icons.brightness_6, color: Colors.white),
                          Expanded(
                            child: Slider(
                              value: _brightness,
                              min: 0,
                              max: 100,
                              activeColor: Colors.red,
                              inactiveColor: Colors.grey.withOpacity(0.5),
                              onChanged: _setBrightness,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
        // Tap detector for showing controls
        GestureDetector(
          onTap: _showControlsTemporarily,
          behavior: HitTestBehavior.translucent,
          child: Container(color: Colors.transparent),
        ),
      ],
    );
  }
} 