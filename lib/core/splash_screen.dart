import 'package:flutter/material.dart';

import 'l10n_ext.dart';
import 'session_controller.dart';

/// Показывается, пока проверяется сессия и загружается профиль.
/// При ошибке загрузки даёт повторить попытку или выйти из аккаунта.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ListenableBuilder(
            listenable: session,
            builder: (context, _) {
              if (session.status != SessionStatus.error) {
                return const CircularProgressIndicator();
              }
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.splashLoadFailed,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: session.reloadProfile,
                      child: Text(context.l10n.commonRetry),
                    ),
                    TextButton(
                      onPressed: session.signOut,
                      child: Text(context.l10n.splashSignOut),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
