import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_links.dart';
import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../core/schema_compat.dart';
import '../../l10n/app_localizations.dart';
import 'telegram_poster.dart' deferred as poster;
import 'telegram_repository.dart';

/// Открыть ссылку t.me: Telegram на телефоне, новая вкладка в браузере.
Future<void> openTelegramLink(BuildContext context, String url) async {
  final ok =
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
          .catchError((_) => false);
  if (!ok && context.mounted) {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      showAppMessage(context, context.l10n.tgLinkCopied,
          type: AppMessageType.success);
    }
  }
}

Future<void> _copy(BuildContext context, String url) async {
  await Clipboard.setData(ClipboardData(text: url));
  if (context.mounted) {
    showAppMessage(context, context.l10n.tgLinkCopied,
        type: AppMessageType.success);
  }
}

/// Шторка с одноразовым кодом: код, ссылка, QR, «Открыть Telegram»,
/// «Скопировать ссылку». [check] — кнопка «Готово, проверить».
Future<void> showTelegramCode(
  BuildContext context, {
  required String title,
  required String code,
  required String url,
  required String howTo,
  Future<void> Function()? check,
}) {
  final l = context.l10n;
  return showAppSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      top: false,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SheetHeader(title: title),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.l),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(howTo, style: AppText.callout),
                  const SizedBox(height: AppSpace.l),
                  Center(child: AppQrCode(url, size: 184, semanticLabel: url)),
                  const SizedBox(height: AppSpace.l),
                  AppGroup(children: [
                    _Selectable(l.tgCodeLabel, code, AppText.title2),
                    _Selectable(l.tgLinkLabel, url,
                        AppText.footnote.copyWith(color: AppColors.accentText)),
                  ]),
                  AppButton.primary(
                      icon: AppIcons.telegram,
                      label: l.tgOpenTelegram,
                      onPressed: () => openTelegramLink(ctx, url)),
                  const SizedBox(height: AppSpace.s),
                  AppButton.secondary(
                      icon: AppIcons.copy,
                      label: l.tgCopyLink,
                      onPressed: () => _copy(ctx, url)),
                  if (check != null) ...[
                    const SizedBox(height: AppSpace.s),
                    AppButton.tinted(
                        icon: AppIcons.check,
                        label: l.tgCheck,
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await check();
                        }),
                  ],
                ]),
          ),
        ),
      ]),
    ),
  );
}

class _Selectable extends StatelessWidget {
  const _Selectable(this.label, this.text, this.style);
  final String label;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpace.rowH, vertical: AppSpace.rowV),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppText.caption),
          const SizedBox(height: AppSpace.xxs),
          SelectableText(text, style: style),
        ]),
      );
}

Future<bool> _confirm(BuildContext context, String title, String message,
        String action) async =>
    await showAppDialog<bool>(
      context: context,
      title: title,
      message: message,
      actions: [
        AppDialogAction(action, true, destructive: true),
        AppDialogAction(context.l10n.commonCancel, false),
      ],
    ) ==
    true;

// ---------------------------------------------------------------------------
// Настройки → Telegram
// ---------------------------------------------------------------------------

/// Привязка своего аккаунта к Telegram: заявки боту — от своего имени.
class TelegramAccountScreen extends StatefulWidget {
  const TelegramAccountScreen({super.key});

  @override
  State<TelegramAccountScreen> createState() => _TelegramAccountScreenState();
}

class _TelegramAccountScreenState extends State<TelegramAccountScreen> {
  final _repo = TelegramRepository();
  TelegramAccount? _account;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final a = await _repo.myAccount();
      if (!mounted) return;
      setState(() {
        _account = a;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Telegram account: $e');
      if (!mounted) return;
      final l = context.l10n;
      setState(() {
        _error = e is MigrationMissing
            ? l.migrationNeeded(TelegramRepository.migration)
            : l.errorGeneric;
        _loading = false;
      });
    }
  }

  Future<void> _connect() async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final code = await _repo.createAccountCode();
      if (!mounted) return;
      setState(() => _busy = false);
      await showTelegramCode(context,
          title: l.tgCodeTitle,
          code: code,
          url: telegramStartLink('link_$code'),
          howTo: l.tgCodeHowTo, check: () async {
        await _load();
        if (mounted && _account == null) {
          showAppMessage(context, l.tgStillNotConnected);
        }
      });
    } catch (e) {
      debugPrint('Telegram code: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      showAppMessage(context, l.errorGeneric, type: AppMessageType.error);
    }
  }

  Future<void> _disconnect() async {
    final l = context.l10n;
    if (!await _confirm(
        context, l.tgDisconnect, l.tgDisconnectConfirm, l.tgGroupRemove)) {
      return;
    }
    try {
      await _repo.unlinkMe();
      if (!mounted) return;
      showAppMessage(context, l.tgDisconnected, type: AppMessageType.success);
      await _load();
    } catch (e) {
      debugPrint('Telegram unlink: $e');
      if (mounted) {
        showAppMessage(context, l.errorGeneric, type: AppMessageType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final a = _account;
    return AppScaffold(
      title: l.tgTitle,
      onRefresh: _load,
      slivers: [
        SliverContent(
          sliver: SliverList.list(children: [
            if (_loading && a == null)
              const Padding(
                padding: EdgeInsetsDirectional.only(top: AppSpace.xxl),
                child: AppLoader(),
              )
            else if (_error != null)
              AppEmptyState(
                  text: _error!,
                  error: true,
                  actionLabel: l.commonRetry,
                  onAction: _load)
            else ...[
              AppGroup(footer: l.tgSettingsHint(kTelegramBot), children: [
                AppRow(
                  leading: const LeadingIcon(AppIcons.telegram),
                  title: a == null
                      ? l.tgNotConnected
                      : l.tgConnectedAs(a.label ?? l.tgTitle),
                  subtitle: a?.createdAt == null
                      ? null
                      : l.tgConnectedSince(l.dateTime(a!.createdAt!)),
                  chevron: false,
                ),
              ]),
              if (a == null)
                AppButton.primary(
                    icon: AppIcons.telegram,
                    label: l.tgConnect,
                    loading: _busy,
                    onPressed: _connect)
              else
                AppButton.destructive(
                    label: l.tgDisconnect, onPressed: _disconnect),
            ],
          ]),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Ссылка объекта (QR) или компании + группы объекта
// ---------------------------------------------------------------------------

/// «Заявки через Telegram»: ссылка и QR-код объекта ([objectId]) или
/// компании (null), плакат, новая ссылка, отключение; у объекта — группы.
class ReportLinkScreen extends StatefulWidget {
  const ReportLinkScreen(
      {super.key, required this.objectId, required this.placeName});

  final String? objectId;

  /// Название объекта («Москва · Офис 3») или компании — на плакате.
  final String placeName;

  @override
  State<ReportLinkScreen> createState() => _ReportLinkScreenState();
}

class _ReportLinkScreenState extends State<ReportLinkScreen> {
  final _repo = TelegramRepository();
  ReportLink? _link;
  List<TelegramGroup> _groups = const [];
  bool _loading = true;
  bool _busy = false;
  bool _printing = false;
  String? _error;

  String? get _obj => widget.objectId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Future.wait<Object?>([
        _repo.reportLink(_obj),
        _obj == null
            ? Future.value(const <TelegramGroup>[])
            : _repo.groups(_obj!),
      ]);
      if (!mounted) return;
      setState(() {
        _link = r[0] as ReportLink?;
        _groups = r[1] as List<TelegramGroup>;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Report link: $e');
      if (!mounted) return;
      final l = context.l10n;
      setState(() {
        _error = e is MigrationMissing
            ? l.migrationNeeded(TelegramRepository.migration)
            : l.errorGeneric;
        _loading = false;
      });
    }
  }

  Future<void> _act(Future<void> Function() f, String done) async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      await f();
      if (!mounted) return;
      showAppMessage(context, done, type: AppMessageType.success);
      await _load();
    } catch (e) {
      debugPrint('Report link action: $e');
      if (mounted) {
        showAppMessage(context, l.errorGeneric, type: AppMessageType.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rotate() async {
    final l = context.l10n;
    if (_link != null &&
        !await _confirm(
            context, l.tgLinkRotate, l.tgLinkRotateConfirm, l.tgLinkRotate)) {
      return;
    }
    await _act(() => _repo.rotate(_obj),
        l.tgLinkCreated);
  }

  Future<void> _disable() async {
    final l = context.l10n;
    if (!await _confirm(
        context, l.tgLinkDisable, l.tgLinkDisableConfirm, l.tgLinkDisable)) {
      return;
    }
    await _act(() => _repo.disable(_obj), l.tgLinkDisabled);
  }

  Future<void> _poster(ReportLink link) async {
    final l = context.l10n;
    setState(() => _printing = true);
    try {
      await poster.loadLibrary();
      await poster.printPoster(l, widget.placeName, link.url);
    } catch (e) {
      debugPrint('Poster: $e');
      if (mounted) {
        showAppMessage(context, l.errorGeneric, type: AppMessageType.error);
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _addGroup() async {
    final l = context.l10n;
    try {
      final code = await _repo.createGroupCode(_obj!);
      if (!mounted) return;
      await showTelegramCode(context,
          title: l.tgGroupCodeTitle,
          code: code,
          url: telegramGroupLink(code),
          howTo: l.tgGroupCodeHowTo(kTelegramBot, code),
          check: _load);
    } catch (e) {
      debugPrint('Group code: $e');
      if (mounted) {
        showAppMessage(context, l.errorGeneric, type: AppMessageType.error);
      }
    }
  }

  Future<void> _removeGroup(TelegramGroup g) async {
    final l = context.l10n;
    final title = g.title ?? l.tgGroupNoTitle;
    if (!await _confirm(context, l.tgGroupRemove, l.tgGroupRemoveConfirm(title),
        l.tgGroupRemove)) {
      return;
    }
    await _act(() => _repo.removeGroup(g.id), l.tgGroupRemoved);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final link = _link;
    return AppScaffold(
      title: _obj == null ? l.tgCompanyRow : l.tgObjectRow,
      eyebrow: widget.placeName,
      onRefresh: _load,
      slivers: [
        SliverContent(
          sliver: SliverList.list(children: [
            if (_loading && link == null && _error == null)
              const Padding(
                padding: EdgeInsetsDirectional.only(top: AppSpace.xxl),
                child: AppLoader(),
              )
            else if (_error != null)
              AppEmptyState(
                  text: _error!,
                  error: true,
                  actionLabel: l.commonRetry,
                  onAction: _load)
            else ...[
              Padding(
                padding: const EdgeInsetsDirectional.only(
                    start: AppSpace.rowH,
                    end: AppSpace.rowH,
                    bottom: AppSpace.m),
                child: Text(
                    _obj == null ? l.tgLinkCompanyHint : l.tgLinkObjectHint,
                    style: AppText.footnote),
              ),
              if (link == null) ...[
                AppGroup(children: [
                  AppRow(
                      leading: const LeadingIcon.neutral(AppIcons.qr),
                      title: l.tgLinkNone,
                      chevron: false),
                ]),
                AppButton.primary(
                    icon: AppIcons.qr,
                    label: l.tgLinkCreate,
                    loading: _busy,
                    onPressed: _rotate),
              ] else
                ..._linkBlock(l, link),
              if (_obj != null) ...[
                const SizedBox(height: AppSpace.group),
                AppGroup(
                  header: l.tgGroupsTitle,
                  headerTrailing: AppButton.tinted(
                      small: true,
                      expand: false,
                      icon: AppIcons.add,
                      label: l.tgGroupAdd,
                      onPressed: _busy ? null : _addGroup),
                  footer: l.tgGroupsHint(kTelegramBot),
                  children: [
                    if (_groups.isEmpty)
                      AppRow(
                          title: l.tgGroupsEmpty,
                          titleStyle: AppText.callout,
                          chevron: false)
                    else
                      for (final g in _groups)
                        AppRow(
                          leading: const LeadingIcon(AppIcons.chats),
                          title: g.title ?? l.tgGroupNoTitle,
                          subtitle: g.createdAt == null
                              ? null
                              : l.tgConnectedSince(l.dateTime(g.createdAt!)),
                          trailing: Icon(AppIcons.close,
                              size: AppSizes.iconS,
                              color: AppColors.tertiary,
                              semanticLabel: l.tgGroupRemove),
                          chevron: false,
                          onTap: _busy ? null : () => _removeGroup(g),
                        ),
                  ],
                ),
              ],
            ],
          ]),
        ),
      ],
    );
  }

  List<Widget> _linkBlock(AppLocalizations l, ReportLink link) => [
        AppGroup(children: [
          Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Center(
                child: AppQrCode(link.url, size: 220, semanticLabel: link.url)),
          ),
          _Selectable(
              link.createdAt == null
                  ? l.tgLinkLabel
                  : '${l.tgLinkLabel} · ${l.tgLinkSince(l.dateTime(link.createdAt!))}',
              link.url,
              AppText.footnote.copyWith(color: AppColors.accentText)),
        ]),
        if (_obj != null) ...[
          AppButton.primary(
              icon: AppIcons.print,
              label: l.tgPoster,
              loading: _printing,
              onPressed: () => _poster(link)),
          const SizedBox(height: AppSpace.s),
        ],
        AppButton.secondary(
            icon: AppIcons.copy,
            label: l.tgCopyLink,
            onPressed: () => _copy(context, link.url)),
        const SizedBox(height: AppSpace.s),
        AppButton.tinted(
            icon: AppIcons.refresh,
            label: l.tgLinkRotate,
            loading: _busy,
            onPressed: _rotate),
        const SizedBox(height: AppSpace.s),
        AppButton.destructive(
            label: l.tgLinkDisable, onPressed: _busy ? null : _disable),
      ];
}
