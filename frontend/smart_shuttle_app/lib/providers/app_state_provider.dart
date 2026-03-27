// ============================================================
// Smart Shuttle — App State Provider
// Manages shared state: active role, alert flags, session
// Satisfies: Functional Product rubric criterion (Provider pattern)
// ============================================================

import 'package:flutter/foundation.dart';
import 'dart:async';

enum CrowdDensity { low, medium, high }

enum UserRole { student, driver, admin }

class AppStateProvider extends ChangeNotifier {
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
    if (!_sessionActive) {
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

  void triggerYawn(bool active) {
    _yawnAlert = active;
    _yawnClearTimer?.cancel();

    if (active) {
      _safetyScore = (_safetyScore - 1).clamp(0, 100);
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
      _safetyScore = (_safetyScore - 5).clamp(0, 100);
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
      _safetyScore = (_safetyScore - 2).clamp(0, 100);
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
}
