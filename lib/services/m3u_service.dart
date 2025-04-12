import 'dart:convert';
import 'package:http/http.dart' as http;

/// A model class representing a channel from an M3U playlist
class M3UChannel {
  final String name;
  final String url;
  final String? logo;
  final String? group;
  final String? id;
  final Map<String, String> attributes;

  M3UChannel({
    required this.name,
    required this.url,
    this.logo,
    this.group,
    this.id,
    required this.attributes,
  });
}

/// Service to parse and handle M3U playlists
class M3UService {
  /// Parse M3U playlist content and return a list of channels
  List<M3UChannel> parsePlaylist(String content) {
    final List<M3UChannel> channels = [];
    final lines = content.split('\n');
    
    String? currentName;
    Map<String, String> currentAttributes = {};
    
    // Verify it's a valid M3U file
    if (lines.isEmpty || !lines[0].trim().startsWith('#EXTM3U')) {
      throw Exception('Invalid M3U format');
    }
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      // Skip empty lines
      if (line.isEmpty) {
        continue;
      }
      
      // Parse EXTINF line (channel info)
      if (line.startsWith('#EXTINF:')) {
        // Reset for a new channel
        currentAttributes = {};
        
        // Extract attributes
        final String infoLine = line.substring(8);
        _parseExtInf(infoLine, currentAttributes);
        
        // Extract name (the part after the comma in EXTINF line)
        final int commaIndex = infoLine.indexOf(',');
        if (commaIndex != -1 && commaIndex < infoLine.length - 1) {
          currentName = infoLine.substring(commaIndex + 1).trim();
        }
      } 
      // Parse tvg-* and group-title attributes
      else if (line.startsWith('#EXTVLCOPT:') || line.startsWith('#EXTGRP:')) {
        _parseAttributes(line, currentAttributes);
      }
      // Parse the URL (non-comment line after an EXTINF line)
      else if (!line.startsWith('#') && currentName != null) {
        final url = line;
        
        channels.add(M3UChannel(
          name: currentName,
          url: url,
          logo: currentAttributes['tvg-logo'],
          group: currentAttributes['group-title'],
          id: currentAttributes['tvg-id'],
          attributes: Map.from(currentAttributes),
        ));
        
        // Reset after creating a channel
        currentName = null;
        currentAttributes = {};
      }
    }
    
    return channels;
  }
  
  /// Parse the EXTINF line to extract attributes
  void _parseExtInf(String line, Map<String, String> attributes) {
    // Extract duration
    final durationEndIndex = line.indexOf(' ');
    if (durationEndIndex != -1) {
      try {
        final durationStr = line.substring(0, durationEndIndex).trim();
        attributes['duration'] = durationStr;
      } catch (e) {
        // If we can't parse duration, just continue
      }
      
      // Extract other attributes
      final attributesPart = line.substring(0, line.indexOf(','));
      _parseAttributes(attributesPart, attributes);
    }
  }
  
  /// Parse attributes like tvg-logo, group-title, etc.
  void _parseAttributes(String line, Map<String, String> attributes) {
    final RegExp attrRegex = RegExp(r'([a-zA-Z0-9-_]+)="([^"]*)"');
    final matches = attrRegex.allMatches(line);
    
    for (final match in matches) {
      if (match.groupCount >= 2) {
        final key = match.group(1)!;
        final value = match.group(2)!;
        attributes[key] = value;
      }
    }
  }
  
  /// Fetch a playlist from a URL
  Future<List<M3UChannel>> fetchPlaylist(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        return parsePlaylist(response.body);
      } else {
        throw Exception('Failed to fetch playlist: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching playlist: ${e.toString()}');
    }
  }
  
  /// Group channels by their group attribute
  Map<String, List<M3UChannel>> groupChannels(List<M3UChannel> channels) {
    final Map<String, List<M3UChannel>> groups = {};
    
    for (final channel in channels) {
      final group = channel.group ?? 'Ungrouped';
      if (!groups.containsKey(group)) {
        groups[group] = [];
      }
      groups[group]!.add(channel);
    }
    
    return groups;
  }
} 