import 'package:flutter/material.dart';

import 'onboarding_repository.dart';

/// Экран для пользователя без компании (profiles.company_id == null).
///
/// Два пути: создать свою компанию (станет админом) или вступить
/// по коду приглашения от подрядчика (станет исполнителем).
/// [onCompleted] вызывается после успеха — в нём нужно перезагрузить
/// профиль и перейти на главный экран.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onCompleted,
    this.repository,
  });

  final Future<void> Function() onCompleted;
  final OnboardingRepository? repository;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final OnboardingRepository _repo =
      widget.repository ?? OnboardingRepository();

  final _companyCtrl = TextEditingController();
  final _inviteCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _companyCtrl.dispose();
    _inviteCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await widget.onCompleted();
    } on OnboardingException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Нет связи с сервером. Попробуйте ещё раз.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Начало работы')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Выберите, как вы будете работать в Hey Helpy',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 20),
                _Section(
                  icon: Icons.apartment_outlined,
                  title: 'Создать компанию',
                  subtitle: 'Для владельцев и управляющих объектами. '
                      'Вы станете администратором.',
                  field: TextField(
                    controller: _companyCtrl,
                    enabled: !_busy,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Название компании',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  actionLabel: 'Создать',
                  onAction: _busy
                      ? null
                      : () => _run(() => _repo.createCompany(_companyCtrl.text)),
                ),
                const SizedBox(height: 16),
                _Section(
                  icon: Icons.handyman_outlined,
                  title: 'У меня есть код приглашения',
                  subtitle: 'Для исполнителей подрядных организаций.',
                  field: TextField(
                    controller: _inviteCtrl,
                    enabled: !_busy,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Код приглашения',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  actionLabel: 'Вступить',
                  onAction: _busy
                      ? null
                      : () => _run(() => _repo.acceptInvite(_inviteCtrl.text)),
                ),
                if (_busy) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!,
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.field,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget field;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            ]),
            const SizedBox(height: 6),
            Text(subtitle, style: theme.textTheme.bodySmall),
            const SizedBox(height: 14),
            field,
            const SizedBox(height: 12),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
