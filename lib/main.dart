import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/app_config.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/deal_provider.dart';
import 'core/providers/location_provider.dart';
import 'core/providers/reservation_provider.dart';
import 'core/providers/wishlist_provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/profile_provider.dart';
import 'core/services/device_id.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );

  await DeviceId.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => DealProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => ReservationProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const TownFlashDealApp(),
    ),
  );
}

class TownFlashDealApp extends StatelessWidget {
  const TownFlashDealApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: '우리 동네 타임딜',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.mode,
      home: const SplashScreen(),
      // [Claude | 2026-11-04] 컴퓨터처럼 넓은 화면에서는 가운데에 폰 크기 화면만 보여 줍니다(전시용).
      builder: (context, child) => _PhoneFrame(child: child ?? const SizedBox()),
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});
  final Widget child;

  static const double _phoneWidth = 430;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= 600) return child;
    final height = media.size.height > 960 ? 932.0 : media.size.height;
    return ColoredBox(
      color: const Color(0xFF2B2B2B),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(media.size.height > 960 ? 28 : 0),
          child: SizedBox(
            width: _phoneWidth,
            height: height,
            child: MediaQuery(
              data: media.copyWith(size: Size(_phoneWidth, height)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
