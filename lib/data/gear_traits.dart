import 'content_catalog.dart';

bool validGearSpecs(List<int> specs) =>
    specs.isEmpty ||
    specs.length == 6 &&
        List.generate(6, (i) => i).every(
          (slot) =>
              specs[slot] >= 0 &&
              specs[slot] < gearCatalog.length &&
              gearCatalog[specs[slot]].slot == slot,
        );

List<int> checkedGearSpecs(Iterable<int> raw) {
  final specs = List<int>.unmodifiable(raw);
  if (!validGearSpecs(specs))
    throw const FormatException('Invalid gear loadout');
  return specs;
}

/// Comparable contribution only: perks, set effects and roles stay explicit.
double gearBaseContribution(GearItem g) => g.definition.slot < 3
    ? g.rank * .06 +
          g.level * .02 +
          (g.spec == 2
              ? .02 * (g.rank + 1)
              : g.spec == 4
              ? .03 * (g.rank + 1)
              : 0)
    : g.rank * .08 +
          g.level * .025 +
          (g.spec == 6
              ? .04 * (g.rank + 1)
              : g.spec == 9
              ? .03 * (g.rank + 1)
              : 0);
