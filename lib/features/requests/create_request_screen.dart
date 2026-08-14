import 'package:flutter/material.dart';

/// Заготовка экрана создания заявки (Фаза 1 наполнит логикой).
///
/// Здесь появится: тип заявки (разовая / регулярная с чек-листом),
/// приоритет, объект/оборудование, фотоподтверждение, а также
/// мультимодальный ввод: голос (wake-word «Эй Хелпи») и умная камера.
class CreateRequestScreen extends StatelessWidget {
  const CreateRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новая заявка')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionTitle('Как опишем проблему?'),
          _InputChannelCard(
            icon: Icons.keyboard,
            title: 'Текстом',
            subtitle: 'Заполнить поля вручную',
            enabled: true,
            onTap: () => _todo(context, 'Текстовый ввод — Фаза 1'),
          ),
          _InputChannelCard(
            icon: Icons.mic,
            title: 'Голосом',
            subtitle: 'Активация по фразе «Эй Хелпи» — Фаза 2',
            enabled: false,
          ),
          _InputChannelCard(
            icon: Icons.camera_alt_outlined,
            title: 'Умной камерой',
            subtitle: 'Распознавание оборудования — Фаза 3',
            enabled: false,
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Тип заявки'),
          const _PlaceholderTile(
            text: 'Разовая (со сроком) или регулярная (чек-лист + период)',
          ),
          const _SectionTitle('Параметры'),
          const _PlaceholderTile(
            text: 'Приоритет · объект/оборудование · фотоподтверждение',
          ),
        ],
      ),
    );
  }

  void _todo(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _InputChannelCard extends StatelessWidget {
  const _InputChannelCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: enabled
              ? const Icon(Icons.chevron_right)
              : const Icon(Icons.lock_outline, size: 18),
          onTap: enabled ? onTap : null,
        ),
      ),
    );
  }
}

class _PlaceholderTile extends StatelessWidget {
  const _PlaceholderTile({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text),
      ),
    );
  }
}
