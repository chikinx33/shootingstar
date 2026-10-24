import '../l10n/app_language.dart';

import '../art/raster_assets.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One portrait viewport for every route, dialog and battle. Keyboard insets
/// never change the viewport width; phones use their full available width.
class PortraitViewport extends StatelessWidget {
  const PortraitViewport({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, bounds) {
        final fullHeight = bounds.maxHeight;
        final phonePortrait = bounds.maxWidth <= 600;
        final width = phonePortrait
            ? bounds.maxWidth
            : math.min(480.0, math.min(bounds.maxWidth, fullHeight * 9 / 19.5));
        final rotate =
            fullHeight < 500 &&
            bounds.maxWidth > fullHeight &&
            media.viewInsets.bottom == 0;
        return ColoredBox(
          color: const Color(0xFF030711),
          child: Center(
            child: SizedBox(
              key: const Key('portrait-viewport'),
              width: width,
              height: bounds.maxHeight,
              child: MediaQuery(
                data: media.copyWith(size: Size(width, bounds.maxHeight)),
                child: ClipRect(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      TickerMode(
                        enabled: !rotate,
                        child: Offstage(
                          offstage: rotate,
                          child: OverflowBox(
                            minWidth: rotate ? 390 : width,
                            maxWidth: rotate ? 390 : width,
                            minHeight: rotate ? 844 : bounds.maxHeight,
                            maxHeight: rotate ? 844 : bounds.maxHeight,
                            child: SizedBox(
                              width: rotate ? 390 : width,
                              height: rotate ? 844 : bounds.maxHeight,
                              child: MediaQuery(
                                data: media.copyWith(
                                  size: rotate
                                      ? const Size(390, 844)
                                      : Size(width, bounds.maxHeight),
                                ),
                                child: child,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (rotate)
                        Material(
                          color: Color(0xFF080F1E),
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RasterIcon(Icons.screen_rotation, size: 40),
                                  SizedBox(height: 16),
                                  Text(
                                    tr('기기를 세로로 돌려주세요'),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    tr('진행은 그대로 유지됩니다.'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
