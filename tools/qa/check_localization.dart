import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'package:shootingstar/l10n/english_catalog.dart';

class CatalogCheck extends RecursiveAstVisitor<void> {
  final String path;
  final missing = <String>{};
  CatalogCheck(this.path);
  void check(String value) {
    if (RegExp(r'[가-힣]').hasMatch(value) &&
        !englishCatalog.containsKey(value)) {
      missing.add('$path: $value');
    }
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (node.parent is! StringInterpolation) check(node.value);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    var i = 0;
    check(
      node.elements
          .map((e) => e is InterpolationString ? e.value : '{${i++}}')
          .join(),
    );
    super.visitStringInterpolation(node);
  }
}

void main() {
  final missing = <String>{};
  var count = 0;
  for (final file in Directory(
    'lib',
  ).listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart') ||
        file.path.contains(
          '${Platform.pathSeparator}l10n${Platform.pathSeparator}',
        )) {
      continue;
    }
    final checker = CatalogCheck(file.path);
    parseString(
      content: file.readAsStringSync(),
      path: file.path,
    ).unit.accept(checker);
    missing.addAll(checker.missing);
    count++;
  }
  // Guild mail and API failures are displayed by the same client boundaries.
  final server = File('server/src/worker.mjs');
  final quoted = RegExp(r'''(['"`])((?:\\.|(?!\1)[^\\])*?)\1''', dotAll: true);
  for (final literal in quoted.allMatches(server.readAsStringSync())) {
    var index = 0;
    final key = literal[2]!.replaceAllMapped(RegExp(r'\$\{[^}]+\}'), (_) => '{${index++}}');
    if (RegExp(r'[가-힣]').hasMatch(key) && !englishCatalog.containsKey(key)) {
      missing.add('${server.path}: $key');
    }
  }
  if (missing.isNotEmpty) {
    stderr.writeln(missing.join('\n'));
    exitCode = 1;
  } else {
    stdout.writeln(
      'Localization coverage: $count sources, ${englishCatalog.length} catalog entries, no missing Korean literals.',
    );
  }
}
