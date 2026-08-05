import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'custom_media_picker/custom_media_picker.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Custom Media Picker Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF25D366),
        useMaterial3: true,
      ),
      home: const DemoHomePage(),
    );
  }
}

/// A couple of ready-made themes to prove the color tokens are injectable.
enum DemoTheme { light, dark, whatsapp, purple }

MediaPickerColors colorsFor(DemoTheme t) {
  switch (t) {
    case DemoTheme.light:
      return const MediaPickerColors();
    case DemoTheme.dark:
      return const MediaPickerColors(
        background: Color(0xFF121212),
        appBar: Color(0xFF1E1E1E),
        title: Color(0xFFFFFFFF),
        text: Color(0xFFFFFFFF),
        secondaryText: Color(0xFF9E9E9E),
        icon: Color(0xFFFFFFFF),
        selectedBadge: Color(0xFF64B5F6),
        confirmButton: Color(0xFF64B5F6),
        confirmButtonDisabled: Color(0xFF424242),
        tilePlaceholder: Color(0xFF2C2C2C),
        divider: Color(0x33FFFFFF),
      );
    case DemoTheme.whatsapp:
      return const MediaPickerColors(
        selectedBadge: Color(0xFF25D366),
        confirmButton: Color(0xFF128C7E),
      );
    case DemoTheme.purple:
      return const MediaPickerColors(
        background: Color(0xFFF7F2FA),
        appBar: Color(0xFFF7F2FA),
        title: Color(0xFF4A148C),
        icon: Color(0xFF4A148C),
        selectedBadge: Color(0xFF7B1FA2),
        confirmButton: Color(0xFF7B1FA2),
      );
  }
}

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  LayoutStyle _layout = LayoutStyle.sheet;
  ListStyle _list = ListStyle.grid;
  MediaFilter _filter = MediaFilter.all;
  FullScreenLeading _leading = FullScreenLeading.close;
  DemoTheme _theme = DemoTheme.light;
  int _maxSelection = 9; // 0 = unlimited
  int _gridColumns = 3;
  bool _enableSort = false; // off by default; user flips this on

  List<PickedMediaAsset> _picked = [];

  Future<void> _pick() async {
    final config = MediaPickerConfig(
      layoutStyle: _layout,
      listStyle: _list,
      mediaFilter: _filter,
      fullScreenLeading: _leading,
      maxSelection: _maxSelection,
      gridCrossAxisCount: _gridColumns,
      enableSort: _enableSort,
      colors: colorsFor(_theme),
      title: 'Select media',
      confirmLabelBuilder: (n) => 'Send ($n)',
      onSelectionLimitReached: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Max $_maxSelection items'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      onPermissionDenied: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photos permission denied — enable it in Settings'),
          ),
        );
      },
    );

    final assets = await CustomMediaPicker.pick(context, config: config);
    if (assets != null && mounted) {
      setState(() => _picked = assets);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custom Media Picker')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Layout'),
          SegmentedButton<LayoutStyle>(
            segments: const [
              ButtonSegment(
                  value: LayoutStyle.sheet,
                  label: Text('Sheet'),
                  icon: Icon(Icons.call_to_action_outlined)),
              ButtonSegment(
                  value: LayoutStyle.fullScreen,
                  label: Text('Full screen'),
                  icon: Icon(Icons.fullscreen)),
            ],
            selected: {_layout},
            onSelectionChanged: (s) => setState(() => _layout = s.first),
          ),
          if (_layout == LayoutStyle.fullScreen) ...[
            const SizedBox(height: 8),
            SegmentedButton<FullScreenLeading>(
              segments: const [
                ButtonSegment(
                    value: FullScreenLeading.close,
                    label: Text('X (close)'),
                    icon: Icon(Icons.close)),
                ButtonSegment(
                    value: FullScreenLeading.back,
                    label: Text('Back'),
                    icon: Icon(Icons.arrow_back)),
              ],
              selected: {_leading},
              onSelectionChanged: (s) => setState(() => _leading = s.first),
            ),
          ],
          _section('List style'),
          SegmentedButton<ListStyle>(
            segments: const [
              ButtonSegment(
                  value: ListStyle.grid,
                  label: Text('Grid'),
                  icon: Icon(Icons.grid_view)),
              ButtonSegment(
                  value: ListStyle.listView,
                  label: Text('List'),
                  icon: Icon(Icons.view_list)),
            ],
            selected: {_list},
            onSelectionChanged: (s) => setState(() => _list = s.first),
          ),
          if (_list == ListStyle.grid) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Grid columns'),
                Expanded(
                  child: Slider(
                    value: _gridColumns.toDouble(),
                    min: 2,
                    max: 5,
                    divisions: 3,
                    label: '$_gridColumns',
                    onChanged: (v) => setState(() => _gridColumns = v.round()),
                  ),
                ),
                Text('$_gridColumns'),
              ],
            ),
          ],
          _section('Media filter'),
          SegmentedButton<MediaFilter>(
            segments: const [
              ButtonSegment(value: MediaFilter.all, label: Text('All')),
              ButtonSegment(
                  value: MediaFilter.onlyImages, label: Text('Images')),
              ButtonSegment(
                  value: MediaFilter.onlyVideos, label: Text('Videos')),
            ],
            selected: {_filter},
            onSelectionChanged: (s) => setState(() => _filter = s.first),
          ),
          _section('Max selection (0 = unlimited)'),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _maxSelection.toDouble(),
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: _maxSelection == 0 ? '∞' : '$_maxSelection',
                  onChanged: (v) => setState(() => _maxSelection = v.round()),
                ),
              ),
              SizedBox(
                width: 32,
                child: Text(_maxSelection == 0 ? '∞' : '$_maxSelection'),
              ),
            ],
          ),
          _section('Sort (Recent tab)'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show sort row'),
            subtitle: const Text('Old to new / New to old / Custom range'),
            value: _enableSort,
            onChanged: (v) => setState(() => _enableSort = v),
          ),
          _section('Theme (color tokens)'),
          Wrap(
            spacing: 8,
            children: DemoTheme.values.map((t) {
              return ChoiceChip(
                label: Text(t.name),
                selected: _theme == t,
                onSelected: (_) => setState(() => _theme = t),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Open picker'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 24),
          if (_picked.isNotEmpty) ...[
            _section('Picked (${_picked.length}) — in selection order'),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: _picked.length,
              itemBuilder: (context, i) => _ResultTile(
                asset: _picked[i],
                index: i + 1,
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      );
}

class _ResultTile extends StatelessWidget {
  final PickedMediaAsset asset;
  final int index;

  const _ResultTile({required this.asset, required this.index});

  @override
  Widget build(BuildContext context) {
    final path = asset.resolvedPath;

    Widget content;
    if (!asset.isVideo && path != null) {
      content = Image.file(File(path), fit: BoxFit.cover);
    } else if (asset.isVideo) {
      content = _VideoThumbnail(path: path, durationLabel: asset.durationLabel);
    } else {
      content = Container(
        color: Colors.black87,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              asset.isVideo ? Icons.videocam : Icons.image,
              color: Colors.white,
            ),
            if (asset.isVideo)
              Text(
                asset.durationLabel,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AssetPreviewPage(asset: asset),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
            PositionedDirectional(
              top: 4,
              start: 4,
              child: CircleAvatar(
                radius: 10,
                backgroundColor: Colors.black54,
                child: Text(
                  '$index',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoThumbnail extends StatefulWidget {
  final String? path;
  final String durationLabel;

  const _VideoThumbnail({required this.path, required this.durationLabel});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.path != null) {
      _controller = VideoPlayerController.file(File(widget.path!));
      _controller!.initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _isInitialized = true;
        });
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.path == null) {
      return Container(
        color: Colors.black87,
        alignment: Alignment.center,
        child: const Icon(Icons.videocam, color: Colors.white),
      );
    }

    if (_controller == null || !_isInitialized) {
      return Container(
        color: Colors.black87,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
        Positioned(
          left: 6,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              widget.durationLabel,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
        const Positioned(
          right: 6,
          bottom: 6,
          child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 24),
        ),
      ],
    );
  }
}

class AssetPreviewPage extends StatefulWidget {
  final PickedMediaAsset asset;

  const AssetPreviewPage({super.key, required this.asset});

  @override
  State<AssetPreviewPage> createState() => _AssetPreviewPageState();
}

class _AssetPreviewPageState extends State<AssetPreviewPage> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _showControls = true;
  final String _qualityLabel = 'Auto';

  @override
  void initState() {
    super.initState();
    final path = widget.asset.resolvedPath;

    if (widget.asset.isVideo && path != null) {
      _videoController = VideoPlayerController.file(File(path));
      _videoController!.initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _isVideoInitialized = true;
        });
        _videoController!.play();
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.asset.resolvedPath;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.asset.name ?? widget.asset.typeString),
      ),
      body: SafeArea(
        child: path == null
            ? const Center(
                child: Text(
                  'Unable to resolve media path',
                  style: TextStyle(color: Colors.white),
                ),
              )
            : widget.asset.isVideo
                ? (_videoController != null && _isVideoInitialized)
                    ? Stack(
                        children: [
                          Center(
                            child: AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            ),
                          ),
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _showControls = !_showControls);
                              },
                              child: Container(color: Colors.transparent),
                            ),
                          ),
                          if (_showControls)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 8, 12, 16),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black87,
                                      Colors.transparent
                                    ],
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              if (_videoController!
                                                  .value.isPlaying) {
                                                _videoController!.pause();
                                              } else {
                                                _videoController!.play();
                                              }
                                            });
                                          },
                                          icon: Icon(
                                            _videoController!.value.isPlaying
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                        Expanded(
                                          child: VideoProgressIndicator(
                                            _videoController!,
                                            allowScrubbing: true,
                                            colors: const VideoProgressColors(
                                              playedColor: Color(0xFF25D366),
                                              bufferedColor: Colors.white38,
                                              backgroundColor: Colors.white24,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _formatDuration(
                                              _videoController!.value.position),
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.high_quality,
                                            color: Colors.white70),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Quality: $_qualityLabel',
                                          style: const TextStyle(
                                              color: Colors.white70),
                                        ),
                                        const Spacer(),
                                        const Icon(Icons.settings,
                                            color: Colors.white70),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Playback',
                                          style:
                                              TextStyle(color: Colors.white70),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      )
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white))
                : InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Image.file(File(path), fit: BoxFit.contain),
                  ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
