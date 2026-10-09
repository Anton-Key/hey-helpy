import 'package:flutter/material.dart';

import '../../core/design/design.dart';
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
    final l = context.l10n;
    final errorText = _offline
        ? l.onboardingNoConnection
        : (_error == null ? null : onboardingErrorText(l, _error!));

    return AppScaffold(
      title: l.onboardingTitle,
      slivers: [
        SliverContent(
          maxWidth: 520,
          sliver: SliverList.list(children: [
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpace.xs),
              child: Text(l.onboardingChoose(l.appName),
                  style: AppText.callout.copyWith(color: AppColors.secondary)),
            ),
            _Section(
              icon: AppIcons.building,
              title: l.onboardingCreateTitle,
              subtitle: l.onboardingCreateSubtitle,
              field: TextField(
                controller: _companyCtrl,
                enabled: !_busy,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(labelText: l.onboardingCompanyName),
              ),
              actionLabel: l.onboardingCreate,
              primary: true,
              onAction: _busy
                  ? null
                  : () => _run(() => _repo.createCompany(_companyCtrl.text)),
            ),
            _Section(
              icon: AppIcons.wrench,
              title: l.onboardingInviteTitle,
              subtitle: l.onboardingInviteSubtitle,
              field: TextField(
                controller: _inviteCtrl,
                enabled: !_busy,
                autocorrect: false,
                decoration: InputDecoration(labelText: l.onboardingInviteCode),
              ),
              actionLabel: l.onboardingJoin,
              primary: false,
              onAction: _busy
                  ? null
                  : () => _run(() => _repo.acceptInvite(_inviteCtrl.text)),
            ),
            if (_busy) ...[
              const SizedBox(height: AppSpace.xl),
              const AppLoader(),
            ],
            if (errorText != null) ...[
              const SizedBox(height: AppSpace.l),
              Text(errorText,
                  style: AppText.callout.copyWith(color: AppColors.danger),
                  textAlign: TextAlign.center),
            ],
          ]),
        ),
      ],
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
    required this.primary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget field;
  final String actionLabel;
  final VoidCallback? onAction;

  /// Главный путь — акцентная кнопка, второй — тонированная.
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpace.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title),
          AppGroup(
            margin: EdgeInsets.zero,
            children: [
              AppRow(
                leading: LeadingIcon(icon),
                title: title,
                subtitle: subtitle,
                subtitleMaxLines: 4,
              ),
              field,
            ],
          ),
          const SizedBox(height: AppSpace.m),
          AppButton(
            label: actionLabel,
            kind: primary ? AppButtonKind.primary : AppButtonKind.tinted,
            onPressed: onAction,
          ),
          const SizedBox(height: AppSpace.s),
        ],
      ),
    );
  }
}
