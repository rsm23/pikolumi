abstract class RecordStore {
  Future<String?> read(String namespace, String key);
  Future<Map<String, String>> list(String namespace);
  Future<void> write(String namespace, String key, String value);
  Future<void> remove(String namespace, String key);
  Future<void> close();
}
