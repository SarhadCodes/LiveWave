import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../widgets/media_card.dart';
import '../services/tmdb_service.dart';
import '../models/movie.dart';
import '../models/tv_show.dart';
import 'movie_detail_screen.dart';
import 'tv_show_detail_screen.dart';

class MediaGridScreen extends StatelessWidget {
  final String title;
  final List<dynamic> items;
  final bool isMobile;

  const MediaGridScreen({
    super.key,
    required this.title,
    required this.items,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          title,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: isMobile ? 18 : 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GridView.builder(
        padding: EdgeInsets.all(isMobile ? AppTheme.spacingM : AppTheme.spacingXXL),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isMobile ? 3 : 5,
          childAspectRatio: isMobile ? 0.7 : 0.68,
          crossAxisSpacing: isMobile ? 12 : 20,
          mainAxisSpacing: isMobile ? 12 : 24,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          if (item is Movie) {
            return MediaCard(
              id: 'grid_${item.id}',
              title: item.title,
              posterUrl: TmdbService.getPosterUrl(item.posterPath),
              rating: item.ratingFormatted,
              year: item.year,
              isMovie: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MovieDetailScreen(movie: item)),
                );
              },
            );
          } else if (item is TvShow) {
            return MediaCard(
              id: 'grid_${item.id}',
              title: item.name,
              posterUrl: TmdbService.getPosterUrl(item.posterPath),
              rating: item.ratingFormatted,
              year: item.year,
              isMovie: false,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TvShowDetailScreen(tvShow: item)),
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
