import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/ui/catalog_screens.dart';

/// A tab by its label: v12.8 kit tabs ([GameTab]) or the Material
/// [ChoiceChip]s some screens still use.
Finder tabWithText(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((w) => w is GameTab || w is ChoiceChip),
);
