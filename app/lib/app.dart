import 'package:flutter/material.dart';

import 'claims/claim_service.dart';
import 'claims/household_builder.dart';
import 'data/app_settings.dart';
import 'data/database.dart';
import 'ui/family_tab.dart';
import 'ui/first_run.dart';
import 'ui/theme.dart';

/// The account that writes claims on this device until sign-in arrives in M2.
const String localAccountId = 'local';

/// The app: the first-run screen until the person who is "me" is known, then
/// the family tab for that person.
///
/// "Known" means the local `selfPersonId` setting is set, not that the
/// database has people in it. A database that was never written to is the
/// normal case on first launch.
class RelatedApp extends StatefulWidget {
  const RelatedApp({super.key, required this.db});

  final AppDatabase db;

  @override
  State<RelatedApp> createState() => _RelatedAppState();
}

class _RelatedAppState extends State<RelatedApp> {
  late final Future<String?> _self = widget.db.selfPersonId();

  /// Set once first run has saved, so the family tab shows without a re-read.
  String? _savedSelf;

  late final HouseholdBuilder _builder = HouseholdBuilder(
    widget.db,
    ClaimService(widget.db, accountId: localAccountId),
    accountId: localAccountId,
  );

  /// Called after first run has committed, which includes the self setting.
  void _onSaved(String me) {
    if (mounted) {
      setState(() => _savedSelf = me);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Related',
      theme: buildAppTheme(),
      home: Scaffold(
        body: SafeArea(
          child: FutureBuilder<String?>(
            future: _self,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                // Not first run: the family may be there and unread.
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Could not open your family.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                );
              }
              final String? self = _savedSelf ?? snapshot.data;
              if (self != null) {
                return FamilyTab(db: widget.db, selfPersonId: self);
              }
              if (snapshot.connectionState != ConnectionState.done) {
                // Nothing while the setting is read.
                return const SizedBox.shrink();
              }
              return FirstRunScreen(
                builder: _builder,
                remember: widget.db.setSelfPersonId,
                onSaved: _onSaved,
              );
            },
          ),
        ),
      ),
    );
  }
}
