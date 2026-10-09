import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/design/design.dart';
import '../../core/language_picker.dart';
import '../../core/l10n_ext.dart';
import '../../models/profile.dart';
import 'profile_repository.dart';
import '../../core/app_message.dart';

/// Пароль Supabase Auth — не короче 6 символов (настройка проекта по умолчанию).
const _minPassword = 6;

/// Профиль → «Настройки»: имя и телефон, пароль, язык, версия и «О приложении».
/// Возвращает true, если имя или телефон изменились.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.me});
  final Profile me;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repo = ProfileRepository();
  late final _name = TextEditingController(text: widget.me.fullName ?? '');
  late final _phone = TextEditingController(text: widget.me.phone ?? '');
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _changed = false;
  String? _passError;
  late final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  void _toast(String text, {AppMessageType type = AppMessageType.info}) =>
      showAppMessage(context, text, type: type);

  Future<void> _saveProfile() async {
    final l = context.l10n;
    FocusScope.of(context).unfocus();
    setState(() => _savingProfile = true);
    try {
      await _repo.updateMe(fullName: _name.text, phone: _phone.text);
      _changed = true;
      _toast(l.settingsSaved, type: AppMessageType.success);
    } catch (e) {
      debugPrint('Settings profile: $e');
      _toast(l.settingsSaveFailed, type: AppMessageType.error);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _savePassword() async {
    final l = context.l10n;
    FocusScope.of(context).unfocus();
    final p = _pass.text;
    if (p.length < _minPassword) {
      setState(() => _passError = l.settingsPasswordShort(_minPassword));
      return;
    }
    if (p != _pass2.text) {
      setState(() => _passError = l.settingsPasswordMismatch);
      return;
    }
    setState(() {
      _passError = null;
      _savingPassword = true;
    });
    try {
      await _repo.changePassword(p);
      _pass.clear();
      _pass2.clear();
      _toast(l.settingsPasswordChanged, type: AppMessageType.success);
    } catch (e) {
      debugPrint('Settings password: $e');
      if (mounted) setState(() => _passError = l.settingsPasswordFailed);
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Future<void> _about() async {
    final l = context.l10n;
    final info = await _info;
    if (!mounted) return;
    await showAppDialog<void>(
      context: context,
      title: l.settingsAboutApp(l.appName),
      message: '${l.settingsVersion(info.version, info.buildNumber)}\n\n'
          '${l.settingsAboutText(l.appName)}',
      actions: [
        AppDialogAction(MaterialLocalizations.of(context).okButtonLabel, null,
            primary: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: AppScaffold(
        title: l.profileSettings,
        slivers: [
          SliverContent(
            sliver: SliverList.list(children: [
              AppGroup(header: l.settingsProfile, children: [
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: l.settingsName),
                ),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                      labelText: l.settingsPhone,
                      hintText: l.settingsPhoneHint),
                ),
              ]),
              AppButton.primary(
                  label: l.commonSave,
                  loading: _savingProfile,
                  onPressed: _saveProfile),
              const SizedBox(height: AppSpace.s),
              AppGroup(header: l.settingsPassword, children: [
                TextField(
                  controller: _pass,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(labelText: l.settingsNewPassword),
                ),
                TextField(
                  controller: _pass2,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText: l.settingsRepeatPassword,
                      errorText: _passError),
                ),
              ]),
              AppButton.tinted(
                  label: l.settingsChangePassword,
                  loading: _savingPassword,
                  onPressed: _savePassword),
              const SizedBox(height: AppSpace.s),
              AppGroup(header: l.profileLanguage, children: [
                AppRow(
                  leading: const LeadingIcon(AppIcons.language),
                  title: l.profileLanguage,
                  value: currentLanguageName(context),
                  onTap: () => pickLanguage(context),
                ),
              ]),
              AppGroup(header: l.settingsAbout, children: [
                AppRow(
                  leading: const LeadingIcon(AppIcons.info),
                  title: l.settingsAboutApp(l.appName),
                  chevron: false,
                  onTap: _about,
                ),
              ]),
              FutureBuilder<PackageInfo>(
                future: _info,
                builder: (_, s) => Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpace.rowH),
                  child: Text(
                      s.hasData
                          ? l.settingsVersion(
                              s.data!.version, s.data!.buildNumber)
                          : '…',
                      style: AppText.footnote),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
