import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/public_key_entry.dart';

class KeyStorageService {
  static const String _keysKey = 'public_keys';
  SharedPreferences? _prefs;
  final _uuid = const Uuid();

  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<PublicKeyEntry>> getAllKeys() async {
    await _ensureInitialized();
    final String? keysJson = _prefs?.getString(_keysKey);
    if (keysJson == null) return [];

    final List<dynamic> keysList = jsonDecode(keysJson);
    return keysList.map((json) => PublicKeyEntry.fromJson(json)).toList();
  }

  Future<void> addKey(String publicKey, String label) async {
    final keys = await getAllKeys();
    final newKey = PublicKeyEntry(
      id: _uuid.v4(),
      publicKey: publicKey,
      label: label,
    );
    
    keys.add(newKey);
    await _saveKeys(keys);
  }

  Future<void> updateKeyLabel(String id, String newLabel) async {
    final keys = await getAllKeys();
    final index = keys.indexWhere((k) => k.id == id);
    if (index != -1) {
      keys[index] = PublicKeyEntry(
        id: keys[index].id,
        publicKey: keys[index].publicKey,
        label: newLabel,
      );
      await _saveKeys(keys);
    }
  }

  Future<void> deleteKey(String id) async {
    final keys = await getAllKeys();
    keys.removeWhere((k) => k.id == id);
    await _saveKeys(keys);
  }

  Future<List<PublicKeyEntry>> searchKeys(String query) async {
    final keys = await getAllKeys();
    if (query.isEmpty) return keys;

    query = query.toLowerCase();
    return keys.where((key) =>
      key.label.toLowerCase().contains(query) ||
      key.publicKey.toLowerCase().contains(query)
    ).toList();
  }

  Future<void> _saveKeys(List<PublicKeyEntry> keys) async {
    await _ensureInitialized();
    final String keysJson = jsonEncode(keys.map((k) => k.toJson()).toList());
    await _prefs?.setString(_keysKey, keysJson);
  }
}
