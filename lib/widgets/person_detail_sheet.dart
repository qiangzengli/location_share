import 'package:x_amap_flutter_base/amap_flutter_base.dart';
import 'package:flutter/material.dart';
import 'package:location_share/models/participant_location.dart';
import 'package:location_share/utils/geo_utils.dart';
import 'package:location_share/utils/time_utils.dart';

Future<void> showPersonDetailSheet(
  BuildContext context, {
  required ParticipantLocation person,
  required bool isSelf,
  LatLng? viewerPosition,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final dist = viewerPosition == null
          ? null
          : distanceMeters(viewerPosition, person.latLng);
      return Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 8,
          bottom: MediaQuery.paddingOf(ctx).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              person.displayName,
              style: Theme.of(ctx).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              isSelf ? '这是你当前设备的位置' : '共享组成员',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            _row(ctx, '更新时间', relativeTimeZh(person.updatedAt)),
            if (person.accuracy != null)
              _row(ctx, '水平精度', '约 ${person.accuracy!.toStringAsFixed(0)} 米'),
            if (dist != null)
              _row(ctx, '距我约', '${dist.toStringAsFixed(0)} 米'),
            _row(
              ctx,
              '坐标',
              '${person.latitude.toStringAsFixed(5)}, ${person.longitude.toStringAsFixed(5)}',
            ),
          ],
        ),
      );
    },
  );
}

Widget _row(BuildContext context, String k, String v) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            k,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Expanded(child: Text(v, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    ),
  );
}
