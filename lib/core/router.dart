import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/floors/floor_plan_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import 'session_controller.dart';
import 'splash_screen.dart';

/// Служебные экраны, с которых готового пользователя уводим на главный.
const _gateRoutes = {'/splash', '/login', '/onboarding'};

/// Создаёт роутер. Вызывать один раз за жизнь приложения.
GoRouter createRouter(SessionController session) {
  // Ссылка, по которой открыли приложение (план этажа), — запоминается на
  // время заставки и входа и открывается, когда пользователь готов.
  String? pending;
  return GoRouter(
    initialLocation: '/',
    refreshListenable: session,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final deepLink = !_gateRoutes.contains(loc) && loc != '/';

      switch (session.status) {
        case SessionStatus.loading:
        case SessionStatus.error:
          if (deepLink) pending = state.uri.toString();
          return loc == '/splash' ? null : '/splash';
        case SessionStatus.signedOut:
          if (deepLink) pending = state.uri.toString();
          return loc == '/login' ? null : '/login';
        case SessionStatus.needsOnboarding:
          return loc == '/onboarding' ? null : '/onboarding';
        case SessionStatus.ready:
          if (_gateRoutes.contains(loc)) {
            final to = pending ?? '/';
            pending = null;
            return to;
          }
          return null;
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
      // План этажа (шаг 14b): ссылкой можно поделиться.
      GoRoute(
        path: '/objects/:objectId/floors/:floorId',
        builder: (_, state) => FloorPlanScreen(
          objectId: state.pathParameters['objectId']!,
          floorId: state.pathParameters['floorId']!,
          focus: state.uri.queryParameters['focus'],
          startEditing: state.uri.queryParameters['edit'] == '1',
        ),
      ),
    ],
  );
}
