import 'package:flutter/material.dart';

import 'picker_config.dart';

/// Opens the picker's own date-range selector (used by the Recent tab's
/// "Custom range" sort option).
///
/// This is intentionally not `showDateRangePicker` — that dialog can't be
/// made to page months horizontally, drop its edit-mode toggle, or use
/// custom header spacing/labels, all of which this widget controls
/// directly.
Future<DateTimeRange?> showMediaDateRangePicker({
  required BuildContext context,
  required MediaPickerConfig config,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialRange,
}) {
  return showModalBottomSheet<DateTimeRange>(
    context: context,
    isScrollControlled: true,
    backgroundColor: config.colors.dateRangeSurface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(config.sheetCornerRadius),
      ),
    ),
    builder: (_) => _MediaDateRangeSheet(
      config: config,
      firstDate: firstDate,
      lastDate: lastDate,
      initialRange: initialRange,
    ),
  );
}

class _MediaDateRangeSheet extends StatefulWidget {
  final MediaPickerConfig config;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTimeRange? initialRange;

  const _MediaDateRangeSheet({
    required this.config,
    required this.firstDate,
    required this.lastDate,
    this.initialRange,
  });

  @override
  State<_MediaDateRangeSheet> createState() => _MediaDateRangeSheetState();
}

class _MediaDateRangeSheetState extends State<_MediaDateRangeSheet> {
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _monthAbbrs = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const _rowHeight = 42.0;

  late final DateTime _firstMonth =
      DateTime(widget.firstDate.year, widget.firstDate.month);
  late final DateTime _firstDay = _dayOnly(widget.firstDate);
  late final DateTime _lastDay = _dayOnly(widget.lastDate);
  late final int _pageCount =
      _monthIndex(DateTime(widget.lastDate.year, widget.lastDate.month)) + 1;

  late final PageController _pageController;
  late int _pageIndex;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  MediaPickerConfig get config => widget.config;
  MediaPickerColors get c => config.colors;

  /// Tracks [MediaPickerColors.confirmButton] unless the caller passed an
  /// explicit override.
  Color get _selectedFill => c.dateRangeSelectedFill ?? c.confirmButton;
  Color get _rangeFill =>
      c.dateRangeRangeFill ?? c.confirmButton.withValues(alpha: 0.5);

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int _monthIndex(DateTime month) =>
      (month.year - _firstMonth.year) * 12 + (month.month - _firstMonth.month);

  DateTime _monthAt(int index) =>
      DateTime(_firstMonth.year, _firstMonth.month + index);

  @override
  void initState() {
    super.initState();
    _rangeStart = widget.initialRange?.start;
    _rangeEnd = widget.initialRange?.end;
    final anchor = _rangeStart ?? widget.lastDate;
    _pageIndex = _monthIndex(DateTime(anchor.year, anchor.month))
        .clamp(0, _pageCount - 1);
    _pageController = PageController(initialPage: _pageIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _onDayTap(DateTime day) {
    setState(() {
      if (_rangeStart == null || _rangeEnd != null) {
        _rangeStart = day;
        _rangeEnd = null;
      } else if (day.isBefore(_rangeStart!)) {
        _rangeEnd = _rangeStart;
        _rangeStart = day;
      } else {
        _rangeEnd = day;
      }
    });
  }

  void _save() {
    final start = _rangeStart;
    if (start == null) return;
    Navigator.of(context)
        .pop(DateTimeRange(start: start, end: _rangeEnd ?? start));
  }

  String _shortDate(DateTime d) => '${d.day} ${_monthAbbrs[d.month - 1]}';

  String _headerLabel() {
    final start =
        _rangeStart == null ? config.dateRangeStartLabel : _shortDate(_rangeStart!);
    final end =
        _rangeEnd == null ? config.dateRangeEndLabel : _shortDate(_rangeEnd!);
    return '$start - $end';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (config.showSheetDragHandle)
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              decoration: BoxDecoration(
                color: c.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          _buildActionBar(),
          _buildMonthNav(),
          _buildWeekdayRow(),
          SizedBox(
            height: _rowHeight * 6,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pageCount,
              onPageChanged: (i) => setState(() => _pageIndex = i),
              itemBuilder: (_, i) => _buildMonthGrid(_monthAt(i)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(Icons.close, color: c.icon, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _headerLabel(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _rangeStart == null ? null : _save,
            child: Text(
              config.dateRangeSaveLabel,
              style: TextStyle(
                color: _selectedFill
                    .withValues(alpha: _rangeStart == null ? 0.5 : 1),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthNav() {
    final month = _monthAt(_pageIndex);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: c.icon),
            onPressed:
                _pageIndex > 0 ? () => _goToPage(_pageIndex - 1) : null,
          ),
          Expanded(
            child: Center(
              child: Text(
                '${_monthNames[month.month - 1]} ${month.year}',
                style: TextStyle(
                  color: c.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: c.icon),
            onPressed: _pageIndex < _pageCount - 1
                ? () => _goToPage(_pageIndex + 1)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: _weekdayLabels
            .map((l) => Expanded(
                  child: Center(
                    child: Text(
                      l,
                      style: TextStyle(color: c.secondaryText, fontSize: 12),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  /// Always 6 rows so every month page is the same height while paging.
  Widget _buildMonthGrid(DateTime month) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final leading = firstOfMonth.weekday % 7; // Sunday = 0
    final gridStart = firstOfMonth.subtract(Duration(days: leading));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: List.generate(6, (row) {
          return Expanded(
            child: Row(
              children: List.generate(7, (col) {
                final date = gridStart.add(Duration(days: row * 7 + col));
                return Expanded(
                  child: date.month == month.month
                      ? _dayCell(date)
                      : const SizedBox.shrink(),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _dayCell(DateTime date) {
    final day = _dayOnly(date);
    final enabled = !day.isBefore(_firstDay) && !day.isAfter(_lastDay);
    final isStart = _rangeStart != null && _sameDay(day, _rangeStart!);
    final isEnd = _rangeEnd != null && _sameDay(day, _rangeEnd!);
    final hasRange = _rangeStart != null &&
        _rangeEnd != null &&
        !_sameDay(_rangeStart!, _rangeEnd!);
    final inRange = _rangeStart != null &&
        _rangeEnd != null &&
        day.isAfter(_rangeStart!) &&
        day.isBefore(_rangeEnd!);

    return GestureDetector(
      onTap: enabled ? () => _onDayTap(day) : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isStart && hasRange)
            Positioned.fill(
              child: Row(
                children: [
                  const Spacer(),
                  Expanded(child: Container(color: _rangeFill)),
                ],
              ),
            ),
          if (isEnd && hasRange)
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(child: Container(color: _rangeFill)),
                  const Spacer(),
                ],
              ),
            ),
          if (inRange) Positioned.fill(child: Container(color: _rangeFill)),
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isStart || isEnd) ? _selectedFill : null,
            ),
            child: Text(
              '${date.day}',
              style: TextStyle(
                color: !enabled
                    ? c.secondaryText.withValues(alpha: 0.4)
                    : (isStart || isEnd)
                        ? c.dateRangeHeaderText
                        : inRange
                            ? c.dateRangeRangeText
                            : c.text,
                fontWeight:
                    (isStart || isEnd) ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
