import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import 'audio_feedback.dart';
import 'game_ui.dart';

/// The guardian cats' story in four illustrated cards (first launch, and
/// again from the guide). Tap or "다음" advances; "건너뛰기" closes.
class PrologueScreen extends StatefulWidget {
  const PrologueScreen({super.key});

  static const pages = [
    (
      'assets/art/story_v11/story_1.jpg',
      '밤하늘의 별똥별',
      '사실 별똥별은 지구를 지키는 수호묘들의 출격이었습니다.\n고양이가 허공을 빤히 보는 건 제국 정찰기를 감시하는 중이죠.',
    ),
    (
      'assets/art/story_v11/story_2.jpg',
      '흡입대왕 바큠',
      '은하수 너머에 봉인된 살아 있는 블랙홀.\n봉인이 약해지자 진공 제국 함대가 지구의 온기를 노리고 몰려옵니다.',
    ),
    (
      'assets/art/story_v11/story_3.jpg',
      '상자 속 비밀 격납고',
      '집사가 출근한 사이, 신참 수호묘 치즈가 출격 명령을 받았습니다.\n상자 속으로 쏙 뛰어들면 격납고가 열립니다.',
    ),
    (
      'assets/art/story_v11/story_4.jpg',
      '수호묘, 출격!',
      '병아리 친구들과 함께 함대 사령관 10명을 물리치고 봉인을 지키세요.\n집사가 돌아오기 전까지!',
    ),
  ];

  @override
  State<PrologueScreen> createState() => _PrologueScreenState();
}

class _PrologueScreenState extends State<PrologueScreen> {
  int _page = 0;

  void _next() {
    if (_page >= PrologueScreen.pages.length - 1) {
      Navigator.of(context).pop();
    } else {
      setState(() => _page++);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final (image, title, body) = PrologueScreen.pages[_page];
    final last = _page == PrologueScreen.pages.length - 1;
    return Scaffold(
      backgroundColor: const Color(0xFF0E1726),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                key: const Key('prologue-art'),
                onTap: audible(_next),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  child: Padding(
                    key: ValueKey(_page),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        image,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  Text(
                    tr(title),
                    key: const Key('prologue-title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFFD43D),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(body),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < PrologueScreen.pages.length; i++)
                  Container(
                    width: i == _page ? 22 : 10,
                    height: 10,
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: i == _page
                          ? const Color(0xFFFFD43D)
                          : const Color(0xFF3B5470),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!last)
                    Expanded(
                      child: GameActionButton(
                        label: '건너뛰기',
                        icon: Icons.fast_forward,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  if (!last) const SizedBox(width: 8),
                  Expanded(
                    child: GameActionButton(
                      key: const Key('prologue-next'),
                      label: last ? '출격 준비' : '다음',
                      icon: last ? Icons.rocket_launch : Icons.arrow_forward,
                      primary: true,
                      onPressed: _next,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
