import 'dart:math' as math;

/// v11 quests, after PuzzleKnight's design: one set of lifetime counters
/// feeds every goal, so no system keeps its own tally.
///
/// * Captain Momo's story quests: a hand-written chain that teaches each
///   system in order (fly, equip, upgrade, chicks, bosses, worlds).
/// * Achievements: endless tiers per counter; targets grow triangularly and
///   rewards grow linearly with a star-dust bonus every fifth tier.
enum GuardianStat {
  flights,
  kills,
  bosses,
  stagesCleared,
  worldsCleared,
  gearUpgrades,
  gearOwned,
  pilotLevel,
  chickLevel,
}

const guardianStatNames = {
  GuardianStat.flights: '출격',
  GuardianStat.kills: '제국 병기 격파',
  GuardianStat.bosses: '함대 사령관 격파',
  GuardianStat.stagesCleared: '항로 완주',
  GuardianStat.worldsCleared: '세계 해방',
  GuardianStat.gearUpgrades: '장비 강화',
  GuardianStat.gearOwned: '장비 수집',
  GuardianStat.pilotLevel: '수호묘 레벨',
  GuardianStat.chickLevel: '병아리 레벨 합계',
};

class QuestReward {
  const QuestReward({this.churu = 0, this.stardust = 0, this.gearRarity});
  final int churu, stardust;

  /// A guaranteed gear piece of this rarity (story milestones).
  final int? gearRarity;
  String get summary => [
    if (churu > 0) '츄르 $churu',
    if (stardust > 0) '별가루 $stardust',
    if (gearRarity != null)
      '${const ['일반', '고급', '희귀', '영웅', '전설'][gearRarity!]} 장비 1',
  ].join(' · ');
}

class StoryQuest {
  const StoryQuest(this.title, this.line, this.stat, this.target, this.reward);
  final String title;

  /// What Captain Momo says when the quest is offered.
  final String line;
  final GuardianStat stat;
  final int target;
  final QuestReward reward;
}

/// Captain Momo, the retired guardian, walks a rookie through the game.
const storyQuests = [
  StoryQuest(
    '첫 출격',
    '신참, 상자 속 격납고는 찾았지? 일단 한 번 날아 보자!',
    GuardianStat.flights,
    1,
    QuestReward(churu: 120, stardust: 2),
  ),
  StoryQuest(
    '청소기 정찰대 소탕',
    '제국 놈들은 청소기 소리부터 다르지. 50기만 쫓아내 봐.',
    GuardianStat.kills,
    50,
    QuestReward(churu: 150, gearRarity: 1),
  ),
  StoryQuest(
    '첫 항로 완주',
    '사령관 스프리츠를 물리치고 1-1 항로를 지켜 내라.',
    GuardianStat.stagesCleared,
    1,
    QuestReward(churu: 200, stardust: 4),
  ),
  StoryQuest(
    '장비 손질',
    '장비는 아끼면 녹슨다. 성장 → 장비에서 한 번 강화해 봐.',
    GuardianStat.gearUpgrades,
    1,
    QuestReward(churu: 180, stardust: 3),
  ),
  StoryQuest(
    '병아리 친구',
    '병아리들도 함께 자라야지. 병아리 레벨 합계를 3까지!',
    GuardianStat.chickLevel,
    3,
    QuestReward(churu: 220, stardust: 4),
  ),
  StoryQuest(
    '사령관 사냥',
    '사령관 셋을 쓰러뜨리면 너도 어엿한 수호묘다.',
    GuardianStat.bosses,
    3,
    QuestReward(churu: 260, gearRarity: 2),
  ),
  StoryQuest(
    '우리 동네 해방',
    '1세계 10개 항로를 모두 지키면 동네 고양이들이 안심할 거야.',
    GuardianStat.worldsCleared,
    1,
    QuestReward(churu: 400, stardust: 10),
  ),
  StoryQuest(
    '장비 수집가',
    '세트를 맞추면 힘이 난다. 장비를 12개 모아 봐.',
    GuardianStat.gearOwned,
    12,
    QuestReward(churu: 300, gearRarity: 2),
  ),
  StoryQuest(
    '노을 너머로',
    '노을 구름바다까지 해방해라. 드라이언의 열풍을 조심하고!',
    GuardianStat.worldsCleared,
    2,
    QuestReward(churu: 500, stardust: 12),
  ),
  StoryQuest(
    '베테랑의 길',
    '수호묘 레벨 10. 이제 내가 가르칠 게 별로 없겠군.',
    GuardianStat.pilotLevel,
    10,
    QuestReward(churu: 600, gearRarity: 3),
  ),
  StoryQuest(
    '달까지',
    '달 궤도의 거품 제독 버블스… 목욕은 질색이지만 가야 한다.',
    GuardianStat.worldsCleared,
    4,
    QuestReward(churu: 800, stardust: 20),
  ),
  StoryQuest(
    '봉인의 수호자',
    '은하수 봉인문까지. 흡입대왕이 다시는 못 나오게!',
    GuardianStat.worldsCleared,
    10,
    QuestReward(churu: 3000, gearRarity: 4),
  ),
];

class Achievement {
  const Achievement(this.stat, this.tier, this.target, this.reward);
  final GuardianStat stat;
  final int tier, target;
  final QuestReward reward;
  String get id => 'achievement_${stat.name}_$tier';
  String get title => '${guardianStatNames[stat]} ${tier}단계';
}

/// Endless achievement tier [tier] (1-based) for [stat].
Achievement achievementFor(GuardianStat stat, int tier) {
  final t = math.max(1, tier);
  final tri = t * (t + 1) ~/ 2;
  final target = switch (stat) {
    GuardianStat.flights => tri * 3,
    GuardianStat.kills => tri * 150,
    GuardianStat.bosses => tri * 2,
    GuardianStat.stagesCleared => t * 3,
    GuardianStat.worldsCleared => t,
    GuardianStat.gearUpgrades => tri * 3,
    GuardianStat.gearOwned => t * 8,
    GuardianStat.pilotLevel => t * 5,
    GuardianStat.chickLevel => t * 4,
  };
  final step = math.min(20, t - 1);
  final reward = QuestReward(
    churu: 60 + step * 25,
    stardust: 1 + step ~/ 3 + (t % 5 == 0 ? 10 + math.min(40, t ~/ 5 * 5) : 0),
  );
  return Achievement(stat, t, target, reward);
}

/// What the account has claimed. Progress itself is read live from the
/// profile (see Profile.guardianStat), so nothing can drift out of step.
class GuardianQuestState {
  int storyStep = 0;
  final Map<GuardianStat, int> achievementTier = {
    for (final s in GuardianStat.values) s: 1,
  };

  /// Lifetime counters the profile does not already keep.
  int bosses = 0, gearUpgrades = 0;

  StoryQuest? get currentStory =>
      storyStep < storyQuests.length ? storyQuests[storyStep] : null;

  Achievement nextAchievement(GuardianStat stat) =>
      achievementFor(stat, achievementTier[stat] ?? 1);

  Map<String, dynamic> toJson() => {
    'storyStep': storyStep,
    'tiers': {for (final e in achievementTier.entries) e.key.name: e.value},
    'bosses': bosses,
    'gearUpgrades': gearUpgrades,
  };

  static GuardianQuestState restore(Object? raw) {
    final state = GuardianQuestState();
    if (raw is! Map) return state;
    final step = raw['storyStep'];
    if (step is int) state.storyStep = step.clamp(0, storyQuests.length);
    final tiers = raw['tiers'];
    if (tiers is Map) {
      for (final s in GuardianStat.values) {
        final t = tiers[s.name];
        if (t is int) state.achievementTier[s] = t.clamp(1, 999);
      }
    }
    final b = raw['bosses'], g = raw['gearUpgrades'];
    if (b is int) state.bosses = math.max(0, b);
    if (g is int) state.gearUpgrades = math.max(0, g);
    return state;
  }
}
