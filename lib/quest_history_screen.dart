import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class QuestHistoryScreen extends StatefulWidget {
  const QuestHistoryScreen({super.key});

  @override
  State<QuestHistoryScreen> createState() => _QuestHistoryScreenState();
}

class _QuestHistoryScreenState extends State<QuestHistoryScreen> {
  final _firestore = FirebaseFirestore.instance;
  late final String _userId;

  List<Map<String, dynamic>> _cycles = [];
  List<Map<String, dynamic>> _bonuses = [];
  Map<String, bool> _achievements = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser!.uid;
    _loadData();
  }

  Future<void> _loadData() async {
    final salesSnap = await _firestore
        .collection('sales')
        .where('userId', isEqualTo: _userId)
        .orderBy('timestamp', descending: true)
        .get();

    final allSales = salesSnap.docs.map((doc) {
      final data = doc.data();
      return {
        'shopId': data['shopId'] as String? ?? '',
        'step': data['step'] as int? ?? 0,
        'timestamp': (data['timestamp'] as Timestamp).toDate(),
      };
    }).toList();

    // Собираем названия магазинов
    final shopIds = allSales.map((s) => s['shopId'] as String).toSet();
    final shopNames = <String, String>{};
    for (final id in shopIds) {
      if (id.isEmpty) continue;
      final doc = await _firestore.collection('shops').doc(id).get();
      if (doc.exists) {
        shopNames[id] = doc.data()?['name'] as String? ?? id;
      } else {
        shopNames[id] = id;
      }
    }

    // Разбиваем на циклы (при появлении шага 1 — новый цикл)
    final List<List<Map<String, dynamic>>> cyclesList = [];
    List<Map<String, dynamic>> currentCycle = [];
    for (final sale in allSales) {
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
          .toList(); // List<String>
      cyclesData.add({
        'index': i + 1,
        'startDate': startDate,
        'endDate': endDate,
        'shops': shops, // List<String>
      });
    }

    // Бонусы
    final userDoc = await _firestore.collection('user_progress').doc(_userId).get();
    final data = userDoc.data() ?? {};
    final pendingBonuses = (data['pendingBonuses'] as List<dynamic>?) ?? [];
    final claimedBonuses = (data['claimedBonuses'] as List<dynamic>?) ?? [];
    final allBonuses = <Map<String, dynamic>>[];
    for (final b in pendingBonuses) {
      allBonuses.add({
        'description': b is Map ? (b['title']?.toString() ?? b.toString()) : b.toString(),
        'status': 'pending'
      });
    }
    for (final b in claimedBonuses) {
      allBonuses.add({
        'description': b is Map ? (b['title']?.toString() ?? b.toString()) : b.toString(),
        'status': 'claimed'
      });
    }

    // Ачивки
    final achievements = <String, bool>{};
    achievements['Первый цикл'] = cyclesList.length >= 1;
    achievements['5 циклов'] = cyclesList.length >= 5;
    achievements['10 циклов'] = cyclesList.length >= 10;

    setState(() {
      _cycles = cyclesData;
      _bonuses = allBonuses;
      _achievements = achievements;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мои достижения')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
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