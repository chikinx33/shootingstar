import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/components.dart';
import 'package:shootingstar/ui/guild_screen.dart';
import 'package:shootingstar/ui/home.dart';

import 'ui_actions.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader(
      'NotoSansKR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
  });
  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'shared centered guild, pages, painted decision and dialog $width/$scale',
        (tester) async {
          final size = Size(width, width == 320 ? 568 : 844);
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          final p = await Profile.load();
          p.soundEnabled = false;
          final app = ShootingstarApp(
            profile: p,
          ).build(tester.element(find.byType(View))) as MaterialApp;
          Future<void> mount(Widget child) async {
            await tester.pumpWidget(
              MaterialApp(
                theme: app.theme,
                builder: (c, w) => MediaQuery(
                  data: MediaQuery.of(c)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: w!,
                ),
                home: child,
              ),
            );
            await tester.pumpAndSettle();
          }

          await mount(GuildScreen(profile: p));
          for (final label in ['함께하는 함대', '동료와 함께 성장하세요']) {
            final text = find.text(label);
            expect(
              tester.getCenter(text).dx,
              closeTo(width / 2, .6),
              reason: label,
            );
            expect(
              tester.renderObject<RenderParagraph>(text).textAlign,
              TextAlign.center,
            );
          }
          final action = find.widgetWithText(GameActionButton, '계정 로그인 · 가입');
          await revealUi(tester, action);
          final paint = find.descendant(
            of: action,
            matching: find.byType(FilledButton),
          );
          expect(tester.getCenter(paint).dx, closeTo(width / 2, .6));
          expect(tester.getSize(paint).width, lessThanOrEqualTo(264));
          expect(tester.takeException(), isNull);
          await mount(
            Scaffold(
              body: Center(
                child: GameActionButton(
                  label: '상세 열기',
                  onPressed: () => showDialog<void>(
                    context: tester.element(find.byType(GameActionButton)),
                    builder: (_) => GameDialog(
                      title: '가운데 정렬 상세',
                      child: Column(
                        children: [
                          const GameSectionTitle('공통 제목'),
                          const Text(
                            '여러 줄의 설명도 콘텐츠 영역의 가운데에 맞춰서 표시합니다. 줄바꿈과 페이지 이동은 기존 방식으로 유지합니다.',
                            textAlign: TextAlign.center,
                          ),
                          GameActionButton(
                            label: '확인',
                            onPressed: () => Navigator.pop(
                              tester.element(find.byType(GameDialog)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('상세 열기'));
          await tester.pumpAndSettle();
          final panel = tester.getRect(
            find.byKey(const Key('game-dialog-panel')),
          );
          expect(
            tester.getCenter(find.text('가운데 정렬 상세')).dx,
            closeTo(panel.center.dx, .6),
          );
          final confirm = find.descendant(
            of: find.widgetWithText(GameActionButton, '확인'),
            matching: find.byType(FilledButton),
          );
          await revealUi(tester, confirm);
          expect(tester.getCenter(confirm).dx, closeTo(panel.center.dx, .6));
          expect(tester.takeException(), isNull);
          p.onboarded = true;
          p.reducedEffects = true;
          await mount(HomeScreen(profile: p));
          expect(
            tester.getCenter(find.text('슈팅스타')).dx,
            closeTo(width / 2, .6),
          );
          expect(find.byTooltip('격납고'), findsNothing);
          expect(find.text('격납고'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          p.dispose();
        },
      );
    }
  }
}
