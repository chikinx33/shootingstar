import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import '../main.dart';
import 'game_dialog.dart';
import 'game_ui.dart';
import '../art/raster_assets.dart';
import '../art/toon_assets.dart';
export '../art/raster_assets.dart';
export 'game_ui.dart';
export 'game_dialog.dart';
export 'game_info.dart';
export 'game_pages.dart';

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = cyan});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Text(
      tr(text),
      style: TextStyle(
        color: color,
        letterSpacing: 2.3,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),

      textAlign: TextAlign.center,
    );
  }
}

class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.active = false,
    this.rarity,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool active;
  final int? rarity;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return rarity != null
        ? ToonRarityFrame(
            rank: rarity!,
            child: Padding(padding: padding, child: child),
          )
        : RasterPanel(
            skin: active ? 1 : 0,
            child: Padding(padding: padding, child: child),
          );
  }
}

class Stat extends StatelessWidget {
  const Stat(this.value, this.label, {super.key});
  final String value, label;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          tr(value),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),

          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3),
        Text(
          tr(label),
          style: const TextStyle(fontSize: 14, color: muted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

Widget gap([double height = 16]) => SizedBox(height: height);

Future<void> showGuide(BuildContext context, VoidCallback done) async {
  var completed = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialog) => GameDialog(
      title: '비행 가이드',
      actions: [
        GameActionButton(
          label: '비행 준비 완료',
          primary: true,
          onPressed: audible(() {
            if (completed) return;
            completed = true;
            done();
            Navigator.pop(dialog);
          }),
        ),
      ],
      // Each tip is centred at the same width, so the icons line up and the
      // block sits in the middle (user 2026-10-25); separate tips still let
      // the smallest phones split the guide into pages.
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GuideTip(
            icon: Icons.navigation,
            title: '이동',
            text: '누른 채 드래그하면 이동해요.\n손을 떼면 5% 속도로 느려져요.',
          ),
          GuideTip(
            icon: Icons.gps_fixed,
            title: '자동 발사',
            text: '주포는 위쪽으로 자동 발사돼요.',
          ),
          GuideTip(
            icon: Icons.diamond,
            title: '보석과 레벨업',
            text: '보석을 모으면 레벨업해요.\n카드 3장 중 하나를 고르세요.',
          ),
          GuideTip(
            icon: Icons.pause,
            title: '일시정지',
            text: '오른쪽 위 일시정지 버튼을 눌러요.',
          ),
        ],
      ),
    ),
  );
}

/// One short guide fact: icon, then a left-aligned title and note. Every tip
/// is [width] wide and centred, so a list of tips reads as one centred block.
class GuideTip extends StatelessWidget {
  const GuideTip({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title, text;

  static const width = 290.0;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: SizedBox(
          width: width,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RasterIcon(icon, size: 44),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      tr(title),
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.start,
                    ),
                    Text(
                      tr(text),
                      style: const TextStyle(
                        fontSize: GameUi.body,
                        height: 1.35,
                      ),
                      textAlign: TextAlign.start,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
