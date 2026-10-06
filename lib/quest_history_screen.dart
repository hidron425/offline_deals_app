import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

class QuestHistoryScreen extends StatefulWidget {
  const QuestHistoryScreen({super.key});

  @override
  State<QuestHistoryScreen> createState() => _QuestHistoryScreenState();
}

class _QuestHistoryScreenState extends State<QuestHistoryScreen> {
  late final String _userId;

  List<Map<String, dynamic>> _allShops = [];
  Set<String> _visitedShopIds = {};
  List<Map<String, dynamic>> _cycles = [];
  List<Map<String, dynamic>> _bonuses = [];
  Map<String, bool> _achievements = {};
  bool _allShopsBonusClaimed = false;
  bool _loading = true;

  supa.SupabaseClient get _sb => supa.Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _userId = supa.Supabase.instance.client.auth.currentUser!.id;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      // 1. Данные пользователя
      final userData = await _sb
          .from('user_progress')
          .select()
          .eq('user_id', _userId)
          .maybeSingle();

      if (userData == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final selectedMallId = userData['selected_mall_id'] as String? ?? '';
      _allShopsBonusClaimed = userData['all_shops_bonus_claimed'] == true;

      // 2. Магазины выбранного ТЦ
      if (selectedMallId.isNotEmpty) {
        final shopsData = await _sb
            .from('shops')
            .select('firestore_id, name, icon')
            .eq('mall_id', selectedMallId);

        _allShops = (shopsData as List).map((json) {
          final m = Map<String, dynamic>.from(json);
          return {
            'id': m['firestore_id'] ?? '',
            'name': m['name'] ?? m['firestore_id'] ?? '',
            'icon': m['icon'] ?? '🛍️',
          };
        }).toList();
      }

      // 3. Посещённые магазины
      final allVisited = (userData['all_visited_shop_ids'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toSet();

      final salesData = await _sb
          .from('sales')
          .select('shop_id, step, created_at')
          .eq('user_id', _userId)
          .order('created_at', ascending: true);

      final salesList = (salesData as List).map((json) {
        final m = Map<String, dynamic>.from(json);
        return {
          'shopId': m['shop_id'] as String? ?? '',
          'step': (m['step'] as num?)?.toInt() ?? 0,
          'timestamp': m['created_at'] != null
              ? DateTime.tryParse(m['created_at'].toString()) ?? DateTime.now()
              : DateTime.now(),
        };
      }).toList();

      final salesShopIds = salesList
          .map((s) => s['shopId'] as String)
          .where((id) => id.isNotEmpty)
          .toSet();

      _visitedShopIds = {...allVisited, ...salesShopIds};

      // 4. Группировка по циклам
      final shopNames = <String, String>{};
      for (final s in _allShops) {
        shopNames[s['id'] as String] = s['name'] as String;
      }

      final List<List<Map<String, dynamic>>> cyclesList = [];
      List<Map<String, dynamic>> currentCycle = [];
      for (final sale in salesList) {
        if (sale['step'] == 1 && currentCycle.isNotEmpty) {
          cyclesList.add(List.from(currentCycle));
          currentCycle = [];
        }
        currentCycle.add(sale);
      }
      if (currentCycle.isNotEmpty) cyclesList.add(currentCycle);

      final cyclesData = <Map<String, dynamic>>[];
      for (int i = 0; i < cyclesList.length; i++) {
        final cycle = cyclesList[i];
        final startDate = cycle.first['timestamp'] as DateTime;
        final endDate = cycle.last['timestamp'] as DateTime;
        final shops = cycle
            .map((s) => shopNames[s['shopId']] ?? s['shopId'])
            .toList();
        cyclesData.add({
          'index': i + 1,
          'startDate': startDate,
          'endDate': endDate,
          'shops': shops,
        });
      }

      // 5. Бонусы
      final pendingBonuses = (userData['pending_bonuses'] as List<dynamic>?) ?? [];
      final claimedBonuses = (userData['claimed_bonuses'] as List<dynamic>?) ?? [];
      final allBonuses = <Map<String, dynamic>>[];
      for (final b in pendingBonuses) {
        allBonuses.add({
          'description': b is Map ? (b['title']?.toString() ?? b.toString()) : b.toString(),
          'status': 'pending',
        });
      }
      for (final b in claimedBonuses) {
        allBonuses.add({
          'description': b is Map ? (b['title']?.toString() ?? b.toString()) : b.toString(),
          'status': 'claimed',
        });
      }

      // 6. Ачивки
      final achievements = <String, bool>{};
      achievements['Первый цикл'] = cyclesList.length >= 1;
      achievements['5 циклов'] = cyclesList.length >= 5;
      achievements['10 циклов'] = cyclesList.length >= 10;
      achievements['Все магазины ТЦ'] =
          _allShops.isNotEmpty && _visitedShopIds.containsAll(_allShops.map((s) => s['id']));

      if (mounted) {
        setState(() {
          _cycles = cyclesData;
          _bonuses = allBonuses;
          _achievements = achievements;
          _loading = false;
        });
      }
    } catch (e) {
      print('❌ _loadData (quest_history): $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final visitedCount = _allShops.where((s) => _visitedShopIds.contains(s['id'])).length;
    final totalShops = _allShops.length;
    final progress = totalShops > 0 ? visitedCount / totalShops : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Мои достижения')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Прогресс по магазинам
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🏬 Исследование ТЦ',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    color: const Color(0xFF6C63FF),
                  ),
                  const SizedBox(height: 8),
                  Text('$visitedCount из $totalShops магазинов посещено'),
                  if (progress >= 1.0 && !_allShopsBonusClaimed)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Бонус будет начислен автоматически при посещении последнего магазина',
                          style: TextStyle(color: Colors.orange)),
                    ),
                  if (_allShopsBonusClaimed)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('🎉 Вы уже получили бонус за все магазины!',
                          style: TextStyle(color: Colors.green)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Список магазинов
          if (_allShops.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Магазины ТЦ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._allShops.map((shop) {
                      final visited = _visitedShopIds.contains(shop['id']);
                      return ListTile(
                        dense: true,
                        leading: Text(shop['icon'], style: const TextStyle(fontSize: 24)),
                        title: Text(shop['name']),
                        trailing: Icon(
                          visited ? Icons.check_circle : Icons.circle_outlined,
                          color: visited ? Colors.green : Colors.grey,
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),

          const Divider(height: 32),

          // Бонусы
          Text('🎁 Бонусы', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (_bonuses.isEmpty)
            const Text('У вас пока нет бонусов')
          else
            ..._bonuses.map((b) => Card(
                  child: ListTile(
                    leading: Icon(
                      b['status'] == 'claimed' ? Icons.check_circle : Icons.hourglass_empty,
                      color: b['status'] == 'claimed' ? Colors.green : Colors.orange,
                    ),
                    title: Text(b['description']),
                    subtitle: Text(b['status'] == 'claimed' ? 'Получен' : 'Ожидает'),
                  ),
                )),
          const Divider(height: 32),

          // Ачивки
          Text('🏆 Ачивки', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ..._achievements.entries.map((e) => ListTile(
                leading: Icon(
                  e.value ? Icons.emoji_events : Icons.lock,
                  color: e.value ? Colors.amber : Colors.grey,
                ),
                title: Text(e.key),
                subtitle: Text(e.value ? 'Получено' : 'Не выполнено'),
              )),
          const Divider(height: 32),

          // История циклов
          Text('🔄 Пройденные циклы', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (_cycles.isEmpty)
            const Text('Вы ещё не проходили квесты')
          else
            ..._cycles.map((cycle) => Card(
                  child: ExpansionTile(
                    title: Text('Цикл ${cycle['index']}'),
                    subtitle: Text(
                      '${DateFormat('dd.MM.yyyy').format(cycle['startDate'] as DateTime)} – '
                      '${DateFormat('dd.MM.yyyy').format(cycle['endDate'] as DateTime)}',
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: List<String>.from(cycle['shops'] as List)
                              .asMap()
                              .entries
                              .map((entry) => Text('Шаг ${entry.key + 1}: ${entry.value}'))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}