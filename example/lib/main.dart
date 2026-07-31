import 'dart:io';

import 'package:custom_media_picker/custom_media_picker.dart';
import 'package:flutter/material.dart';

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
  int _maxSelection = 9;
  int _gridColumns = 3;

  List<PickedMediaAsset> _picked = [];

  Future<void> _pick() async {
    final config = MediaPickerConfig(
      layoutStyle: _layout,
      listStyle: _list,
      mediaFilter: _filter,
      fullScreenLeading: _leading,
      maxSelection: _maxSelection,
      gridCrossAxisCount: _gridColumns,
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
                icon: Icon(Icons.call_to_action_outlined),
              ),
              ButtonSegment(
                value: LayoutStyle.fullScreen,
                label: Text('Full screen'),
                icon: Icon(Icons.fullscreen),
              ),
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
                  icon: Icon(Icons.close),
                ),
                ButtonSegment(
                  value: FullScreenLeading.back,
                  label: Text('Back'),
                  icon: Icon(Icons.arrow_back),
                ),
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
                icon: Icon(Icons.grid_view),
              ),
              ButtonSegment(
                value: ListStyle.listView,
                label: Text('List'),
                icon: Icon(Icons.view_list),
              ),
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
                value: MediaFilter.onlyImages,
                label: Text('Images'),
              ),
              ButtonSegment(
                value: MediaFilter.onlyVideos,
                label: Text('Videos'),
              ),
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
}

Widget _section(String label) {
  return Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
    ),
  );
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.asset, required this.index});

  final PickedMediaAsset asset;
  final int index;

  @override
  Widget build(BuildContext context) {
    final file = asset.resolvedPath == null ? null : File(asset.resolvedPath!);
    final hasFile = file != null && file.existsSync();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade200,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: hasFile
                ? Image.file(file, fit: BoxFit.cover)
                : const ColoredBox(color: Colors.grey),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$index',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
