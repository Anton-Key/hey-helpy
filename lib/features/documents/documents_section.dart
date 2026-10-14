import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/file_share.dart';
import '../../core/l10n_ext.dart';
import '../../core/schema_compat.dart';
import 'document_logic.dart';
import 'document_repository.dart';

/// Выбрать файлы для заявки: PDF, Word, Excel, JPG / PNG, TXT до 20 МБ.
/// Неподходящие пропускаются с сообщением.
Future<List<PickedDocument>> pickDocuments(BuildContext context) async {
  final l = context.l10n;
  final List<PlatformFile> files;
  try {
    files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: kDocumentExtensions,
    );
  } catch (e) {
    debugPrint('pick documents: ${e.runtimeType}');
    if (context.mounted) {
      showAppMessage(context, l.docPickFailed, type: AppMessageType.error);
    }
    return const [];
  }
  final out = <PickedDocument>[];
  for (final f in files) {
    final size = await f.length() ?? f.lengthSync() ?? 0;
    final problem = checkDocument(f.name, size);
    if (problem != null) {
      if (context.mounted) {
        showAppMessage(
            context,
            switch (problem) {
              DocProblem.tooBig => l.docTooBig(f.name),
              DocProblem.badType => l.docBadType(f.name),
              DocProblem.empty => l.docEmpty(f.name),
            },
            type: AppMessageType.error);
      }
      continue;
    }
    final bytes = await f.readAsBytes();
    out.add(PickedDocument(f.name, bytes));
  }
  return out;
}

IconData docIcon(DocKind k) => switch (k) {
      DocKind.pdf || DocKind.word || DocKind.text => AppIcons.fileText,
      DocKind.excel => AppIcons.fileSheet,
      DocKind.image => AppIcons.fileImage,
      DocKind.other => AppIcons.file,
    };

String docSizeLabel(BuildContext context, int bytes) {
  final l = context.l10n;
  return formatFileSize(bytes, l.localeName, kb: l.docKb, mb: l.docMb);
}

/// Раздел «Документы» карточки заявки: список, «Прикрепить файл»,
/// открыть / скачать / поделиться, удалить (загрузивший или менеджер).
class OrderDocumentsSection extends StatefulWidget {
  const OrderDocumentsSection({
    super.key,
    required this.orderId,
    required this.companyId,
    required this.canUpload,
    required this.isManager,
    required this.uid,
  });
  final String orderId;
  final String companyId;
  final bool canUpload;
  final bool isManager;
  final String? uid;

  @override
  State<OrderDocumentsSection> createState() => _OrderDocumentsSectionState();
}

class _OrderDocumentsSectionState extends State<OrderDocumentsSection> {
  final _repo = DocumentRepository();
  List<OrderDocument>? _docs;
  bool _failed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await _repo.list(widget.orderId);
      if (mounted) {
        setState(() {
          _docs = d;
          _failed = false;
        });
      }
    } catch (e) {
      debugPrint('documents: ${e.runtimeType}');
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _attach() async {
    final l = context.l10n;
    final files = await pickDocuments(context);
    if (files.isEmpty || !mounted) return;
    setState(() => _busy = true);
    var failed = 0;
    for (final f in files) {
      try {
        await _repo.upload(
            companyId: widget.companyId, workOrderId: widget.orderId, file: f);
      } catch (e) {
        debugPrint('document upload: ${e.runtimeType}');
        failed++;
      }
    }
    await _load();
    if (!mounted) return;
    setState(() => _busy = false);
    showAppMessage(
        context, failed == 0 ? l.docUploaded(files.length) : l.docUploadFailed,
        type: failed == 0 ? AppMessageType.success : AppMessageType.error);
  }

  bool _canDelete(OrderDocument d) =>
      widget.isManager || (d.uploadedBy != null && d.uploadedBy == widget.uid);

  Future<void> _open(OrderDocument d) async {
    final l = context.l10n;
    try {
      final url = await _repo.signedUrl(d.storagePath);
      if (mounted) await openStorageUrl(context, url);
    } catch (e) {
      debugPrint('document open: ${e.runtimeType}');
      if (mounted) {
        showAppMessage(context, l.fileOpenFailed, type: AppMessageType.error);
      }
    }
  }

  Future<void> _share(OrderDocument d) async {
    final l = context.l10n;
    try {
      final url = await _repo.signedUrl(d.storagePath);
      if (!mounted) return;
      await shareStorageFile(
          context: context,
          url: url,
          fileName: d.fileName,
          mime: d.mime,
          bytes: () => _repo.download(d.storagePath));
    } catch (e) {
      debugPrint('document share: ${e.runtimeType}');
      if (mounted) {
        showAppMessage(context, l.fileOpenFailed, type: AppMessageType.error);
      }
    }
  }

  Future<void> _delete(OrderDocument d) async {
    final l = context.l10n;
    final ok = await showAppDialog<bool>(
      context: context,
      title: l.docDeleteTitle,
      message: d.fileName,
      actions: [
        AppDialogAction(l.actionDelete, true, destructive: true),
        AppDialogAction(l.commonCancel, false),
      ],
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.delete(d);
      await _load();
      if (mounted) showAppMessage(context, l.docDeleted);
    } catch (e) {
      debugPrint('document delete: ${e.runtimeType}');
      if (mounted) {
        showAppMessage(context, l.docDeleteFailed, type: AppMessageType.error);
      }
    }
  }

  Future<void> _menu(OrderDocument d) async {
    final l = context.l10n;
    final action = await showAppSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SheetHeader(title: d.fileName, cancelLabel: l.commonCancel),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.l),
            child: AppGroup(
                separatorInset: AppSpace.separatorInsetIcon,
                children: [
                  AppRow(
                      leading: const LeadingIcon(AppIcons.externalLink),
                      title: l.docOpen,
                      onTap: () => Navigator.pop(ctx, 'open')),
                  AppRow(
                      leading: const LeadingIcon(
                          isWebPlatform ? AppIcons.download : AppIcons.share),
                      title: isWebPlatform ? l.fileDownload : l.fileShare,
                      onTap: () => Navigator.pop(ctx, 'share')),
                  if (_canDelete(d))
                    AppRow(
                        leading: const LeadingIcon.danger(AppIcons.delete),
                        title: l.actionDelete,
                        onTap: () => Navigator.pop(ctx, 'delete')),
                ]),
          ),
        ]),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'open':
        await _open(d);
      case 'share':
        await _share(d);
      case 'delete':
        await _delete(d);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final docs = _docs;
    // До миграции 0019 раздела нет совсем.
    if (SchemaCompat.has('0019') == false) return const SizedBox.shrink();
    if (docs == null && !_failed) return const SizedBox.shrink();
    final list = docs ?? const <OrderDocument>[];
    if (list.isEmpty && !widget.canUpload && !_failed) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpace.group),
      child: AppGroup(
        header: list.isEmpty ? l.docsTitle : '${l.docsTitle} · ${list.length}',
        separatorInset: AppSpace.separatorInsetIcon,
        children: [
          if (_failed)
            AppRow(
                leading: const LeadingIcon.danger(AppIcons.warning),
                title: l.docLoadFailed,
                onTap: _load),
          for (final d in list)
            AppRow(
              leading: LeadingIcon(docIcon(d.kind)),
              title: d.fileName,
              subtitle: [
                docSizeLabel(context, d.sizeBytes),
                if (d.uploaderName?.isNotEmpty == true) d.uploaderName!,
                if (d.createdAt != null) l.dateTime(d.createdAt!.toLocal()),
              ].join(' · '),
              onTap: () => _menu(d),
            ),
          if (widget.canUpload)
            AppRow(
              leading: const LeadingIcon(AppIcons.attach),
              title: _busy ? l.docUploading : l.docAttach,
              subtitle: list.isEmpty ? l.docAttachHint : null,
              onTap: _busy ? null : _attach,
              chevron: false,
            ),
        ],
      ),
    );
  }
}
