import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class PlayerProvider with ChangeNotifier {
  String? _username;
  int _coins = 0;
  int _rps = 0;
  String? _publicKeyHash;
  List<String> _equippedTools = [];
  bool _isLoading = false;

  String? get username => _username;
  int get coins => _coins;
  int get rps => _rps;
  String? get publicKeyHash => _publicKeyHash;
  List<String> get equippedTools => List.unmodifiable(_equippedTools);
  bool get isLoading => _isLoading;

  Future<void> loadPlayer() async {
    _isLoading = true;
    notifyListeners();

    try {
      final profile = await ApiService.getProfile();
      _username = profile['username'];
      _coins = profile['coins'] ?? 0;
      _rps = profile['experience'] ?? 0;
      _publicKeyHash = profile['publicKeyHash'];
      _equippedTools = List<String>.from(profile['equippedTools'] ?? []);
      notifyListeners();
    } catch (e) {
      print('Error loading player: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePlayer({
    String? username,
    int? coins,
    int? rps,
    String? publicKeyHash,
    List<String>? equippedTools,
  }) async {
    if (username != null) _username = username;
    if (coins != null) _coins = coins;
    if (rps != null) _rps = rps;
    if (publicKeyHash != null) _publicKeyHash = publicKeyHash;
    if (equippedTools != null) _equippedTools = List<String>.from(equippedTools);
    notifyListeners();
  }

  void clear() {
    _username = null;
    _coins = 0;
    _rps = 0;
    _publicKeyHash = null;
    _equippedTools.clear();
    notifyListeners();
  }
}
