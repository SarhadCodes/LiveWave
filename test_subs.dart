import 'package:flutter/material.dart';
import 'lib/services/subtitle_service.dart';

void main() async {
  // Mock debugPrint
  debugPrint = (String? message, {int? wrapWidth}) => print(message);

  print("Testing TV Show: From S04E02");
  var tvSub = await SubtitleService.getKurdishTvSubtitle("From", 4, 2);
  if (tvSub != null) {
    print("Found TV Sub: ${tvSub.fileName}");
  } else {
    print("Not found TV sub.");
  }

  print("\nTesting Movie: Twilight of the Warriors: Walled In (2024)");
  var movieSub = await SubtitleService.getKurdishMovieSubtitle("Twilight of the Warriors: Walled In", releaseYear: 2024);
  if (movieSub != null) {
    print("Found Movie Sub: ${movieSub.fileName}");
  } else {
    print("Not found Movie sub.");
  }

  print("\nTesting Movie: 180 (2026)");
  var movieSub2 = await SubtitleService.getKurdishMovieSubtitle("180", releaseYear: 2026);
  if (movieSub2 != null) {
    print("Found Movie Sub: ${movieSub2.fileName}");
  } else {
    print("Not found Movie sub.");
  }
}
