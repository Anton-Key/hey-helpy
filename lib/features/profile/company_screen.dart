import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_links.dart';
import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../l10n/app_localizations.dart';
import '../../models/profile.dart';
import '../../models/user_role.dart';
import '../directory/directory.dart';
import '../onboarding/onboarding_repository.dart';
import '../onboarding/onboarding_screen.dart';
import 'profile_repository.dart';

const _muted = Color(0xFF8A9098);
const _danger = Color(0xFFC24444);

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

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  // ---------------------------------------------------------------------
  // Название компании
  // ---------------------------------------------------------------------
  Future<void> _rename() async {
    final l = context.l10n;
    final ctrl = TextEditingController(text: _name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.companyRenameTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 200,
          decoration: InputDecoration(labelText: l.onboardingCompanyName),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l.commonCancel)),
          FilledButton(
              style: brandButtonStyle(),
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(l.commonSave)),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty || name == _name) return;
    try {
      final ok = await _repo.renameCompany(_me.companyId!, name);
      if (!ok) {
        _toast(l.companyRenameUnavailable);
        return;
      }
      _toast(l.companyRenamed);
      await _load();
    } catch (e) {
      debugPrint('Company rename: $e');
      _toast(l.companyRenameUnavailable);
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
    final chosen = await showModalBottomSheet<UserRole>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 4),
            child: Text(l.companyRoleTitle(_memberName(l, m)),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          for (final r in roles)
            ListTile(
              title: Text(l.role(r)),
              trailing: r == m.role
                  ? const Icon(Icons.check_rounded, color: HeyHelpyTheme.link)
                  : null,
              onTap: () => Navigator.pop(ctx, r),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 16),
            child: Text(l.companyRoleExecutorHint,
                style: const TextStyle(color: _muted, fontSize: 12)),
          ),
        ]),
      ),
    );
    if (chosen == null || chosen == m.role) return;
    try {
      await _onb.setMemberRole(m.id, chosen.name);
      _toast(l.companyRoleChanged);
      await _load();
    } on OnboardingException catch (e) {
      _toast(onboardingErrorText(l, e.error));
    } catch (e) {
      debugPrint('Role: $e');
      _toast(l.errorGeneric);
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(l.inviteTitle),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: contractorId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.inviteContractor),
                  items: [
                    for (final c in _contractors)
                      DropdownMenuItem(value: c.id, child: Text(c.orgName)),
                  ],
                  onChanged: (v) => set(() => contractorId = v ?? contractorId),
                ),
                const SizedBox(height: 14),
                Text(l.inviteRoleInfo,
                    style: const TextStyle(color: _muted, fontSize: 13)),
                const SizedBox(height: 14),
                Text(l.inviteValidity,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (final d in _inviteDays)
                    ChoiceTag(
                        label: l.inviteDays(d),
                        selected: d == days,
                        onTap: () => set(() => days = d)),
                ]),
              ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.commonCancel)),
            FilledButton(
                style: brandButtonStyle(),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.inviteCreate)),
          ],
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
      _toast(l.inviteFailed);
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
    _toast(done);
  }

  /// Готовое приглашение: код, ссылка, «скопировать», «отозвать».
  Future<void> _showInvite(Invite i) async {
    final l = context.l10n;
    final revoke = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 16),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.inviteReadyTitle(_contractorName(i.contractorId)),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                    l.inviteValidUntil(
                        i.expiresAt == null ? '—' : l.dateTime(i.expiresAt!)),
                    style: const TextStyle(color: _muted, fontSize: 13)),
                const SizedBox(height: 14),
                Text(l.inviteCodeLabel,
                    style: const TextStyle(color: _muted, fontSize: 12)),
                SelectableText(i.token,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace')),
                const SizedBox(height: 10),
                Text(l.inviteLinkLabel,
                    style: const TextStyle(color: _muted, fontSize: 12)),
                SelectableText(inviteLink(i.token),
                    style: const TextStyle(
                        color: HeyHelpyTheme.link, fontSize: 13)),
                const SizedBox(height: 10),
                Text(l.inviteHowTo,
                    style: const TextStyle(color: _muted, fontSize: 12)),
                const SizedBox(height: 16),
                FilledButton.icon(
                    style: brandButtonStyle(),
                    onPressed: () => _copy(_inviteText(l, i), l.inviteCopied),
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(l.inviteCopyMessage)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                    onPressed: () => _copy(i.token, l.inviteCodeCopied),
                    icon: const Icon(Icons.key_outlined),
                    label: Text(l.inviteCopyCode)),
                if (i.id.isNotEmpty)
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l.inviteRevoke,
                          style: const TextStyle(color: _danger))),
              ]),
        ),
      ),
    );
    if (revoke != true) return;
    try {
      await _repo.revokeInvite(i.id);
      _toast(l.inviteRevoked);
      await _load();
    } catch (e) {
      debugPrint('Invite revoke: $e');
      _toast(l.errorGeneric);
    }
  }

  String _memberName(AppLocalizations l, Member m) =>
      (m.fullName == null || m.fullName!.isEmpty)
          ? l.profileDefaultName
          : m.fullName!;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          title: Text(l.profileMyCompany), backgroundColor: Colors.white),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 40),
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_failed)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  Text(l.companyLoadFailed,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _danger)),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: Text(l.commonRetry)),
                ]),
              )
            else ...[
              _companyCard(l),
              SectionTitle(l.companyMembers(_members.length)),
              for (final m in _members) _memberTile(l, m),
              if (_canManage) ...[
                SectionTitle(l.companyInvites,
                    trailing: FilledButton.icon(
                        style: brandButtonStyle(),
                        onPressed: _loading ? null : _createInvite,
                        icon: const Icon(Icons.person_add_alt_1, size: 18),
                        label: Text(l.companyInvite))),
                if (_invites.isEmpty)
                  Text(l.companyNoInvites,
                      style: const TextStyle(color: _muted, fontSize: 13))
                else
                  for (final i in _invites)
                    TapCard(
                      onTap: () => _showInvite(i),
                      chevron: false,
                      child: Row(children: [
                        const Icon(Icons.link, color: _muted, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              l.companyInviteRow(
                                  _contractorName(i.contractorId),
                                  i.expiresAt == null
                                      ? '—'
                                      : l.dateTime(i.expiresAt!)),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        const Icon(Icons.copy_rounded, color: _muted, size: 18),
                      ]),
                    ),
              ],
              SectionTitle(l.companyDirectory),
              TapCard(
                onTap: () => Navigator.pop(context, companyTabContractors),
                child: _iconText(Icons.handshake_outlined, l.tabContractors),
              ),
              TapCard(
                onTap: () => Navigator.pop(context, companyTabObjects),
                child: _iconText(Icons.apartment_outlined, l.tabLocations),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _iconText(IconData icon, String text) => Row(children: [
        Icon(icon, size: 20, color: HeyHelpyTheme.ink),
        const SizedBox(width: 12),
        Expanded(
            child: Text(text,
                style: const TextStyle(fontWeight: FontWeight.w600))),
      ]);

  Widget _companyCard(AppLocalizations l) => TapCard(
        onTap: _canManage && !_loading ? _rename : null,
        chevron: false,
        child: Row(children: [
          const Icon(Icons.apartment, color: HeyHelpyTheme.link),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.companyNameLabel,
                  style: const TextStyle(color: _muted, fontSize: 12)),
              Text(_name ?? '…',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
          ),
          if (_canManage)
            Icon(Icons.edit_outlined,
                color: HeyHelpyTheme.link,
                size: 20,
                semanticLabel: l.companyRenameTitle),
        ]),
      );

  Widget _memberTile(AppLocalizations l, Member m) {
    final canChange = _canChangeRole(m);
    final phone =
        (m.phone == null || m.phone!.isEmpty) ? l.companyNoPhone : m.phone!;
    return TapCard(
      onTap: canChange ? () => _changeRole(m) : null,
      chevron: false,
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: HeyHelpyTheme.mint,
          child: Text(_memberName(l, m).characters.first.toUpperCase(),
              style: const TextStyle(
                  color: HeyHelpyTheme.onBrand, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                m.id == _me.id
                    ? l.companyMemberYou(_memberName(l, m))
                    : _memberName(l, m),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            SelectableText(phone,
                style: const TextStyle(color: _muted, fontSize: 13)),
          ]),
        ),
        const SizedBox(width: 8),
        Text(l.role(m.role),
            style: TextStyle(
                color: canChange ? HeyHelpyTheme.link : _muted,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
        if (canChange) ...[
          const SizedBox(width: 4),
          Icon(Icons.edit_outlined,
              color: HeyHelpyTheme.link,
              size: 16,
              semanticLabel: l.companyRoleChange),
        ],
      ]),
    );
  }
}
