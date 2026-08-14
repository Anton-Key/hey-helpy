import 'package:flutter/material.dart';

/// Заготовка раздела отчётов (web, Фаза 1).
/// Таблицы/графики по заявкам с фильтрами + экспорт CSV/XLSX/PDF/почта.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Отчёты')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.insert_chart_outlined, size: 56),
              SizedBox(height: 16),
              Text(
                'Отчёты появятся в Фазе 1',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              SizedBox(height: 8),
              Text(
                'Фильтры: объект, тип работ, исполнитель, период, время.\n'
                'Экспорт: CSV / XLSX / PDF / отправка на почту.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
