import 'package:flutter/material.dart';

export 'campaign.dart';
export 'enemy_doctrine.dart';
export 'combat_loadout.dart';

@immutable
class ShipSpec {
  const ShipSpec({
    required this.name,
    required this.tagline,
    required this.detail,
    required this.color,
    required this.unlockCost,
    required this.health,
    required this.speed,
    required this.damage,
    required this.asset,
  });
  final String name, tagline, detail, asset;
  final Color color;
  final int unlockCost;
  final double health, speed, damage;
}

const ships = <ShipSpec>[
  ShipSpec(
    name: '치즈 · 선샤인',
    tagline: '균형형 신참 수호묘',
    detail: '의욕만 넘치는 치즈태비 신참. 든든한 선체와 빠른 연사로 처음 출격하기에 딱 좋습니다.',
    color: Color(0xFF60E7EF),
    unlockCost: 0,
    health: 120,
    speed: 200,
    damage: 1,
    asset: 'assets/art/survival_ship.png',
  ),
  ShipSpec(
    name: '구름 · 클라우드',
    tagline: '고속 요격형 수호묘',
    detail: '느긋해 보여도 누구보다 빠른 러시안블루. 포위를 뚫고 강하게 쏘지만 선체가 가볍습니다.',
    color: Color(0xFFFFB768),
    unlockCost: 200,
    health: 90,
    speed: 245,
    damage: 1.2,
    asset: 'assets/art/shootingstar_scout.png',
  ),
  ShipSpec(
    name: '까미 · 나이트폴',
    tagline: '중장갑 베테랑 수호묘',
    detail: '과묵한 턱시도 베테랑. 느리지만 두꺼운 장갑과 강한 쌍포로 전선을 밀어냅니다.',
    color: Color(0xFFB9A1FF),
    unlockCost: 450,
    health: 175,
    speed: 165,
    damage: 1.15,
    asset: 'assets/art/shootingstar_bastion.png',
  ),
];

@immutable
class EquipmentSpec {
  const EquipmentSpec(this.name, this.detail, this.color);
  final String name, detail;
  final Color color;
}

const equipmentOptions = <EquipmentSpec>[
  EquipmentSpec('보강 프레임', '최대 선체 +20% · 균형 잡힌 생존 장비', Color(0xFF60E7EF)),
  EquipmentSpec('과충전 코어', '피해 +20% · 최대 선체 −10%', Color(0xFFFFB768)),
  EquipmentSpec('회수 렌즈', '경험치 회수 범위 +70% · 이동 속도 +5%', Color(0xFFB9A1FF)),
];

const maxUpgradeLevel = 5;
int upgradeCost(int currentLevel) => 80 + currentLevel * 60;
