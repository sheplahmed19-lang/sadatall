import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../constants/app_constants.dart';
import '../../theme/app_theme.dart';

class VoiceRecorderWidget extends StatefulWidget {
  final Function(File) onRecordingComplete;

  const VoiceRecorderWidget({
    super.key,
    required this.onRecordingComplete,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  bool _isPaused = false;
  bool _hasRecording = false;
  bool _isPlaying = false;

  int _recordDuration = 0;
  Timer? _timer;
  String? _audioPath;

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يجب السماح بإذن الميكروفون لتسجيل الصوت'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final Directory tempDir = await getTemporaryDirectory();
        final String filePath = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: filePath,
        );

        setState(() {
          _isRecording = true;
          _isPaused = false;
          _recordDuration = 0;
        });

        _startTimer();
      } else {
        await _requestPermission();
      }
    } catch (e) {
      ('Error starting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء بدء التسجيل'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      _timer?.cancel();
      final String? path = await _audioRecorder.stop();

      if (path != null) {
        setState(() {
          _isRecording = false;
          _isPaused = false;
          _hasRecording = true;
          _audioPath = path;
        });
      }
    } catch (e) {
      ('Error stopping recording: $e');
    }
  }

  Future<void> _pauseRecording() async {
    try {
      await _audioRecorder.pause();
      _timer?.cancel();
      setState(() {
        _isPaused = true;
      });
    } catch (e) {
      ('Error pausing recording: $e');
    }
  }

  Future<void> _resumeRecording() async {
    try {
      await _audioRecorder.resume();
      _startTimer();
      setState(() {
        _isPaused = false;
      });
    } catch (e) {
      ('Error resuming recording: $e');
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordDuration++;
      });

      // Auto-stop at max duration
      if (_recordDuration >= AppConstants.maxVoiceNoteDuration) {
        _stopRecording();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم الوصول إلى الحد الأقصى للتسجيل (5 دقائق)'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    });
  }

  Future<void> _playRecording() async {
    if (_audioPath != null) {
      try {
        await _audioPlayer.play(DeviceFileSource(_audioPath!));
        setState(() {
          _isPlaying = true;
        });

        _audioPlayer.onPlayerComplete.listen((event) {
          setState(() {
            _isPlaying = false;
          });
        });
      } catch (e) {
        ('Error playing recording: $e');
      }
    }
  }

  Future<void> _stopPlaying() async {
    try {
      await _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
      });
    } catch (e) {
      ('Error stopping playback: $e');
    }
  }

  void _deleteRecording() {
    setState(() {
      _hasRecording = false;
      _audioPath = null;
      _recordDuration = 0;
    });
  }

  void _confirmRecording() {
    if (_audioPath != null) {
      widget.onRecordingComplete(File(_audioPath!));
      Navigator.of(context).pop();
    }
  }

  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'تسجيل صوتي',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Recording indicator and timer
          if (_isRecording || _hasRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: _isRecording && !_isPaused
                    ? Colors.red.shade50
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isRecording && !_isPaused)
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Text(
                    _formatDuration(_recordDuration),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '/ ${_formatDuration(AppConstants.maxVoiceNoteDuration)}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),

          // Controls
          if (!_hasRecording)
            _buildRecordingControls()
          else
            _buildPlaybackControls(),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRecordingControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Cancel button
        if (_isRecording)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            iconSize: 32,
            color: Colors.red,
            onPressed: () {
              _stopRecording();
              _deleteRecording();
            },
          ),

        const SizedBox(width: 20),

        // Main record button
        GestureDetector(
          onTap: () {
            if (!_isRecording) {
              _startRecording();
            } else if (_isPaused) {
              _resumeRecording();
            } else {
              _pauseRecording();
            }
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _isRecording
                  ? (_isPaused ? Colors.orange : Colors.red)
                  : AppTheme.primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (_isRecording
                          ? (_isPaused ? Colors.orange : Colors.red)
                          : AppTheme.primaryColor)
                      .withOpacity(0.3),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              _isRecording
                  ? (_isPaused ? Icons.play_arrow : Icons.pause)
                  : Icons.mic,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),

        const SizedBox(width: 20),

        // Stop button
        if (_isRecording)
          IconButton(
            icon: const Icon(Icons.stop),
            iconSize: 32,
            color: AppTheme.primaryColor,
            onPressed: _stopRecording,
          ),
      ],
    );
  }

  Widget _buildPlaybackControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Delete button
            IconButton(
              icon: const Icon(Icons.delete_outline),
              iconSize: 32,
              color: Colors.red,
              onPressed: _deleteRecording,
            ),

            const SizedBox(width: 20),

            // Play/Pause button
            GestureDetector(
              onTap: _isPlaying ? _stopPlaying : _playRecording,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 16,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  _isPlaying ? Icons.stop : Icons.play_arrow,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),

            const SizedBox(width: 20),

            // Confirm button
            IconButton(
              icon: const Icon(Icons.check_circle),
              iconSize: 32,
              color: AppTheme.successColor,
              onPressed: _confirmRecording,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Confirm button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _confirmRecording,
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text(
              'تأكيد التسجيل',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
