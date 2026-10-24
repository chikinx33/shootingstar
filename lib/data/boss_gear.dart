import 'content_catalog.dart';

/// Earned odd-kill milestones; inventory-full rewards stay claimable forever.
class BossGearBook {
  List<int> defeats = List.filled(10, 0), claimed = List.filled(10, 0);
  int available(int world) => (defeats[world] + 1) ~/ 2;
  int pending(int world) => available(world) - claimed[world];
  int nextSpec(int world) => 12 + world * 2 + claimed[world] % 2;
  void record(int world, int bosses) {
    if (world >= 0 && world < 10 && bosses > 0) {
      defeats[world] = (defeats[world] + bosses.clamp(0, 3)).clamp(0, 9999);
    }
  }

  Map<String, dynamic> toJson() => {
    'defeats': [...defeats],
    'claimed': [...claimed],
  };
  static BossGearBook restore(dynamic raw) {
    final book = BossGearBook();
    if (raw is! Map) return book;
    for (var i = 0; i < 10; i++) {
      if (raw['defeats'] is List && i < (raw['defeats'] as List).length) {
        book.defeats[i] = boundedInt(raw['defeats'][i], 0, 9999);
      }
      if (raw['claimed'] is List && i < (raw['claimed'] as List).length) {
        book.claimed[i] = boundedInt(raw['claimed'][i], 0, book.available(i));
      }
    }
    return book;
  }
}
