import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';    // For playing alert sounds

enum CrowdDensity { low, medium, high }

enum UserRole { student, driver, admin }

class AppStateProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ── Session & Auth ─────────────────────────────────────────
  String? _jwtToken;
  String? get jwtToken => _jwtToken;

  String? _userEmail;
  String? get userEmail => _userEmail;

  void setSession(String? token, String? email) {
    _jwtToken = token;
    _userEmail = email;
    notifyListeners();
  }

  // ── Role ───────────────────────────────────────────────────
  UserRole _currentRole = UserRole.student;
  UserRole get currentRole => _currentRole;

  void setRole(UserRole role) {
    _currentRole = role;
    notifyListeners();
  }

  // ── Driver Session ─────────────────────────────────────────
  bool _sessionActive = false;
  bool get sessionActive => _sessionActive;

  bool _isFirstSnapshot = true;
  int _prevYawnCount = 0;
  int _prevPhoneCount = 0;
  int _prevDrowsinessCount = 0;

  int _tripDurationSeconds = 0;
  int get tripDurationSeconds => _tripDurationSeconds;

  double _safetyScore = 100.0;
  double get safetyScore => _safetyScore;

  void setSafetyScore(double score) {
    _safetyScore = score.clamp(0, 100);
    notifyListeners();
  }

  void toggleSession() {
    _sessionActive = !_sessionActive;
    if (_sessionActive) {
      _isFirstSnapshot = true;
    } else {
      _tripDurationSeconds = 0;
      // Keep safety score in-sync with the database, do not reset to 100 here.
      _drowsinessAlert = false;
      _phoneUseAlert = false;
      _yawnAlert = false;
      // Cancel any pending timers
      _yawnClearTimer?.cancel();
      _phoneUseClearTimer?.cancel();
      _drowsinessClearTimer?.cancel();
    }
    notifyListeners();
  }

  // Trigger alarm if current count greater than previous count, then update previous counts
  void syncCounts(int curYawn, int curPhone, int curDrowsy) {
    if (_isFirstSnapshot) {
      _prevYawnCount = curYawn;
      _prevPhoneCount = curPhone;
      _prevDrowsinessCount = curDrowsy;
      _isFirstSnapshot = false;
    } else {
      if (curYawn > _prevYawnCount) triggerYawn(true);
      if (curPhone > _prevPhoneCount) triggerPhoneUse(true);
      if (curDrowsy > _prevDrowsinessCount) triggerDrowsiness(true);

      _prevYawnCount = curYawn;
      _prevPhoneCount = curPhone;
      _prevDrowsinessCount = curDrowsy;
    }
  }

  void tickSecond() {
    if (_sessionActive) {
      _tripDurationSeconds++;
      notifyListeners();
    }
  }

  // ── Driver Safety Alerts ───────────────────────────────────
  bool _yawnAlert = false;
  bool _drowsinessAlert = false;
  bool _phoneUseAlert = false;
  bool get yawnAlert => _yawnAlert;
  bool get drowsinessAlert => _drowsinessAlert;
  bool get phoneUseAlert => _phoneUseAlert;

  // ── Auto-clear timers ──────────────────────────────────────
  Timer? _yawnClearTimer;
  Timer? _phoneUseClearTimer;
  Timer? _drowsinessClearTimer;

  bool _isPlayingSound = false;

  Future<void> _playAlarm() async {
    if (_isPlayingSound) return;
    _isPlayingSound = true;
    try {
      await _audioPlayer.play(AssetSource('audio/Alarm.mp3'));
    } catch (e) {
      debugPrint("Error playing audio: $e");
    }
    _isPlayingSound = false;
  }

  void triggerYawn(bool active) {
    _yawnAlert = active;
    _yawnClearTimer?.cancel();

    if (active) {
      _playAlarm();
      _safetyScore = (_safetyScore - 0).clamp(0, 100);
      // Auto-clear after 3 seconds
      _yawnClearTimer = Timer(const Duration(seconds: 3), () {
        _yawnAlert = false;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void triggerDrowsiness(bool active) {
    _drowsinessAlert = active;
    _drowsinessClearTimer?.cancel();

    if (active) {
      _playAlarm();
      _safetyScore = (_safetyScore - 0).clamp(0, 100);
      // Auto-clear after 3 seconds
      _drowsinessClearTimer = Timer(const Duration(seconds: 3), () {
        _drowsinessAlert = false;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void triggerPhoneUse(bool active) {
    _phoneUseAlert = active;
    _phoneUseClearTimer?.cancel();

    if (active) {
      _playAlarm();
      _safetyScore = (_safetyScore - 0).clamp(0, 100);
      // Auto-clear after 3 seconds
      _phoneUseClearTimer = Timer(const Duration(seconds: 3), () {
        _phoneUseAlert = false;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  // ── Student — Crowd Density ────────────────────────────────
  CrowdDensity _crowdDensity = CrowdDensity.low;
  CrowdDensity get crowdDensity => _crowdDensity;

  void setCrowdDensity(CrowdDensity density) {
    _crowdDensity = density;
    notifyListeners();
  }

  // ── ETA ────────────────────────────────────────────────────
  int _etaMinutes = 7;
  int get etaMinutes => _etaMinutes;

  void setEta(int minutes) {
    _etaMinutes = minutes;
    notifyListeners();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _yawnClearTimer?.cancel();
    _phoneUseClearTimer?.cancel();
    _drowsinessClearTimer?.cancel();
    super.dispose();
  }
}
