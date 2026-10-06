import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

/// Модель приза для колеса
class WheelPrize {
  final String label;
  final String icon;
  final int weight;
  final String? targetShopId;
  final String description;
  final int coins;                       // ← НОВОЕ

  const WheelPrize({
    required this.label,
    required this.icon,
    required this.weight,
    this.targetShopId,
    required this.description,
    this.coins = 0,                      // ← НОВОЕ
  });
}

/// Список призов по умолчанию
List<WheelPrize> getDefaultWheelPrizes() {
  return const [
    WheelPrize(
      label: 'Скидка 10% в H&M',
      icon: '👕',
      weight: 3,
      targetShopId: 'H&M',
      description: 'Предъявите QR-код на кассе для получения скидки.',
    ),
    WheelPrize(
      label: 'Бесплатный капучино в Starbucks',
      icon: '☕',
      weight: 2,
      targetShopId: 'Starbucks',
      description: 'Покажите этот бонус бариста.',
    ),
    WheelPrize(
      label: 'Скидка 15% на электронику',
      icon: '🔌',
      weight: 2,
      targetShopId: 'DNS',
      description: 'Скидка на любой товар при предъявлении бонуса.',
    ),
    WheelPrize(
      label: 'Промокод на 50 монет',
      icon: '🪙',
      weight: 4,
      description: 'Монеты начислены на ваш счёт.',
      coins: 50,                         // ← НОВОЕ
    ),
    WheelPrize(
      label: 'Подарочный стикерпак',
      icon: '🎁',
      weight: 1,
      description: 'Загляните в раздел бонусов, чтобы забрать подарок.',
    ),
    WheelPrize(
      label: 'Скидка 20% на следующую покупку',
      icon: '🏷️',
      weight: 2,
      description: 'Действует на любой магазин ТЦ в течение 7 дней.',
    ),
  ];
}

/// Виджет диалога с колесом фортуны
class WheelOfFortuneDialog extends StatefulWidget {
  final List<WheelPrize> prizes;
  final String userId;

  const WheelOfFortuneDialog({
    Key? key,
    required this.prizes,
    required this.userId,
  }) : super(key: key);

  @override
  _WheelOfFortuneDialogState createState() => _WheelOfFortuneDialogState();
}

class _WheelOfFortuneDialogState extends State<WheelOfFortuneDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _rotation = 0;
  WheelPrize? _selectedPrize;
  bool _isSpinning = false;
  bool _prizeClaimed = false;

  supa.SupabaseClient get _sb => supa.Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _controller.addListener(() {
      setState(() {
        _rotation = _controller.value * 2 * pi * 5;
      });
    });
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finishSpin();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startSpin() async {
  if (_isSpinning) return;

  // Загружаем уже полученные бонусы, чтобы не повторяться
  Set<String> alreadyWonLabels = {};
  try {
    final data = await _sb
        .from('user_progress')
        .select('pending_bonuses, claimed_bonuses')
        .eq('user_id', widget.userId)
        .maybeSingle();
    if (data != null) {
      for (final item in (data['pending_bonuses'] as List? ?? [])) {
        if (item is Map && item['title'] != null) {
          alreadyWonLabels.add(item['title'].toString());
        }
      }
      for (final item in (data['claimed_bonuses'] as List? ?? [])) {
        if (item is Map && item['title'] != null) {
          alreadyWonLabels.add(item['title'].toString());
        }
      }
    }
  } catch (e) {
    print('❌ _startSpin load: $e');
  }

  // Фильтруем призы — оставляем только не выигранные
  final availablePrizes = widget.prizes
      .where((p) => !alreadyWonLabels.contains(p.label))
      .toList();

  // Если всё выиграно — сбрасываем и разрешаем повтор
  final pool = availablePrizes.isEmpty ? widget.prizes : availablePrizes;

  setState(() {
    _isSpinning = true;
    _prizeClaimed = false;
  });

  final totalWeight = pool.fold(0, (sum, p) => sum + p.weight);
  final random = Random();
  int target = random.nextInt(totalWeight);
  int cumulative = 0;
  for (final prize in pool) {
    cumulative += prize.weight;
    if (target < cumulative) {
      _selectedPrize = prize;
      break;
    }
  }

  _controller.reset();
  _controller.forward();
}

  Future<void> _finishSpin() async {
    if (_selectedPrize == null || _prizeClaimed) return;
    setState(() => _prizeClaimed = true);

    // Добавляем приз в pending_bonuses
    try {
      final data = await _sb
          .from('user_progress')
          .select('pending_bonuses')
          .eq('user_id', widget.userId)
          .maybeSingle();

      if (data != null) {
        final pending = List<dynamic>.from(data['pending_bonuses'] ?? []);
        pending.add({
          'title': _selectedPrize!.label,
          'message': _selectedPrize!.description,
          'icon': _selectedPrize!.icon,
          'targetShopId': _selectedPrize!.targetShopId ?? '',
          'coins': _selectedPrize!.coins,  // ← НОВОЕ — прокидываем монеты
        });

        await _sb.from('user_progress').update({
          'pending_bonuses': pending,
        }).eq('user_id', widget.userId);
      }
    } catch (e) {
      print('❌ _finishSpin (wheel): $e');
    }

    if (mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${_selectedPrize!.icon} Поздравляем!'),
          content: Text(
            'Вы выиграли: ${_selectedPrize!.label}\n\n${_selectedPrize!.description}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отлично'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Колесо фортуны'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Испытайте удачу после завершения цикла!'),
          const SizedBox(height: 20),
          Transform.rotate(
            angle: _rotation,
            child: CustomPaint(
              size: const Size(250, 250),
              painter: _WheelPainter(prizes: widget.prizes),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _isSpinning ? null : _startSpin,
            icon: const Icon(Icons.casino),
            label: Text(_isSpinning ? 'Крутится...' : 'Крутить колесо'),
          ),
        ],
      ),
    );
  }
}

/// Отрисовщик колеса с секторами
class _WheelPainter extends CustomPainter {
  final List<WheelPrize> prizes;

  _WheelPainter({required this.prizes});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final totalWeight = prizes.fold(0, (sum, p) => sum + p.weight);
    double startAngle = -pi / 2;

    for (final prize in prizes) {
      final sweepAngle = (prize.weight / totalWeight) * 2 * pi;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = _colorForPrize(prize);
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          startAngle, sweepAngle, true, paint);

      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white;
      canvas.drawLine(center,
          center + Offset(cos(startAngle), sin(startAngle)) * radius, borderPaint);

      final labelAngle = startAngle + sweepAngle / 2;
      final labelPos = center + Offset(cos(labelAngle), sin(labelAngle)) * (radius * 0.6);
      TextPainter(
        text: TextSpan(
          text: prize.icon,
          style: const TextStyle(fontSize: 24),
        ),
        textDirection: TextDirection.ltr,
      )..layout()..paint(canvas, labelPos - Offset(12, 12));

      startAngle += sweepAngle;
    }
  }

  Color _colorForPrize(WheelPrize prize) {
    final colors = [
      Colors.blue.shade100,
      Colors.green.shade100,
      Colors.orange.shade100,
      Colors.purple.shade100,
      Colors.teal.shade100,
      Colors.pink.shade100,
    ];
    final index = prizes.indexOf(prize) % colors.length;
    return colors[index];
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}