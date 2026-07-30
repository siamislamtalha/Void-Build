import 'package:voidmusic/core/models/exported.dart';
import 'package:voidmusic/src/rust/api/plugin/plugin_info.dart';

/// Service providing curated playlist suggestions for different regions/genres
/// All playlists are available to all countries - no geo-restrictions
class PlaylistSuggestionsService {
  /// Get curated playlist suggestions based on region/genre
  /// Returns a list of playlist search queries that can be used with any plugin
  static List<PlaylistSuggestion> getSuggestions() {
    return [
      // Indian Music (previously IN-only, now global)
      PlaylistSuggestion(
        title: 'Indian Music',
        description: 'Top Bollywood and Indian regional hits',
        searchQuery: 'Indian music hits',
        icon: 'IN',
        category: 'Regional',
      ),
      PlaylistSuggestion(
        title: 'Bollywood Classics',
        description: 'Timeless Bollywood songs',
        searchQuery: 'Bollywood classics',
        icon: 'BF',
        category: 'Regional',
      ),
      PlaylistSuggestion(
        title: 'Punjabi Hits',
        description: 'Latest Punjabi chartbusters',
        searchQuery: 'Punjabi hits 2024',
        icon: 'PB',
        category: 'Regional',
      ),
      
      // USA Music (previously US-only, now global)
      PlaylistSuggestion(
        title: 'USA Top 100',
        description: 'Billboard Hot 100 hits',
        searchQuery: 'USA top 100 hits',
        icon: 'US',
        category: 'Charts',
      ),
      PlaylistSuggestion(
        title: 'Hip Hop Hits',
        description: 'Trending hip hop and rap',
        searchQuery: 'hip hop hits 2024',
        icon: 'HH',
        category: 'Genre',
      ),
      PlaylistSuggestion(
        title: 'Country Music',
        description: 'Best country songs',
        searchQuery: 'country music hits',
        icon: 'CM',
        category: 'Genre',
      ),
      
      // Bangladesh Music (previously BD-only, now global)
      PlaylistSuggestion(
        title: 'Bangla Hits',
        description: 'Top Bengali songs',
        searchQuery: 'Bangla music hits',
        icon: 'BD',
        category: 'Regional',
      ),
      PlaylistSuggestion(
        title: 'Bangladeshi Pop',
        description: 'Popular Bangladeshi pop music',
        searchQuery: 'Bangladeshi pop songs',
        icon: 'BP',
        category: 'Regional',
      ),
      
      // UK Music (previously UK-only, now global)
      PlaylistSuggestion(
        title: 'UK Top 40',
        description: 'Official UK chart hits',
        searchQuery: 'UK top 40 songs',
        icon: 'UK',
        category: 'Charts',
      ),
      PlaylistSuggestion(
        title: 'British Pop',
        description: 'Best of British pop',
        searchQuery: 'British pop hits',
        icon: 'BP',
        category: 'Regional',
      ),
      
      // Genre-based suggestions (global)
      PlaylistSuggestion(
        title: 'K-Pop',
        description: 'Korean pop music',
        searchQuery: 'K-pop hits 2024',
        icon: 'KP',
        category: 'Genre',
      ),
      PlaylistSuggestion(
        title: 'Latin Music',
        description: 'Top Latin and Spanish hits',
        searchQuery: 'Latin music hits',
        icon: 'LM',
        category: 'Genre',
      ),
      PlaylistSuggestion(
        title: 'Electronic Dance',
        description: 'EDM and dance music',
        searchQuery: 'EDM dance hits',
        icon: 'ED',
        category: 'Genre',
      ),
      PlaylistSuggestion(
        title: 'Rock Classics',
        description: 'Legendary rock songs',
        searchQuery: 'rock classics playlist',
        icon: 'RC',
        category: 'Genre',
      ),
      PlaylistSuggestion(
        title: 'Jazz & Blues',
        description: 'Smooth jazz and blues',
        searchQuery: 'jazz blues playlist',
        icon: 'JB',
        category: 'Genre',
      ),
      PlaylistSuggestion(
        title: 'Classical Music',
        description: 'Classical masterpieces',
        searchQuery: 'classical music essentials',
        icon: 'CL',
        category: 'Genre',
      ),
      
      // Mood-based suggestions (global)
      PlaylistSuggestion(
        title: 'Workout Music',
        description: 'High-energy workout tracks',
        searchQuery: 'workout music playlist',
        icon: 'WO',
        category: 'Mood',
      ),
      PlaylistSuggestion(
        title: 'Chill Vibes',
        description: 'Relaxing chill music',
        searchQuery: 'chill vibes playlist',
        icon: 'CV',
        category: 'Mood',
      ),
      PlaylistSuggestion(
        title: 'Focus & Study',
        description: 'Concentration-enhancing music',
        searchQuery: 'focus study music',
        icon: 'FS',
        category: 'Mood',
      ),
      PlaylistSuggestion(
        title: 'Party Hits',
        description: 'Ultimate party anthems',
        searchQuery: 'party hits playlist',
        icon: 'PH',
        category: 'Mood',
      ),
      PlaylistSuggestion(
        title: 'Romantic Ballads',
        description: 'Love songs and ballads',
        searchQuery: 'romantic love songs',
        icon: 'RB',
        category: 'Mood',
      ),
      
      // Spotify-specific suggestions (when Spotify plugin is available)
      PlaylistSuggestion(
        title: 'Spotify Today\'s Top Hits',
        description: 'Most streamed tracks on Spotify',
        searchQuery: 'Today\'s Top Hits',
        icon: 'SP',
        category: 'Spotify',
        preferredPlugin: 'spotify',
      ),
      PlaylistSuggestion(
        title: 'Spotify RapCaviar',
        description: 'Hip hop playlist from Spotify',
        searchQuery: 'RapCaviar',
        icon: 'SR',
        category: 'Spotify',
        preferredPlugin: 'spotify',
      ),
      
      // JioSaavn-specific suggestions (when JioSaavn plugin is available)
      PlaylistSuggestion(
        title: 'JioSaavn Trending',
        description: 'Trending on JioSaavn',
        searchQuery: 'trending',
        icon: 'JT',
        category: 'JioSaavn',
        preferredPlugin: 'jiosaavn',
      ),
      PlaylistSuggestion(
        title: 'JioSaavn Top 50',
        description: 'Top 50 tracks on JioSaavn',
        searchQuery: 'top 50',
        icon: 'J5',
        category: 'JioSaavn',
        preferredPlugin: 'jiosaavn',
      ),
      
      // Multi-source suggestions (aggregated from multiple sources)
      PlaylistSuggestion(
        title: 'Multi-Source Trending',
        description: 'Trending across all platforms',
        searchQuery: 'trending hits',
        icon: 'MS',
        category: 'Multi',
        preferredPlugin: 'multi',
      ),
      PlaylistSuggestion(
        title: 'Global Top 100',
        description: 'Top 100 across all sources',
        searchQuery: 'top 100 global',
        icon: 'G1',
        category: 'Multi',
        preferredPlugin: 'multi',
      ),
    ];
  }
  
  /// Get suggestions filtered by category
  static List<PlaylistSuggestion> getSuggestionsByCategory(String category) {
    return getSuggestions().where((s) => s.category == category).toList();
  }
  
  /// Get suggestions that work best with a specific plugin
  static List<PlaylistSuggestion> getSuggestionsForPlugin(String pluginId) {
    final id = pluginId.toLowerCase();
    if (id.contains('spotify')) {
      return getSuggestions().where((s) => s.preferredPlugin == 'spotify' || s.preferredPlugin == null).toList();
    } else if (id.contains('jiosaavn') || id.contains('jio')) {
      return getSuggestions().where((s) => s.preferredPlugin == 'jiosaavn' || s.preferredPlugin == null).toList();
    }
    return getSuggestions().where((s) => s.preferredPlugin == null).toList();
  }
  
  /// Get country-specific suggestions when a country is selected
  /// This prioritizes suggestions from the selected country while still allowing all plugins
  /// Order: BD/India region → Spotify → JioSaavn → Multi-source → Other plugins → Other countries
  static List<PlaylistSuggestion> getSuggestionsForCountry(String countryCode) {
    final allSuggestions = getSuggestions();
    final normalizedCode = countryCode.toUpperCase();
    
    // BD and India are treated as the same region
    final isSouthAsiaRegion = normalizedCode == 'IN' || normalizedCode == 'BD';
    
    // South Asia region suggestions (BD + India together)
    final southAsiaRegionTitles = [
      'Indian Music', 'Bollywood Classics', 'Punjabi Hits',
      'Bangla Hits', 'Bangladeshi Pop'
    ];
    
    // Other country-specific suggestions mapping
    final countrySuggestions = <String, List<String>>{
      'US': ['USA Top 100', 'Hip Hop Hits', 'Country Music'],
      'GB': ['UK Top 40', 'British Pop'],
      'KR': ['K-Pop'],
      'MX': ['Latin Music'],
      'DE': ['Electronic Dance', 'Rock Classics'],
      'JP': ['K-Pop'],
    };
    
    final countryTitles = isSouthAsiaRegion 
        ? southAsiaRegionTitles 
        : (countrySuggestions[normalizedCode] ?? []);
    
    // All regional/country playlist titles
    final allCountryTitles = [
      'Indian Music', 'Bollywood Classics', 'Punjabi Hits',
      'USA Top 100', 'Hip Hop Hits', 'Country Music',
      'UK Top 40', 'British Pop',
      'Bangla Hits', 'Bangladeshi Pop',
      'K-Pop', 'Latin Music'
    ];
    
    // Organize into groups
    final regionSuggestions = <PlaylistSuggestion>[];
    final spotifySuggestions = <PlaylistSuggestion>[];
    final jiosaavnSuggestions = <PlaylistSuggestion>[];
    final multiSourceSuggestions = <PlaylistSuggestion>[];
    final otherPluginSuggestions = <PlaylistSuggestion>[];
    final genreSuggestions = <PlaylistSuggestion>[];
    final moodSuggestions = <PlaylistSuggestion>[];
    final otherCountrySuggestions = <PlaylistSuggestion>[];
    
    for (final suggestion in allSuggestions) {
      if (countryTitles.contains(suggestion.title)) {
        regionSuggestions.add(suggestion);
      } else if (suggestion.category == 'Spotify') {
        spotifySuggestions.add(suggestion);
      } else if (suggestion.category == 'JioSaavn') {
        jiosaavnSuggestions.add(suggestion);
      } else if (suggestion.category == 'Multi') {
        multiSourceSuggestions.add(suggestion);
      } else if (suggestion.category == 'Genre') {
        genreSuggestions.add(suggestion);
      } else if (suggestion.category == 'Mood') {
        moodSuggestions.add(suggestion);
      } else if (allCountryTitles.contains(suggestion.title)) {
        otherCountrySuggestions.add(suggestion);
      } else {
        // Other plugins that don't fit in specific categories
        otherPluginSuggestions.add(suggestion);
      }
    }
    
    // Return in order: region → Spotify → JioSaavn → Multi-source → Other plugins → Genre → Mood → Other countries
    return [
      ...regionSuggestions,
      ...spotifySuggestions,
      ...jiosaavnSuggestions,
      ...multiSourceSuggestions,
      ...otherPluginSuggestions,
      ...genreSuggestions,
      ...moodSuggestions,
      ...otherCountrySuggestions,
    ];
  }
}

class PlaylistSuggestion {
  final String title;
  final String description;
  final String searchQuery;
  final String icon;
  final String category;
  final String? preferredPlugin;
  
  PlaylistSuggestion({
    required this.title,
    required this.description,
    required this.searchQuery,
    required this.icon,
    required this.category,
    this.preferredPlugin,
  });
}
