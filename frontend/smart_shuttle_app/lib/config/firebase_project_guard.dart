import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

class FirebaseProjectGuard {
  static const String _manifestAsset =
      'assets/config/firebase_project_manifest.json';

  static Future<Map<String, dynamic>> validate({
    required FirebaseOptions options,
    required String platformKey,
  }) async {
    final manifest = await _loadManifest();
    final platformConfigs =
        Map<String, dynamic>.from(manifest['platforms'] as Map? ?? const {});
    final platformConfig = Map<String, dynamic>.from(
      platformConfigs[platformKey] as Map? ?? const {},
    );

    final expected = <String, String>{
      'project_id': manifest['project_id']?.toString() ?? '',
      'api_key': platformConfig['api_key']?.toString() ?? '',
      'app_id': platformConfig['app_id']?.toString() ?? '',
      'messaging_sender_id':
          platformConfig['messaging_sender_id']?.toString() ?? '',
      'auth_domain': platformConfig['auth_domain']?.toString() ?? '',
      'storage_bucket': platformConfig['storage_bucket']?.toString() ?? '',
    };
    final actual = <String, String>{
      'project_id': options.projectId,
      'api_key': options.apiKey,
      'app_id': options.appId,
      'messaging_sender_id': options.messagingSenderId,
      'auth_domain': options.authDomain ?? '',
      'storage_bucket': options.storageBucket ?? '',
    };

    final mismatches = <String>[];
    expected.forEach((field, expectedValue) {
      if (expectedValue.isEmpty) {
        return;
      }
      final actualValue = actual[field] ?? '';
      if (actualValue != expectedValue) {
        mismatches.add(
          '${_fieldLabel(field)}: expected "$expectedValue" but found "$actualValue".',
        );
      }
    });

    if (mismatches.isNotEmpty) {
      throw StateError(
        'Firebase manifest mismatch for $platformKey.\n'
        'Manifest asset: $_manifestAsset\n'
        '${mismatches.join('\n')}',
      );
    }

    return manifest;
  }

  static Future<Map<String, dynamic>> _loadManifest() async {
    final raw = await rootBundle.loadString(_manifestAsset);
    return Map<String, dynamic>.from(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  static String _fieldLabel(String field) {
    switch (field) {
      case 'project_id':
        return 'Project ID';
      case 'api_key':
        return 'API Key';
      case 'app_id':
        return 'App ID';
      case 'messaging_sender_id':
        return 'Messaging Sender ID';
      case 'auth_domain':
        return 'Auth Domain';
      case 'storage_bucket':
        return 'Storage Bucket';
      default:
        return field;
    }
  }
}
