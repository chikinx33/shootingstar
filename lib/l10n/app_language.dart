import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'english_catalog.dart';
import 'language_document_stub.dart'
    if (dart.library.js_interop) 'language_document_web.dart';

/// Device preference: independent of cloud saves, guest backups and test runs.
class AppLanguage extends ChangeNotifier {
  static final instance = AppLanguage();
  static const storageKey = 'shootingstar.language.v1';
  String _code = 'ko';
  SharedPreferences? _preferences;
  Future<void> _write = Future.value();
  bool saveFailed = false;
  String get code => _code;
  Locale get locale => Locale(_code);
  bool get english => _code == 'en';

  static void watch(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanguageScope>();

  Future<void> load({SharedPreferences? preferences}) async {
    try {
      _preferences = preferences ?? await SharedPreferences.getInstance();
      _code = _preferences!.getString(storageKey) == 'en' ? 'en' : 'ko';
    } catch (_) {
      _code = 'ko';
      saveFailed = true;
    }
    _cache.clear();
    updateLanguageDocument(_code);
    notifyListeners();
  }

  Future<void> select(String code) async {
    if (code != 'ko' && code != 'en') return;
    _code = code;
    _cache.clear();
    updateLanguageDocument(_code);
    notifyListeners();
    // Serialize rapid switches; the final choice always wins on disk.
    _write = _write.then((_) async {
      try {
        _preferences ??= await SharedPreferences.getInstance();
        saveFailed = !await _preferences!.setString(storageKey, code);
      } catch (_) {
        saveFailed = true;
      }
    });
    await _write;
    notifyListeners();
  }
}

class LanguageScope extends InheritedNotifier<AppLanguage> {
  LanguageScope({super.key, required super.child})
    : super(notifier: AppLanguage.instance);
}

final _hangul = RegExp(r'[가-힣]');
final _cache = <String, String>{};
final _templates =
    englishCatalog.entries
        .where(
          (e) => RegExp(r'\{\d+\}').hasMatch(e.key) && _hangul.hasMatch(e.key),
        )
        .map(_Message.new)
        .toList()
      ..sort((a, b) => b.specificity.compareTo(a.specificity));

final _composedTemplates = englishCatalog.entries
    .where(
      (e) => RegExp(r'\{\d+\}').hasMatch(e.key) && !_hangul.hasMatch(e.key),
    )
    .map(_Message.new)
    .toList();

class _Message {
  _Message(MapEntry<String, String> entry) : english = entry.value {
    if (entry.key == '{0} {1}-{2}') {
      expression = RegExp(r'^(.*) (\d+)-(\d+)$');
      indices.addAll([0, 1, 2]);
      specificity = 3;
      return;
    }
    final token = RegExp(r'\{(\d+)\}');
    var end = 0;
    final pattern = StringBuffer('^');
    for (final match in token.allMatches(entry.key)) {
      pattern.write(RegExp.escape(entry.key.substring(end, match.start)));
      pattern.write('([\\s\\S]*?)');
      indices.add(int.parse(match[1]!));
      end = match.end;
    }
    pattern.write(RegExp.escape(entry.key.substring(end)));
    pattern.write(r'$');
    expression = RegExp(pattern.toString());
    specificity = entry.key.replaceAll(token, '').length;
  }
  final String english;
  final indices = <int>[];
  late final RegExp expression;
  late final int specificity;
  String? apply(String source, int depth) {
    final match = expression.firstMatch(source);
    if (match == null) return null;
    final values = <int, String>{};
    for (int i = 0; i < indices.length; i++) {
      values[indices[i]] = _translate(match[i + 1]!, depth + 1);
    }
    return english.replaceAllMapped(
      RegExp(r'\{(\d+)\}'),
      (m) => values[int.parse(m[1]!)] ?? m[0]!,
    );
  }
}

/// Only presentation boundaries call this. IDs, saves and comparisons stay raw.
T tr<T extends String?>(T source) {
  if (source == null ||
      !AppLanguage.instance.english ||
      !_hangul.hasMatch(source)) {
    return source;
  }
  final cached = _cache[source];
  if (cached != null) return cached as T;
  final result = _translate(source, 0);
  if (_cache.length >= 512) _cache.remove(_cache.keys.first);
  _cache[source] = result;
  return result as T;
}

String _translate(String source, int depth) {
  if (!_hangul.hasMatch(source) || depth > 8) return source;
  final direct = englishCatalog[source];
  if (direct != null && !direct.contains(RegExp(r'\{\d+\}'))) return direct;
  for (final message in _templates) {
    final result = message.apply(source, depth);
    if (result != null) return result;
  }
  // Composed reward summaries and data labels retain their numbers/separators.
  for (final separator in ['\n', ' · ', ' / ', ' + ', ': ', ' → ']) {
    if (source.contains(separator)) {
      return source
          .split(separator)
          .map((s) => _translate(s, depth + 1))
          .join(separator);
    }
  }
  for (final message in _composedTemplates) {
    final result = message.apply(source, depth);
    if (result != null) return result;
  }
  return source;
}

/// Typed interpolation keeps message identity and argument order unambiguous.
String message(String korean, List<Object?> values) {
  final english = AppLanguage.instance.english;
  final template = english ? englishCatalog[korean] ?? korean : korean;
  return template.replaceAllMapped(RegExp(r'\{(\d+)\}'), (match) {
    final index = int.parse(match[1]!);
    if (index >= values.length) return match[0]!;
    final text = '${values[index]}';
    return english ? tr(text) : text;
  });
}
