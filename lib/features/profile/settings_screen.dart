import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/language_picker.dart';
import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../models/profile.dart';
import 'profile_repository.dart';

const _muted = Color(0xFF8A9098);

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

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _saveProfile() async {
    final l = context.l10n;
    FocusScope.of(context).unfocus();
    setState(() => _savingProfile = true);
    try {
      await _repo.updateMe(fullName: _name.text, phone: _phone.text);
      _changed = true;
      _toast(l.settingsSaved);
    } catch (e) {
      debugPrint('Settings profile: $e');
      _toast(l.settingsSaveFailed);
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
      _toast(l.settingsPasswordChanged);
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
    showAboutDialog(
      context: context,
      applicationName: l.appName,
      applicationVersion: l.settingsVersion(info.version, info.buildNumber),
      applicationIcon: const CircleAvatar(
          backgroundColor: HeyHelpyTheme.brand,
          child: Icon(Icons.support_agent, color: HeyHelpyTheme.onBrand)),
      children: [
        const SizedBox(height: 12),
        Text(l.settingsAboutText(l.appName)),
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
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
            title: Text(l.profileSettings), backgroundColor: Colors.white),
        body: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 40),
          children: [
            SectionTitle(l.settingsProfile),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                  labelText: l.settingsName,
                  border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                  labelText: l.settingsPhone,
                  hintText: l.settingsPhoneHint,
                  border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            FilledButton(
                style: brandButtonStyle(),
                onPressed: _savingProfile ? null : _saveProfile,
                child: Text(l.commonSave)),
            SectionTitle(l.settingsPassword),
            TextField(
              controller: _pass,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                  labelText: l.settingsNewPassword,
                  border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pass2,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: l.settingsRepeatPassword,
                  errorText: _passError,
                  border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: _savingPassword ? null : _savePassword,
                child: Text(l.settingsChangePassword)),
            SectionTitle(l.profileLanguage),
            TapCard(
              onTap: () => pickLanguage(context),
              child: Row(children: [
                const Icon(Icons.language, size: 20),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(currentLanguageName(context),
                        style: const TextStyle(fontWeight: FontWeight.w600))),
              ]),
            ),
            SectionTitle(l.settingsAbout),
            TapCard(
              onTap: _about,
              chevron: false,
              child: Row(children: [
                const Icon(Icons.info_outline, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.settingsAboutApp(l.appName),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        FutureBuilder<PackageInfo>(
                          future: _info,
                          builder: (_, s) => Text(
                              s.hasData
                                  ? l.settingsVersion(
                                      s.data!.version, s.data!.buildNumber)
                                  : '…',
                              style:
                                  const TextStyle(color: _muted, fontSize: 13)),
                        ),
                      ]),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
