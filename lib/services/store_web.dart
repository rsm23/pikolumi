import 'package:web/web.dart' as web;

import 'store_interface.dart';

class BrowserRecordStore implements RecordStore {
  String key(String namespace, String id) => 'pikolumi.v1.$namespace.$id';
  @override
  Future<String?> read(String namespace, String id) async =>
      web.window.localStorage.getItem(key(namespace, id));
  @override
  Future<Map<String, String>> list(String namespace) async {
    final store = web.window.localStorage;
    final prefix = key(namespace, '');
    final values = <String, String>{};
    for (var i = 0; i < store.length; i++) {
      final k = store.key(i);
      if (k != null && k.startsWith(prefix)) {
        values[k.substring(prefix.length)] = store.getItem(k)!;
      }
    }
    return values;
  }

  @override
  Future<void> write(String namespace, String id, String value) async =>
      web.window.localStorage.setItem(key(namespace, id), value);
  @override
  Future<void> remove(String namespace, String id) async =>
      web.window.localStorage.removeItem(key(namespace, id));
  @override
  Future<void> close() async {}
}

Future<RecordStore> openStore() async => BrowserRecordStore();
