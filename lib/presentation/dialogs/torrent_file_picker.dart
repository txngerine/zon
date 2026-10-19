import 'package:flutter/material.dart';

import '../../core/theme/app_type.dart';
import '../../core/theme/zon_palette.dart';
import '../../core/utils/formatters.dart';
import '../../engine/torrent/torrent_manifest.dart';

/// Folder tree of a torrent's files with tri-state checkboxes, search and
/// quick filters. Rows are built lazily, so torrents with thousands of files
/// stay smooth.
class TorrentFilePicker extends StatefulWidget {
  const TorrentFilePicker({
    super.key,
    required this.manifest,
    required this.selected,
    required this.onChanged,
  });

  final TorrentManifest manifest;

  /// Chosen file indexes (see [TorrentFileEntry.index]).
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  State<TorrentFilePicker> createState() => _TorrentFilePickerState();
}

const _videoExtensions = {
  'mp4', 'mkv', 'avi', 'mov', 'webm', 'm4v', 'ts', 'wmv', 'flv', 'mpg', //
  'mpeg', 'm2ts',
};

const _extraExtensions = {
  'txt', 'nfo', 'url', 'sfv', 'md5', 'jpg', 'jpeg', 'png', 'gif', 'exe', //
  'lnk', 'html', 'htm', 'db',
};

String _extension(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

class _Folder {
  _Folder(this.name, this.depth);

  final String name;
  final int depth;
  final Map<String, _Folder> folders = {};
  final List<TorrentFileEntry> files = [];

  /// Every file below this folder.
  final List<TorrentFileEntry> all = [];
  int size = 0;
}

/// One visible line: a folder or a file.
class _Row {
  const _Row.folder(this.folder, this.depth) : file = null;
  const _Row.file(this.file, this.depth) : folder = null;

  final _Folder? folder;
  final TorrentFileEntry? file;
  final int depth;
}

class _TorrentFilePickerState extends State<TorrentFilePicker> {
  static const _rowHeight = 30.0;

  late _Folder _root;
  final Set<_Folder> _expanded = {};
  final TextEditingController _search = TextEditingController();
  List<_Row> _rows = const [];

  @override
  void initState() {
    super.initState();
    _build();
  }

  @override
  void didUpdateWidget(TorrentFilePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.manifest, widget.manifest)) {
      _expanded.clear();
      _build();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _build() {
    final root = _Folder(widget.manifest.name, -1);
    for (final file in widget.manifest.visibleFiles) {
      var folder = root;
      folder.all.add(file);
      folder.size += file.length;
      for (final segment in file.segments.take(file.segments.length - 1)) {
        folder = folder.folders.putIfAbsent(
          segment,
          () => _Folder(segment, folder.depth + 1),
        );
        folder.all.add(file);
        folder.size += file.length;
      }
      folder.files.add(file);
    }
    _root = root;
    // Small torrents open fully; big ones open just the first level.
    final small = root.all.length <= 60;
    void open(_Folder folder) {
      for (final child in folder.folders.values) {
        if (small || folder == root && root.folders.length == 1) {
          _expanded.add(child);
        }
        if (small) open(child);
      }
    }

    open(root);
    _refreshRows();
  }

  void _refreshRows() {
    final query = _search.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      _rows = [
        for (final file in _root.all)
          if (file.path.toLowerCase().contains(query)) _Row.file(file, 0),
      ];
      return;
    }
    final rows = <_Row>[];
    void walk(_Folder folder) {
      final folders = folder.folders.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      for (final child in folders) {
        rows.add(_Row.folder(child, child.depth));
        if (_expanded.contains(child)) walk(child);
      }
      for (final file in folder.files) {
        rows.add(_Row.file(file, folder.depth + 1));
      }
    }

    walk(_root);
    _rows = rows;
  }

  /// Files the bulk actions apply to: search matches, or everything.
  Iterable<TorrentFileEntry> get _scope =>
      _search.text.trim().isEmpty ? _root.all : _rows.map((row) => row.file!);

  void _set(Iterable<TorrentFileEntry> files, bool selected) {
    final next = Set<int>.of(widget.selected);
    for (final file in files) {
      selected ? next.add(file.index) : next.remove(file.index);
    }
    widget.onChanged(next);
  }

  void _only(bool Function(TorrentFileEntry file) keep) {
    final next = Set<int>.of(widget.selected);
    for (final file in _scope) {
      keep(file) ? next.add(file.index) : next.remove(file.index);
    }
    widget.onChanged(next);
  }

  bool? _folderState(_Folder folder) {
    var picked = 0;
    for (final file in folder.all) {
      if (widget.selected.contains(file.index)) picked++;
    }
    if (picked == 0) return false;
    return picked == folder.all.length ? true : null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final all = _root.all;
    var pickedSize = 0;
    var pickedCount = 0;
    for (final file in all) {
      if (widget.selected.contains(file.index)) {
        pickedCount++;
        pickedSize += file.length;
      }
    }
    final hasVideo = all.any(
      (file) => _videoExtensions.contains(_extension(file.name)),
    );
    final searching = _search.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('FILES', style: AppType.eyebrow(palette.textMuted)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$pickedCount of ${all.length}  •  '
                '${formatBytes(pickedSize)} of ${formatBytes(_root.size)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: AppType.numeric(palette.textSecondary, size: 11.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (all.length > 1) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Action(
                label: searching ? 'Select matches' : 'All',
                onTap: () => _set(_scope, true),
              ),
              _Action(
                label: searching ? 'Clear matches' : 'None',
                onTap: () => _set(_scope, false),
              ),
              if (hasVideo)
                _Action(
                  label: 'Videos only',
                  onTap: () => _only(
                    (file) => _videoExtensions.contains(_extension(file.name)),
                  ),
                ),
              _Action(
                label: 'Skip extras',
                onTap: () => _only(
                  (file) =>
                      widget.selected.contains(file.index) &&
                      !_extraExtensions.contains(_extension(file.name)) &&
                      !file.name.toLowerCase().contains('sample'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            children: [
              if (all.length > 8) _searchField(palette),
              SizedBox(
                height: (_rows.length * _rowHeight).clamp(_rowHeight, 280),
                child: _rows.isEmpty
                    ? Center(
                        child: Text(
                          'No files match',
                          style: AppType.body(palette.textMuted, size: 12),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        itemExtent: _rowHeight,
                        itemCount: _rows.length,
                        itemBuilder: (context, i) => _row(palette, _rows[i]),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _searchField(ZonPalette palette) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 15, color: palette.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(_refreshRows),
              style: AppType.body(palette.textPrimary, size: 12.5),
              decoration: InputDecoration(
                hintText: 'Search ${_root.all.length} files',
                hintStyle: AppType.body(palette.textMuted, size: 12.5),
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (_search.text.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() {
                _search.clear();
                _refreshRows();
              }),
              child: Icon(
                Icons.close_rounded,
                size: 15,
                color: palette.textMuted,
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(ZonPalette palette, _Row row) {
    final folder = row.folder;
    final file = row.file;
    final indent = 8.0 + row.depth * 16;

    if (folder != null) {
      final open = _expanded.contains(folder);
      final state = _folderState(folder);
      return InkWell(
        onTap: () => setState(() {
          open ? _expanded.remove(folder) : _expanded.add(folder);
          _refreshRows();
        }),
        child: Padding(
          padding: EdgeInsets.only(left: indent, right: 12),
          child: Row(
            children: [
              Icon(
                open
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_right_rounded,
                size: 16,
                color: palette.textMuted,
              ),
              const SizedBox(width: 4),
              _Tick(value: state, onTap: () => _set(folder.all, state != true)),
              const SizedBox(width: 9),
              Icon(Icons.folder_outlined, size: 15, color: palette.textMuted),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  folder.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body(
                    palette.textPrimary,
                    size: 12.5,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${folder.all.length}  •  ${formatBytes(folder.size)}',
                style: AppType.numeric(palette.textMuted, size: 11),
              ),
            ],
          ),
        ),
      );
    }

    final picked = widget.selected.contains(file!.index);
    final searching = _search.text.trim().isNotEmpty;
    return InkWell(
      onTap: () => _set([file], !picked),
      child: Padding(
        // Line up with folder checkboxes (past the chevron).
        padding: EdgeInsets.only(left: indent + 20, right: 12),
        child: Row(
          children: [
            _Tick(value: picked, onTap: () => _set([file], !picked)),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                searching ? file.path : file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.body(
                  picked ? palette.textPrimary : palette.textMuted,
                  size: 12.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              formatBytes(file.length),
              style: AppType.numeric(palette.textMuted, size: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small checkbox: checked, empty, or a dash for a partly chosen folder.
class _Tick extends StatelessWidget {
  const _Tick({required this.value, required this.onTap});

  final bool? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final on = value != false;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: on ? palette.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: on ? palette.accent : palette.borderStrong,
            width: 1.4,
          ),
        ),
        child: on
            ? Icon(
                value == true ? Icons.check_rounded : Icons.remove_rounded,
                size: 12,
                color: palette.onAccent,
              )
            : null,
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surfaceHigh,
      shape: StadiumBorder(side: BorderSide(color: palette.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          child: Text(
            label,
            style: AppType.body(
              palette.textSecondary,
              size: 11.5,
              weight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
