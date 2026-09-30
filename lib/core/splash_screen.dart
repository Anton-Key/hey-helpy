import 'package:flutter/material.dart';

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
                    const Text(
                      'Не удалось загрузить профиль.\nПроверьте подключение к интернету.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: session.reloadProfile,
                      child: const Text('Повторить'),
                    ),
                    TextButton(
                      onPressed: session.signOut,
                      child: const Text('Выйти из аккаунта'),
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
