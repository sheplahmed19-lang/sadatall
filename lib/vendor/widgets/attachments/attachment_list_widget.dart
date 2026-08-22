import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:audioplayers/audioplayers.dart';
import '../../constants/app_constants.dart';
import '../../theme/app_theme.dart';
import '../../models/attachment.dart';
import '../../services/wasabi_service.dart';
import 'voice_recorder_widget.dart';

class AttachmentListWidget extends StatefulWidget {
  final String orderId;
  final List<Attachment> attachments;
  final Function(List<Attachment>) onAttachmentsChanged;

  const AttachmentListWidget({
    super.key,
    required this.orderId,
    required this.attachments,
    required this.onAttachmentsChanged,
  });

  @override
  State<AttachmentListWidget> createState() => _AttachmentListWidgetState();
}

class _AttachmentListWidgetState extends State<AttachmentListWidget> {
  final ImagePicker _imagePicker = ImagePicker();
  final WasabiService _wasabiService = WasabiService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _playingAudioPath;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('اختيار من المعرض'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImages();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('التقاط صورة مباشرة'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImages(fromCamera: true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImages({bool fromCamera = false}) async {
    try {
      // Check current image count
      final currentImageCount = widget.attachments
          .where((a) => a.type == AttachmentType.image)
          .length;

      if (currentImageCount >= AppConstants.maxImages) {
        _showError('لا يمكن إضافة أكثر من ${AppConstants.maxImages} صور');
        return;
      }

      final List<XFile> images;
      if (fromCamera) {
        final XFile? photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
        );
        images = photo != null ? [photo] : [];
      } else {
        images = await _imagePicker.pickMultiImage();
      }

      if (images.isEmpty) return;

      // Check if adding these images exceeds the limit
      if (currentImageCount + images.length > AppConstants.maxImages) {
        _showError(
          'يمكنك إضافة ${AppConstants.maxImages - currentImageCount} صورة فقط',
        );
        return;
      }

      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      final List<Attachment> newAttachments = [];
      final List<String> uploadErrors = [];

      for (int i = 0; i < images.length; i++) {
        final XFile image = images[i];

        // Compress image
        final File compressedImage = await _compressImage(File(image.path));

        // Check file size
        final fileSize = await compressedImage.length();
        if (fileSize > AppConstants.maxImageSizeMB * 1024 * 1024) {
          _showError(
            'حجم الصورة كبير جداً (الحد الأقصى ${AppConstants.maxImageSizeMB}MB)',
          );
          continue;
        }

        // Generate filename
        final fileName = _wasabiService.generateFileName(
          orderId: widget.orderId,
          extension: 'jpg',
          index: currentImageCount + i,
        );

        // Upload to Wasabi — a failure here must not be silently dropped:
        // the old null-on-failure contract meant a fully-failed upload
        // showed zero feedback at all (no error, no success message).
        try {
          final uploadedPath = await _wasabiService.uploadFile(
            file: compressedImage,
            fileName: fileName,
          );
          newAttachments.add(
            Attachment(
              type: AttachmentType.image,
              link: uploadedPath,
              localPath: compressedImage.path, // Store local path
            ),
          );
        } catch (e) {
          uploadErrors.add(e.toString());
        }

        setState(() {
          _uploadProgress = (i + 1) / images.length;
        });
      }

      setState(() {
        _isUploading = false;
      });

      if (newAttachments.isNotEmpty) {
        widget.onAttachmentsChanged([...widget.attachments, ...newAttachments]);
        _showSuccess('تم رفع ${newAttachments.length} صورة بنجاح');
      }
      if (uploadErrors.isNotEmpty) {
        _showError(
          'تعذر رفع ${uploadErrors.length} صورة: ${uploadErrors.first}',
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      _showError('حدث خطأ أثناء رفع الصور: ${e.toString()}');
    }
  }

  Future<File> _compressImage(File file) async {
    try {
      // Read image
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return file;

      // Resize if too large
      img.Image resized = image;
      if (image.width > 1920 || image.height > 1920) {
        resized = img.copyResize(
          image,
          width: image.width > image.height ? 1920 : null,
          height: image.height > image.width ? 1920 : null,
        );
      }

      // Compress to JPEG with quality 85
      final compressed = img.encodeJpg(resized, quality: 85);

      // Write to temp file
      final tempPath =
          '${file.parent.path}/compressed_${file.uri.pathSegments.last}';
      final compressedFile = File(tempPath);
      await compressedFile.writeAsBytes(compressed);

      return compressedFile;
    } catch (e) {
      ('Error compressing image: $e');
      return file;
    }
  }

  Future<void> _recordVoice() async {
    try {
      // Check if voice note already exists
      final hasVoice = widget.attachments.any(
        (a) => a.type == AttachmentType.voice,
      );

      if (hasVoice) {
        _showError('يمكنك إضافة ملاحظة صوتية واحدة فقط');
        return;
      }

      // Show voice recorder
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => VoiceRecorderWidget(
          onRecordingComplete: (File audioFile) async {
            setState(() {
              _isUploading = true;
              _uploadProgress = 0.0;
            });

            // Check file size
            final fileSize = await audioFile.length();
            if (fileSize > AppConstants.maxVoiceNoteSizeMB * 1024 * 1024) {
              setState(() {
                _isUploading = false;
              });
              _showError(
                'حجم الملف الصوتي كبير جداً (الحد الأقصى ${AppConstants.maxVoiceNoteSizeMB}MB)',
              );
              return;
            }

            // Generate filename
            final fileName = _wasabiService.generateFileName(
              orderId: widget.orderId,
              extension: 'm4a',
            );

            // Upload to Wasabi
            try {
              final uploadedPath = await _wasabiService.uploadFile(
                file: audioFile,
                fileName: fileName,
              );

              setState(() {
                _isUploading = false;
              });

              final newAttachment = Attachment(
                type: AttachmentType.voice,
                link: uploadedPath,
              );
              widget.onAttachmentsChanged([
                ...widget.attachments,
                newAttachment,
              ]);
              _showSuccess('تم رفع الملاحظة الصوتية بنجاح');
            } catch (e) {
              setState(() {
                _isUploading = false;
              });
              _showError('فشل رفع الملاحظة الصوتية: ${e.toString()}');
            }
          },
        ),
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      _showError('حدث خطأ أثناء تسجيل الملاحظة الصوتية');
      ('Error recording voice: $e');
    }
  }

  void _deleteAttachment(int index) {
    final updatedAttachments = List<Attachment>.from(widget.attachments);
    updatedAttachments.removeAt(index);
    widget.onAttachmentsChanged(updatedAttachments);
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageCount = widget.attachments
        .where((a) => a.type == AttachmentType.image)
        .length;
    final hasVoice = widget.attachments.any(
      (a) => a.type == AttachmentType.voice,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with buttons
        Row(
          children: [
            // const Text(
            //   'المرفقات (اختياري)',
            //   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            // ),
            // const Spacer(),

            // Add image button
            ElevatedButton.icon(
              onPressed: _isUploading || imageCount >= AppConstants.maxImages
                  ? null
                  : _showImageSourcePicker,
              icon: const Icon(Icons.image, size: 18),
              label: Text('صورة ($imageCount/${AppConstants.maxImages})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                textStyle: const TextStyle(fontSize: 14),
              ),
            ),

            const SizedBox(width: 8),

            // Add voice button
            ElevatedButton.icon(
              onPressed: _isUploading || hasVoice ? null : _recordVoice,
              icon: const Icon(Icons.mic, size: 18),
              label: Text(hasVoice ? 'تم التسجيل' : 'صوت'),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasVoice ? Colors.grey : AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                textStyle: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Upload progress
        if (_isUploading)
          Column(
            children: [
              LinearProgressIndicator(
                value: _uploadProgress,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'جاري الرفع... ${(_uploadProgress * 100).toInt()}%',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
            ],
          ),

        // Attachments list
        if (widget.attachments.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.attachments.asMap().entries.map((entry) {
              final index = entry.key;
              final attachment = entry.value;

              return _buildAttachmentCard(attachment, index);
            }).toList(),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.attach_file, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'لم يتم إضافة أي مرفقات',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAttachmentCard(Attachment attachment, int index) {
    if (attachment.type == AttachmentType.image) {
      return Stack(
        children: [
          GestureDetector(
            onTap: () => _showFullImage(context, attachment),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: attachment.localPath != null
                    ? Image.file(File(attachment.localPath!), fit: BoxFit.cover)
                    : Image.network(
                        'https://s3.${AppConstants.wasabiRegion}.wasabisys.com/${AppConstants.wasabiBucket}/${attachment.link}',
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.broken_image,
                            size: 40,
                            color: Colors.grey,
                          );
                        },
                      ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _deleteAttachment(index),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    } else {
      // Voice attachment
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primaryColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text(
              'ملاحظة صوتية',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _deleteAttachment(index),
              child: const Icon(Icons.close, size: 18, color: Colors.red),
            ),
          ],
        ),
      );
    }
  }

  void _showFullImage(BuildContext context, Attachment attachment) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: attachment.localPath != null
                    ? Image.file(
                        File(attachment.localPath!),
                        fit: BoxFit.contain,
                      )
                    : const Icon(
                        Icons.broken_image,
                        size: 60,
                        color: Colors.white,
                      ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
