import 'package:flutter/material.dart';

import '../claims/first_run_save.dart';
import '../claims/household_builder.dart';
import '../data/database.dart';

/// The first screen: who you are, your father, his house and the brothers and
/// sisters in it.
///
/// Nothing is required. Every slot has an "I don't know" control that clears
/// and disables it, and a blank field counts as not known. There is no
/// validation, no counter and no progress: Save is always there. What is saved
/// is exactly what was said; a father who is not named becomes a fresh
/// placeholder with a house of his own, so nothing is invented as shared.
class FirstRunScreen extends StatefulWidget {
  const FirstRunScreen({
    super.key,
    required this.builder,
    this.remember,
    this.onSaved,
  });

  final HouseholdBuilder builder;

  /// Records who "me" is. It runs inside the same transaction as the writes,
  /// so the family and this record are saved together or not at all.
  final Future<void> Function(String selfPersonId)? remember;

  /// Called with the id of "me" after everything has been committed. It is a
  /// plain UI callback: it does no writing.
  final void Function(String selfPersonId)? onSaved;

  static const Key nameKey = ValueKey('first-run-name');
  static const Key nameUnknownKey = ValueKey('first-run-name-unknown');
  static const Key fatherKey = ValueKey('first-run-father');
  static const Key fatherUnknownKey = ValueKey('first-run-father-unknown');
  static const Key houseKey = ValueKey('first-run-house');
  static const Key houseUnknownKey = ValueKey('first-run-house-unknown');
  static const Key siblingsKey = ValueKey('first-run-siblings');
  static const Key siblingsUnknownKey = ValueKey('first-run-siblings-unknown');
  static const Key saveKey = ValueKey('first-run-save');

  @override
  State<FirstRunScreen> createState() => _FirstRunScreenState();
}

class _FirstRunScreenState extends State<FirstRunScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _father = TextEditingController();
  final TextEditingController _house = TextEditingController();
  final TextEditingController _siblings = TextEditingController();

  bool _nameUnknown = false;
  bool _fatherUnknown = false;
  bool _houseUnknown = false;
  bool _siblingsUnknown = false;

  /// Who "me" is. Null reads "I don't know".
  Sex? _sex;

  /// True from the first tap on Save. It is checked as well as shown, because
  /// a second tap can arrive before the button is redrawn.
  bool _saving = false;
  bool _failed = false;

  @override
  void dispose() {
    _name.dispose();
    _father.dispose();
    _house.dispose();
    _siblings.dispose();
    super.dispose();
  }

  /// A trimmed value, or null when blank.
  String? _text(TextEditingController c) {
    final String t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  /// What was said, with every "I don't know" and every blank as not known.
  FirstRunAnswers _answers() {
    final int? number = _houseUnknown ? null : int.tryParse(_house.text.trim());
    return FirstRunAnswers(
      name: _nameUnknown ? null : _text(_name),
      sex: _sex,
      fatherName: _fatherUnknown ? null : _text(_father),
      houseNumber: number,
      siblingNames: _siblingsUnknown
          ? const []
          : [
              for (final String line in _siblings.text.split('\n'))
                if (line.trim().isNotEmpty) line.trim(),
            ],
    );
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
      _failed = false;
    });
    final FirstRunAnswers answers = _answers();
    final HouseholdBuilder builder = widget.builder;
    final String me;
    try {
      // One transaction: the family and the record of who "me" is commit
      // together, so a failure leaves nothing to duplicate on a retry.
      me = await builder.atomically(() async {
        final String me = await saveFirstRun(builder, answers);
        await widget.remember?.call(me);
        return me;
      });
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'first run',
        ),
      );
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
      return;
    }
    // Save stays disabled: what was typed is now written.
    widget.onSaved?.call(me);
  }

  /// A question, its text field and the control that says it is not known.
  Widget _slot({
    required String question,
    required Key fieldKey,
    required Key unknownKey,
    required TextEditingController controller,
    required bool unknown,
    required ValueChanged<bool> onUnknown,
    TextInputType keyboardType = TextInputType.text,
    int? minLines,
    String? note,
  }) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The question is the field's label for assistive technology, so
          // its visible text is not announced a second time.
          ExcludeSemantics(
            child: Text(question, style: theme.textTheme.bodyLarge),
          ),
          if (note != null)
            ExcludeSemantics(
              child: Text(
                note,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Semantics(
            label: question,
            hint: note,
            child: TextField(
              key: fieldKey,
              controller: controller,
              enabled: !unknown,
              keyboardType: keyboardType,
              textCapitalization: keyboardType == TextInputType.number
                  ? TextCapitalization.none
                  : TextCapitalization.words,
              autocorrect: false,
              // Null lines: the field grows to show everything typed, so a
              // long name wraps instead of scrolling out of sight.
              maxLines: null,
              minLines: minLines,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
          CheckboxListTile(
            key: unknownKey,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            // Said with its question, so the four are told apart.
            title: Text(
              "I don't know",
              semanticsLabel: "$question: I don't know",
            ),
            value: unknown,
            onChanged: (bool? v) {
              onUnknown(v ?? false);
            },
          ),
        ],
      ),
    );
  }

  /// Ticking "I don't know" clears the field and turns it off.
  ValueChanged<bool> _toggle(
    TextEditingController c,
    void Function(bool) assign,
  ) {
    return (bool v) => setState(() {
      assign(v);
      if (v) {
        c.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            header: true,
            child: Text('Start with your own family', style: text.titleLarge),
          ),
          const SizedBox(height: 8),
          Text(
            'Say what you know. Nothing here is required.',
            style: text.bodyLarge,
          ),
          _slot(
            question: 'Your name',
            fieldKey: FirstRunScreen.nameKey,
            unknownKey: FirstRunScreen.nameUnknownKey,
            controller: _name,
            unknown: _nameUnknown,
            onUnknown: _toggle(_name, (v) => _nameUnknown = v),
          ),
          const SizedBox(height: 24),
          Text('I am a', style: text.bodyLarge),
          RadioGroup<Sex?>(
            groupValue: _sex,
            onChanged: (Sex? v) => setState(() => _sex = v),
            child: const Column(
              children: [
                RadioListTile<Sex?>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Son'),
                  value: Sex.male,
                ),
                RadioListTile<Sex?>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Daughter'),
                  value: Sex.female,
                ),
                RadioListTile<Sex?>(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    "I don't know",
                    semanticsLabel: "I am a: I don't know",
                  ),
                  value: null,
                ),
              ],
            ),
          ),
          _slot(
            question: "Your father's name",
            fieldKey: FirstRunScreen.fatherKey,
            unknownKey: FirstRunScreen.fatherUnknownKey,
            controller: _father,
            unknown: _fatherUnknown,
            onUnknown: _toggle(_father, (v) => _fatherUnknown = v),
          ),
          _slot(
            question: 'His house number',
            note: 'The number of the house you were born to.',
            fieldKey: FirstRunScreen.houseKey,
            unknownKey: FirstRunScreen.houseUnknownKey,
            controller: _house,
            unknown: _houseUnknown,
            onUnknown: _toggle(_house, (v) => _houseUnknown = v),
            keyboardType: TextInputType.number,
          ),
          _slot(
            question: 'Brothers and sisters in his house',
            note: 'One name on each line.',
            fieldKey: FirstRunScreen.siblingsKey,
            unknownKey: FirstRunScreen.siblingsUnknownKey,
            controller: _siblings,
            unknown: _siblingsUnknown,
            onUnknown: _toggle(_siblings, (v) => _siblingsUnknown = v),
            keyboardType: TextInputType.multiline,
            minLines: 3,
          ),
          const SizedBox(height: 32),
          if (_failed) ...[
            Text('Could not save. Please try again.', style: text.bodyLarge),
            const SizedBox(height: 8),
          ],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton(
              key: FirstRunScreen.saveKey,
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
