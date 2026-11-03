import 'package:flutter/material.dart';

import '../data/database.dart';
import '../tree/ancestors.dart';
import '../tree/house_model.dart';
import '../tree/spoken_chain.dart';
import 'chain_view.dart';
import 'house_view.dart';

/// The family tab, read-only: the spoken chain of one person, or the houses
/// of that person's father, chosen with a plain two-option toggle.
///
/// Both views load once, together, when the tab is built for a person, so
/// switching between them is instant and nothing is fetched on a rebuild.
class FamilyTab extends StatefulWidget {
  const FamilyTab({super.key, required this.db, required this.selfPersonId});

  final AppDatabase db;

  /// The person whose chain is shown.
  final String selfPersonId;

  @override
  State<FamilyTab> createState() => _FamilyTabState();
}

class _FamilyData {
  const _FamilyData({required this.lines, required this.fathersHouses});

  final List<ChainLine> lines;

  /// The houses of the father, or null when there is no father to follow.
  final HouseViewModel? fathersHouses;
}

class _FamilyTabState extends State<FamilyTab> {
  late Future<_FamilyData> _data = _load();
  bool _showHouses = false;

  @override
  void didUpdateWidget(FamilyTab old) {
    super.didUpdateWidget(old);
    if (old.db != widget.db || old.selfPersonId != widget.selfPersonId) {
      _data = _load();
    }
  }

  Future<_FamilyData> _load() async {
    final AppDatabase db = widget.db;
    final String me = widget.selfPersonId;
    final List<ChainLine> lines = await spokenChain(db, me);
    // The first step is the father. A depth 0 step stands for a starting
    // person whose own parentage is disputed: there is no father to follow.
    final List<AncestorStep> steps = await ancestorsOf(db, me);
    final String? father = steps.isNotEmpty && steps.first.depth > 0
        ? steps.first.personId
        : null;
    return _FamilyData(
      lines: lines,
      fathersHouses: father == null
          ? null
          : await buildHouseViewModel(db, father),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FamilyData>(
      key: ValueKey(widget.selfPersonId),
      future: _data,
      builder: (context, snapshot) {
        final TextStyle? body = Theme.of(context).textTheme.bodyLarge;
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Could not read the family.', style: body),
          );
        }
        final _FamilyData? data = snapshot.data;
        if (data == null) {
          // Nothing while the first read finishes.
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ToggleButton(
                    label: 'Chain',
                    selected: !_showHouses,
                    onPressed: () => setState(() => _showHouses = false),
                  ),
                  _ToggleButton(
                    label: 'Houses',
                    selected: _showHouses,
                    onPressed: () => setState(() => _showHouses = true),
                  ),
                ],
              ),
            ),
            Expanded(child: _view(context, data)),
          ],
        );
      },
    );
  }

  Widget _view(BuildContext context, _FamilyData data) {
    if (!_showHouses) {
      return ChainView(lines: data.lines, onShowDiagram: null);
    }
    final HouseViewModel? houses = data.fathersHouses;
    if (houses != null) {
      return HouseView(house: houses);
    }
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'not known yet',
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// One option of the toggle. The chosen one is bold and underlined and is
/// announced as selected, so it does not depend on colour.
class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // One semantic node that is the button and says whether it is selected.
    return Semantics(
      container: true,
      button: true,
      enabled: true,
      selected: selected,
      label: label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: OutlinedButton(
          onPressed: onPressed,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              decoration: selected
                  ? TextDecoration.underline
                  : TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
