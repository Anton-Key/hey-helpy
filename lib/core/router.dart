import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import 'session_controller.dart';
import 'splash_screen.dart';

/// Служебные экраны, с которых готового пользователя уводим на главный.
const _gateRoutes = {'/splash', '/login', '/onboarding'};

/// Создаёт роутер. Вызывать один раз за жизнь приложения.
GoRouter createRouter(SessionController session) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: session,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      switch (session.status) {
        case SessionStatus.loading:
        case SessionStatus.error:
          return loc == '/splash' ? null : '/splash';
        case SessionStatus.signedOut:
          return loc == '/login' ? null : '/login';
        case SessionStatus.needsOnboarding:
          return loc == '/onboarding' ? null : '/onboarding';
        case SessionStatus.ready:
          return _gateRoutes.contains(loc) ? '/' : null;
      }
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => SplashScreen(session: session),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => OnboardingScreen(onCompleted: session.reloadProfile),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const HomeScreen(),
      ),
    ],
  );
}
