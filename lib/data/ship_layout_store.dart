import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'ship_part_layout.dart';

const shipLayoutsAssetPath = 'assets/data/ship_layouts.json';
const shipLayoutsStorageKey = 'shootingstar.shipLayouts.v1';

/// Same-origin route of tools/play_web.py that reads and writes the project
/// file assets/data/ship_layouts.json. Only the loopback preview has it.
const shipLayoutsProjectRoute = 'editor/ship-layouts';

/// Where a loaded or saved layout book lives.
enum ShipLayoutSource { bundled, project, browser }

class ShipLayoutLoad {
  const ShipLayoutLoad(this.book, this.source);
  final ShipLayoutBook book;
  final ShipLayoutSource source;
}

class ShipLayoutSaveResult {
  const ShipLayoutSaveResult({required this.book, required this.project});
  final ShipLayoutBook book;

  /// True when the project file was written (local preview only).
  final bool project;
}

/// Loads the newest layout book and saves editor changes.
///
/// The bundled asset is the game's default. On the loopback preview the
/// editor also writes the project file, so an edit lands in the repository
/// and is picked up by the next build. Everywhere else the save stays in
/// this browser until its JSON is copied into the project.
class ShipLayoutStore {
  const ShipLayoutStore({this.preferences, this.bundle, this.client});

  final Future<SharedPreferences> Function()? preferences;
  final AssetBundle? bundle;
  final http.Client? client;

  static bool get localPreview {
    if (!kIsWeb) return false;
    final host = Uri.base.host;
    return host == '127.0.0.1' || host == 'localhost';
  }

  Uri get _projectUri => Uri.base.resolve('/$shipLayoutsProjectRoute');

  Future<SharedPreferences> _prefs() =>
      (preferences ?? SharedPreferences.getInstance)();

  static ShipLayoutBook? decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic>
          ? ShipLayoutBook.fromJson(value)
          : null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  static String encode(ShipLayoutBook book) =>
      const JsonEncoder.withIndent('  ').convert(book.toJson());

  Future<ShipLayoutBook?> loadBundled() async {
    try {
      return decode(
        await (bundle ?? rootBundle).loadString(shipLayoutsAssetPath),
      );
    } on Object {
      return null;
    }
  }

  Future<ShipLayoutBook?> _loadProject() async {
    if (!localPreview) return null;
    try {
      final response = await (client ?? http.Client())
          .get(_projectUri)
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200
          ? decode(utf8.decode(response.bodyBytes))
          : null;
    } on Object {
      return null;
    }
  }

  Future<ShipLayoutLoad> load() async {
    final candidates = <(ShipLayoutBook, ShipLayoutSource)>[
      if (await loadBundled() case final b?) (b, ShipLayoutSource.bundled),
      if (await _loadProject() case final p?) (p, ShipLayoutSource.project),
      if (decode((await _prefs()).getString(shipLayoutsStorageKey))
          case final s?)
        (s, ShipLayoutSource.browser),
    ];
    if (candidates.isEmpty) {
      return const ShipLayoutLoad(
        ShipLayoutBook(revision: 0, ships: {}),
        ShipLayoutSource.bundled,
      );
    }
    // Newest revision wins; on a tie prefer the project file, then bundled.
    candidates.sort((a, b) {
      final byRevision = b.$1.revision.compareTo(a.$1.revision);
      if (byRevision != 0) return byRevision;
      int rank(ShipLayoutSource s) => switch (s) {
        ShipLayoutSource.project => 0,
        ShipLayoutSource.bundled => 1,
        ShipLayoutSource.browser => 2,
      };
      return rank(a.$2).compareTo(rank(b.$2));
    });
    return ShipLayoutLoad(candidates.first.$1, candidates.first.$2);
  }

  Future<ShipLayoutSaveResult> save(ShipLayoutBook book) async {
    final next = book.nextRevision();
    final raw = encode(next);
    await (await _prefs()).setString(shipLayoutsStorageKey, raw);
    var project = false;
    if (localPreview) {
      try {
        final response = await (client ?? http.Client())
            .put(
              _projectUri,
              headers: const {
                'content-type': 'application/json; charset=utf-8',
              },
              body: raw,
            )
            .timeout(const Duration(seconds: 3));
        project = response.statusCode == 200;
      } on Object {
        project = false;
      }
    }
    return ShipLayoutSaveResult(book: next, project: project);
  }

  /// Forgets this browser's copy so the bundled/project file applies again.
  Future<void> clearBrowserCopy() async =>
      (await _prefs()).remove(shipLayoutsStorageKey);
}
