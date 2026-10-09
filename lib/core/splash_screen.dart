import 'package:flutter/material.dart';

import 'design/design.dart';
import 'l10n_ext.dart';
import 'session_controller.dart';

/// Показывается, пока проверяется сессия и загружается профиль.
/// При ошибке загрузки даёт повторить попытку или выйти из аккаунта.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: ListenableBuilder(
            listenable: session,
            builder: (context, _) {
              if (session.status != SessionStatus.error) {
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(l.appName, style: AppText.title),
                  const SizedBox(height: AppSpace.xl),
                  const AppLoader(),
                ]);
              }
              return Padding(
                padding: const EdgeInsets.all(AppSpace.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(AppIcons.offline,
                          size: 44, color: AppColors.tertiary),
                      const SizedBox(height: AppSpace.l),
                      Text(
                        l.splashLoadFailed,
                        textAlign: TextAlign.center,
                        style: AppText.callout
                            .copyWith(color: AppColors.secondary),
                      ),
                      const SizedBox(height: AppSpace.xl),
                      AppButton.primary(
                        label: l.commonRetry,
                        onPressed: session.reloadProfile,
                      ),
                      const SizedBox(height: AppSpace.s),
                      AppButton.plain(
                        label: l.splashSignOut,
                        onPressed: session.signOut,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
