import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'mall_map_screen.dart';
import 'models.dart';
import 'dart:math' as math;
import 'quest_history_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'reward_shop_screen.dart';
import 'content_service.dart';

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
      backgroundColor: Colors.white,   // <-- белый фон
      body: body,
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
  scaffoldBackgroundColor: Colors.white,   // белый фон для всего приложения
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF6C63FF),
    primary: const Color(0xFF6C63FF),
    secondary: const Color(0xFFFF6584),
    tertiary: const Color(0xFF00C9A7),
    surface: Colors.white,                // поверхность карточек и т.д.
    onPrimary: Colors.white,              // текст на primary-цвете (кнопки)
    onSurface: Colors.black87,            // основной текст
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
    foregroundColor: Colors.black87,       // тёмные иконки и текст
    titleTextStyle: TextStyle(
      color: Colors.black87,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    iconTheme: IconThemeData(color: Colors.black87),
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
      const MallMapScreen(),
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

// ----- КАРУСЕЛЬ БАННЕРОВ -----
class BannersCarousel extends StatefulWidget {
  final List<BannerAd> banners;
  final Map<String, Shop> shopById;
  final void Function(Shop shop)? onActivateShop;
  final double height;

  const BannersCarousel({
    super.key,
    required this.banners,
    required this.shopById,
    this.onActivateShop,
    this.height = 160,
  });

  @override
  State<BannersCarousel> createState() => _BannersCarouselState();
}

class _BannersCarouselState extends State<BannersCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(covariant BannersCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners != widget.banners) {
      _currentPage = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _restartAutoScroll();
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    if (widget.banners.length <= 1) return;

    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients || widget.banners.isEmpty) {
        return;
      }
      final next = (_currentPage + 1) % widget.banners.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    });
  }

  void _restartAutoScroll() => _startAutoScroll();

  Shop? _shopFor(BannerAd banner) {
    final id = banner.targetShopId;
    if (id.isEmpty) return null;
    return widget.shopById[id];
  }

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;

    if (banners.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F5F8),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Center(child: Text('Нет активных баннеров')),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            itemCount: banners.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              _restartAutoScroll();
            },
            itemBuilder: (context, index) {
              final banner = banners[index];
              return BannerItem(
                banner: banner,
                targetShop: _shopFor(banner),
                onActivate: (shop) => widget.onActivateShop?.call(shop),
              );
            },
          ),
        ),
        if (banners.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(banners.length, (index) {
              final active = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF6C63FF)
                      : const Color(0xFF6C63FF).withOpacity(0.22),
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class BannerItem extends StatelessWidget {
  final BannerAd banner;
  final Shop? targetShop;
  final void Function(Shop shop) onActivate;

  const BannerItem({
    super.key,
    required this.banner,
    required this.targetShop,
    required this.onActivate,
  });

  @override
Widget build(BuildContext context) {
  final shop = targetShop;
  final hasDiscount = banner.discount.trim().isNotEmpty;
  final title = banner.title.isNotEmpty ? banner.title : (shop?.name ?? 'Акция');
  final subtitle = banner.description.isNotEmpty ? banner.description : (shop?.category ?? '');

  Rect? crop;
  if (banner.cropRectData != null && banner.cropRectData!.length == 4) {
    final d = banner.cropRectData!;
    crop = Rect.fromLTWH(d[0], d[1], d[2], d[3]);
  }

  return GestureDetector(
    onTap: shop == null ? null : () async {
      // Логируем клик по баннеру
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('banner_clicks').add({
          'bannerId': banner.id,
          'userId': user.uid,
          'shopId': shop!.id,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      onActivate(shop!);
    },
    child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Color(banner.color).withOpacity(0.28),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ФОН с обрезкой или градиент
            Positioned.fill(
              child: banner.imageUrl.trim().isNotEmpty
                  ? BannerImagePreview(
                      imageUrl: banner.imageUrl,
                      cropRect: crop,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(banner.color),
                            Color(banner.color).withOpacity(0.75),
                          ],
                        ),
                      ),
                    ),
            ),

            // Затемнение
            if (banner.imageUrl.trim().isNotEmpty)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withOpacity(0.55),
                        Colors.black.withOpacity(0.12),
                      ],
                    ),
                  ),
                ),
              ),

            // Контент
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasDiscount)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              banner.discount,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        if (hasDiscount) const SizedBox(height: 8),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, height: 1.15),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                          ),
                        ],
                        if (shop != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            shop.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----- КАРТОЧКА МАГАЗИНА (с иконкой информации и наведением на карту) -----
class _ShopCard extends StatefulWidget {
  final Shop shop;
  final Function(Shop) onTap;
  final VoidCallback? onInfoTap;
  final ValueChanged<String?> onHover;

  const _ShopCard({
    required this.shop,
    required this.onTap,
    this.onInfoTap,
    required this.onHover,
  });

  @override
  State<_ShopCard> createState() => _ShopCardState();
}

class _ShopCardState extends State<_ShopCard> {
  bool _isHovered = false;
  bool _infoHovered = false;

  @override
  Widget build(BuildContext context) {
    final String cardDiscount = widget.shop.shortDiscount.isNotEmpty
        ? widget.shop.shortDiscount
        : widget.shop.discount;

    final Matrix4 transformMatrix = widget.shop.imageTransform != null
        ? Matrix4.fromList(widget.shop.imageTransform!)
        : Matrix4.identity();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _isHovered = true);
        widget.onHover(widget.shop.id);
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        widget.onHover(null);
      },
      child: GestureDetector(
        onTap: () => widget.onTap(widget.shop),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _isHovered ? Matrix4.translationValues(0, -6, 0) : Matrix4.identity(),
          child: Container(
            width: 130,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 10),
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Изображение с иконкой информации
                  Stack(
                    children: [
                      if (widget.shop.imageUrl.isNotEmpty)
                        ClipRect(
                          child: Transform(
                            transform: transformMatrix,
                            child: Image.network(
                              widget.shop.imageUrl,
                              width: double.infinity,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 100,
                                color: Colors.grey[300],
                                child: Center(child: Text(widget.shop.icon, style: const TextStyle(fontSize: 48))),
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 100,
                          color: Colors.grey[300],
                          child: Center(child: Text(widget.shop.icon, style: const TextStyle(fontSize: 48))),
                        ),
                      // Иконка информации
                      if (widget.onInfoTap != null)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: MouseRegion(
                            onEnter: (_) => setState(() => _infoHovered = true),
                            onExit: (_) => setState(() => _infoHovered = false),
                            child: GestureDetector(
                              onTap: widget.onInfoTap,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: _infoHovered ? Colors.black87 : Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.info_outline,
                                  size: _infoHovered ? 14 : 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Нижняя плашка (полупрозрачная)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.02),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        if (cardDiscount.isNotEmpty)
                          Text(
                            cardDiscount,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E7D32),
                            ),
                            textAlign: TextAlign.center,
                          ),
                      ],
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

// ----- КНОПКА ОТЛОЖЕННОГО МАГАЗИНА (с иконкой информации и наведением на карту) -----
class _PendingShopButton extends StatefulWidget {
  final Shop shop;
  final Function(Shop) onTap;
  final VoidCallback? onInfoTap;
  final ValueChanged<String?> onHover;

  const _PendingShopButton({
    required this.shop,
    required this.onTap,
    this.onInfoTap,
    required this.onHover,
  });

  @override
  State<_PendingShopButton> createState() => _PendingShopButtonState();
}

class _PendingShopButtonState extends State<_PendingShopButton> {
  bool _isHovered = false;
  bool _infoHovered = false;

  @override
  Widget build(BuildContext context) {
    final String cardDiscount = widget.shop.shortDiscount.isNotEmpty
        ? widget.shop.shortDiscount
        : widget.shop.discount;

    final Matrix4 transformMatrix = widget.shop.imageTransform != null
        ? Matrix4.fromList(widget.shop.imageTransform!)
        : Matrix4.identity();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _isHovered = true);
        widget.onHover(widget.shop.id);
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        widget.onHover(null);
      },
      child: GestureDetector(
        onTap: () => widget.onTap(widget.shop),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _isHovered ? Matrix4.translationValues(0, -6, 0) : Matrix4.identity(),
          child: Container(
            width: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 10),
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.shop.imageUrl.isNotEmpty)
                    ClipRect(
                      child: Transform(
                        transform: transformMatrix,
                        child: Image.network(
                          widget.shop.imageUrl,
                          width: double.infinity,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 100,
                            color: Colors.grey[300],
                            child: Center(child: Text(widget.shop.icon, style: const TextStyle(fontSize: 48))),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 100,
                      color: Colors.grey[300],
                      child: Center(child: Text(widget.shop.icon, style: const TextStyle(fontSize: 48))),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.02),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(28),
                        bottomRight: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.shop.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        if (cardDiscount.isNotEmpty)
                          Text(
                            cardDiscount,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2e7d32),
                            ),
                            textAlign: TextAlign.center,
                          ),
                      ],
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
// ----- КНОПКА ВЫБОРА В ДИАЛОГЕ (С АНИМАЦИЕЙ) -----
class _ChoiceButton extends StatefulWidget {
  final Shop shop;
  final Function(Shop) onTap;
  final bool isCollab;
  final String? collabDocId;
  final Future<void> Function(String, Shop) onCollabActivated;

  const _ChoiceButton({
    required this.shop,
    required this.onTap,
    this.isCollab = false,
    this.collabDocId,
    required this.onCollabActivated,
  });

  @override
  State<_ChoiceButton> createState() => _ChoiceButtonState();
}

class _ChoiceButtonState extends State<_ChoiceButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final String discountText = widget.shop.shortDiscount.isNotEmpty
        ? widget.shop.shortDiscount
        : widget.shop.discount;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () async {
          Navigator.pop(context); // закрываем диалог

          if (widget.isCollab && widget.collabDocId != null) {
            final firestore = FirebaseFirestore.instance;
            final collabRef = firestore.collection('active_collabs').doc(widget.collabDocId);
            try {
              final collabDoc = await collabRef.get();
              if (collabDoc.exists) {
                final data = collabDoc.data()!;
                final currentClicks = (data['clicks'] as int?) ?? 0;
                await collabRef.update({'clicks': currentClicks + 1});

                final offerId = data['offerId'] as String?;
                final bid = data['bid'] as int?;
                if (offerId != null && bid != null && bid > 0) {
                  final offerRef = firestore.collection('auction_offers').doc(offerId);
                  final offerDoc = await offerRef.get();
                  if (offerDoc.exists) {
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
                }
              }
            } catch (e) {
              print('❌ Ошибка в коллаборации: $e');
            }
            await widget.onCollabActivated('collab_activated', widget.shop);
          }
          widget.onTap(widget.shop);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _isHovered ? Matrix4.translationValues(0, -6, 0) : Matrix4.identity(),
          child: Container(
            width: 130,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.isCollab ? Colors.orange.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: widget.isCollab ? Colors.orange : const Color(0xFF6C63FF).withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: _isHovered
                  ? [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 8))]
                  : [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.shop.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(widget.shop.imageUrl, height: 70, width: 70, fit: BoxFit.cover),
                  )
                else
                  Text(widget.shop.icon, style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                Text(
                  widget.shop.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                if (widget.isCollab)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('🎁 Спецпредложение!', style: TextStyle(fontSize: 10, color: Colors.deepOrange)),
                  ),
                if (discountText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      discountText,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ----- ГЛАВНЫЙ ИГРОВОЙ ЭКРАН (С БЕСКОНЕЧНЫМИ ЦИКЛАМИ, КАРТОЙ И ПОДСВЕТКОЙ) -----
class DealsGameScreen extends StatefulWidget {
  const DealsGameScreen({super.key});

  @override
  State<DealsGameScreen> createState() => _DealsGameScreenState();
}

class _DealsGameScreenState extends State<DealsGameScreen> {
  final _firestore = FirebaseFirestore.instance;
  String? _hoveredShopId;   // ID магазина, на который наведён курсор
  // Поиск и фильтр
String _searchQuery = '';
String? _selectedCategory;
Shop? _selectedRouteShop;   // выбранный магазин для маршрута
final TextEditingController _mapSearchController = TextEditingController();

// Точка входа (можно загружать из Firestore или задать константы)
Offset _entrancePosition = const Offset(0.5, 0.8); // в долях от размеров карты (0..1)

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

  List<BannerAd> _banners = [];
  Map<String, Shop> _shopById = {};

 @override
void initState() {
  super.initState();
  FirebaseFunctions functions = FirebaseFunctions.instance;
  functions.useFunctionsEmulator('localhost', 5001);

  _userId = FirebaseAuth.instance.currentUser!.uid;
  _loadAll();
  FirebaseFirestore.instance.collection('user_progress').doc(_userId).update({
    'lastActive': FieldValue.serverTimestamp(),
  });

  // Загружаем контент CMS (правила, приветствие и т.д.)
  ContentService.preload(['home_welcome', 'quest_rules']);
}
  Future<void> _ensureDailyTasks() async {
  final doc = await _firestore.collection('user_progress').doc(_userId).get();
  final data = doc.data() ?? {};
  final lastGenerated = (data['dailyTasksGeneratedAt'] as Timestamp?)?.toDate();
  final now = DateTime.now();

  // Генерируем, если ещё не сгенерированы сегодня
  if (lastGenerated == null || lastGenerated.day != now.day || lastGenerated.month != now.month || lastGenerated.year != now.year) {
    final tasks = _generateDailyTasks();
    await _firestore.collection('user_progress').doc(_userId).update({
      'dailyTasks': tasks,
      'dailyTasksGeneratedAt': Timestamp.fromDate(now),
    });
  }
}

List<Map<String, dynamic>> _generateDailyTasks() {
  final categories = _allShops.map((s) => s.category).where((c) => c.isNotEmpty).toSet().toList();
  final randomCategory = categories.isNotEmpty ? categories[math.Random().nextInt(categories.length)] : 'cafe';

  return [
    {
      'id': 'task_1',
      'type': 'complete_quest',
      'description': 'Завершите один квест',
      'reward': 50,
      'progress': 0,
      'target': 1,
      'completed': false,
    },
    {
      'id': 'task_2',
      'type': 'visit_category',
      'category': randomCategory,
      'description': 'Посетите магазин категории "$randomCategory"',
      'reward': 30,
      'progress': 0,
      'target': 1,
      'completed': false,
    },
    {
      'id': 'task_3',
      'type': 'invite_friend',
      'description': 'Пригласите друга (поделитесь кодом)',
      'reward': 20,
      'progress': 0,
      'target': 1,
      'completed': false,
    },
  ];
}

Future<void> _updateTaskProgress(String type, {String? category}) async {
  final doc = await _firestore.collection('user_progress').doc(_userId).get();
  final data = doc.data() ?? {};
  final tasks = List<Map<String, dynamic>>.from(data['dailyTasks'] ?? []);
  bool changed = false;

  for (int i = 0; i < tasks.length; i++) {
    final task = Map<String, dynamic>.from(tasks[i]);
    if (task['completed'] == true) continue;

    if (task['type'] == type) {
      // Для категорий проверяем совпадение
      if (type == 'visit_category' && category != null && task['category'] != category) continue;

      final newProgress = (task['progress'] as int) + 1;
      task['progress'] = newProgress;
      if (newProgress >= (task['target'] as int)) {
        task['completed'] = true;
        final reward = task['reward'] as int;
        await _firestore.collection('user_progress').doc(_userId).update({
          'coins': FieldValue.increment(reward),
          'dailyTasks': tasks,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Задание выполнено! +$reward монет')),
          );
        }
        changed = true;
        break;
      }
      tasks[i] = task;
      changed = true;
      break;
    }
  }

  if (changed) {
    await _firestore.collection('user_progress').doc(_userId).update({'dailyTasks': tasks});
  }
}

  Future<void> _loadAll() async {
    await _loadUserLocation();
    await _loadShops();
    await _loadBanners();
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
    _shopById = { for (final s in _allShops) s.id : s };
  }

Future<void> _loadBanners() async {
  final snap = await _firestore.collection('banners').where('isActive', isEqualTo: true).get();
  setState(() {
    _banners = snap.docs.map((d) => BannerAd.fromFirestore(d)).toList();
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
        _isPathActive = (data['isPathActive'] as bool?) ?? (completedSteps > 0);
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
        'isPathActive': false,
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
      'isPathActive': _isPathActive,
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
      'isPathActive': false,
    });
    await _loadAll();
  }

  // --- Универсальная проверка бонусов ---
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

      if (conditions['cycleCount'] != null && cycleCount != conditions['cycleCount']) continue;
      if (conditions['stepCount'] != null && completedSteps != conditions['stepCount']) continue;
      if (conditions['minStepsCompleted'] != null && completedSteps < conditions['minStepsCompleted']) continue;
      if (conditions['shopId'] != null && currentShop?.id != conditions['shopId']) continue;
      if (conditions['category'] != null && currentShop?.category != conditions['category']) continue;

      if (rule['oncePerUser'] == true) {
        if (pending.contains(doc.id) || claimed.contains(doc.id)) continue;
      }

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

  // ----- ИНФОРМАЦИОННОЕ ОКНО МАГАЗИНА (вызывается по нажатию на "i") -----
  void _showShopInfo(Shop shop) {
    final infoImage = (shop.infoImageUrl.isNotEmpty) ? shop.infoImageUrl : shop.imageUrl;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final containerWidth = screenWidth * 0.3;
    final imageHeight = containerWidth * (720 / 960);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Center(
        child: FractionallySizedBox(
          widthFactor: 0.3,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (infoImage.isNotEmpty)
                      Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: imageHeight,
                            color: Colors.grey[200],
                            child: Image.network(
                              infoImage,
                              width: double.infinity,
                              height: imageHeight,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: imageHeight,
                                color: Colors.grey[200],
                                alignment: Alignment.center,
                                child: Text(shop.icon, style: const TextStyle(fontSize: 48)),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => Navigator.pop(ctx),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(shop.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          if (shop.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(shop.description, style: const TextStyle(fontSize: 14, height: 1.3)),
                          ],
                          if (shop.discount.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.local_offer, color: Color(0xFF6C63FF), size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      shop.discount,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6C63FF)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (shop.location.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(child: Text(shop.location, style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
                              ],
                            ),
                          ],
                        ],
                      ),
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

  // ----- МИНИ-КАРТА НА ГЛАВНОМ ЭКРАНЕ (С ПОДСВЕТКОЙ) -----
 Widget _buildEnhancedMap() {
  // Уникальные категории для фильтра
  final categories = _allShops
      .map((s) => s.category)
      .where((c) => c.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  // Фильтрованные магазины
  List<Shop> visibleShops = _allShops.where((s) {
    if (_searchQuery.isNotEmpty) {
      return s.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }
    return true;
  }).where((s) {
    if (_selectedCategory != null) return s.category == _selectedCategory;
    return true;
  }).toList();

  return Column(
    children: [
      // Панель поиска и фильтра
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _mapSearchController,
                decoration: InputDecoration(
                  hintText: 'Поиск магазина',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _mapSearchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            const SizedBox(width: 8),
            // Фильтр по категории
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedCategory,
                  hint: const Text('Все категории', style: TextStyle(fontSize: 14)),
                  isDense: true,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Все'),
                    ),
                    ...categories.map((cat) => DropdownMenuItem<String?>(
                          value: cat,
                          child: Text(cat),
                        )),
                  ],
                  onChanged: (val) => setState(() => _selectedCategory = val),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      // Сама карта
      SizedBox(
        height: 300, // можно увеличить для маршрута
        child: LayoutBuilder(
          builder: (context, constraints) {
            const double imageWidth = 2045;
            const double imageHeight = 731;
            final double scaleX = constraints.maxWidth / imageWidth;
            final double scaleY = constraints.maxHeight / imageHeight;
            final double scale = math.min(scaleX, scaleY);
            final double displayWidth = imageWidth * scale;
            final double displayHeight = imageHeight * scale;
            final double offsetX = (constraints.maxWidth - displayWidth) / 2;
            final double offsetY = (constraints.maxHeight - displayHeight) / 2;

            return Stack(
              children: [
                // Фоновое изображение
                Image.asset(
                  'assets/images/mall_map.png',
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  fit: BoxFit.contain,
                ),
                // Слой магазинов (иконки/подсветка)
                ...visibleShops.where((s) => s.mapX != null && s.mapY != null).map((shop) {
                  final bool isHovered = _hoveredShopId == shop.id;
                  final bool isRouteTarget = (_selectedRouteShop?.id == shop.id);
                  if (shop.mapWidth == null || shop.mapHeight == null ||
                      shop.mapWidth! <= 0 || shop.mapHeight! <= 0) {
                    return const SizedBox.shrink();
                  }

                  double w = shop.mapWidth! * imageWidth;
                  double h = shop.mapHeight! * imageHeight;
                  final double xOnImage = shop.mapX! * imageWidth;
                  final double yOnImage = shop.mapY! * imageHeight;
                  final double left = (xOnImage - w / 2) * scale + offsetX;
                  final double top = (yOnImage - h / 2) * scale + offsetY;
                  final double rectWidth = w * scale;
                  final double rectHeight = h * scale;

                  return Positioned(
                    left: left,
                    top: top,
                    width: rectWidth,
                    height: rectHeight,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedRouteShop = shop;
                          _hoveredShopId = shop.id; // показываем подсветку
                        });
                      },
                      child: MouseRegion(
                        onEnter: (_) => setState(() => _hoveredShopId = shop.id),
                        onExit: (_) => setState(() => _hoveredShopId = null),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: (isHovered || isRouteTarget)
                                ? Colors.orange.withOpacity(0.4)
                                : Colors.transparent,
                            border: Border.all(
                              color: isRouteTarget
                                  ? Colors.red
                                  : (isHovered ? Colors.orange : Colors.transparent),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
                // Слой маршрута
                if (_selectedRouteShop != null)
                  CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: _RoutePainter(
                      from: Offset(
                        _entrancePosition.dx * imageWidth * scale + offsetX,
                        _entrancePosition.dy * imageHeight * scale + offsetY,
                      ),
                      to: Offset(
                        _selectedRouteShop!.mapX! * imageWidth * scale + offsetX,
                        _selectedRouteShop!.mapY! * imageHeight * scale + offsetY,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      // Кнопка сброса маршрута
      if (_selectedRouteShop != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: TextButton.icon(
            icon: const Icon(Icons.close, size: 16),
            label: Text('Сбросить маршрут до ${_selectedRouteShop!.name}'),
            onPressed: () => setState(() => _selectedRouteShop = null),
          ),
        ),
        // ... начало метода до карты ...

      // Кнопка сброса маршрута
      if (_selectedRouteShop != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: TextButton.icon(
            icon: const Icon(Icons.close, size: 16),
            label: Text('Сбросить маршрут до ${_selectedRouteShop!.name}'),
            onPressed: () => setState(() {
              _selectedRouteShop = null;
              _hoveredShopId = null;
            }),
          ),
        ),

      // Информация о выбранном магазине и кнопка "В путь"
      if (_selectedRouteShop != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Card(
            color: Colors.orange.shade50,
            child: ListTile(
              leading: Text(_selectedRouteShop!.icon, style: const TextStyle(fontSize: 32)),
              title: Text(_selectedRouteShop!.name),
              subtitle: Text(_selectedRouteShop!.discount),
              trailing: ElevatedButton(
                onPressed: () {
                  _activateShop(_selectedRouteShop!);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                ),
                child: const Text('В путь'),
              ),
            ),
          ),
        ),
    ],
  );
}
  // ----- ОСТАЛЬНЫЕ МЕТОДЫ КВЕСТА (без изменений) -----
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

    final collab = await _getActiveCollab(currentShop);
    final hasCollab = collab != null;
    final toShop = hasCollab ? collab!['toShop'] as Shop : null;
    final collabDocId = hasCollab ? collab!['collabDocId'] as String : null;

    if (hasCollab) {
      nextShops.removeWhere((shop) => shop.id == toShop!.id);
    }

    if (nextShops.isEmpty && !hasCollab) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет доступных магазинов для продолжения. Сбросьте прогресс.')),
        );
      }
      return;
    }

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
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                for (final shop in nextShops)
                  _ChoiceButton(
                    shop: shop,
                    onTap: _activateShop,
                    isCollab: false,
                    onCollabActivated: (trigger, shop) => _checkBonuses(trigger, currentShop: shop),
                  ),
                if (hasCollab)
                  _ChoiceButton(
                    shop: toShop!,
                    onTap: _activateShop,
                    isCollab: true,
                    collabDocId: collabDocId,
                    onCollabActivated: (trigger, shop) => _checkBonuses(trigger, currentShop: shop),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _pendingForkShops = nextShops.isNotEmpty ? nextShops : null;
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
    final String discountText = shop.shortDiscount.isNotEmpty ? shop.shortDiscount : shop.discount;

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
              await _checkBonuses('collab_activated', currentShop: shop);
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
              Text(discountText, style: const TextStyle(fontSize: 12)),
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
    await _updateTaskProgress('visit_category', category: shop.category);
    await _checkBonuses('step_completed', currentShop: shop);

    if (_completedSteps == _totalSteps) {
      _startNewCycle();
    } else {
      await _showForkDialog(shop);
    }
  }

  Future<void> _startNewCycle() async {
    final newCycleCount = _cycleCount + 1;
    await _firestore.collection('user_progress').doc(_userId).update({
      'cycleCount': newCycleCount,
      'completedSteps': 0,
      'usedShopIds': [],
      'pendingForkShops': [],
      'lastShopId': null,
      'isPathActive': true,
    });

    // ---------- Реферальный бонус ----------
    final userDoc = await _firestore.collection('user_progress').doc(_userId).get();
    final referredBy = userDoc.data()?['referredBy'] as String?;
    if (referredBy != null) {
      final referrerBonus = {
        'title': 'Реферальный бонус',
        'message': 'Ваш друг завершил первый квест!',
        'icon': '🎁',
      };
      final selfBonus = {
        'title': 'Бонус за использование кода',
        'message': 'Вы завершили первый квест по приглашению!',
        'icon': '🎉',
      };

      await _firestore.collection('user_progress').doc(referredBy).update({
        'pendingBonuses': FieldValue.arrayUnion([referrerBonus]),
      });
      await _firestore.collection('user_progress').doc(_userId).update({
        'pendingBonuses': FieldValue.arrayUnion([selfBonus]),
        'referredBy': FieldValue.delete(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Поздравляем! Вы и ваш друг получили бонусы!')),
        );
      }
    }

    setState(() {
      _completedSteps = 0;
      _usedShopIds.clear();
      _cycleCount = newCycleCount;
      _isPathActive = true;
      _pendingForkShops = null;
      _lastShop = null;
      _lastShopId = null;
    });
await _updateTaskProgress('complete_quest');
    if (!mounted) return;
    await _checkBonuses('cycle_completed');
  }

  Future<void> _showQRDialog(Shop shop) async {
  final userDoc = await _firestore.collection('user_progress').doc(_userId).get();
  final subscribedShops = List<String>.from(userDoc.data()?['subscribedShops'] ?? []);
  final isSubscribed = subscribedShops.contains(shop.id);
  final String discountText = shop.shortDiscount.isNotEmpty ? shop.shortDiscount : shop.discount;

  // Генерируем уникальный токен
  final token = DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
      _userId.substring(0, 4);
  final qrDoc = {
    'token': token,
    'shopId': shop.id,
    'userId': _userId,
    'createdAt': FieldValue.serverTimestamp(),
    'status': 'pending',
  };
  await _firestore.collection('qr_tokens').add(qrDoc);

  // Строим QR-код, содержащий токен (показываем токен текстом)
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(shop.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Здесь можно вставить настоящий QR-код (пакет qr_flutter),
          // но пока отобразим токен крупным шрифтом
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              token,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ),
          const SizedBox(height: 8),
          Text(discountText, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
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
                _PendingShopButton(
                  shop: _pendingForkShops![0],
                  onTap: _activateShop,
                  onInfoTap: () => _showShopInfo(_pendingForkShops![0]),
                  onHover: (id) => setState(() => _hoveredShopId = id),
                ),
                const SizedBox(width: 20),
                _PendingShopButton(
                  shop: _pendingForkShops![1],
                  onTap: _activateShop,
                  onInfoTap: () => _showShopInfo(_pendingForkShops![1]),
                  onHover: (id) => setState(() => _hoveredShopId = id),
                ),
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
            children: _allShops.map((shop) => _ShopCard(
              shop: shop,
              onTap: _activateShop,
              onInfoTap: () => _showShopInfo(shop),
              onHover: (id) => setState(() => _hoveredShopId = id),
            )).toList(),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
  onPressed: _showFirstChoice,
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF6C63FF),
    foregroundColor: Colors.white,
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
    // Оборачиваем всё в SingleChildScrollView, чтобы не было переполнения
    body: SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.9),
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
          // Баннер (можно добавить отступы при необходимости)
          BannersCarousel(
            banners: _banners,
            shopById: _shopById,
            onActivateShop: (shop) => _activateShop(shop),
            height: 168,
          ),
          const SizedBox(height: 16),
          // 🆕 Улучшенная карта
          _buildEnhancedMap(),
          const SizedBox(height: 16),
          // Контент больше не растягивается на весь экран
          _buildMainContent(),
        ],
      ),
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

  // Реферальная система
  String? _referralCode;
  String? _referralStatus;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser!.uid;
    _loadPushSettings();
    _loadSubscribedShops();
    _ensureReferralCode();
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

  Future<void> _claimBonus(String ruleId, Map<String, dynamic> rewardData) async {
    final targetShopId = rewardData['targetShopId'] as String? ?? '';
    final bonusDescription = rewardData['title'] as String? ?? 'Бонус';
    final message = rewardData['message'] as String? ?? '';
    final icon = rewardData['icon'] as String? ?? '🎁';

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
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('$icon $bonusDescription'),
          content: Text(message),
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

    await _firestore.collection('user_progress').doc(_userId).update({
      'pendingBonuses': FieldValue.arrayRemove([ruleId]),
      'claimedBonuses': FieldValue.arrayUnion([ruleId]),
    });
    setState(() {});
  }

  // ================== Реферальная система ==================
  Future<void> _ensureReferralCode() async {
    final doc = await _firestore.collection('user_progress').doc(_userId).get();
    final data = doc.data() ?? {};
    if (data['referralCode'] == null) {
      final code = _generateReferralCode();
      await _firestore.collection('user_progress').doc(_userId).set({
        'referralCode': code,
      }, SetOptions(merge: true));
      setState(() => _referralCode = code);
    } else {
      setState(() => _referralCode = data['referralCode'] as String);
    }
    if (data['referredBy'] != null) {
      setState(() => _referralStatus = 'pending');
    }
  }

  String _generateReferralCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    return List.generate(6, (index) {
      final charIndex = (random.codeUnitAt(index % random.length) + index) % chars.length;
      return chars[charIndex];
    }).join();
  }

  Future<void> _showEnterReferralDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Введите код друга'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'ABC123',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              final code = controller.text.trim().toUpperCase();
              if (code.isEmpty) return;
              final snap = await _firestore
                  .collection('user_progress')
                  .where('referralCode', isEqualTo: code)
                  .limit(1)
                  .get();
              if (snap.docs.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Код не найден')),
                  );
                }
                return;
              }
              final referrerId = snap.docs.first.id;
              if (referrerId == _userId) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Нельзя использовать свой код')),
                  );
                }
                return;
              }
              await _firestore.collection('user_progress').doc(_userId).set({
                'referredBy': referrerId,
              }, SetOptions(merge: true));
              Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Код применён! Завершите первый квест, чтобы получить бонус.')),
                );
                setState(() => _referralStatus = 'pending');
              }
            },
            child: const Text('Применить'),
          ),
        ],
      ),
    );
  }
  // ================== Конец реферальной системы ==================

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
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QuestHistoryScreen()),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('Мои достижения'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                  ),
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
          const SizedBox(height: 16),
          // Карточка "Пригласи друга"
          Card(
            margin: const EdgeInsets.all(16),
            color: Colors.white.withOpacity(0.9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🎁 Пригласи друга',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Ваш персональный код:'),
                  const SizedBox(height: 4),
                  Text(
                    _referralCode ?? '------',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Поделитесь кодом с другом. Когда он завершит первый квест, вы оба получите бонус!',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  if (_referralStatus == 'pending')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Вы ввели код друга. Бонус будет начислен после завершения первого квеста.',
                        style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final text =
                                'Присоединяйся к OfflineDeals и получи скидки!\nМой код: $_referralCode';
                            Share.share(text);
                          },
                          icon: const Icon(Icons.share),
                          label: const Text('Поделиться'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showEnterReferralDialog,
                          icon: const Icon(Icons.edit),
                          label: const Text('Ввести код'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
                    // Карточка монет и ежедневных заданий
          FutureBuilder<DocumentSnapshot>(
            future: _firestore.collection('user_progress').doc(_userId).get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
              final coins = data['coins'] as int? ?? 0;
              final tasks = List<Map<String, dynamic>>.from(data['dailyTasks'] ?? []);

              return Card(
                margin: const EdgeInsets.all(16),
                color: Colors.white.withOpacity(0.9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.monetization_on, color: Colors.amber, size: 28),
                          const SizedBox(width: 8),
                          Text('$coins монет', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          ElevatedButton(
  onPressed: () {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardShopScreen()));
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF6C63FF),
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  child: const Text('Магазин наград'),
),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Ежедневные задания', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...tasks.map((task) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              task['completed'] == true ? Icons.check_circle : Icons.circle_outlined,
                              color: task['completed'] == true ? Colors.green : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(task['description'] ?? '')),
                            Text('+${task['reward'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                            const SizedBox(width: 8),
                            Text('${task['progress'] ?? 0}/${task['target'] ?? 1}', style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
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
class BannerImagePreview extends StatefulWidget {
  final String imageUrl;
  final Rect? cropRect;
  final double width;
  final double height;

  const BannerImagePreview({
    Key? key,
    required this.imageUrl,
    required this.cropRect,
    required this.width,
    required this.height,
  }) : super(key: key);

  @override
  State<BannerImagePreview> createState() => _BannerImagePreviewState();
}

class _BannerImagePreviewState extends State<BannerImagePreview> {
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _loadSize();
  }

  @override
  void didUpdateWidget(covariant BannerImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _imageSize = null;
      _loadSize();
    }
  }

  void _loadSize() {
    if (widget.imageUrl.isEmpty) return;
    Image.network(widget.imageUrl)
        .image
        .resolve(const ImageConfiguration())
        .addListener(ImageStreamListener((info, _) {
      if (mounted) {
        setState(() {
          _imageSize = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        });
      }
    }));
  }

  Widget _buildWithSize(double maxW, double maxH) {
    if (widget.cropRect == null ||
        widget.cropRect!.isEmpty ||
        widget.cropRect!.width == 0 ||
        _imageSize == null) {
      return Image.network(
        widget.imageUrl,
        fit: BoxFit.cover,
        width: maxW,
        height: maxH,
        errorBuilder: (_, __, ___) => Container(color: Colors.grey[300]),
      );
    }

    final crop = widget.cropRect!;
    final previewScale = maxW / crop.width;

    return ClipRect(
      child: Stack(
        children: [
          Positioned(
            left: -crop.left * previewScale,
            top: -crop.top * previewScale,
            width: _imageSize!.width * previewScale,
            height: _imageSize!.height * previewScale,
            child: Image.network(
              widget.imageUrl,
              fit: BoxFit.fill,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey[300]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.width.isInfinite || widget.height.isInfinite) {
      return LayoutBuilder(
        builder: (context, constraints) => _buildWithSize(
          constraints.maxWidth.isFinite ? constraints.maxWidth : widget.width,
          constraints.maxHeight.isFinite ? constraints.maxHeight : widget.height,
        ),
      );
    } else {
      return _buildWithSize(widget.width, widget.height);
    }
  }
}
  class _RoutePainter extends CustomPainter {
  final Offset from;
  final Offset to;
  _RoutePainter({required this.from, required this.to});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(from, to, paint);

    // Кружки на концах
    final circlePaint = Paint()..color = Colors.red;
    canvas.drawCircle(from, 6, circlePaint);
    canvas.drawCircle(to, 6, circlePaint);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.from != from || oldDelegate.to != to;
}