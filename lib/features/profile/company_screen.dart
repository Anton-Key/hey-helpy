import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_links.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';
import '../../models/profile.dart';
import '../../models/user_role.dart';
import '../directory/directory.dart';
import '../onboarding/onboarding_repository.dart';
import '../onboarding/onboarding_screen.dart';
import 'profile_repository.dart';
import '../../core/app_message.dart';

/// Сроки приглашения на выбор (дней). Больше 7 не даём: так решено в 0008.
const _inviteDays = [1, 3, 7];

/// Вкладки главного экрана, на которые ведут кнопки «Подрядчики» и «Объекты».
const companyTabContractors = 1;
const companyTabObjects = 2;

/// Профиль → «Моя компания»: название, сотрудники, приглашения, справочники.
/// Возвращает номер вкладки главного экрана, если нажали «Подрядчики» или «Объекты».
class MyCompanyScreen extends StatefulWidget {
  const MyCompanyScreen({super.key, required this.me});
  final Profile me;

  @override
  State<MyCompanyScreen> createState() => _MyCompanyScreenState();
}

class _MyCompanyScreenState extends State<MyCompanyScreen> {
  final _repo = ProfileRepository();
  final _onb = OnboardingRepository();
  final _dir = DirectoryRepo();

  String? _name;
  List<Member> _members = const [];
  List<Invite> _invites = const [];
  List<Contractor> _contractors = const [];
  bool _loading = true;
  bool _failed = false;

  Profile get _me => widget.me;
  bool get _canManage => _me.role.canManage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final companyId = _me.companyId;
    if (companyId == null) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final r = await Future.wait<Object?>([
        _repo.companyName(companyId),
        _repo.members(companyId),
        _canManage ? _repo.invites() : Future.value(const <Invite>[]),
        _canManage ? _dir.contractors() : Future.value(const <Contractor>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _name = r[0] as String?;
        _members = r[1] as List<Member>;
        _invites = (r[2] as List<Invite>).where((i) => i.active).toList();
        _contractors = r[3] as List<Contractor>;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Company: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  void _toast(String text, {AppMessageType type = AppMessageType.info}) =>
      showAppMessage(context, text, type: type);

  // ---------------------------------------------------------------------
  // Название компании
  // ---------------------------------------------------------------------
  Future<void> _rename() async {
    final l = context.l10n;
    final ctrl = TextEditingController(text: _name ?? '');
    final save = await showAppDialog<bool>(
      context: context,
      title: l.companyRenameTitle,
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: 200,
        decoration: InputDecoration(
            labelText: l.onboardingCompanyName, fillColor: AppColors.fill),
      ),
      actions: [
        AppDialogAction(l.commonSave, true, primary: true),
        AppDialogAction(l.commonCancel, false),
      ],
    );
    final name = save == true ? ctrl.text.trim() : null;
    ctrl.dispose();
    if (name == null || name.isEmpty || name == _name) return;
    try {
      final ok = await _repo.renameCompany(_me.companyId!, name);
      if (!ok) {
        _toast(l.companyRenameUnavailable, type: AppMessageType.error);
        return;
      }
      _toast(l.companyRenamed, type: AppMessageType.success);
      await _load();
    } catch (e) {
      debugPrint('Company rename: $e');
      _toast(l.companyRenameUnavailable, type: AppMessageType.error);
    }
  }

  // ---------------------------------------------------------------------
  // Роли сотрудников (RPC set_member_role)
  // ---------------------------------------------------------------------
  bool _canChangeRole(Member m) =>
      _canManage &&
      m.id != _me.id &&
      (_me.role == UserRole.admin || m.role != UserRole.admin);

  Future<void> _changeRole(Member m) async {
    final l = context.l10n;
    final roles = [
      if (_me.role == UserRole.admin) UserRole.admin,
      UserRole.manager,
      UserRole.requester,
      UserRole.executor,
    ];
    final chosen = await showAppSheet<UserRole>(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SheetHeader(title: l.companyRoleTitle(_memberName(l, m))),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.l),
            child: AppGroup(
              margin: EdgeInsets.zero,
              footer: l.companyRoleExecutorHint,
              children: [
                for (final r in roles)
                  AppRow(
                    title: l.role(r),
                    chevron: false,
                    trailing: r == m.role
                        ? const Icon(AppIcons.check,
                            size: AppSizes.icon, color: AppColors.accentText)
                        : null,
                    onTap: () => Navigator.pop(ctx, r),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
    if (chosen == null || chosen == m.role) return;
    try {
      await _onb.setMemberRole(m.id, chosen.name);
      _toast(l.companyRoleChanged, type: AppMessageType.success);
      await _load();
    } on OnboardingException catch (e) {
      _toast(onboardingErrorText(l, e.error), type: AppMessageType.error);
    } catch (e) {
      debugPrint('Role: $e');
      _toast(l.errorGeneric, type: AppMessageType.error);
    }
  }

  // ---------------------------------------------------------------------
  // Приглашения (таблица invites; вступление — RPC accept_invite)
  // ---------------------------------------------------------------------
  Future<void> _createInvite() async {
    final l = context.l10n;
    if (_contractors.isEmpty) {
      _toast(l.inviteNoContractors);
      return;
    }
    var contractorId = _contractors.first.id;
    var days = _inviteDays.last;
    final ok = await showAppSheet<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SheetHeader(
                title: l.inviteTitle,
                doneLabel: l.inviteCreate,
                onDone: () => Navigator.pop(ctx, true)),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpace.screen, 0, AppSpace.screen, AppSpace.l),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppGroup(
                        header: l.inviteContractor,
                        footer: l.inviteRoleInfo,
                        children: [
                          for (final c in _contractors)
                            AppRow(
                              leading: InitialsTile(c.orgName),
                              title: c.orgName,
                              chevron: false,
                              trailing: c.id == contractorId
                                  ? const Icon(AppIcons.check,
                                      size: AppSizes.icon,
                                      color: AppColors.accentText)
                                  : null,
                              onTap: () => set(() => contractorId = c.id),
                            ),
                        ],
                      ),
                      SectionHeader(l.inviteValidity),
                      Wrap(
                          spacing: AppSpace.s,
                          runSpacing: AppSpace.s,
                          children: [
                            for (final d in _inviteDays)
                              AppChip(
                                  label: l.inviteDays(d),
                                  selected: d == days,
                                  onTap: () => set(() => days = d)),
                          ]),
                      const SizedBox(height: AppSpace.xl),
                      AppButton.primary(
                          label: l.inviteCreate,
                          icon: AppIcons.userAdd,
                          onPressed: () => Navigator.pop(ctx, true)),
                    ]),
              ),
            ),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    try {
      final token =
          await _onb.createInvite(contractorId, validFor: Duration(days: days));
      await _load();
      final invite = _invites.where((i) => i.token == token).firstOrNull ??
          Invite(
              id: '',
              token: token,
              contractorId: contractorId,
              expiresAt: DateTime.now().add(Duration(days: days)));
      if (mounted) await _showInvite(invite);
    } catch (e) {
      debugPrint('Invite: $e');
      _toast(l.inviteFailed, type: AppMessageType.error);
    }
  }

  String _contractorName(String id) =>
      _contractors.where((c) => c.id == id).firstOrNull?.orgName ?? '—';

  String _inviteText(AppLocalizations l, Invite i) => l.inviteMessage(
      l.appName,
      _contractorName(i.contractorId),
      inviteLink(i.token),
      i.token,
      i.expiresAt == null ? '—' : l.dateTime(i.expiresAt!));

  Future<void> _copy(String text, String done) async {
    await Clipboard.setData(ClipboardData(text: text));
    _toast(done, type: AppMessageType.success);
  }

  /// Готовое приглашение: код, ссылка, «скопировать», «отозвать».
  Future<void> _showInvite(Invite i) async {
    final l = context.l10n;
    final revoke = await showAppSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SheetHeader(title: l.inviteTitle),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.l),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l.inviteReadyTitle(_contractorName(i.contractorId)),
                        style: AppText.title2),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                        l.inviteValidUntil(i.expiresAt == null
                            ? '—'
                            : l.dateTime(i.expiresAt!)),
                        style: AppText.footnote),
                    const SizedBox(height: AppSpace.l),
                    AppGroup(footer: l.inviteHowTo, children: [
                      _selectable(l.inviteCodeLabel, i.token, AppText.headline),
                      _selectable(
                          l.inviteLinkLabel,
                          inviteLink(i.token),
                          AppText.footnote
                              .copyWith(color: AppColors.accentText)),
                    ]),
                    const SizedBox(height: AppSpace.s),
                    AppButton.primary(
                        icon: AppIcons.copy,
                        label: l.inviteCopyMessage,
                        onPressed: () =>
                            _copy(_inviteText(l, i), l.inviteCopied)),
                    const SizedBox(height: AppSpace.s),
                    AppButton.secondary(
                        icon: AppIcons.key,
                        label: l.inviteCopyCode,
                        onPressed: () => _copy(i.token, l.inviteCodeCopied)),
                    if (i.id.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.s),
                      AppButton.destructive(
                          label: l.inviteRevoke,
                          onPressed: () => Navigator.pop(ctx, true)),
                    ],
                  ]),
            ),
          ),
        ]),
      ),
    );
    if (revoke != true) return;
    try {
      await _repo.revokeInvite(i.id);
      _toast(l.inviteRevoked, type: AppMessageType.success);
      await _load();
    } catch (e) {
      debugPrint('Invite revoke: $e');
      _toast(l.errorGeneric, type: AppMessageType.error);
    }
  }

  String _memberName(AppLocalizations l, Member m) =>
      (m.fullName == null || m.fullName!.isEmpty)
          ? l.profileDefaultName
          : m.fullName!;

  /// Строка группы с подписью и выделяемым текстом (код, ссылка).
  Widget _selectable(String label, String text, TextStyle style) => Padding(
        padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpace.rowH, vertical: AppSpace.rowV),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppText.caption),
          const SizedBox(height: AppSpace.xxs),
          SelectableText(text, style: style),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppScaffold(
      title: l.profileMyCompany,
      onRefresh: _load,
      slivers: [
        SliverContent(
          sliver: SliverList.list(children: [
            if (_loading && _name == null)
              const Padding(
                padding: EdgeInsetsDirectional.only(top: AppSpace.xxl),
                child: AppLoader(),
              )
            else if (_failed)
              AppEmptyState(
                  text: l.companyLoadFailed,
                  error: true,
                  actionLabel: l.commonRetry,
                  onAction: _load)
            else ...[
              _companyGroup(l),
              AppGroup(
                header: l.companyMembers(_members.length),
                children: [for (final m in _members) _memberRow(l, m)],
              ),
              if (_canManage)
                AppGroup(
                  header: l.companyInvites,
                  headerTrailing: AppButton.tinted(
                      small: true,
                      expand: false,
                      icon: AppIcons.userAdd,
                      label: l.companyInvite,
                      onPressed: _loading ? null : _createInvite),
                  footer: _invites.isEmpty ? l.companyNoInvites : null,
                  children: [
                    for (final i in _invites)
                      AppRow(
                        leading: const LeadingIcon(AppIcons.link),
                        title: l.companyInviteRow(
                            _contractorName(i.contractorId),
                            i.expiresAt == null
                                ? '—'
                                : l.dateTime(i.expiresAt!)),
                        trailing: const Icon(AppIcons.copy,
                            size: AppSizes.iconS, color: AppColors.tertiary),
                        chevron: false,
                        onTap: () => _showInvite(i),
                      ),
                  ],
                ),
              AppGroup(header: l.companyDirectory, children: [
                AppRow(
                  leading: const LeadingIcon(AppIcons.contractor),
                  title: l.tabContractors,
                  onTap: () => Navigator.pop(context, companyTabContractors),
                ),
                AppRow(
                  leading: const LeadingIcon(AppIcons.building),
                  title: l.tabLocations,
                  onTap: () => Navigator.pop(context, companyTabObjects),
                ),
              ]),
            ],
          ]),
        ),
      ],
    );
  }

  Widget _companyGroup(AppLocalizations l) => AppGroup(children: [
        AppRow(
          leading: const LeadingIcon(AppIcons.building),
          title: _name ?? '…',
          titleStyle: AppText.headline,
          subtitle: l.companyNameLabel,
          chevron: false,
          trailing: _canManage
              ? Icon(AppIcons.edit,
                  size: AppSizes.iconS,
                  color: AppColors.accentText,
                  semanticLabel: l.companyRenameTitle)
              : null,
          onTap: _canManage && !_loading ? _rename : null,
        ),
      ]);

  Widget _memberRow(AppLocalizations l, Member m) {
    final canChange = _canChangeRole(m);
    final phone =
        (m.phone == null || m.phone!.isEmpty) ? l.companyNoPhone : m.phone!;
    return AppRow(
      leading: InitialsTile(_memberName(l, m)),
      title: m.id == _me.id
          ? l.companyMemberYou(_memberName(l, m))
          : _memberName(l, m),
      subtitle: phone,
      chevron: canChange,
      trailing: Text(l.role(m.role),
          semanticsLabel:
              canChange ? '${l.role(m.role)}, ${l.companyRoleChange}' : null,
          style: AppText.footnote.copyWith(
              color: canChange ? AppColors.accentText : AppColors.secondary,
              fontWeight: FontWeight.w600)),
      onTap: canChange ? () => _changeRole(m) : null,
    );
  }
}
