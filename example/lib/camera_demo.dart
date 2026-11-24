import 'package:custom_media_picker/custom_media_picker.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

/// Demo of [CustomMediaPicker.capture]: default UI or a fully custom one.
///
/// Captures count toward the same limit as the gallery picks: with
/// [maxSelection] 2 and 2 items already picked, the camera refuses the next
/// capture with a notice.
class CameraDemoSection extends StatefulWidget {
  /// 0 = unlimited.
  final int maxSelection;

  /// Items already picked in the gallery.
  final int pickedCount;

  /// Captures so far (owned by the parent so the gallery picker can count
  /// them too).
  final List<CapturedMedia> captures;
  final ValueChanged<CapturedMedia> onCaptured;
  final VoidCallback onClear;

  const CameraDemoSection({
    super.key,
    required this.maxSelection,
    required this.pickedCount,
    required this.captures,
    required this.onCaptured,
    required this.onClear,
  });

  @override
  State<CameraDemoSection> createState() => _CameraDemoSectionState();
}

class _CameraDemoSectionState extends State<CameraDemoSection> {
  bool _saveToGallery = false;
  bool _customUi = false;
  bool _limit15s = true;

  Future<void> _open() async {
    final messenger = ScaffoldMessenger.of(context);
    final media = await CustomMediaPicker.capture(
      context,
      config: CameraConfig(
        maxSelection: widget.maxSelection,
        selectedCount: widget.pickedCount + widget.captures.length,
        selectionLimitMessage: (max) => 'Max $max items — remove one first',
        maxVideoDuration: _limit15s ? const Duration(seconds: 15) : null,
        saveToGallery: _saveToGallery,
        galleryAlbum: _saveToGallery ? 'Custom Media Picker' : null,
        onSaveToGalleryFailed: (e) => messenger.showSnackBar(
          SnackBar(content: Text("Couldn't save to gallery: $e")),
        ),
        // Replace parts of the UI; anything left null keeps the default.
        topBarBuilder: _customUi ? _topBar : null,
        shutterBuilder: _customUi ? _shutter : null,
        overlayBuilder: _customUi ? (_, _) => const _ThirdsGrid() : null,
      ),
    );
    if (media != null && mounted) widget.onCaptured(media);
  }

  Widget _topBar(BuildContext context, CameraControls c) => Padding(
    padding: const EdgeInsets.all(8),
    child: Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Close',
          onPressed: c.isRecording ? null : c.close,
          icon: const Icon(Icons.arrow_back),
        ),
        const Spacer(),
        if (c.isRecording)
          Chip(
            avatar: const Icon(Icons.fiber_manual_record, color: Colors.red),
            label: Text(formatRecording(c.recordingElapsed)),
          ),
        const Spacer(),
        IconButton.filledTonal(
          tooltip: 'Flash',
          onPressed: c.cycleFlash,
          icon: Icon(flashIcon(c.flash)),
        ),
      ],
    ),
  );

  Widget _shutter(BuildContext context, CameraControls c) => GestureDetector(
    onTap: c.capture,
    child: Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.isRecording ? Colors.red : Colors.deepPurple,
        border: Border.all(color: Colors.white, width: 4),
      ),
      child: Icon(
        c.isRecording
            ? Icons.stop
            : (c.mode == CaptureMode.video ? Icons.videocam : Icons.camera),
        color: Colors.white,
        size: 36,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          title: const Text('Save captures to gallery'),
          value: _saveToGallery,
          onChanged: (v) => setState(() => _saveToGallery = v),
        ),
        SwitchListTile(
          title: const Text('Custom camera UI'),
          subtitle: const Text('Own top bar, shutter and grid overlay'),
          value: _customUi,
          onChanged: (v) => setState(() => _customUi = v),
        ),
        SwitchListTile(
          title: const Text('Limit videos to 15 s'),
          value: _limit15s,
          onChanged: (v) => setState(() => _limit15s = v),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _open,
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Open camera'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
        if (widget.captures.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Text(
                  'Captured (${widget.captures.length}) · selected '
                  '${widget.pickedCount + widget.captures.length}'
                  '${widget.maxSelection > 0 ? ' / ${widget.maxSelection}' : ''}',
                ),
                const Spacer(),
                TextButton(
                  onPressed: widget.onClear,
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
        for (final media in widget.captures)
          ListTile(
            leading: media.isVideo
                ? const Icon(Icons.videocam)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      media.file,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
            title: Text(
              media.isVideo
                  ? 'Video ${formatRecording(media.duration)}'
                  : 'Photo',
            ),
            subtitle: Text(
              media.galleryId == null
                  ? media.path.split('/').last
                  : 'Saved to gallery (${media.galleryId})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

/// Rule-of-thirds grid drawn over the preview.
class _ThirdsGrid extends StatelessWidget {
  const _ThirdsGrid();

  @override
  Widget build(BuildContext context) {
    const line = ColoredBox(color: Color(0x55FFFFFF));
    return IgnorePointer(
      child: Stack(
        children: [
          for (final f in [1 / 3, 2 / 3]) ...[
            Align(
              alignment: Alignment(0, f * 2 - 1),
              child: const SizedBox(
                height: 1,
                width: double.infinity,
                child: line,
              ),
            ),
            Align(
              alignment: Alignment(f * 2 - 1, 0),
              child: const SizedBox(
                width: 1,
                height: double.infinity,
                child: line,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
