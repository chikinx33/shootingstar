/// Describes existing auxiliary behavior. Tags never grant slots or raw power.
enum AuxiliaryRole {
  crowd('측면·군집'),
  priority('우선 표적'),
  defense('근접 방어'),
  control('제어·지원');

  const AuxiliaryRole(this.label);
  final String label;
}

enum WeaponTag {
  direct('직격'),
  pierce('관통'),
  chain('연쇄'),
  burn('연소'),
  explosive('폭발'),
  guard('방호');

  const WeaponTag(this.label);
  final String label;
}

class WeaponRoleProfile {
  const WeaponRoleProfile(this.role, this.tags);
  final AuxiliaryRole role;
  final Set<WeaponTag> tags;
  String get label => '${role.label} · ${tags.map((t) => t.label).join('·')}';
}

const auxiliaryProfiles = <String, WeaponRoleProfile>{
  'missile': WeaponRoleProfile(AuxiliaryRole.priority, {WeaponTag.explosive}),
  'drone': WeaponRoleProfile(AuxiliaryRole.priority, {WeaponTag.direct}),
  'side': WeaponRoleProfile(AuxiliaryRole.crowd, {WeaponTag.direct}),
  'mine': WeaponRoleProfile(AuxiliaryRole.defense, {WeaponTag.explosive}),
  'trail': WeaponRoleProfile(AuxiliaryRole.crowd, {WeaponTag.burn}),
  'guardian': WeaponRoleProfile(AuxiliaryRole.defense, {WeaponTag.guard}),
  'lightning': WeaponRoleProfile(AuxiliaryRole.crowd, {WeaponTag.chain}),
  'droneB': WeaponRoleProfile(AuxiliaryRole.crowd, {WeaponTag.direct}),
  'ball': WeaponRoleProfile(AuxiliaryRole.crowd, {WeaponTag.direct}),
  'drill': WeaponRoleProfile(AuxiliaryRole.priority, {WeaponTag.pierce}),
  'laser': WeaponRoleProfile(AuxiliaryRole.control, {WeaponTag.pierce}),
  'forcefield': WeaponRoleProfile(AuxiliaryRole.defense, {WeaponTag.direct}),
  'brick': WeaponRoleProfile(AuxiliaryRole.priority, {WeaponTag.pierce}),
  'boomerang': WeaponRoleProfile(AuxiliaryRole.crowd, {WeaponTag.direct}),
  'durian': WeaponRoleProfile(AuxiliaryRole.crowd, {WeaponTag.direct}),
  'infernoMine': WeaponRoleProfile(AuxiliaryRole.crowd, {
    WeaponTag.explosive,
    WeaponTag.burn,
  }),
  'thunderMine': WeaponRoleProfile(AuxiliaryRole.crowd, {
    WeaponTag.explosive,
    WeaponTag.chain,
  }),
  'medicDrone': WeaponRoleProfile(AuxiliaryRole.control, {WeaponTag.direct}),
};

WeaponRoleProfile? weaponRoleFor(String id, {bool evolved = false}) {
  if (id == 'drone' && evolved) {
    return const WeaponRoleProfile(AuxiliaryRole.priority, {
      WeaponTag.direct,
      WeaponTag.pierce,
    });
  }
  return auxiliaryProfiles[id];
}
