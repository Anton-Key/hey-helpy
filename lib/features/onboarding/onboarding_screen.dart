import 'package:flutter/material.dart';

import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';
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
  /// null — ошибки нет; иначе причина (текст подбирается при отрисовке).
  OnboardingError? _error;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    // Ссылка-приглашение из веб-версии: …/hey-helpy/?invite=<код>.
    final code = Uri.base.queryParameters['invite']?.trim();
    if (code != null && code.isNotEmpty) _inviteCtrl.text = code;
  }

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
      _offline = false;
    });
    try {
      await action();
      await widget.onCompleted();
    } on OnboardingException catch (e) {
      if (mounted) setState(() => _error = e.error);
    } catch (_) {
      if (mounted) setState(() => _offline = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final errorText = _offline ? l.onboardingNoConnection : (_error == null ? null : onboardingErrorText(l, _error!));

    return Scaffold(
      appBar: AppBar(title: Text(l.onboardingTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(l.onboardingChoose(l.appName),
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 20),
                _Section(
                  icon: Icons.apartment_outlined,
                  title: l.onboardingCreateTitle,
                  subtitle: l.onboardingCreateSubtitle,
                  field: TextField(
                    controller: _companyCtrl,
                    enabled: !_busy,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: l.onboardingCompanyName,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  actionLabel: l.onboardingCreate,
                  onAction: _busy
                      ? null
                      : () => _run(() => _repo.createCompany(_companyCtrl.text)),
                ),
                const SizedBox(height: 16),
                _Section(
                  icon: Icons.handyman_outlined,
                  title: l.onboardingInviteTitle,
                  subtitle: l.onboardingInviteSubtitle,
                  field: TextField(
                    controller: _inviteCtrl,
                    enabled: !_busy,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l.onboardingInviteCode,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  actionLabel: l.onboardingJoin,
                  onAction: _busy
                      ? null
                      : () => _run(() => _repo.acceptInvite(_inviteCtrl.text)),
                ),
                if (_busy) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (errorText != null) ...[
                  const SizedBox(height: 16),
                  Text(errorText,
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

/// Понятный текст ошибки онбординга и управления участниками.
String onboardingErrorText(AppLocalizations l, OnboardingError e) =>
    switch (e) {
      OnboardingError.notAuthenticated => l.onbErrNotAuthenticated,
      OnboardingError.companyNameRequired => l.onbErrCompanyNameRequired,
      OnboardingError.alreadyInCompany => l.onbErrAlreadyInCompany,
      OnboardingError.inviteNotFound => l.onbErrInviteNotFound,
      OnboardingError.inviteUsed => l.onbErrInviteUsed,
      OnboardingError.inviteExpired => l.onbErrInviteExpired,
      OnboardingError.otherCompany => l.onbErrOtherCompany,
      OnboardingError.adminOnly => l.onbErrAdminOnly,
      OnboardingError.ownRole => l.onbErrOwnRole,
      OnboardingError.profileNotFound => l.onbErrProfileNotFound,
      OnboardingError.unknown => l.onbErrUnknown,
    };

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
