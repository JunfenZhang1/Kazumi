import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/player/processed_subtitle_view.dart';
import 'package:kazumi/services/player/subtitle_processing.dart';
import 'package:kazumi/services/storage/storage.dart';

class PlayerItemSurface extends StatefulWidget {
  const PlayerItemSurface({
    super.key,
    required this.playerController,
  });

  final PlayerController playerController;

  @override
  State<PlayerItemSurface> createState() => _PlayerItemSurfaceState();
}

class _PlayerItemSurfaceState extends State<PlayerItemSurface> {
  late final Stream<void> _subtitleSettings = GStorage.watchSettings([
    SettingsKeys.subtitleProcessingMode,
    SettingsKeys.subtitleTranslateEndpoint,
    SettingsKeys.subtitleTranslateApiKey,
    SettingsKeys.subtitleLocalAiEndpoint,
    SettingsKeys.subtitleLocalAiModel,
  ]);

  @override
  Widget build(BuildContext context) {
    final playerController = widget.playerController;
    return StreamBuilder<void>(
      stream: _subtitleSettings,
      builder: (context, _) => Observer(builder: (context) {
      if (playerController.playback.loading ||
          playerController.playback.videoController == null) {
        return Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      final aspectRatioMode = playerController.panel.aspectRatioMode;
      final mode = SubtitleProcessingMode.fromStorage(
        GStorage.getSetting(SettingsKeys.subtitleProcessingMode),
      );
      final video = Video(
        controller: playerController.playback.videoController!,
        controls: NoVideoControls,
        pauseUponEnteringBackgroundMode: false,
        fit: aspectRatioMode.fit,
        subtitleViewConfiguration: SubtitleViewConfiguration(
          visible: mode == SubtitleProcessingMode.original,
          style: TextStyle(
            color: Colors.pink,
            fontSize: 48.0,
            background: Paint()..color = Colors.transparent,
            decoration: TextDecoration.none,
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(
                offset: Offset(1.0, 1.0),
                blurRadius: 3.0,
                color: Color.fromARGB(255, 255, 255, 255),
              ),
              Shadow(
                offset: Offset(-1.0, -1.0),
                blurRadius: 3.0,
                color: Color.fromARGB(125, 255, 255, 255),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          padding: const EdgeInsets.all(24.0),
        ),
      );

      final player = playerController.playback.mediaPlayer;
      final surface = mode == SubtitleProcessingMode.original || player == null
          ? video
          : Stack(
              fit: StackFit.expand,
              children: [
                video,
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 24,
                  child: ProcessedSubtitleView(
                    player: player,
                    mode: mode,
                    endpoint: GStorage.getSetting(
                        SettingsKeys.subtitleTranslateEndpoint),
                    apiKey: GStorage.getSetting(
                        SettingsKeys.subtitleTranslateApiKey),
                    localEndpoint: GStorage.getSetting(
                        SettingsKeys.subtitleLocalAiEndpoint),
                    localModel: GStorage.getSetting(
                        SettingsKeys.subtitleLocalAiModel),
                  ),
                ),
              ],
            );

      final frameAspectRatio = aspectRatioMode.frameAspectRatio;
      if (frameAspectRatio == null) {
        return surface;
      }
      return AspectRatio(
        aspectRatio: frameAspectRatio,
        child: surface,
      );
    }),
    );
  }
}
