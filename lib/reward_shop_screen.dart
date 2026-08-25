import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RewardShopScreen extends StatefulWidget {
  const RewardShopScreen({super.key});

  @override
  State<RewardShopScreen> createState() => _RewardShopScreenState();
}

class _RewardShopScreenState extends State<RewardShopScreen> {
  final _firestore = FirebaseFirestore.instance;
  late final String _userId;
  int _cycleCount = 0;

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
    _userId = FirebaseAuth.instance.currentUser!.uid;
    _loadCycleCount();
  }

  Future<void> _loadCycleCount() async {
    final doc = await _firestore.collection('user_progress').doc(_userId).get();
    setState(() {
      _cycleCount = (doc.data()?['cycleCount'] as num?)?.toInt() ?? 0;
    });
  }

  Future<void> _purchaseReward(Map<String, dynamic> reward) async {
    final doc = await _firestore.collection('user_progress').doc(_userId).get();
    final data = doc.data() ?? {};
    final coins = data['coins'] as int? ?? 0;
    final cost = reward['cost'] as int;

    if (coins < cost) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Недостаточно монет')));
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

    await _firestore.collection('user_progress').doc(_userId).update({
      'coins': FieldValue.increment(-cost),
      'purchasedRewards': FieldValue.arrayUnion([reward['id']]),
      'pendingBonuses': FieldValue.arrayUnion([{
        'title': reward['title'],
        'message': 'Вы обменяли монеты на награду!',
        'icon': reward['icon'],
      }]),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Награда "${reward['title']}" получена!')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableRewards = _rewards.where((r) => _cycleCount >= (r['requiredLevel'] as int)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Магазин наград')),
      body: ListView.builder(
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