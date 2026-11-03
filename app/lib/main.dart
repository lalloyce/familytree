import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'data/database.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The database is not encrypted yet. Encryption at rest is a later
  // milestone (spike 5 in docs/spike-results.md).
  final AppDatabase db = AppDatabase(driftDatabase(name: 'related'));
  runApp(RelatedApp(db: db));
}
