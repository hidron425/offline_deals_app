import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:cloud_functions/cloud_functions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const OfflineDealsApp());
}

// ----- ОБЩАЯ ТЕМА И ГРАДИЕНТНАЯ ОБЁРТКА -----
class GradientScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final BottomNavigationBar? bottomNavigationBar;
  final bool resizeToAvoidBottomInset;

  const GradientScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6C63FF), Color(0xFF00C9A7)],
          ),
        ),
        child: body,
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

class OfflineDealsApp extends StatelessWidget {
  const OfflineDealsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Deals',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          primary: const Color(0xFF6C63FF),
          secondary: const Color(0xFFFF6584),
          tertiary: const Color(0xFF00C9A7),
          background: Colors.transparent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        cardTheme: CardThemeData(
          color: Colors.white.withOpacity(0.9),
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF6C63FF),
            elevation: 4,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontSize: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.85),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.white, width: 1.5),
          ),
          labelStyle: const TextStyle(color: Color(0xFF6C63FF)),
          hintStyle: TextStyle(color: Colors.grey[600]),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          titleTextStyle: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6C63FF),
          ),
          contentTextStyle: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            final user = snapshot.data;
            if (user == null) return const AuthScreen();
            return const MainScreen();
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}

// ----- ЭКРАН ВХОДА / РЕГИСТРАЦИИ -----
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;

  Future<void> _submit() async {
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Ошибка';
      if (e.code == 'weak-password') message = 'Слабый пароль.';
      if (e.code == 'email-already-in-use') message = 'Email уже используется.';
      if (e.code == 'user-not-found') message = 'Пользователь не найден.';
      if (e.code == 'wrong-password') message = 'Неверный пароль.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(title: const Text('Добро пожаловать!')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.storefront, size: 80, color: Colors.white),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Пароль'),
                obscureText: true,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submit,
                child: Text(_isLogin ? 'Войти' : 'Зарегистрироваться'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(
                  _isLogin ? 'Нет аккаунта? Зарегистрируйтесь' : 'Уже есть аккаунт? Войдите',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----- ГЛАВНЫЙ ЭКРАН С НИЖНЕЙ НАВИГАЦИЕЙ -----
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const DealsGameScreen(),
      const MapPlaceholder(),
      const ProfileScreen(),
    ];
  }

  void setTab(int index) {
    if (mounted) setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white.withOpacity(0.9),
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey[600],
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.local_offer_outlined), label: 'Акции'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Карта'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Профиль'),
        ],
      ),
    );
  }
}

// ----- МОДЕЛИ ДАННЫХ -----
class Shop {
  final String id;
  final String name;
  final String icon;
  final String discount;
  final String description;
  final String location;
  final String category;
  final int priority;
  final String mallId;
  final String imageUrl;

  Shop({
    required this.id,
    required this.name,
    required this.icon,
    required this.discount,
    required this.description,
    required this.location,
    required this.category,
    required this.priority,
    required this.mallId,
    required this.imageUrl,
  });

  factory Shop.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Shop(
      id: doc.id,
      name: data['name'] ?? 'Без названия',
      icon: data['icon'] ?? '🛍️',
      discount: data['discount'] ?? '',
      description: data['description'] ?? '',
      location: data['location'] ?? '',
      category: data['category'] ?? 'other',
      priority: (data['priority'] as int?) ?? 1,
      mallId: data['mallId'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
    );
  }
}

class BannerAd {
  final String title;
  final String description;
  final int color;
  final String targetShopId;
  final String discount;
  final String mallId;

  BannerAd({
    required this.title,
    required this.description,
    required this.color,
    required this.targetShopId,
    required this.discount,
    required this.mallId,
  });

  factory BannerAd.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    int colorInt = 0xFF6C63FF;
    final colorStr = data['color'] as String?;
    if (colorStr != null && colorStr.isNotEmpty) {
      final hexCode = colorStr.replaceAll('#', '');
      colorInt = int.parse(hexCode, radix: 16);
      if (hexCode.length == 6) colorInt = 0xFF000000 | colorInt;
    }
    return BannerAd(
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      color: colorInt,
      targetShopId: data['targetShopId'] ?? '',
      discount: data['discount'] ?? '',
      mallId: data['mallId'] ?? '',
    );
  }
}

// ----- КАРУСЕЛЬ БАННЕРОВ -----
class BannersCarousel extends StatefulWidget {
  final Function(Shop) onActivateShop;
  final String? mallId;
  const BannersCarousel({super.key, required this.onActivateShop, this.mallId});

  @override
  State<BannersCarousel> createState() => _BannersCarouselState();
}

class _BannersCarouselState extends State<BannersCarousel> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  Timer? _timer;
  List<BannerAd> _banners = [];
  final Map<String, Shop> _shopCache = {};

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  void _loadBanners() {
    FirebaseFirestore.instance.collection('banners').snapshots().listen((snapshot) {
      final allBanners = snapshot.docs.map((doc) => BannerAd.fromFirestore(doc)).toList();
      final filtered = widget.mallId != null
          ? allBanners.where((b) => b.mallId == widget.mallId || b.mallId == 'all').toList()
          : allBanners;
      setState(() {
        _banners = filtered;
        if (_currentIndex >= _banners.length) _currentIndex = 0;
      });
      _restartTimer();
      for (var banner in filtered) {
        if (!_shopCache.containsKey(banner.targetShopId)) {
          FirebaseFirestore.instance.collection('shops').doc(banner.targetShopId).get().then((doc) {
            if (doc.exists) {
              _shopCache[banner.targetShopId] = Shop.fromFirestore(doc);
              if (mounted) setState(() {});
            }
          });
        }
      }
    });
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_banners.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients && mounted && _banners.isNotEmpty) {
        final next = (_currentIndex + 1) % _banners.length;
        _pageController.animateToPage(next,
            duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      }
    });
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_banners.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 160,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _banners.length,
            itemBuilder: (context, index) {
              final banner = _banners[index];
              final targetShop = _shopCache[banner.targetShopId];
              return _BannerItem(
                banner: banner,
                targetShop: targetShop,
                onActivate: widget.onActivateShop,
              );
            },
          ),
          Positioned(
            bottom: 8,
            child: Row(
              children: List.generate(
                _banners.length,
                (index) => GestureDetector(
                  onTap: () {
                    if (_pageController.hasClients) {
                      _pageController.animateToPage(index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == index
                          ? Colors.white
                          : Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerItem extends StatelessWidget {
  final BannerAd banner;
  final Shop? targetShop;
  final Function(Shop) onActivate;
  const _BannerItem({required this.banner, required this.targetShop, required this.onActivate});

  @override
  Widget build(BuildContext context) {
    if (targetShop == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Color(banner.color), Color(banner.color).withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showDialog(context, targetShop!),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(banner.color), Color(banner.color).withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: Colors.white.withOpacity(0.2),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      banner.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black26)],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      banner.description,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDialog(BuildContext context, Shop targetShop) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(banner.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(banner.description, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            Text('Магазин-партнёр: ${targetShop.name}'),
            Text('Скидка: ${banner.discount}'),
            Text('📍 ${targetShop.location}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onActivate(targetShop);
            },
            child: const Text('Получить скидку'),
          ),
        ],
      ),
    );
  }
}

// ----- КАРТОЧКА МАГАЗИНА -----
class _ShopCard extends StatefulWidget {
  final Shop shop;
  final Function(Shop) onTap;
  const _ShopCard({required this.shop, required this.onTap});

  @override
  State<_ShopCard> createState() => _ShopCardState();
}

class _ShopCardState extends State<_ShopCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => widget.onTap(widget.shop),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _isHovered ? Matrix4.translationValues(0, -6, 0) : Matrix4.identity(),
          child: Container(
            width: 130,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(24),
              boxShadow: _isHovered
                  ? [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 8))]
                  : [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.shop.imageUrl.isNotEmpty)
                    Image.network(
                      widget.shop.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[100],
                        child: Center(child: Text(widget.shop.icon, style: const TextStyle(fontSize: 48))),
                      ),
                    )
                  else
                    Container(
                      color: Colors.grey[100],
                      child: Center(child: Text(widget.shop.icon, style: const TextStyle(fontSize: 48))),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.shop.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.shop.discount,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ----- КНОПКА ОТЛОЖЕННОГО МАГАЗИНА -----
class _PendingShopButton extends StatefulWidget {
  final Shop shop;
  final Function(Shop) onTap;
  const _PendingShopButton({required this.shop, required this.onTap});

  @override
  State<_PendingShopButton> createState() => _PendingShopButtonState();
}

class _PendingShopButtonState extends State<_PendingShopButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => widget.onTap(widget.shop),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _isHovered ? Matrix4.translationValues(0, -6, 0) : Matrix4.identity(),
          child: Container(
            width: 140,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(28),
              boxShadow: _isHovered
                  ? [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 8))]
                  : [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: [
                if (widget.shop.imageUrl.isNotEmpty)
                  Image.network(widget.shop.imageUrl, width: 80, height: 80, fit: BoxFit.cover)
                else
                  Text(widget.shop.icon, style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 8),
                Text(widget.shop.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(widget.shop.discount, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ----- ГЛАВНЫЙ ИГРОВОЙ ЭКРАН (С БЕСКОНЕЧНЫМИ ЦИКЛАМИ) -----
class DealsGameScreen extends StatefulWidget {
  const DealsGameScreen({super.key});

  @override
  State<DealsGameScreen> createState() => _DealsGameScreenState();
}

class _DealsGameScreenState extends State<DealsGameScreen> {
  final _firestore = FirebaseFirestore.instance;

  int _completedSteps = 0;
  final int _totalSteps = 5;
  final Set<String> _usedShopIds = {};
  late final String _userId;
  int _cycleCount = 0;

  List<Shop> _allShops = [];
  String? _selectedCity;
  String? _selectedMall;
  String? _selectedMallId;
  bool _isLoading = true;

  List<Shop>? _pendingForkShops;
  bool _isPathActive = false;

  Shop? _lastShop;
  String? _lastShopId;

  @override
  void initState() {
    super.initState();
    FirebaseFunctions functions = FirebaseFunctions.instance;
    functions.useFunctionsEmulator('localhost', 5001);

    _userId = FirebaseAuth.instance.currentUser!.uid;
    _loadAll();
  }

  Future<void> _loadAll() async {
    await _loadUserLocation();
    await _loadShops();
    await _loadProgress();
    setState(() => _isLoading = false);
    if (_selectedMallId == null) _showLocationPicker();
  }

  Future<void> _loadUserLocation() async {
    final doc = await _firestore.collection('user_progress').doc(_userId).get();
    if (doc.exists) {
      setState(() {
        _selectedCity = doc.data()?['selectedCity'] as String?;
        _selectedMall = doc.data()?['selectedMall'] as String?;
        _selectedMallId = doc.data()?['selectedMallId'] as String?;
      });
    }
  }

  Future<void> _saveUserLocation(String city, String mall, String mallId) async {
    await _firestore.collection('user_progress').doc(_userId).set({
      'selectedCity': city,
      'selectedMall': mall,
      'selectedMallId': mallId,
    }, SetOptions(merge: true));
    setState(() {
      _selectedCity = city;
      _selectedMall = mall;
      _selectedMallId = mallId;
    });
  }

  Future<void> _loadShops() async {
    final snapshot = await _firestore.collection('shops').get();
    final all = snapshot.docs.map((doc) => Shop.fromFirestore(doc)).toList();
    setState(() {
      _allShops = _selectedMallId != null ? all.where((s) => s.mallId == _selectedMallId).toList() : all;
    });
  }

  Future<void> _loadProgress() async {
    final doc = await _firestore.collection('user_progress').doc(_userId).get();
    if (doc.exists) {
      final data = doc.data()!;
      final pendingIds = List<String>.from(data['pendingForkShops'] ?? []);
      List<Shop>? pendingShops;
      if (pendingIds.length == 2 && _allShops.isNotEmpty) {
        pendingShops = _allShops.where((shop) => pendingIds.contains(shop.id)).toList();
        if (pendingShops.length != 2) pendingShops = null;
      }

      final lastId = data['lastShopId'] as String?;
      Shop? lastShop;
      if (lastId != null && _allShops.isNotEmpty) {
        lastShop = _allShops.firstWhere(
          (s) => s.id == lastId,
          orElse: () => null as dynamic,
        ) as Shop?;
      }

      int completedSteps = (data['completedSteps'] as num?)?.toInt() ?? 0;

      setState(() {
        _completedSteps = completedSteps;
        final usedList = List<String>.from(data['usedShopIds'] ?? []);
        _usedShopIds.clear();
        _usedShopIds.addAll(usedList);
        _isPathActive = completedSteps > 0;
        _pendingForkShops = pendingShops;
        _cycleCount = (data['cycleCount'] as int?) ?? 0;
        _lastShopId = lastId;
        _lastShop = lastShop;
      });

      if (data.containsKey('bonusClaimed')) {
        await doc.reference.update({'bonusClaimed': FieldValue.delete()});
      }
    } else {
      await _firestore.collection('user_progress').doc(_userId).set({
        'userId': _userId,
        'email': FirebaseAuth.instance.currentUser!.email,
        'completedSteps': 0,
        'usedShopIds': [],
        'pendingBonuses': [],
        'claimedBonuses': [],
        'pendingForkShops': [],
        'subscribedShops': [],
        'pushMinIntervalHours': 1,
        'cycleCount': 0,
        'lastShopId': null,
      });
    }
  }

  Future<void> _saveProgress() async {
    final pendingIds = _pendingForkShops?.map((s) => s.id).toList() ?? [];
    await _firestore.collection('user_progress').doc(_userId).update({
      'completedSteps': _completedSteps,
      'usedShopIds': _usedShopIds.toList(),
      'pendingForkShops': pendingIds,
      'cycleCount': _cycleCount,
      'lastShopId': _lastShopId,
    });
  }

  Future<void> _resetProgress() async {
    setState(() {
      _completedSteps = 0;
      _usedShopIds.clear();
      _isPathActive = false;
      _pendingForkShops = null;
      _lastShop = null;
      _lastShopId = null;
    });
    await _saveProgress();
  }

  Future<void> _fullReset() async {
    setState(() {
      _completedSteps = 0;
      _usedShopIds.clear();
      _isPathActive = false;
      _pendingForkShops = null;
      _selectedCity = null;
      _selectedMall = null;
      _selectedMallId = null;
      _isLoading = true;
      _cycleCount = 0;
      _lastShop = null;
      _lastShopId = null;
    });
    await _firestore.collection('user_progress').doc(_userId).update({
      'completedSteps': 0,
      'usedShopIds': [],
      'pendingBonuses': [],
      'claimedBonuses': [],
      'bonusClaimed': FieldValue.delete(),
      'selectedCity': FieldValue.delete(),
      'selectedMall': FieldValue.delete(),
      'selectedMallId': FieldValue.delete(),
      'pendingForkShops': [],
      'cycleCount': 0,
      'lastShopId': FieldValue.delete(),
    });
    await _loadAll();
  }

  // ------------------------------------------------------------
  // Универсальный метод проверки и выдачи бонусов (новый)
  // ------------------------------------------------------------
  Future<void> _checkBonuses(String trigger, {Shop? currentShop}) async {
    final userDoc = await _firestore.collection('user_progress').doc(_userId).get();
    final userData = userDoc.data()!;
    final pending = List<String>.from(userData['pendingBonuses'] ?? []);
    final claimed = List<String>.from(userData['claimedBonuses'] ?? []);
    final cycleCount = userData['cycleCount'] ?? 0;
    final completedSteps = userData['completedSteps'] ?? 0;

    final rulesSnap = await _firestore
        .collection('bonus_rules')
        .where('active', isEqualTo: true)
        .where('trigger', isEqualTo: trigger)
        .get();

    for (var doc in rulesSnap.docs) {
      final rule = doc.data() as Map<String, dynamic>;
      final conditions = rule['conditions'] as Map<String, dynamic>? ?? {};

      // Проверка условий
      if (conditions['cycleCount'] != null && cycleCount != conditions['cycleCount']) continue;
      if (conditions['stepCount'] != null && completedSteps != conditions['stepCount']) continue;
      if (conditions['minStepsCompleted'] != null && completedSteps < conditions['minStepsCompleted']) continue;
      if (conditions['shopId'] != null && currentShop?.id != conditions['shopId']) continue;
      if (conditions['category'] != null && currentShop?.category != conditions['category']) continue;

      // Проверка на однократность получения
      if (rule['oncePerUser'] == true) {
        if (pending.contains(doc.id) || claimed.contains(doc.id)) continue;
      }

      // Выдаём бонус
      await _firestore.collection('user_progress').doc(_userId).update({
        'pendingBonuses': FieldValue.arrayUnion([doc.id]),
      });

      if (mounted) {
        final reward = rule['reward'] as Map<String, dynamic>? ?? {};
        final title = reward['title'] ?? 'Новый бонус!';
        final message = reward['message'] ?? 'Зайдите в профиль, чтобы получить.';
        final icon = reward['icon'] ?? '🎁';
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('$icon $title'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Позже'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.findAncestorStateOfType<_MainScreenState>()?.setTab(2);
                },
                child: const Text('В профиль'),
              ),
            ],
          ),
        );
      }
    }
  }

  // ------------------------------------------------------------
  // Остальные методы (без изменений, кроме удаления старого бонусного кода)
  // ------------------------------------------------------------
  Future<void> _showLocationPicker({bool isChanging = false}) async {
    final Map<String, List<Map<String, String>>> citiesAndMalls = {
      'Москва': [
        {'name': 'ТЦ Афимолл', 'id': 'mall_afimall'},
        {'name': 'ТЦ Европейский', 'id': 'mall_europe'},
        {'name': 'ТЦ МЕГА', 'id': 'mall_mega'},
      ],
      'Санкт-Петербург': [
        {'name': 'ТЦ Галерея', 'id': 'mall_gallery'},
        {'name': 'ТЦ Невский', 'id': 'mall_nevsky'},
      ],
      'Казань': [
        {'name': 'ТЦ Мега', 'id': 'mall_kazan_mega'},
        {'name': 'ТЦ Кольцо', 'id': 'mall_kazan_ring'},
      ],
    };

    String? selectedCity = _selectedCity;
    String? selectedMall;
    String? selectedMallId;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(isChanging ? 'Изменить локацию' : 'Добро пожаловать!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Выберите ваш город и торговый центр, чтобы начать квест.'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Город'),
                  value: selectedCity,
                  items: citiesAndMalls.keys.map((city) => DropdownMenuItem(value: city, child: Text(city))).toList(),
                  onChanged: (value) {
                    setStateDialog(() {
                      selectedCity = value;
                      selectedMall = null;
                      selectedMallId = null;
                    });
                  },
                ),
                if (selectedCity != null) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Торговый центр'),
                    value: selectedMall,
                    items: citiesAndMalls[selectedCity!]!.map((mall) {
                      return DropdownMenuItem(value: mall['name'], child: Text(mall['name']!));
                    }).toList(),
                    onChanged: (value) {
                      final selected = citiesAndMalls[selectedCity!]!.firstWhere((mall) => mall['name'] == value);
                      setStateDialog(() {
                        selectedMall = value;
                        selectedMallId = selected['id'];
                      });
                    },
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (isChanging) Navigator.pop(context);
                  else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Выберите локацию, чтобы продолжить')),
                    );
                  }
                },
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedCity != null && selectedMall != null && selectedMallId != null) {
                    await _saveUserLocation(selectedCity!, selectedMall!, selectedMallId!);
                    if (isChanging) {
                      await _resetProgress();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Локация изменена, прогресс сброшен')),
                      );
                    }
                    Navigator.pop(context);
                    await _loadShops();
                    setState(() {});
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Выберите город и торговый центр')),
                    );
                  }
                },
                child: const Text('Подтвердить'),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Shop> _getNextTwoShops(Shop currentShop) {
    var available = _allShops.where((s) => !_usedShopIds.contains(s.id) && s.id != currentShop.id).toList();
    if (available.length < 2) return available;
    final weighted = <Shop>[];
    for (var shop in available) {
      for (int i = 0; i < shop.priority; i++) weighted.add(shop);
    }
    weighted.shuffle();
    final selected = <Shop>[];
    for (var shop in weighted) {
      if (!selected.contains(shop)) {
        selected.add(shop);
        if (selected.length == 2) break;
      }
    }
    return selected;
  }

  List<String> _getRelatedCategories(String cat) {
    switch (cat) {
      case 'clothing':
        return ['clothing', 'shoes', 'accessories'];
      case 'shoes':
        return ['shoes', 'clothing'];
      case 'cafe':
        return ['cafe', 'clothing'];
      default:
        return [cat];
    }
  }

  Future<Map<String, dynamic>?> _getActiveCollab(Shop currentShop) async {
    try {
      final collabQuery = await _firestore
          .collection('active_collabs')
          .where('fromShopId', isEqualTo: currentShop.id)
          .where('expires', isGreaterThan: Timestamp.now())
          .limit(1)
          .get();
      if (collabQuery.docs.isEmpty) return null;
      final collabData = collabQuery.docs.first.data();
      final toShopDoc = await _firestore.collection('shops').doc(collabData['toShopId']).get();
      if (!toShopDoc.exists) return null;
      final toShop = Shop.fromFirestore(toShopDoc);
      return {
        'collab': collabData,
        'toShop': toShop,
        'collabDocId': collabQuery.docs.first.id,
      };
    } catch (e) {
      print('❌ Ошибка в _getActiveCollab: $e');
      return null;
    }
  }

  Future<void> _showForkDialog(Shop currentShop) async {
    final nextShops = _getNextTwoShops(currentShop);
    if (nextShops.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет доступных магазинов для продолжения пути. Сбросьте прогресс.')),
        );
      }
      return;
    }

    final collab = await _getActiveCollab(currentShop);
    final hasCollab = collab != null;
    final toShop = hasCollab ? collab!['toShop'] as Shop : null;
    final collabDocId = hasCollab ? collab!['collabDocId'] as String : null;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Выбери путь дальше'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Вы получили скидку в ${currentShop.name}. Куда отправимся дальше?'),
            const SizedBox(height: 16),
            hasCollab
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _forkButton(nextShops[0], isCollab: false),
                      _forkButton(nextShops[1], isCollab: false),
                      _forkButton(toShop!, isCollab: true, collabDocId: collabDocId),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _forkButton(nextShops[0], isCollab: false),
                      _forkButton(nextShops[1], isCollab: false),
                    ],
                  ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _pendingForkShops = nextShops;
                _isPathActive = true;
                _lastShopId = currentShop.id;
                _lastShop = currentShop;
              });
              _saveProgress();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.black87),
            child: const Text('Закончить путь (продолжить позже)'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _resetProgress();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.black87),
            child: const Text('Сбросить путь'),
          ),
        ],
      ),
    );
  }

  Widget _forkButton(Shop shop, {required bool isCollab, String? collabDocId}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            if (isCollab && collabDocId != null) {
              final collabRef = _firestore.collection('active_collabs').doc(collabDocId);
              try {
                final collabDoc = await collabRef.get();
                if (!collabDoc.exists) return;
                final data = collabDoc.data()!;
                final currentClicks = (data['clicks'] as int?) ?? 0;
                await collabRef.update({'clicks': currentClicks + 1});

                final offerId = data['offerId'] as String?;
                final bid = data['bid'] as int?;
                if (offerId != null && bid != null && bid > 0) {
                  final offerRef = _firestore.collection('auction_offers').doc(offerId);
                  final offerDoc = await offerRef.get();
                  if (!offerDoc.exists) return;
                  final offerData = offerDoc.data()!;
                  final remaining = offerData['remainingBudget'] as int? ?? 0;
                  if (remaining >= bid) {
                    final newRemaining = remaining - bid;
                    await offerRef.update({'remainingBudget': newRemaining});
                    if (newRemaining <= 0) {
                      await offerRef.update({'status': 'exhausted'});
                      await collabRef.delete();
                    }
                  } else {
                    await collabRef.delete();
                  }
                }
              } catch (e) {
                print('❌ Ошибка в коллаборации: $e');
              }
            }
            await _activateShop(shop);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isCollab ? Colors.orange : Colors.white,
            foregroundColor: isCollab ? Colors.white : const Color(0xFF6C63FF),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Column(
            children: [
              Text(shop.icon, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 4),
              Text(shop.name, style: const TextStyle(fontSize: 14)),
              if (isCollab) const Text('🎁 Спецпредложение!', style: TextStyle(fontSize: 10)),
              Text(shop.discount, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _activateShop(Shop shop) async {
    if (_usedShopIds.contains(shop.id)) return;
    final currentStep = _completedSteps + 1;
    setState(() {
      _usedShopIds.add(shop.id);
      if (_completedSteps < _totalSteps) _completedSteps++;
      _pendingForkShops = null;
      _isPathActive = _completedSteps > 0 && _completedSteps < _totalSteps;
      _lastShop = shop;
      _lastShopId = shop.id;
    });
    await _saveProgress();
    await _showQRDialog(shop);
    await _firestore.collection('sales').add({
      'shopId': shop.id,
      'userId': _userId,
      'step': currentStep,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Проверка бонусов за завершение шага
    await _checkBonuses('step_completed', currentShop: shop);

    if (_completedSteps == _totalSteps) {
      _startNewCycle();
    } else {
      await _showForkDialog(shop);
    }
  }

 Future<void> _startNewCycle() async {
  final newCycleCount = _cycleCount + 1;
  // Сохраняем новый цикл в Firestore
  await _firestore.collection('user_progress').doc(_userId).update({
    'cycleCount': newCycleCount,
    'completedSteps': 0,
    'usedShopIds': [],
    'pendingForkShops': [],
    'lastShopId': null,
  });

  setState(() {
    _completedSteps = 0;
    _usedShopIds.clear();
    _cycleCount = newCycleCount;
    _isPathActive = true;
    _pendingForkShops = null;
    _lastShop = null;
    _lastShopId = null;
  });

  if (!mounted) return;

  // Проверяем и начисляем бонусы за завершение цикла
  await _checkBonuses('cycle_completed');

  // Сразу предлагаем начать новый путь
  _showFirstChoice();
}

  Future<void> _showQRDialog(Shop shop) async {
    final userDoc = await _firestore.collection('user_progress').doc(_userId).get();
    final subscribedShops = List<String>.from(userDoc.data()?['subscribedShops'] ?? []);
    final isSubscribed = subscribedShops.contains(shop.id);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(shop.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner_rounded, size: 120, color: Color(0xFF6C63FF)),
            const SizedBox(height: 16),
            Text(shop.discount, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(shop.description, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isSubscribed ? Icons.notifications_active : Icons.notifications_off, color: Colors.grey),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    List<String> newSubscribed;
                    if (isSubscribed) {
                      newSubscribed = subscribedShops.where((id) => id != shop.id).toList();
                    } else {
                      newSubscribed = [...subscribedShops, shop.id];
                    }
                    await _firestore.collection('user_progress').doc(_userId).update({
                      'subscribedShops': newSubscribed,
                    });
                    if (mounted) Navigator.pop(context);
                    _showQRDialog(shop);
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.black87),
                  child: Text(isSubscribed ? 'Отписаться от уведомлений' : 'Подписаться на акции'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.black87),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _showFirstChoice() async {
    if (_allShops.isEmpty) return;
    var available = _allShops.where((s) => !_usedShopIds.contains(s.id)).toList();
    if (available.isEmpty) return;
    available.shuffle();
    final first = available.take(2).toList();
    if (first.isEmpty) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Начни свой путь!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Выбери магазин, с которого начнёшь:'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _forkButton(first[0], isCollab: false),
                if (first.length > 1) _forkButton(first[1], isCollab: false),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _pendingForkShops = first;
                _isPathActive = true;
              });
              _saveProgress();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.black87),
            child: const Text('Позже (продолжить позже)'),
          ),
        ],
      ),
    );
  }

  Future<void> _resumePath() async {
    if (_completedSteps == 0) {
      _showFirstChoice();
      return;
    }

    if (_lastShop != null) {
      await _showForkDialog(_lastShop!);
      return;
    }

    if (_lastShopId != null) {
      final doc = await _firestore.collection('shops').doc(_lastShopId).get();
      if (doc.exists) {
        final shop = Shop.fromFirestore(doc);
        setState(() => _lastShop = shop);
        await _showForkDialog(shop);
        return;
      }
    }

    if (_usedShopIds.isNotEmpty) {
      final lastUsedId = _usedShopIds.last;
      final doc = await _firestore.collection('shops').doc(lastUsedId).get();
      if (doc.exists) {
        final shop = Shop.fromFirestore(doc);
        setState(() {
          _lastShop = shop;
          _lastShopId = shop.id;
        });
        await _saveProgress();
        await _showForkDialog(shop);
        return;
      }
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Нет данных'),
          content: const Text('Не удалось найти последний магазин. Сбросить прогресс?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _resetProgress();
              },
              child: const Text('Сбросить'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildMainContent() {
    if (_pendingForkShops != null && _pendingForkShops!.length == 2) {
      return SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Text(
                'Продолжите путь, выбрав один из магазинов:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PendingShopButton(shop: _pendingForkShops![0], onTap: _activateShop),
                const SizedBox(width: 20),
                _PendingShopButton(shop: _pendingForkShops![1], onTap: _activateShop),
              ],
            ),
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton(
                onPressed: () => _resetProgress(),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                child: const Text('Остановить путь'),
              ),
            ),
          ],
        ),
      );
    }

    if (_isPathActive) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Text(
                'Продолжайте путь, выбирая предложенные варианты',
                style: TextStyle(color: Colors.black87),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _resumePath,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Продолжить путь', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      );
    }

    return _buildShopIconsGrid();
  }

  Widget _buildShopIconsGrid() {
    if (_allShops.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(40),
          ),
          child: const Text('Нет магазинов в этом ТЦ'),
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: _allShops.map((shop) => _ShopCard(shop: shop, onTap: _activateShop)).toList(),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _showFirstChoice,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
            ),
            child: const Text('Начать путь', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const GradientScaffold(
        appBar: PreferredSize(preferredSize: Size.fromHeight(56), child: SizedBox.shrink()),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_selectedMallId == null) {
      return GradientScaffold(
        appBar: AppBar(title: const Text('Offline Deals')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Выберите город и торговый центр',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Offline Deals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: () => _showLocationPicker(isChanging: true),
            tooltip: 'Сменить город/ТЦ',
          ),
          IconButton(onPressed: _fullReset, icon: const Icon(Icons.refresh), tooltip: 'Сброс прогресса'),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(_totalSteps, (index) => _stepCircle(index)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Цикл $_cycleCount – Прогресс: $_completedSteps / $_totalSteps',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
                if (_selectedCity != null && _selectedMall != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${_selectedCity!}, ${_selectedMall!}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          BannersCarousel(
            onActivateShop: (shop) async => _activateShop(shop),
            mallId: _selectedMallId,
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }

  Widget _stepCircle(int index) {
    bool completed = index < _completedSteps;
    bool current = index == _completedSteps && _completedSteps < _totalSteps;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completed
                ? colorScheme.tertiary
                : (current ? colorScheme.primary : Colors.white.withOpacity(0.25)),
          ),
          child: Center(
            child: completed
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: current ? Colors.white : Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Шаг ${index + 1}',
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
      ],
    );
  }
}

// ----- ЭКРАН ПРОФИЛЯ (с настройками пушей и подписками) -----
// ----- ЭКРАН ПРОФИЛЯ (адаптирован под универсальные бонусы) -----
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firestore = FirebaseFirestore.instance;
  late final String _userId;
  int _pushIntervalHours = 1;
  List<String> _subscribedShops = [];
  Map<String, String> _shopNames = {};

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser!.uid;
    _loadPushSettings();
    _loadSubscribedShops();
  }

  Future<void> _loadPushSettings() async {
    final doc = await _firestore.collection('user_progress').doc(_userId).get();
    final data = doc.data();
    if (data != null && data['pushMinIntervalHours'] != null) {
      setState(() => _pushIntervalHours = data['pushMinIntervalHours']);
    }
  }

  Future<void> _loadSubscribedShops() async {
    final doc = await _firestore.collection('user_progress').doc(_userId).get();
    final data = doc.data();
    if (data != null && data['subscribedShops'] != null) {
      final ids = List<String>.from(data['subscribedShops']);
      setState(() => _subscribedShops = ids);
      for (final id in ids) {
        final shopDoc = await _firestore.collection('shops').doc(id).get();
        if (shopDoc.exists) {
          _shopNames[id] = shopDoc.data()?['name'] ?? 'Магазин';
        }
      }
      setState(() {});
    }
  }

  Future<void> _savePushInterval(int hours) async {
    await _firestore.collection('user_progress').doc(_userId).update({
      'pushMinIntervalHours': hours,
    });
    setState(() => _pushIntervalHours = hours);
  }

  Future<void> _unsubscribeFromShop(String shopId) async {
    final doc = await _firestore.collection('user_progress').doc(_userId).get();
    final current = List<String>.from(doc.data()?['subscribedShops'] ?? []);
    final updated = current.where((id) => id != shopId).toList();
    await doc.reference.update({'subscribedShops': updated});
    _loadSubscribedShops();
  }

  // Загружаем сами документы правил (не только ID)
  Future<List<QueryDocumentSnapshot>> _getPendingBonuses() async {
    final userDoc = await _firestore.collection('user_progress').doc(_userId).get();
    final pendingIds = List<String>.from(userDoc.data()?['pendingBonuses'] ?? []);
    if (pendingIds.isEmpty) return [];
    final snapshot = await _firestore
        .collection('bonus_rules')
        .where(FieldPath.documentId, whereIn: pendingIds)
        .get();
    return snapshot.docs;
  }

  // Обновлённый метод получения бонуса – теперь принимает reward (map)
  Future<void> _claimBonus(String ruleId, Map<String, dynamic> rewardData) async {
    final targetShopId = rewardData['targetShopId'] as String? ?? '';
    final bonusDescription = rewardData['title'] as String? ?? 'Бонус';
    final message = rewardData['message'] as String? ?? '';
    final icon = rewardData['icon'] as String? ?? '🎁';

    // Если есть targetShopId – показываем QR с магазином
    if (targetShopId.isNotEmpty) {
      final shopDoc = await _firestore.collection('shops').doc(targetShopId).get();
      if (shopDoc.exists) {
        final targetShop = Shop.fromFirestore(shopDoc);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text('$icon $bonusDescription'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.qr_code_scanner_rounded, size: 120, color: Color(0xFF6C63FF)),
                const SizedBox(height: 16),
                Text(message),
                const SizedBox(height: 8),
                Text('Магазин: ${targetShop.name}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: Colors.black87),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        );
      }
    } else {
      // Бонус без конкретного магазина (например, значок)
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('$icon $bonusDescription'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }

    // Удаляем из pending, добавляем в claimed
    await _firestore.collection('user_progress').doc(_userId).update({
      'pendingBonuses': FieldValue.arrayRemove([ruleId]),
      'claimedBonuses': FieldValue.arrayUnion([ruleId]),
    });

    setState(() {}); // обновляем список бонусов
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return GradientScaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(
        children: [
          Center(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12)],
                  ),
                  child: const CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 50, color: Color(0xFF6C63FF)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.email ?? 'Не авторизован',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Выйти'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          const Divider(color: Colors.white54, thickness: 1, indent: 24, endIndent: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Text(
              'Мои бонусы',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          FutureBuilder<List<QueryDocumentSnapshot>>(
            future: _getPendingBonuses(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final bonuses = snapshot.data ?? [];
              if (bonuses.isEmpty) {
                return Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Center(child: Text('У вас пока нет доступных бонусов.')),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: bonuses.length,
                itemBuilder: (context, index) {
                  final rule = bonuses[index];
                  final data = rule.data() as Map<String, dynamic>;
                  final reward = data['reward'] as Map<String, dynamic>? ?? {};
                  final title = reward['title'] ?? 'Бонус';
                  final icon = reward['icon'] ?? '🎁';
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: Text(icon, style: const TextStyle(fontSize: 32)),
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => _claimBonus(rule.id, reward),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Получить'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'Настройки уведомлений',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          Card(
            margin: const EdgeInsets.all(16),
            color: Colors.white.withOpacity(0.9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Минимальный интервал между пушами'),
                      DropdownButton<int>(
                        value: _pushIntervalHours,
                        items: [1, 3, 6, 12, 24].map((hours) {
                          return DropdownMenuItem(value: hours, child: Text('$hours ч'));
                        }).toList(),
                        onChanged: (val) => _savePushInterval(val!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Магазины, на которые вы подписаны:'),
                  ),
                  const SizedBox(height: 8),
                  if (_subscribedShops.isEmpty)
                    const Text('Нет подписок', style: TextStyle(color: Colors.grey))
                  else
                    Column(
                      children: _subscribedShops.map((shopId) {
                        return ListTile(
                          title: Text(_shopNames[shopId] ?? shopId),
                          trailing: IconButton(
                            icon: const Icon(Icons.notifications_off, color: Colors.red),
                            onPressed: () => _unsubscribeFromShop(shopId),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ----- ЗАГЛУШКА ЭКРАНА КАРТЫ -----
class MapPlaceholder extends StatelessWidget {
  const MapPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(title: const Text('Карта скидок')),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(40),
          ),
          child: const Text(
            'Здесь будет карта ТЦ с акциями',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}