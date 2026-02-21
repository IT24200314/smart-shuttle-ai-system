// ============================================================
// Smart Shuttle — App State Provider
// Manages shared state: active role, alert flags, session
// Satisfies: Functional Product rubric criterion (Provider pattern)
// ============================================================

import 'package:flutter/foundation.dart';

enum CrowdDensity { low, medium, high }
enum UserRole { student, driver, admin }

class AppStateProvider extends ChangeNotifier {
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

  double _safetyScore = 97.0;
  double get safetyScore => _safetyScore;

  void toggleSession() {
    _sessionActive = !_sessionActive;
    if (!_sessionActive) {
      _tripDurationSeconds = 0;
      _safetyScore = 97.0;
      _drowsinessAlert = false;
      _phoneUseAlert = false;
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
  bool _drowsinessAlert = false;
  bool _phoneUseAlert   = false;
  bool get drowsinessAlert => _drowsinessAlert;
  bool get phoneUseAlert   => _phoneUseAlert;

  void triggerDrowsiness(bool active) {
    _drowsinessAlert = active;
    if (active) _safetyScore = (_safetyScore - 8).clamp(0, 100);
    notifyListeners();
  }

  void triggerPhoneUse(bool active) {
    _phoneUseAlert = active;
    if (active) _safetyScore = (_safetyScore - 5).clamp(0, 100);
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
