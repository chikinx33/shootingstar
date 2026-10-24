import 'dart:math';

/// Small, portable combat RNG whose state survives a checkpoint. Not a source
/// of security tokens. 32-bit shifts have identical VM and JavaScript results.
class CombatRandom implements Random {
  CombatRandom([int? seed]) : state = 0 {
    // Jenkins mix prevents neighboring daily/test seeds from sharing an opening
    // spawn direction. Add/shift operations stay portable at 32-bit boundaries.
    var x = (seed ?? Random().nextInt(0x7fffffff)) & 0xffffffff;
    x = (x + 0x7ed55d16 + (x << 12)) & 0xffffffff;
    x = (x ^ 0xc761c23c ^ (x >>> 19)) & 0xffffffff;
    x = (x + 0x165667b1 + (x << 5)) & 0xffffffff;
    x = ((x + 0xd3a2646c) ^ (x << 9)) & 0xffffffff;
    x = (x + 0xfd7046c5 + (x << 3)) & 0xffffffff;
    state = (x ^ 0xb55a4f09 ^ (x >>> 16)) & 0xffffffff;
    if (state == 0) state = 0x6d2b79f5;
  }
  CombatRandom.fromState(this.state);
  int state;
  int _next() {
    var x = state;
    x = (x ^ (x << 13)) & 0xffffffff;
    x = (x ^ (x >>> 17)) & 0xffffffff;
    state = (x ^ (x << 5)) & 0xffffffff;
    return state;
  }

  @override
  double nextDouble() => _next() / 4294967296.0;
  @override
  bool nextBool() => _next().isOdd;
  @override
  int nextInt(int max) {
    if (max <= 0 || max > 0x7fffffff) {
      throw RangeError.range(max, 1, 0x7fffffff);
    }
    final limit = 4294967296 - 4294967296 % max;
    var value = _next();
    while (value >= limit) {
      value = _next();
    }
    return value % max;
  }
}
