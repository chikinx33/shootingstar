import 'l10n/app_language.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';

import 'ui/portrait_viewport.dart';
import 'ui/game_ui.dart';
import 'ui/audio_feedback.dart';

import 'data/profile.dart';
import 'data/cloud_sync.dart';
import 'services/commerce_controller.dart';
import 'ui/developer_screen.dart';
import 'art/raster_assets.dart';
import 'art/arcade_style.dart';
import 'art/toon_assets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLanguage.instance.load();
  await RasterAssets.load();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final profile = await Profile.load();
  await profile.restoreDeveloperSession();
  final online = CloudSync(profile);
  final commerce = CommerceController(profile, online);
  runApp(LanguageScope(child: ShootingstarApp(profile: profile)));
  await commerce.initialize();
  online.initialize();
}

const ink = ArcadeStyle.ink;
const panel = ArcadeStyle.panel;
// Retain the shared accent's public name for existing screens and save flows.
const cyan = ArcadeStyle.gold;
const muted = ArcadeStyle.muted;
const toonTextShadows = [
  Shadow(color: Color(0x66111722), offset: Offset(0, 1)),
];

class ShootingstarApp extends StatelessWidget {
  const ShootingstarApp({super.key, required this.profile});
  final Profile profile;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: AppLanguage.instance.locale,
      supportedLocales: const [Locale('ko'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      onGenerateTitle: (_) => tr('수호묘 특공대'),
      navigatorObservers: [AudioNavigationObserver()],
      builder: (context, child) => AnimatedBuilder(
        animation: profile,
        builder: (_, _) => GameAudioHost(
          profile: profile.developerSession ?? profile,
          child: PortraitViewport(
            child: ToonBackdrop(child: child ?? const SizedBox()),
          ),
        ),
      ),
      title: '수호묘 특공대',
      theme: ThemeData(
        visualDensity: VisualDensity.standard,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: const ColorScheme.dark(
          primary: cyan,
          onPrimary: ArcadeStyle.outline,
          secondary: Color(0xFF73D8FF),
          surface: panel,
          onSurface: Color(0xFFF8FAFF),
          outline: Color(0xFF92A3BC),
        ),
        fontFamily: 'NotoSansKR',
        iconTheme: const IconThemeData(size: 28, color: Colors.white),
        // v12.9: input fields are framed game slots, not bare underlines
        inputDecorationTheme: InputDecorationTheme(
          floatingLabelAlignment: FloatingLabelAlignment.center,
          filled: true,
          fillColor: const Color(0xFF0C1A33),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF7FA6D6), width: 2.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF7FA6D6), width: 2.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFFFC928), width: 3),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFFF6B5E), width: 3),
          ),
          labelStyle: const TextStyle(
            color: Color(0xFFDCE6F2),
            fontWeight: FontWeight.w800,
          ),
          floatingLabelStyle: const TextStyle(
            color: Color(0xFFFFD43D),
            fontWeight: FontWeight.w900,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        actionIconTheme: ActionIconThemeData(
          backButtonIconBuilder: (_) => const RasterIcon(Icons.arrow_back),
          closeButtonIconBuilder: (_) => const RasterIcon(Icons.close),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: ink,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'NotoSansKR',
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        // v12.9: toasts are small gold-rimmed game plates
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF14284A),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFFFC928), width: 3),
          ),
          contentTextStyle: const TextStyle(
            fontFamily: 'NotoSansKR',
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        // v12.9: menus read as game panels (navy, gold rim), not system lists
        popupMenuTheme: PopupMenuThemeData(
          color: const Color(0xFF14284A),
          surfaceTintColor: Colors.transparent,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFFFC928), width: 3),
          ),
          textStyle: const TextStyle(
            fontFamily: 'NotoSansKR',
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF263447),
          indicatorColor: Color(0xFF566786),
          surfaceTintColor: Colors.transparent,
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
          titleLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
          titleMedium: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
          bodyLarge: TextStyle(
            color: Colors.white,
            height: 1.4,
            shadows: toonTextShadows,
          ),
          bodyMedium: TextStyle(
            color: Colors.white,
            fontSize: GameUi.body,
            height: 1.4,
            shadows: toonTextShadows,
          ),
          bodySmall: TextStyle(
            fontSize: GameUi.caption,
            color: muted,
            height: 1.4,
            shadows: toonTextShadows,
          ),
          labelLarge: TextStyle(fontWeight: FontWeight.w800),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style:
              FilledButton.styleFrom(
                foregroundColor: ArcadeStyle.outline,
                backgroundColor: cyan,
                disabledForegroundColor: const Color(0xFFBAC5D4),
                disabledBackgroundColor: const Color(0xFF4D5A70),
                minimumSize: const Size(48, GameUi.buttonHeight),
                elevation: 3,
                shadowColor: ArcadeStyle.outline,
                surfaceTintColor: Colors.transparent,
                side: const BorderSide(color: ArcadeStyle.outline, width: 2.5),
                textStyle: const TextStyle(
                  fontFamily: 'NotoSansKR',
                  fontWeight: FontWeight.w800,
                  fontSize: GameUi.buttonLabel,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ).copyWith(
                elevation: WidgetStateProperty.resolveWith(
                  (states) =>
                      states.contains(WidgetState.pressed) ||
                          states.contains(WidgetState.disabled)
                      ? 0
                      : 3,
                ),
                backgroundBuilder: (context, states, child) =>
                    _generatedButton(states, child, 2),
              ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style:
              OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF526783),
                disabledForegroundColor: const Color(0xFFABB7C9),
                disabledBackgroundColor: const Color(0xFF3C4B61),
                minimumSize: const Size(48, GameUi.buttonHeight),
                textStyle: const TextStyle(
                  fontFamily: 'NotoSansKR',
                  fontSize: GameUi.buttonLabel,
                  fontWeight: FontWeight.w800,
                ),
                side: const BorderSide(color: ArcadeStyle.outline, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ).copyWith(
                side: WidgetStateProperty.resolveWith(
                  (states) => BorderSide(
                    color: states.contains(WidgetState.focused)
                        ? cyan
                        : ArcadeStyle.outline,
                    width: 2,
                  ),
                ),
                backgroundBuilder: (context, states, child) =>
                    _generatedButton(states, child, 3),
              ),
        ),
        sliderTheme: SliderThemeData(
          trackHeight: 8,
          thumbShape: const RasterSliderThumb(),
          trackShape: const RasterSliderTrack(),
          overlayShape: SliderComponentShape.noOverlay,
          showValueIndicator: ShowValueIndicator.onDrag,
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: Colors.white,
            disabledForegroundColor: const Color(0xFF8D9BB0),
          ),
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFF6A7C97)),
        chipTheme: ChipThemeData(
          backgroundColor: panel,
          selectedColor: cyan,
          side: const BorderSide(color: ArcadeStyle.outline, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          labelStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
          secondaryLabelStyle: const TextStyle(
            color: ArcadeStyle.outline,
            fontWeight: FontWeight.w900,
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: panel,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: const TextStyle(
            fontFamily: 'NotoSansKR',
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      home: DeveloperSessionHost(profile: profile),
    );
  }
}

Widget _generatedButton(Set<WidgetState> states, Widget? child, int skin) =>
    Opacity(
      opacity: states.contains(WidgetState.disabled) ? .58 : 1,
      child: RasterPanel(
        skin: states.contains(WidgetState.disabled) ? 4 : skin,
        child: child ?? const SizedBox(),
      ),
    );
