import 'package:flutter/material.dart';
import 'package:location_share/models/participant_location.dart';
import 'package:location_share/providers/sharing_controller.dart';
import 'package:location_share/utils/geo_utils.dart';
import 'package:location_share/utils/time_utils.dart';
import 'package:provider/provider.dart';

typedef PersonTapCallback = void Function(
  ParticipantLocation person,
  bool isSelf,
);

class PeopleSheet extends StatelessWidget {
  const PeopleSheet({
    super.key,
    required this.scrollController,
    required this.onPersonTap,
  });

  final ScrollController scrollController;
  final PersonTapCallback onPersonTap;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SharingController>();
    final people = c.peopleForList();
    final myPos = c.myLatLng;

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Text(
                  '人物',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                if (!c.hasSyncBackend)
                  Text(
                    '未配置 API',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
              ],
            ),
          ),
        ),
        if (people.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '开启共享并允许定位后，你的位置会显示在这里；'
                '同组其他成员也会出现在列表中。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final p = people[i];
                final self = p.participantId == c.participantId;
                final dist = myPos == null
                    ? null
                    : distanceMeters(myPos, p.latLng);
                return _PersonTile(
                  person: p,
                  isSelf: self,
                  distanceMeters: dist,
                  onTap: () => onPersonTap(p, self),
                );
              },
              childCount: people.length,
            ),
          ),
      ],
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.person,
    required this.isSelf,
    required this.distanceMeters,
    required this.onTap,
  });

  final ParticipantLocation person;
  final bool isSelf;
  final double? distanceMeters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = person.displayName.isNotEmpty
        ? String.fromCharCode(person.displayName.runes.first)
        : '?';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: isSelf
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.secondaryContainer,
        foregroundColor: isSelf
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSecondaryContainer,
        child: Text(initial.toUpperCase()),
      ),
      title: Text(
        isSelf ? '${person.displayName}（我）' : person.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          relativeTimeZh(person.updatedAt),
          if (distanceMeters != null && !isSelf)
            ' · ${distanceMeters!.toStringAsFixed(0)} 米',
        ].join(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).colorScheme.outline,
      ),
      onTap: onTap,
    );
  }
}
