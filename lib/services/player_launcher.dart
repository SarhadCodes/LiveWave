import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../screens/player_screen.dart';

class PlayerLauncher {
  static Future<void> launch({
    required BuildContext context,
    required Channel channel,
    required List<Channel>? allChannels,
    required int? initialChannelIndex,
  }) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          channel: channel,
          allChannels: allChannels,
          initialChannelIndex: initialChannelIndex,
        ),
      ),
    );
  }
}
