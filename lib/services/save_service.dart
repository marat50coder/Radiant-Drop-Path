import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/component_type.dart';

/// Persistent progression, resources, cosmetics and settings storage.
/// Backed by SharedPreferences. Call [SaveService.instance.init] once at
/// app start (done on the loading screen).
class SaveService {
  SaveService._();
  static final SaveService instance = SaveService._();

  late SharedPreferences _prefs;
  bool _ready = false;

  int crystals = 0;
  int microParts = 0;
  int processors = 0;
  int xp = 0;

  int bestEndlessScore = 0;
  int highestUnlockedLevel = 1;
  final Map<int, int> levelStars = {}; // levelId -> 0..3
  final Map<ComponentType, int> selectedSkin = {};
  final Map<ComponentType, Set<int>> unlockedSkins = {};

  bool musicEnabled = true;
  bool sfxEnabled = true;
  double musicVolume = 0.55;
  double sfxVolume = 0.9;
  double defaultSimSpeed = 1.0;

  // Daily tasks progress: key -> value, resets when [dailyResetKey] changes.
  String dailyResetKey = '';
  final Map<String, int> dailyProgress = {};
  final Set<String> dailyClaimed = {};

  Future<void> init() async {
    if (_ready) return;
    _prefs = await SharedPreferences.getInstance();
    crystals = _prefs.getInt('crystals') ?? 120;
    microParts = _prefs.getInt('microParts') ?? 40;
    processors = _prefs.getInt('processors') ?? 10;
    xp = _prefs.getInt('xp') ?? 0;
    bestEndlessScore = _prefs.getInt('bestEndlessScore') ?? 0;
    highestUnlockedLevel = _prefs.getInt('highestUnlockedLevel') ?? 1;
    musicEnabled = _prefs.getBool('musicEnabled') ?? true;
    sfxEnabled = _prefs.getBool('sfxEnabled') ?? true;
    musicVolume = _prefs.getDouble('musicVolume') ?? 0.55;
    sfxVolume = _prefs.getDouble('sfxVolume') ?? 0.9;
    defaultSimSpeed = _prefs.getDouble('defaultSimSpeed') ?? 1.0;
    dailyResetKey = _prefs.getString('dailyResetKey') ?? '';

    final starsRaw = _prefs.getString('levelStars');
    if (starsRaw != null) {
      final map = jsonDecode(starsRaw) as Map<String, dynamic>;
      map.forEach((k, v) => levelStars[int.parse(k)] = v as int);
    }

    final skinRaw = _prefs.getString('selectedSkin');
    if (skinRaw != null) {
      final map = jsonDecode(skinRaw) as Map<String, dynamic>;
      map.forEach((k, v) {
        final type = ComponentType.values.firstWhere((t) => t.name == k, orElse: () => ComponentType.amplifier);
        selectedSkin[type] = v as int;
      });
    }

    final unlockedRaw = _prefs.getString('unlockedSkins');
    for (final type in ComponentType.values) {
      unlockedSkins[type] = {0};
    }
    if (unlockedRaw != null) {
      final map = jsonDecode(unlockedRaw) as Map<String, dynamic>;
      map.forEach((k, v) {
        final type = ComponentType.values.firstWhere((t) => t.name == k, orElse: () => ComponentType.amplifier);
        unlockedSkins[type] = (v as List).map((e) => e as int).toSet()..add(0);
      });
    }

    final dailyProgressRaw = _prefs.getString('dailyProgress');
    if (dailyProgressRaw != null) {
      final map = jsonDecode(dailyProgressRaw) as Map<String, dynamic>;
      map.forEach((k, v) => dailyProgress[k] = v as int);
    }
    final dailyClaimedRaw = _prefs.getStringList('dailyClaimed');
    if (dailyClaimedRaw != null) dailyClaimed.addAll(dailyClaimedRaw);

    _ready = true;
  }

  Future<void> _saveResources() async {
    await _prefs.setInt('crystals', crystals);
    await _prefs.setInt('microParts', microParts);
    await _prefs.setInt('processors', processors);
    await _prefs.setInt('xp', xp);
  }

  Future<void> addResources({int crystals = 0, int microParts = 0, int processors = 0, int xp = 0}) async {
    this.crystals += crystals;
    this.microParts += microParts;
    this.processors += processors;
    this.xp += xp;
    await _saveResources();
  }

  Future<bool> spendCrystals(int amount) async {
    if (crystals < amount) return false;
    crystals -= amount;
    await _saveResources();
    return true;
  }

  Future<void> recordLevelResult({required int levelId, required int stars, required int nextLevelId}) async {
    final prior = levelStars[levelId] ?? 0;
    if (stars > prior) levelStars[levelId] = stars;
    if (nextLevelId > highestUnlockedLevel) highestUnlockedLevel = nextLevelId;
    await _prefs.setString('levelStars', jsonEncode(levelStars.map((k, v) => MapEntry(k.toString(), v))));
    await _prefs.setInt('highestUnlockedLevel', highestUnlockedLevel);
  }

  Future<void> setBestEndlessScore(int score) async {
    if (score > bestEndlessScore) {
      bestEndlessScore = score;
      await _prefs.setInt('bestEndlessScore', score);
    }
  }

  int get totalStars => levelStars.values.fold(0, (a, b) => a + b);

  Future<void> setMusicEnabled(bool v) async {
    musicEnabled = v;
    await _prefs.setBool('musicEnabled', v);
  }

  Future<void> setSfxEnabled(bool v) async {
    sfxEnabled = v;
    await _prefs.setBool('sfxEnabled', v);
  }

  Future<void> setMusicVolume(double v) async {
    musicVolume = v.clamp(0.0, 1.0);
    await _prefs.setDouble('musicVolume', musicVolume);
  }

  Future<void> setSfxVolume(double v) async {
    sfxVolume = v.clamp(0.0, 1.0);
    await _prefs.setDouble('sfxVolume', sfxVolume);
  }

  Future<void> setDefaultSimSpeed(double v) async {
    defaultSimSpeed = v;
    await _prefs.setDouble('defaultSimSpeed', v);
  }

  bool isSkinUnlocked(ComponentType type, int skin) => (unlockedSkins[type] ?? {0}).contains(skin);

  Future<bool> unlockSkin(ComponentType type, int skin, int cost) async {
    if (isSkinUnlocked(type, skin)) return true;
    if (!await spendCrystals(cost)) return false;
    unlockedSkins.putIfAbsent(type, () => {0}).add(skin);
    await _prefs.setString(
      'unlockedSkins',
      jsonEncode(unlockedSkins.map((k, v) => MapEntry(k.name, v.toList()))),
    );
    return true;
  }

  Future<void> selectSkin(ComponentType type, int skin) async {
    selectedSkin[type] = skin;
    await _prefs.setString(
      'selectedSkin',
      jsonEncode(selectedSkin.map((k, v) => MapEntry(k.name, v))),
    );
  }

  int skinFor(ComponentType type) => selectedSkin[type] ?? 0;

  /// Ensures daily task counters are for "today" (YYYY-MM-DD), otherwise
  /// resets progress & claim state for a fresh day.
  Future<void> ensureDailyFresh(String todayKey) async {
    if (dailyResetKey != todayKey) {
      dailyResetKey = todayKey;
      dailyProgress.clear();
      dailyClaimed.clear();
      await _prefs.setString('dailyResetKey', todayKey);
      await _prefs.setString('dailyProgress', jsonEncode(dailyProgress));
      await _prefs.setStringList('dailyClaimed', []);
    }
  }

  Future<void> addDailyProgress(String taskKey, int amount) async {
    dailyProgress[taskKey] = (dailyProgress[taskKey] ?? 0) + amount;
    await _prefs.setString('dailyProgress', jsonEncode(dailyProgress));
  }

  Future<void> claimDaily(String taskKey) async {
    dailyClaimed.add(taskKey);
    await _prefs.setStringList('dailyClaimed', dailyClaimed.toList());
  }
}
