import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/providers/share_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../routing/route_names.dart';

class VoiceMemoScreen extends StatefulWidget {
  const VoiceMemoScreen({super.key});

  @override
  State<VoiceMemoScreen> createState() => _VoiceMemoScreenState();
}

class _VoiceMemoScreenState extends State<VoiceMemoScreen> {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  String? _outputPath;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        context.showSnackBar('Microphone permission is required to record.');
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_memo_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(const RecordConfig(), path: path);

    setState(() {
      _isRecording = true;
      _elapsed = Duration.zero;
      _outputPath = path;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    setState(() => _isRecording = false);

    if (path != null && mounted) {
      // Hand the recorded file off to UploadMediaScreen so all the
      // "save to backend" logic lives in one place.
      context.pushReplacementNamed(
        RouteNames.uploadMedia,
        extra: ShareContent(filePath: path),
      );
    }
  }

  String _formatElapsed() {
    final m = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Memo')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Timer
            Text(
              _formatElapsed(),
              style: context.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w300,
                letterSpacing: 4,
                color: _isRecording
                    ? AppColors.error
                    : context.colorScheme.onSurfaceVariant,
              ),
            ),

            AppSpacing.gapV8,

            // Status label
            Text(
              _isRecording ? 'Recording…' : 'Tap to record',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),

            AppSpacing.gapV48,

            // Record button
            GestureDetector(
              onTap: _toggleRecording,
              child:
                  Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording
                              ? AppColors.error.withValues(alpha: 0.12)
                              : AppColors.primary.withValues(alpha: 0.12),
                        ),
                        child: Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isRecording
                                  ? AppColors.error
                                  : AppColors.primary,
                            ),
                            child: Icon(
                              _isRecording
                                  ? Icons.stop_rounded
                                  : Icons.mic_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      )
                      .animate(
                        onPlay: (c) => c.repeat(reverse: true),
                        target: _isRecording ? 1.0 : 0.0,
                      )
                      .scaleXY(
                        end: 1.06,
                        duration: 600.ms,
                        curve: Curves.easeInOut,
                      ),
            ),

            AppSpacing.gapV32,

            // Hint
            if (!_isRecording && _outputPath == null)
              Text(
                'Your memo will be saved as an audio note.',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
