import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'store_interface.dart';

class LocalDatabase extends GeneratedDatabase {
  LocalDatabase(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await customStatement(
        'CREATE TABLE records (namespace TEXT NOT NULL, record_key TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(namespace, record_key))',
      );
    },
  );
}

class NativeRecordStore implements RecordStore {
  final LocalDatabase database;
  NativeRecordStore(QueryExecutor executor)
    : database = LocalDatabase(executor);
  @override
  Future<String?> read(String namespace, String key) async {
    final row = await database
        .customSelect(
          'SELECT payload FROM records WHERE namespace=? AND record_key=?',
          variables: [Variable(namespace), Variable(key)],
        )
        .getSingleOrNull();
    return row?.read<String>('payload');
  }

  @override
  Future<Map<String, String>> list(String namespace) async {
    final rows = await database
        .customSelect(
          'SELECT record_key,payload FROM records WHERE namespace=?',
          variables: [Variable(namespace)],
        )
        .get();
    return {
      for (final row in rows)
        row.read<String>('record_key'): row.read<String>('payload'),
    };
  }

  @override
  Future<void> write(String namespace, String key, String value) =>
      database.customStatement(
        'INSERT INTO records(namespace,record_key,payload) VALUES(?,?,?) ON CONFLICT(namespace,record_key) DO UPDATE SET payload=excluded.payload',
        [namespace, key, value],
      );
  @override
  Future<void> remove(String namespace, String key) => database.customStatement(
    'DELETE FROM records WHERE namespace=? AND record_key=?',
    [namespace, key],
  );
  @override
  Future<void> close() => database.close();
}

Future<RecordStore> openStore() async {
  final directory = await getApplicationSupportDirectory();
  return NativeRecordStore(
    NativeDatabase.createInBackground(
      File(path.join(directory.path, 'pikolumi.sqlite')),
    ),
  );
}
