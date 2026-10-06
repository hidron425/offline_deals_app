import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'theme/app_theme.dart';
import 'widgets/app_widgets.dart';

class RewardShopScreen extends StatefulWidget {
  const RewardShopScreen({super.key});

  @override
  State<RewardShopScreen> createState() => _RewardShopScreenState();
}

class _RewardShopScreenState extends State<RewardShopScreen> {
  late final String _userId;
  int _cycleCount = 0;
  int _coins = 0;
  bool _loading = true;

  supa.SupabaseClient get _sb => supa.Supabase.instance.client;

  final List<Map<String, dynamic>> _rewards = [
    {
      'title': 'Скидка 15% на любую покупку',
      'cost': 100,
      'icon': '🏷️',
      'id': 'reward_1',
      'requiredLevel': 0,
    },
    {
      'title': 'Бесплатный напиток в кафе',
      'cost': 80,
      'icon': '☕',
      'id': 'reward_2',
      'requiredLevel': 1,
    },
    {
      'title': 'Дополнительный бонусный квест',
      'cost': 200,
      'icon': '🎁',
      'id': 'reward_3',
      'requiredLevel': 2,
    },
  ];

  @override
  void initState() {
    super.initState();
    _userId = supa.Supabase.instance.client.auth.currentUser!.id;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final data = await _sb
          .from('user_progress')
          .select('cycle_count, coins')
          .eq('user_id', _userId)
          .maybeSingle();
      if (data != null && mounted) {
        setState(() {
          _cycleCount = (data['cycle_count'] as num?)?.toInt() ?? 0;
          _coins = (data['coins'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (e) {
      print('❌ _loadUserData: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _purchaseReward(Map<String, dynamic> reward) async {
    final cost = reward['cost'] as int;

    if (_coins < cost) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Недостаточно монет')),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(reward['title']),
        content: Text('Потратить $cost монет?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Купить')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      // Читаем свежие данные (монеты + pending_bonuses)
      final data = await _sb
          .from('user_progress')
          .select('coins, pending_bonuses, purchased_rewards')
          .eq('user_id', _userId)
          .maybeSingle();
      if (data == null) return;

      final currentCoins = (data['coins'] as num?)?.toInt() ?? 0;
      if (currentCoins < cost) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Недостаточно монет')),
          );
        }
        return;
      }

      final pending = List<dynamic>.from(data['pending_bonuses'] ?? []);
      pending.add({
        'title': reward['title'],
        'message': 'Вы обменяли монеты на награду!',
        'icon': reward['icon'],
      });

      final purchased = List<dynamic>.from(data['purchased_rewards'] ?? []);
      purchased.add(reward['id']);

      await _sb.from('user_progress').update({
        'coins': currentCoins - cost,
        'pending_bonuses': pending,
        'purchased_rewards': purchased,
      }).eq('user_id', _userId);

      if (mounted) {
        setState(() => _coins = currentCoins - cost);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Награда "${reward['title']}" получена!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ _purchaseReward: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableRewards = _rewards
        .where((r) => _cycleCount >= (r['requiredLevel'] as int))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Магазин наград'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: CoinBadge(amount: _coins)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: availableRewards.length,
              itemBuilder: (context, index) {
                final reward = availableRewards[index];
                return Card(
                  child: ListTile(
                    leading: Text(reward['icon'], style: const TextStyle(fontSize: 32)),
                    title: Text(reward['title']),
                    subtitle: Text('${reward['cost']} монет'),
                    trailing: ElevatedButton(
                      onPressed: () => _purchaseReward(reward),
                      child: const Text('Купить'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}