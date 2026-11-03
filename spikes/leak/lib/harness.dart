// Spike 1 harness: a fresh server schema per world, viewer sessions under row
// security, a byte recorder for the viewer's wire traffic, and the viewer's
// device as a Drift database.
//
// Throwaway. Not app code.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:postgres/postgres.dart';
import 'package:sqlite3/sqlite3.dart' as s3;

const pgHost = '127.0.0.1';
const pgPort = 55432;
const pgDatabase = 'leak';
const pgUser = 'spike';

/// Directory holding the .sql files. Tests run from spikes/leak.
final sqlDir = Directory.current.path;

/// Same rule as schema.sql derive_id(): first 16 bytes of
/// sha256("<account>:<nonce>"), formatted as a lowercase UUID.
String deriveId(String account, String nonce) {
  final d = sha256.convert(utf8.encode('$account:$nonce')).bytes.sublist(0, 16);
  final h = d.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

Future<Connection> _open({int port = pgPort}) => Connection.open(
  Endpoint(host: pgHost, port: port, database: pgDatabase, username: pgUser),
  settings: const ConnectionSettings(sslMode: SslMode.disable),
);

/// One world: a freshly created "spike" schema with the real server, or the
/// real server with one or more canary files applied on top.
class Server {
  Server._(this.admin);
  final Connection admin;
  final _viewers = <Viewer>[];

  static Future<Server> build({Set<String> canaries = const {}}) async {
    final admin = await _open();
    await admin.execute('drop schema if exists spike cascade');
    await admin.execute('create schema spike');
    await admin.execute(r'''
      do $$ begin
        if not exists (select from pg_roles where rolname = 'app_viewer') then
          create role app_viewer nologin;
        end if;
      end $$''');
    for (final f in ['schema.sql', 'pull_view.sql', for (final c in canaries) '$c.sql']) {
      await admin.execute(
        File('$sqlDir/$f').readAsStringSync(),
        queryMode: QueryMode.simple,
      );
    }
    await admin.execute('set search_path = spike, pg_temp');
    return Server._(admin);
  }

  /// Accounts and their own person rows are seeded by the operator, as sign-up
  /// would do. Everything else is written through submit().
  Future<void> seedAccount(String account, String person, String name) async {
    await admin.execute(
      r'insert into person (id, name_key, created_by) values ($1::uuid, $2, $3::uuid)',
      parameters: [person, name, account],
    );
    await admin.execute(
      r'insert into account (id, person_id) values ($1::uuid, $2::uuid)',
      parameters: [account, person],
    );
    await admin.execute('select refresh_claim_access()');
  }

  Future<Viewer> viewer(String account, {bool recordWire = false}) async {
    WireRecorder? wire;
    if (recordWire) wire = await WireRecorder.start();
    final conn = await _open(port: wire?.port ?? pgPort);
    await conn.execute('set role app_viewer');
    await conn.execute(r"select set_config('app.viewer', $1, false)", parameters: [account]);
    await conn.execute('set search_path = spike, pg_temp');
    final v = Viewer._(account, conn, wire);
    _viewers.add(v);
    return v;
  }

  Future<void> close() async {
    for (final v in _viewers) {
      await v.close();
    }
    await admin.close();
  }
}

/// A viewer's session. Only what an app user could do: call pull_view, call
/// submit, and read tables under row security.
class Viewer {
  Viewer._(this.account, this.conn, this.wire);
  final String account;
  final Connection conn;
  final WireRecorder? wire;
  bool _closed = false;

  /// The payload exactly as the server produced it (jsonb rendered as text).
  Future<String> pull(String since) async {
    final r = await conn.execute(
      r'select pull_view($1::uuid, $2)::text',
      parameters: [account, since],
    );
    return r.first.first as String;
  }

  /// The full response of the write entry point, or every field of the
  /// server error if one escaped. Rendered as one string for comparison.
  Future<String> submit(Map<String, Object?> op) async {
    try {
      final r = await conn.execute(
        r'select submit($1::text::jsonb)::text',
        parameters: [jsonEncode(op)],
      );
      return 'RESULT ${r.first.first}';
    } on ServerException catch (e) {
      return 'ERROR ${renderServerException(e)}';
    }
  }

  static const tables = [
    'account', 'claim', 'claim_access', 'claim_audience', 'person', 'privacy_setting',
  ];

  /// Row counts from every table endpoint, as this viewer.
  Future<Map<String, int>> tableCounts() async {
    final out = <String, int>{};
    for (final t in tables) {
      final r = await conn.execute('select count(*) from spike.$t');
      out[t] = r.first.first as int;
    }
    return out;
  }

  /// Rows visible from every table endpoint, as this viewer, as text.
  /// Sorted by the row text when [natural] is false. When [natural] is true
  /// there is no ORDER BY, so the server's physical scan order is kept: an
  /// endpoint that returns rows unordered exposes that order too.
  Future<Map<String, List<String>>> tableRows({bool natural = false}) async {
    final out = <String, List<String>>{};
    for (final t in tables) {
      final r = await conn.execute(
        natural
            ? 'select row_to_json(x)::text from spike.$t x'
            : 'select row_to_json(x)::text from spike.$t x order by row_to_json(x)::text',
      );
      out[t] = [for (final row in r) row.first as String];
    }
    return out;
  }

  Future<Result> raw(String sql) => conn.execute(sql);

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await conn.close();
    await wire?.close();
  }
}

String renderServerException(ServerException e) => [
  'severity=${e.severity}',
  'code=${e.code}',
  'message=${e.message}',
  'detail=${e.detail}',
  'hint=${e.hint}',
  'position=${e.position}',
  'internalPosition=${e.internalPosition}',
  'internalQuery=${e.internalQuery}',
  'trace=${e.trace}',
  'schema=${e.schemaName}',
  'table=${e.tableName}',
  'column=${e.columnName}',
  'dataType=${e.dataTypeName}',
  'constraint=${e.constraintName}',
  'file=${e.fileName}',
  'line=${e.lineNumber}',
  'routine=${e.routineName}',
].join('|');

/// A TCP relay between one viewer connection and Postgres. Records every byte
/// the server sends to the viewer.
class WireRecorder {
  WireRecorder._(this._listener);
  final ServerSocket _listener;
  final _fromServer = BytesBuilder(copy: true);
  final _sockets = <Socket>[];

  static Future<WireRecorder> start() async {
    final l = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final w = WireRecorder._(l);
    l.listen((client) async {
      final upstream = await Socket.connect(pgHost, pgPort);
      w._sockets..add(client)..add(upstream);
      client.listen(
        upstream.add,
        onDone: upstream.destroy,
        onError: (_) => upstream.destroy(),
      );
      upstream.listen(
        (data) {
          w._fromServer.add(data);
          client.add(data);
        },
        onDone: client.destroy,
        onError: (_) => client.destroy(),
      );
    });
    return w;
  }

  int get port => _listener.port;

  /// Server-to-viewer bytes after the connection handshake, that is after the
  /// first ReadyForQuery ('Z') message. The handshake is excluded because it
  /// carries BackendKeyData: a process id and a random cancel key that differ
  /// on every connection and have nothing to do with the data.
  Uint8List bytesAfterHandshake() {
    final b = _fromServer.toBytes();
    var i = 0;
    while (i + 5 <= b.length) {
      final type = b[i];
      final len = ByteData.sublistView(b, i + 1, i + 5).getInt32(0);
      i += 1 + len;
      if (type == 0x5A) return Uint8List.sublistView(b, i);
    }
    throw StateError('no ReadyForQuery seen');
  }

  Future<void> close() async {
    for (final s in _sockets) {
      s.destroy();
    }
    await _listener.close();
  }
}

/// The viewer's device: a Drift database with no generated code. Holds only
/// what the server sent. No visibility logic.
class DeviceDb extends GeneratedDatabase {
  DeviceDb(super.executor);

  factory DeviceDb.memory() => DeviceDb(NativeDatabase.memory());

  /// A file-backed device, for checking what remains in the file's bytes.
  factory DeviceDb.file(File f, {required bool secureDelete}) => DeviceDb(
    NativeDatabase(
      f,
      setup: (s3.Database db) {
        db.execute('PRAGMA secure_delete = ${secureDelete ? 'ON' : 'OFF'}');
      },
    ),
  );

  static const ddl = [
    '''create table claim (
         id text primary key, kind text not null, subject_id text not null,
         object_id text, body text, asserted_by text not null, basis text,
         base_claim_id text, status text not null, scope text not null,
         created_at text not null)''',
    '''create table person (
         id text primary key, is_placeholder integer not null,
         name_key text not null, created_by text not null, deleted_at text)''',
    'create table sync_state (key text primary key, value text not null)',
  ];

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      for (final s in ddl) {
        await customStatement(s);
      }
    },
  );

  /// Apply one pull payload, as the sync client would.
  Future<void> apply(String payloadJson) async {
    final p = jsonDecode(payloadJson) as Map<String, dynamic>;
    await transaction(() async {
      for (final c in (p['claims'] as List).cast<Map<String, dynamic>>()) {
        await customStatement(
          '''insert into claim (id, kind, subject_id, object_id, body, asserted_by,
               basis, base_claim_id, status, scope, created_at)
             values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
             on conflict (id) do update set
               kind = excluded.kind, subject_id = excluded.subject_id,
               object_id = excluded.object_id, body = excluded.body,
               asserted_by = excluded.asserted_by, basis = excluded.basis,
               base_claim_id = excluded.base_claim_id, status = excluded.status,
               scope = excluded.scope, created_at = excluded.created_at''',
          [
            c['id'], c['kind'], c['subject_id'], c['object_id'], c['body'],
            c['asserted_by'], c['basis'], c['base_claim_id'], c['status'],
            c['scope'], c['created_at'],
          ],
        );
      }
      for (final id in (p['removed_claims'] as List).cast<String>()) {
        await customStatement('delete from claim where id = ?', [id]);
      }
      final persons = (p['persons'] as List).cast<Map<String, dynamic>>();
      final keep = {for (final x in persons) x['id'] as String};
      final held = await customSelect('select id from person').get();
      for (final row in held) {
        final id = row.read<String>('id');
        if (!keep.contains(id)) {
          await customStatement('delete from person where id = ?', [id]);
        }
      }
      for (final x in persons) {
        await customStatement(
          '''insert into person (id, is_placeholder, name_key, created_by, deleted_at)
             values (?, ?, ?, ?, ?)
             on conflict (id) do update set
               is_placeholder = excluded.is_placeholder, name_key = excluded.name_key,
               created_by = excluded.created_by, deleted_at = excluded.deleted_at''',
          [
            x['id'], (x['is_placeholder'] as bool) ? 1 : 0, x['name_key'],
            x['created_by'], x['deleted_at'],
          ],
        );
      }
      await customStatement(
        "insert into sync_state (key, value) values ('cursor', ?) "
        'on conflict (key) do update set value = excluded.value',
        [p['cursor']],
      );
      await customStatement(
        "insert into sync_state (key, value) values ('hide_quiet_details', ?) "
        'on conflict (key) do update set value = excluded.value',
        [(p['me'] as Map)['hide_quiet_details'].toString()],
      );
    });
  }

  /// Every table's full contents in rowid order, plus the schema, as text.
  Future<Map<String, List<String>>> dump() async {
    final out = <String, List<String>>{};
    final master = await customSelect(
      'select type, name, tbl_name, sql from sqlite_master order by name',
    ).get();
    out['sqlite_master'] = [for (final r in master) jsonEncode(r.data)];
    for (final r in master) {
      if (r.read<String>('type') != 'table') continue;
      final name = r.read<String>('name');
      final rows = await customSelect('select rowid as _rowid_, * from "$name" order by rowid').get();
      out[name] = [for (final row in rows) jsonEncode(row.data)];
    }
    return out;
  }

  /// The database as a file image, via VACUUM INTO.
  Future<Uint8List> fileImage() async {
    final dir = await Directory.systemTemp.createTemp('leak_spike_');
    try {
      final path = '${dir.path}/image.db';
      await customStatement('VACUUM INTO ?', [path]);
      return File(path).readAsBytesSync();
    } finally {
      dir.deleteSync(recursive: true);
    }
  }
}

/// True if [needle] occurs anywhere in [hay].
bool containsBytes(List<int> hay, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= hay.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}
