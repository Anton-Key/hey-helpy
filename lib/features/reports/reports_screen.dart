import 'package:flutter/material.dart';

import '../../core/l10n_ext.dart';

/// Заготовка раздела отчётов (web, Фаза 1).
/// Таблицы/графики по заявкам с фильтрами + экспорт CSV/XLSX/PDF/почта.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.navReports)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insert_chart_outlined, size: 56),
              const SizedBox(height: 16),
              Text(
                context.l10n.reportsComingTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.reportsComingBody,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
