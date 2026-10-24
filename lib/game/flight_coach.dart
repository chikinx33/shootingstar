import 'engine.dart';

enum FlightLesson { hold, release, move, collect, draft, ultimate, complete }

/// Observes actual actions; never grants XP, weapons, damage or tutorial rewards.
class FlightCoach {
  FlightLesson lesson = FlightLesson.hold;
  double held = 0, moved = 0;
  bool selected = false;

  void observe(GameEngine game, double dt, {required bool pressed}) {
    if (game.paused ||
        game.finished ||
        game.choices.isNotEmpty ||
        game.resolvingBoss) {
      return;
    }
    if (lesson == FlightLesson.hold && pressed) {
      held += dt;
      if (held >= .7) lesson = FlightLesson.release;
    } else if (lesson == FlightLesson.release && !pressed) {
      lesson = FlightLesson.move;
    } else if (lesson == FlightLesson.move && game.input.distance > .1) {
      moved += dt;
      if (moved >= .5) lesson = FlightLesson.collect;
    } else if (lesson == FlightLesson.collect &&
        (game.level > 1 ||
            game.mainRate + game.mainPower + game.mainCount > 0)) {
      lesson = selected ? FlightLesson.ultimate : FlightLesson.draft;
    } else if (lesson == FlightLesson.draft && selected) {
      lesson = FlightLesson.ultimate;
    } else if (lesson == FlightLesson.ultimate &&
        (!game.hasCommonUltimate || game.ultimateRemaining > 0)) {
      lesson = FlightLesson.complete;
    }
  }

  String hint(GameEngine game) {
    if (game.bossWarning) return '보스 예고선 밖으로 이동하세요 · 밝은 통로가 안전';
    if (game.boss != null) return '예고선을 피하고 코어가 열릴 때 공격하세요';
    if (game.hasCommonUltimate && game.ultimateReady) {
      return '항성포를 눌러 전방 탄막을 정리하세요 · 무적 없음';
    }
    return switch (lesson) {
      FlightLesson.hold => '화면을 눌러 비행 시작 · 손을 떼면 5% 속도',
      FlightLesson.release => '손을 떼어 판단 시간을 확보해 보세요',
      FlightLesson.move => '다시 누르고 드래그해 경험치 쪽으로 이동하세요',
      FlightLesson.collect => '경험치를 모으세요 · R 연사 / P 출력 / N 발사 수',
      FlightLesson.draft => '성장 선택은 이번 출격만 적용 · 특화는 하나만 선택',
      FlightLesson.ultimate => '항성포는 20초 충전 · 준비되면 눌러 사용하세요',
      FlightLesson.complete => '',
    };
  }
}
