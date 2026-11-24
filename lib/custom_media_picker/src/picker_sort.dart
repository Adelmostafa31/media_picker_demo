// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'picker_config.dart';

/// The app's [MaterialLocalizations], or the English defaults when the app
/// has none (e.g. a `WidgetsApp`/`CupertinoApp` without Material delegates).
MaterialLocalizations pickerLocalizations(BuildContext context) =>
    Localizations.of<MaterialLocalizations>(context, MaterialLocalizations) ??
    const DefaultMaterialLocalizations();

/// Tappable "Sort: New to old ⌄" row above the Recent feed.
class PickerSortRow extends StatelessWidget {
  final MediaPickerConfig config;
  final MediaSortOrder sortOrder;
  final DateTimeRange? dateRange;
  final VoidCallback onTap;
  final VoidCallback onClearRange;

  const PickerSortRow({
    super.key,
    required this.config,
    required this.sortOrder,
    required this.dateRange,
    required this.onTap,
    required this.onClearRange,
  });

  String _label(MaterialLocalizations l10n) {
    switch (sortOrder) {
      case MediaSortOrder.oldestFirst:
        return config.sortOldToNewLabel;
      case MediaSortOrder.newestFirst:
        return config.sortNewToOldLabel;
      case MediaSortOrder.dateRange:
        final r = dateRange;
        if (r == null) return config.sortDateRangeLabel;
        return '${l10n.formatShortMonthDay(r.start)} – '
            '${l10n.formatShortMonthDay(r.end)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = config.colors;
    final l10n = pickerLocalizations(context);
    final rangeActive =
        sortOrder == MediaSortOrder.dateRange && dateRange != null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              Icon(
                Icons.sort,
                size: 16,
                color: rangeActive ? c.sortAccent : c.icon,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${config.sortRowLabel}: ${_label(l10n)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: rangeActive ? c.sortAccent : c.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (rangeActive)
                IconButton(
                  onPressed: onClearRange,
                  tooltip: l10n.clearButtonTooltip,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  icon: Icon(Icons.close, size: 16, color: c.secondaryText),
                ),
              const Spacer(),
              Icon(Icons.keyboard_arrow_down, size: 18, color: c.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet listing the sort options; resolves to the chosen one.
Future<MediaSortOrder?> showPickerSortSheet({
  required BuildContext context,
  required MediaPickerConfig config,
  required MediaSortOrder current,
}) {
  final c = config.colors;
  Widget option(BuildContext ctx, MediaSortOrder order, String label) {
    final selected = order == current;
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: () => Navigator.of(ctx).pop(order),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? c.sortAccent : c.text,
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (selected) Icon(Icons.check, size: 18, color: c.sortAccent),
            ],
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<MediaSortOrder>(
    context: context,
    backgroundColor: c.background,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(config.sheetCornerRadius),
      ),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          option(ctx, MediaSortOrder.newestFirst, config.sortNewToOldLabel),
          option(ctx, MediaSortOrder.oldestFirst, config.sortOldToNewLabel),
          option(ctx, MediaSortOrder.dateRange, config.sortDateRangeLabel),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
