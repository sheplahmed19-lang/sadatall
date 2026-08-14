import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../models/attachment.dart';
import '../../theme/app_theme.dart';
import '../common/smart_image.dart';
import '../common/full_screen_image_viewer.dart';

class AttachmentDisplayWidget extends StatefulWidget {
  final List<Attachment> attachments;

  const AttachmentDisplayWidget({
    super.key,
    required this.attachments,
  });

  @override
  State<AttachmentDisplayWidget> createState() =>
      _AttachmentDisplayWidgetState();
}

class _AttachmentDisplayWidgetState extends State<AttachmentDisplayWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _currentPlayingUrl;
  String? _loadingUrl;

  @override
  void initState() {
    super.initState();

    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
          _currentPlayingUrl = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPauseAudio(String url) async {
    if (_currentPlayingUrl == url && _isPlaying) {
      await _audioPlayer.pause();
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    } else {
      // Prevent multiple interactions while loading
      if (_loadingUrl != null) return;

      setState(() {
        _loadingUrl = url;
      });

      try {
        if (_currentPlayingUrl != null && _currentPlayingUrl != url) {
          await _audioPlayer.stop();
        }

        await _audioPlayer.play(UrlSource(url));

        if (mounted) {
          setState(() {
            _isPlaying = true;
            _currentPlayingUrl = url;
            _loadingUrl = null;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _loadingUrl = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل تشغيل الصوت: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    final images = widget.attachments
        .where((a) => a.type == AttachmentType.image)
        .toList();
    final voices = widget.attachments
        .where((a) => a.type == AttachmentType.voice)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'المرفقات',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Images section
        if (images.isNotEmpty) ...[
          const Text(
            'الصور',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final image = images[index];
              final imageUrl = image.linkUrl ?? image.link;
              return GestureDetector(
                onTap: () => _showFullImage(context, imageUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SmartImage(
                    imageSource: imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],

        // Voice notes section
        if (voices.isNotEmpty) ...[
          const Text(
            'الملاحظات الصوتية',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...voices.map((voice) => _buildVoicePlayer(voice)),
        ],
      ],
    );
  }

  Widget _buildVoicePlayer(Attachment voice) {
    final voiceUrl = voice.linkUrl ?? voice.link;
    final isCurrentlyPlaying = _currentPlayingUrl == voiceUrl && _isPlaying;
    final isLoading = _loadingUrl == voiceUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Play/Pause button
              GestureDetector(
                onTap: isLoading ? null : () => _playPauseAudio(voiceUrl),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Icon(
                          isCurrentlyPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 28,
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Progress bar and time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: isCurrentlyPlaying
                            ? _position.inSeconds.toDouble()
                            : 0,
                        max: isCurrentlyPlaying &&
                                _duration.inSeconds.toDouble() > 0
                            ? _duration.inSeconds.toDouble()
                            : 1,
                        activeColor: AppTheme.primaryColor,
                        inactiveColor:
                            AppTheme.primaryColor.withValues(alpha: 0.3),
                        onChanged: isCurrentlyPlaying
                            ? (value) async {
                                final newPosition =
                                    Duration(seconds: value.toInt());
                                await _audioPlayer.seek(newPosition);
                              }
                            : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isLoading
                                ? 'جاري التحميل...'
                                : isCurrentlyPlaying
                                    ? _formatDuration(_position)
                                    : '00:00',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            isCurrentlyPlaying
                                ? _formatDuration(_duration)
                                : '00:00',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              children: [
                Center(
                  child: SmartImage(
                    imageSource: imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  top: 50,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
