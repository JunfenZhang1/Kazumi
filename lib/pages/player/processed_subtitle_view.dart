import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/services/player/subtitle_processing.dart';
import 'package:media_kit/media_kit.dart';

/// Text subtitle overlay. mpv still owns cue timing; no wall-clock timers are
/// used, so seeking and changing playback rate follow the original cue stream.
class ProcessedSubtitleView extends StatefulWidget {
  const ProcessedSubtitleView({
    super.key,
    required this.player,
    required this.mode,
    required this.endpoint,
    required this.apiKey,
  });

  final Player player;
  final SubtitleProcessingMode mode;
  final String endpoint;
  final String apiKey;

  @override
  State<ProcessedSubtitleView> createState() => _ProcessedSubtitleViewState();
}

class _ProcessedSubtitleViewState extends State<ProcessedSubtitleView> {
  StreamSubscription<List<String>>? _subscription;
  CancelToken? _requestCancel;
  String _input = '';
  String _display = '';
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    _subscription = widget.player.stream.subtitle.listen(_onSubtitle);
    _onSubtitle(widget.player.state.subtitle);
  }

  void _onSubtitle(List<String> lines) {
    final input =
        lines.map((line) => line.trim()).where((line) => line.isNotEmpty).join('\n');
    if (input == _input) return;
    _input = input;
    final generation = ++_generation;
    _requestCancel?.cancel('Subtitle changed');
    _requestCancel = null;

    if (input.isEmpty) {
      setState(() => _display = '');
      return;
    }

    if (widget.mode == SubtitleProcessingMode.simplified) {
      setState(
        () => _display = SubtitleProcessingService.toSimplified(input),
      );
      return;
    }

    // Show the original while translating; stale responses never overwrite
    // a later cue.
    setState(() => _display = input);
    if (widget.mode != SubtitleProcessingMode.translate ||
        widget.endpoint.trim().isEmpty) {
      return;
    }

    final cancel = CancelToken();
    _requestCancel = cancel;
    unawaited(_translate(input, generation, cancel));
  }

  Future<void> _translate(
      String input, int generation, CancelToken cancel) async {
    try {
      final translated = await SubtitleProcessingService.translateToSimplified(
        text: input,
        endpoint: widget.endpoint,
        apiKey: widget.apiKey,
        cancelToken: cancel,
      );
      if (mounted && generation == _generation && !cancel.isCancelled) {
        setState(() => _display = translated);
      }
    } catch (_) {
      // Keep the original subtitle on API failures or canceled requests.
    }
  }

  @override
  void didUpdateWidget(covariant ProcessedSubtitleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.player, widget.player) ||
        oldWidget.mode != widget.mode ||
        oldWidget.endpoint != widget.endpoint ||
        oldWidget.apiKey != widget.apiKey) {
      _requestCancel?.cancel('Subtitle settings changed');
      _requestCancel = null;
      _generation++;
      unawaited(_subscription?.cancel());
      _subscription = null;
      _input = '';
      _display = '';
      _subscribe();
    }
  }

  @override
  void dispose() {
    _generation++;
    _requestCancel?.cancel('Subtitle widget disposed');
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_display.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: Text(
        _display,
        textAlign: TextAlign.center,
        softWrap: true,
        style: TextStyle(
          fontSize: MediaQuery.sizeOf(context).width < 650 ? 24 : 38,
          height: 1.25,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          shadows: const [
            Shadow(offset: Offset(1.5, 1.5), blurRadius: 4, color: Colors.black),
            Shadow(offset: Offset(-1.5, -1.5), blurRadius: 4, color: Colors.black),
          ],
        ),
      ),
    );
  }
}
