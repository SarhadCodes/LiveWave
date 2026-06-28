import 'package:live_wave/services/subtitle_service.dart';
import 'package:flutter/foundation.dart';

void main() async {
  debugPrint = (String? message, {int? wrapWidth}) => print(message);
  
  var titleFromApp = "From - S4:E2 Something";
  print("Testing TV Show title from app: \$titleFromApp");
  var tvSub = await SubtitleService.getKurdishTvSubtitle(titleFromApp, 4, 2);
  if (tvSub != null) {
    print("Found TV Sub: \${tvSub.fileName}");
  } else {
    print("Not found TV sub.");
  }
}
