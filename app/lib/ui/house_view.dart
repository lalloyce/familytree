import 'package:flutter/material.dart';

import '../tree/house_model.dart';

/// A husband and his houses, read-only: his name, then for each house its
/// number, wife and children.
///
/// An empty house reads "not known yet" in plain grey and has nothing to
/// press. Names wrap and are never cut short.
class HouseView extends StatelessWidget {
  const HouseView({super.key, required this.house});

  final HouseViewModel house;

  /// The key of the row for the house at [index].
  static Key rowKey(int index) => ValueKey('house-row-$index');

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Semantics(
          container: true,
          header: true,
          child: Text(house.husbandName, style: text.titleLarge),
        ),
        for (int i = 0; i < house.houses.length; i++)
          _HouseRow(key: rowKey(i), row: house.houses[i]),
      ],
    );
  }
}

class _HouseRow extends StatelessWidget {
  const _HouseRow({super.key, required this.row});

  final HouseRowModel row;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? body = theme.textTheme.bodyLarge;
    final TextStyle? grey = body?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final bool empty =
        row.wifeName == null &&
        !row.wifeAccountsDiffer &&
        row.childLines.isEmpty;
    final String? ordinal = row.ordinal == null ? null : ' ${row.ordinal}';

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            header: true,
            child: Text(
              'House${ordinal ?? ''}',
              style: body?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 4),
          if (empty)
            Text('not known yet', style: grey)
          else if (row.wifeAccountsDiffer)
            Text('accounts differ', style: body)
          else if (row.wifeName == null)
            Text('wife not known yet', style: grey)
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${row.wifeName}, married', style: body),
                if (row.wifeSameAsElsewhere) const _SamePersonTag(),
              ],
            ),
          for (final String line in row.childLines)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 16),
              child: Text(line, style: body),
            ),
        ],
      ),
    );
  }
}

/// The text tag "same person", outlined so that it reads as a label.
class _SamePersonTag extends StatelessWidget {
  const _SamePersonTag();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text('same person', style: theme.textTheme.bodyMedium),
      ),
    );
  }
}
