import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'mall_map_screen.dart';
import 'models.dart';
import 'dart:math' as math;
import 'quest_history_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'reward_shop_screen.dart';
import 'content_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_widgets.dart';
import 'package:intl/intl.dart';
import 'wheel_of_fortune.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'all_shops_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'category_labels.dart';
import 'map/mall_map_widget.dart';
import 'map/shop_zone.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await supa.Supabase.initialize(
    url: 'https://cthxobhlihzcehlwruyf.supabase.co',
    anonKey: 'sb_publishable_FjQlbyG5efSoCI7YMOrWSg_9kHwkw5A',
  );
  runApp(const OfflineDealsApp());
}

// ----- ОБЩАЯ ОБЁРТКА SCAFFOLD -----
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
      backgroundColor: AppColors.background,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

class OfflineDealsApp extends StatefulWidget {
  const OfflineDealsApp({super.key});
  @override
  State<OfflineDealsApp> createState() => _OfflineDealsAppState();
}

class _OfflineDealsAppState extends State<OfflineDealsApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShopX',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: (context, child) {
        return DefaultTextStyle(
          style: const TextStyle(
            decoration: TextDecoration.none,
            color: Colors.black87,
            fontSize: 14,
            fontFamily: 'Roboto',
            fontWeight: FontWeight.normal,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: StreamBuilder<supa.AuthState>(
        stream: supa.Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = supa.Supabase.instance.client.auth.currentSession;
          if (session == null) return const AuthScreen();
          return const MainScreen();
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
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заполните все поля'), backgroundColor: AppColors.danger),
        );
      }
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final auth = supa.Supabase.instance.client.auth;
      if (_isLogin) {
        await auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
  final email = _emailController.text.trim();
  final password = _passwordController.text.trim();

  await auth.signUp(
    email: email,
    password: password,
    emailRedirectTo: 'http://localhost:3001',
  );

  if (mounted) {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Проверьте почту'),
        content: Text(
          'Мы отправили ссылку для подтверждения на $email.\n\n'
          'Перейдите по ней, и приложение откроется с уже выполненным входом.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }
}
    } on supa.AuthException catch (e) {
      String message = 'Ошибка входа';
      if (e.message.contains('Invalid login credentials')) message = 'Неверный email или пароль';
      if (e.message.contains('User already registered')) message = 'Email уже используется';
      if (e.message.contains('Password should be at least')) message = 'Слабый пароль (минимум 6 символов)';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: const Icon(Icons.storefront_rounded, size: 44, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              const Center(child: ShopXLogo(fontSize: 44)),
              const SizedBox(height: 4),
              Text(
                _isLogin ? 'Войдите, чтобы продолжить' : 'Создайте новый аккаунт',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Пароль',
                  prefixIcon: Icon(Icons.lock_outline, color: AppColors.textSecondary),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isLogin ? 'Войти' : 'Зарегистрироваться'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(
                  _isLogin ? 'Нет аккаунта? Зарегистрируйтесь' : 'Уже есть аккаунт? Войдите',
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

  /// Доступ к состоянию вкладки «Акции»: со страницы магазина нужно
  /// узнать, идёт ли путь, и запустить активацию.
  final GlobalKey<DealsGameScreenState> _questKey =
      GlobalKey<DealsGameScreenState>();

  /// Посещённые магазины. Множество живёт в состоянии вкладки «Акции», а
  /// владеет нотифаером MainScreen: так «Карта» читает его, не завязываясь
  /// на чужое состояние и не перестраивая квест.
  final ValueNotifier<Set<String>> _visitedShopIds =
      ValueNotifier(const <String>{});

  @override
  void initState() {
    super.initState();
    _screens = [
      DealsGameScreen(key: _questKey, visitedShopIdsOut: _visitedShopIds),
      MallMapScreen(
        onStartQuestFromShop: _handleStartQuestFromShop,
        visitedStoreIds: _visitedShopIds,
      ),
      const ProfileScreen(),
    ];
  }

  @override
  void dispose() {
    _visitedShopIds.dispose();
    super.dispose();
  }

  void setTab(int index) {
    if (mounted) setState(() => _selectedIndex = index);
  }

  /// Вызывается со страницы магазина на вкладке «Карта».
  Future<void> _handleStartQuestFromShop(Shop shop) async {
    final quest = _questKey.currentState;
    if (quest == null) return;

    if (quest.isPathActive) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала завершите текущий цикл квеста'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Не активен — переключаемся на вкладку «Акции» и активируем магазин.
    setTab(0);
    await quest.activateShop(shop);
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      // IndexedStack, а не _screens[_selectedIndex]: вкладки должны
      // оставаться в дереве. Иначе со вкладки «Карта» состояние квеста
      // размонтировано, _questKey.currentState == null, и «Начать квест»
      // молча ничего не делает. Побочно вкладки больше не перезагружаются
      // при каждом переключении.
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.local_offer_outlined), activeIcon: Icon(Icons.local_offer), label: 'Акции'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'Карта'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Профиль'),
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
    _pageController = PageController(viewportFraction: 1.0);   // ← было 0.92
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
      if (!mounted || !_pageController.hasClients || widget.banners.isEmpty) return;
      final next = (_currentPage + 1) % widget.banners.length;
      _pageController.animateToPage(next,
          duration: const Duration(milliseconds: 420), curve: Curves.easeInOut);
    });
  }

  void _restartAutoScroll() => _startAutoScroll();

  void _goPrev() {
    if (widget.banners.length < 2) return;
    final prev = (_currentPage - 1 + widget.banners.length) % widget.banners.length;
    _pageController.animateToPage(prev,
        duration: const Duration(milliseconds: 320), curve: Curves.easeInOut);
    _restartAutoScroll();
  }

  void _goNext() {
    if (widget.banners.length < 2) return;
    final next = (_currentPage + 1) % widget.banners.length;
    _pageController.animateToPage(next,
        duration: const Duration(milliseconds: 320), curve: Curves.easeInOut);
    _restartAutoScroll();
  }

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
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Center(child: Text('Нет активных баннеров', style: AppTextStyles.bodyMedium)),
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
                  color: active ? AppColors.primary : AppColors.primary.withOpacity(0.22),
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

// ---------- Кнопка-стрелка карусели ----------
class _CarouselArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CarouselArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
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
  final subtitle = banner.description.isNotEmpty
      ? banner.description
      : (shop == null ? '' : categoryLabel(shop.category));

  Rect? crop;
  if (banner.cropRectData != null && banner.cropRectData!.length == 4) {
    final d = banner.cropRectData!;
    crop = Rect.fromLTWH(d[0], d[1], d[2], d[3]);
  }

  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: () => _showBannerDetails(context, banner, shop),
      child: Container(
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: Color(banner.color).withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
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
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasDiscount)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        banner.discount,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (hasDiscount) const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (shop != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      shop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  void _showBannerDetails(BuildContext context, BannerAd banner, Shop? shop) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      title: Text(banner.title.isNotEmpty ? banner.title : (shop?.name ?? 'Акция')),
      content: SizedBox(
        width: 320,   // ← фиксированная ширина, чтобы IntrinsicWidth не падал
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (banner.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: SizedBox(
                    height: 140,             // ← только высота, без width
                    width: double.infinity,  // ← внутри SizedBox это валидно
                    child: Image.network(
                      banner.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.surfaceVariant,
                      ),
                    ),
                  ),
                ),
              if (banner.discount.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.successContainer,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    banner.discount,
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (banner.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(banner.description, style: AppTextStyles.bodyLarge),
              ],
              if (shop != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.store_rounded, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        shop.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Закрыть'),
        ),
      ],
    ),
  );
}
}

// ----- КАРТОЧКА МАГАЗИНА -----
class _ShopCard extends StatefulWidget {
  final Shop shop;
  final VoidCallback onTap;
  final VoidCallback? onInfoTap;
  final ValueChanged<String?> onHover;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final bool isVisited;
  const _ShopCard({
    required this.shop,
    required this.onTap,
    this.onInfoTap,
    required this.onHover,
    this.isFavorite = false,
    this.onToggleFavorite,
    this.isVisited = false,
  });
  @override
  State<_ShopCard> createState() => _ShopCardState();
}

class _ShopCardState extends State<_ShopCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final String cardDiscount = widget.shop.shortDiscount.isNotEmpty
        ? widget.shop.shortDiscount
        : widget.shop.discount;

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
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: _isHovered
              ? Matrix4.translationValues(0, -4, 0)
              : Matrix4.identity(),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: widget.isFavorite
                    ? AppColors.accent.withOpacity(0.4)
                    : AppColors.border,
                width: widget.isFavorite ? 1.5 : 1,
              ),
              boxShadow: _isHovered ? AppShadows.cardHover : AppShadows.card,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Stack(
                children: [
                  // ---------- Основное содержимое карточки ----------
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 90,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: AppColors.surface,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: AppColors.border,
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (widget.shop.imageUrl.isNotEmpty)
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Image.network(
                                    widget.shop.imageUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Center(
                                      child: Text(
                                        widget.shop.icon,
                                        style: const TextStyle(fontSize: 40),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else
                              Center(
                                child: Text(
                                  widget.shop.icon,
                                  style: const TextStyle(fontSize: 40),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.shop.name,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  fontSize: 10,
                                  height: 1.1,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (cardDiscount.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.successContainer,
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.pill),
                                  ),
                                  child: Text(
                                    cardDiscount,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.success,
                                      height: 1.1,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ---------- Кнопки избранного и информации ----------
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Row(
                      children: [
                        if (widget.onToggleFavorite != null)
                          _CircleIconButton(
                            icon: widget.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            iconColor: widget.isFavorite
                                ? AppColors.danger
                                : Colors.white,
                            onTap: widget.onToggleFavorite!,
                          ),
                        if (widget.onToggleFavorite != null &&
                            widget.onInfoTap != null)
                          const SizedBox(width: 2),
                        if (widget.onInfoTap != null)
                          _CircleIconButton(
                            icon: Icons.info_outline,
                            iconColor: Colors.white,
                            onTap: widget.onInfoTap!,
                          ),
                      ],
                    ),
                  ),

                  // ---------- Оверлей "Посещён" ----------
                  if (widget.isVisited)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          color: Colors.black.withOpacity(0.55),
                          child: Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Посещён',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Магазин будет доступен в следующих циклах',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      height: 1.15,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
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

class _CircleIconButton extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  State<_CircleIconButton> createState() => _CircleIconButtonState();
}

class _CircleIconButtonState extends State<_CircleIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: _hovered ? Colors.black87 : Colors.black.withOpacity(0.45),
            shape: BoxShape.circle,
          ),
          child: Icon(widget.icon, size: 8, color: widget.iconColor),
        ),
      ),
    );
  }
}

// ----- КНОПКА ОТЛОЖЕННОГО МАГАЗИНА -----
class _PendingShopButton extends StatefulWidget {
  final Shop shop;
  final Function(Shop) onTap;
  final VoidCallback? onInfoTap;
  final ValueChanged<String?> onHover;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  const _PendingShopButton({
    required this.shop,
    required this.onTap,
    this.onInfoTap,
    required this.onHover,
    this.isFavorite = false,
    this.onToggleFavorite,
  });
  @override
  State<_PendingShopButton> createState() => _PendingShopButtonState();
}

class _PendingShopButtonState extends State<_PendingShopButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final String cardDiscount = widget.shop.shortDiscount.isNotEmpty
        ? widget.shop.shortDiscount
        : widget.shop.discount;

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
          curve: Curves.easeOut,
          transform: _isHovered
              ? Matrix4.translationValues(0, -4, 0)
              : Matrix4.identity(),
          child: SizedBox(
            width: 150,
            height: 250,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
                boxShadow: _isHovered ? AppShadows.cardHover : AppShadows.card,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---------- КАРТИНКА ----------
                    SizedBox(
                      height: 140,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                color: AppColors.surface,
                                border: Border(
                                  bottom: BorderSide(
                                    color: AppColors.border,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (widget.shop.imageUrl.isNotEmpty)
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Image.network(
                                  widget.shop.imageUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Center(
                                    child: Text(
                                      widget.shop.icon,
                                      style: const TextStyle(fontSize: 44),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            Center(
                              child: Text(
                                widget.shop.icon,
                                style: const TextStyle(fontSize: 44),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // ---------- ТЕКСТ ----------
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 6,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.shop.name,
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                height: 1.1,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (cardDiscount.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.successContainer,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.pill),
                                ),
                                child: Text(
                                  cardDiscount,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.success,
                                    height: 1.1,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

// ----- КНОПКА ВЫБОРА В ДИАЛОГЕ -----
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

  Future<void> _handleCollabClick() async {
    if (!widget.isCollab || widget.collabDocId == null) return;
    final client = supa.Supabase.instance.client;
    try {
      final collabDoc = await client
          .from('active_collabs')
          .select()
          .eq('id', widget.collabDocId!)
          .maybeSingle();
      if (collabDoc == null) return;
      final currentClicks = (collabDoc['clicks'] as num?)?.toInt() ?? 0;
      await client
          .from('active_collabs')
          .update({'clicks': currentClicks + 1})
          .eq('id', widget.collabDocId!);
      final offerId = collabDoc['offer_id'] as String?;
      final bid = (collabDoc['bid'] as num?)?.toInt();
      if (offerId != null && bid != null && bid > 0) {
        final offerDoc = await client
            .from('auction_offers')
            .select()
            .eq('id', offerId)
            .maybeSingle();
        if (offerDoc != null) {
          final remaining = (offerDoc['remaining_budget'] as num?)?.toInt() ?? 0;
          if (remaining >= bid) {
            final newRemaining = remaining - bid;
            final updates = <String, dynamic>{'remaining_budget': newRemaining};
            if (newRemaining <= 0) updates['status'] = 'exhausted';
            await client.from('auction_offers').update(updates).eq('id', offerId);
            if (newRemaining <= 0) {
              await client.from('active_collabs').delete().eq('id', widget.collabDocId!);
            }
          } else {
            await client.from('active_collabs').delete().eq('id', widget.collabDocId!);
          }
        }
      }
    } catch (e) {
      print('  Ошибка в коллаборации: $e');
    }
    await widget.onCollabActivated('collab_activated', widget.shop);
  }

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
          Navigator.pop(context);
          if (widget.isCollab) {
            await _handleCollabClick();
          }
          widget.onTap(widget.shop);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: _isHovered
              ? Matrix4.translationValues(0, -4, 0)
              : Matrix4.identity(),
          child: SizedBox(
            width: 150,
            height: 250,
            child: Container(
              decoration: BoxDecoration(
                color: widget.isCollab ? AppColors.accentContainer : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: widget.isCollab ? AppColors.accent : AppColors.border,
                  width: widget.isCollab ? 1.5 : 1,
                ),
                boxShadow: _isHovered ? AppShadows.cardHover : AppShadows.card,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---------- КАРТИНКА ----------
                    SizedBox(
                      height: 140,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                color: AppColors.surface,
                                border: Border(
                                  bottom: BorderSide(
                                    color: AppColors.border,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (widget.shop.imageUrl.isNotEmpty)
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Image.network(
                                  widget.shop.imageUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Center(
                                    child: Text(
                                      widget.shop.icon,
                                      style: const TextStyle(fontSize: 44),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            Center(
                              child: Text(
                                widget.shop.icon,
                                style: const TextStyle(fontSize: 44),
                              ),
                            ),
                          if (widget.isCollab)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.pill),
                                ),
                                child: const Text(
                                  'Спецпредложение',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // ---------- ТЕКСТ ----------
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 6,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.shop.name,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                height: 1.05,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (discountText.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.successContainer,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.pill),
                                ),
                                child: Text(
                                  discountText,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.success,
                                    height: 1.1,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

// ----- ГЛАВНЫЙ ИГРОВОЙ ЭКРАН -----
class DealsGameScreen extends StatefulWidget {
  /// Куда зеркалить множество посещённых магазинов, чтобы его увидели
  /// другие вкладки. null — никто не слушает.
  final ValueNotifier<Set<String>>? visitedShopIdsOut;

  const DealsGameScreen({super.key, this.visitedShopIdsOut});

  @override
  State<DealsGameScreen> createState() => DealsGameScreenState();
}

/// Публичный намеренно: вкладка «Карта» через GlobalKey спрашивает, идёт ли
/// путь, и просит активировать магазин. Логика внутри не меняется.
class DealsGameScreenState extends State<DealsGameScreen> {
  /// Открыто наружу: другие вкладки проверяют, идёт ли сейчас путь.
  bool get isPathActive => _isPathActive;

  /// Публикует снимок посещённых магазинов наружу. Логику самого
  /// множества не меняет — только отдаёт копию слушателям.
  void _publishVisited() {
    widget.visitedShopIdsOut?.value =
        Set<String>.unmodifiable(_allVisitedShopIds);
  }

  /// Открыто наружу: запускает активацию магазина так же, как тап по зоне
  /// на главном экране квеста.
  Future<void> activateShop(Shop shop) => _activateShop(shop);

  String? _hoveredShopId;
  String _searchQuery = '';
  String? _selectedCategory;
  Shop? _selectedRouteShop;

  int _completedSteps = 0;
  final int _totalSteps = 5;
  final Set<String> _usedShopIds = {};
  Set<String> _favoriteShops = {};
  Set<String> _allVisitedShopIds = {};
  bool _allShopsBonusClaimed = false;
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
  String? _lastCafeDate;
  String? _lastElectronicsDate;
  Shop? _pendingQRShop;

  List<BannerAd> _banners = [];
  Map<String, Shop> _shopById = {};
  bool _mapPanLocked = false;
String? _selectedMallMapUrl;
double _mallEntranceX = 0.5;
double _mallEntranceY = 0.9;

  supa.SupabaseClient get _sb => supa.Supabase.instance.client;

  @override
void initState() {
  super.initState();
  _userId = supa.Supabase.instance.client.auth.currentUser!.id;
  _loadAll();
  ContentService.preload(['home_welcome', 'quest_rules']);
}

  Future<void> _ensureDailyTasks() async {
    try {
      final data = await _sb
          .from('user_progress')
          .select('daily_tasks, daily_tasks_generated_at')
          .eq('user_id', _userId)
          .maybeSingle();

      if (data == null) return;

      final lastGeneratedStr = data['daily_tasks_generated_at'] as String?;
      final lastGenerated = lastGeneratedStr != null ? DateTime.tryParse(lastGeneratedStr) : null;
      final now = DateTime.now();

      if (lastGenerated == null ||
          lastGenerated.year != now.year ||
          lastGenerated.month != now.month ||
          lastGenerated.day != now.day) {
        final tasks = _generateDailyTasks();
        await _sb.from('user_progress').update({
          'daily_tasks': tasks,
          'daily_tasks_generated_at': now.toIso8601String(),
        }).eq('user_id', _userId);
      }
    } catch (e) {
      print('❌ _ensureDailyTasks: $e');
    }
  }

  List<Map<String, dynamic>> _generateDailyTasks() {
    final categories = _allShops.map((s) => s.category).where((c) => c.isNotEmpty).toSet().toList();
    final randomCategory = categories.isNotEmpty
        ? categories[math.Random().nextInt(categories.length)]
        : 'cafe';

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
        // Ключ английский — по нему сверяется прогресс; в описании,
        // которое читает пользователь, перевод.
        'category': randomCategory,
        'description':
            'Посетите магазин категории "${categoryLabel(randomCategory)}"',
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

  Future<void> _loadAll() async {
  print('►►► _loadAll start');
  try { await _loadUserLocation(); print('✓ _loadUserLocation'); } catch (e) { print('❌ _loadUserLocation: $e'); }
  try { await _loadShops(); print('✓ _loadShops'); } catch (e) { print('❌ _loadShops: $e'); }
  try { await _loadBanners(); print('✓ _loadBanners'); } catch (e) { print('❌ _loadBanners: $e'); }
  try { await _loadProgress(); print('✓ _loadProgress'); } catch (e) { print('❌ _loadProgress: $e'); }
  try { await _ensureDailyTasks(); print('✓ _ensureDailyTasks'); } catch (e) { print('❌ _ensureDailyTasks: $e'); }
  if (mounted) setState(() => _isLoading = false);
  print('►►► _loadAll done');
  if (_selectedMallId == null) _showLocationPicker();
}

  Future<void> _loadUserLocation() async {
  final data = await _sb
      .from('user_progress')
      .select()
      .eq('user_id', _userId)
      .maybeSingle();
  if (data != null) {
    if (mounted) {
      setState(() {
        _selectedCity = data['selected_city'] as String?;
        _selectedMall = data['selected_mall'] as String?;
        _selectedMallId = data['selected_mall_id'] as String?;
      });
    }
  }

  // Загружаем карту и вход выбранного ТЦ
  if (_selectedMallId != null) {
    try {
      final mall = await _sb
          .from('malls')
          .select('map_image_url, entrance_x, entrance_y')
          .eq('firestore_id', _selectedMallId!)
          .maybeSingle();
      if (mall != null && mounted) {
        setState(() {
          _selectedMallMapUrl = mall['map_image_url'] as String?;
          _mallEntranceX = (mall['entrance_x'] as num?)?.toDouble() ?? 0.5;
          _mallEntranceY = (mall['entrance_y'] as num?)?.toDouble() ?? 0.9;
        });
      }
    } catch (e) {
      print('❌ _loadUserLocation mall: $e');
    }
  }
}

  Future<void> _saveUserLocation(String city, String mall, String mallId) async {
  try {
    await _sb.from('user_progress').upsert({
      'user_id': _userId,
      'email': supa.Supabase.instance.client.auth.currentUser?.email,
      'selected_city': city,
      'selected_mall': mall,
      'selected_mall_id': mallId,
    }, onConflict: 'user_id');
    if (mounted) {
      setState(() {
        _selectedCity = city;
        _selectedMall = mall;
        _selectedMallId = mallId;
      });
    }
  } catch (e) {
    print('❌ _saveUserLocation: $e');
    rethrow;
  }
}

  Future<void> _loadShops() async {
    var query = _sb.from('shops').select();
    if (_selectedMallId != null) {
      query = query.eq('mall_id', _selectedMallId!);
    }
    final data = await query;
    final all = (data as List)
        .map((json) => Shop.fromSupabase(Map<String, dynamic>.from(json)))
        .toList();
    setState(() {
      _allShops = all;
    });
    _shopById = { for (final s in _allShops) s.id : s };
  }

  Future<void> _loadBanners() async {
  try {
    final data = await _sb.from('banners').select().eq('is_active', true);
    final banners = (data as List)
        .map((json) => BannerAd.fromSupabase(Map<String, dynamic>.from(json)))
        .toList();
    if (mounted) setState(() => _banners = banners);
  } catch (e) {
    print('❌ _loadBanners: $e');
    if (mounted) setState(() => _banners = []);
  }
}

  Future<void> _loadProgress() async {
    final data = await _sb
        .from('user_progress')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();

    if (data != null) {
      final favList = List<String>.from(data['favorite_shops'] ?? []);
      _allShopsBonusClaimed = data['all_shops_bonus_claimed'] == true;
      _favoriteShops = favList.toSet();
      final visitedAll = List<String>.from(data['all_visited_shop_ids'] ?? []);
      _allVisitedShopIds = visitedAll.toSet();
      _publishVisited();
      _lastCafeDate = data['last_cafe_date'] as String?;
      _lastElectronicsDate = data['last_electronics_date'] as String?;
      final pendingIds = List<String>.from(data['pending_fork_shops'] ?? []);
      List<Shop>? pendingShops;
      if (pendingIds.length == 2 && _allShops.isNotEmpty) {
        pendingShops = _allShops.where((shop) => pendingIds.contains(shop.id)).toList();
        if (pendingShops.length != 2) pendingShops = null;
      }
      final lastId = data['last_shop_id'] as String?;
      Shop? lastShop;
      if (lastId != null && _allShops.isNotEmpty) {
        try { lastShop = _allShops.firstWhere((s) => s.id == lastId); } catch (_) {}
      }
      int completedSteps = (data['completed_steps'] as num?)?.toInt() ?? 0;

      setState(() {
        _completedSteps = completedSteps;
        final usedList = List<String>.from(data['used_shop_ids'] ?? []);
        _usedShopIds.clear();
        _usedShopIds.addAll(usedList);
        _isPathActive = (data['is_path_active'] as bool?) ?? (completedSteps > 0);
        _pendingForkShops = pendingShops;
        _cycleCount = (data['cycle_count'] as num?)?.toInt() ?? 0;
        _lastShopId = lastId;
        _lastShop = lastShop;
      });
      // асинхронно обновляем last_active, не блокируя UI
//Future.microtask(() async {
  //try {
    //await _sb.from('user_progress').update({
      //'last_active': DateTime.now().toIso8601String(),
    //}).eq('user_id', _userId);
  //} catch (_) {}
//});
    } else {
  await _sb.from('user_progress').insert({
    'user_id': _userId,
    'email': supa.Supabase.instance.client.auth.currentUser?.email,
    'completed_steps': 0,
    'used_shop_ids': <String>[],
    'pending_bonuses': <dynamic>[],
    'claimed_bonuses': <dynamic>[],
    'pending_fork_shops': <String>[],
    'subscribed_shops': <String>[],
    'push_min_interval_hours': 1,
    'cycle_count': 0,
    'is_path_active': false,
    'favorite_shops': <String>[],
    'all_shops_bonus_claimed': false,
    'last_active': DateTime.now().toIso8601String(),
  });

  // Локально обнуляем состояние, чтобы UI не показывал старые данные
  if (mounted) {
    setState(() {
      _completedSteps = 0;
      _cycleCount = 0;
      _usedShopIds.clear();
      _allVisitedShopIds.clear();
      _publishVisited();
      _favoriteShops.clear();
      _selectedCity = null;
      _selectedMall = null;
      _selectedMallId = null;
      _isPathActive = false;
      _lastShop = null;
      _lastShopId = null;
      _pendingForkShops = null;
      _lastCafeDate = null;
      _lastElectronicsDate = null;
    });
  }
}
}

  Future<void> _saveProgress() async {
    final pendingIds = _pendingForkShops?.map((s) => s.id).toList() ?? [];
    await _sb.from('user_progress').update({
      'completed_steps': _completedSteps,
      'used_shop_ids': _usedShopIds.toList(),
      'pending_fork_shops': pendingIds,
      'cycle_count': _cycleCount,
      'last_shop_id': _lastShopId,
      'is_path_active': _isPathActive,
    }).eq('user_id', _userId);
  }

  Future<void> _resetProgress() async {
    setState(() {
      _completedSteps = 0;
      _usedShopIds.clear();
      _isPathActive = false;
      _pendingForkShops = null;
      _pendingQRShop = null;
      _lastShop = null;
      _lastShopId = null;
      _selectedRouteShop = null;
    });
    await _saveProgress();
  }

  Future<void> _fullReset() async {
  setState(() {
    _completedSteps = 0;
    _allVisitedShopIds.clear();
    _publishVisited();
    _usedShopIds.clear();
    _favoriteShops.clear();        // ← добавили
    _isPathActive = false;
    _pendingForkShops = null;
    _pendingQRShop = null;         // ← ЭТО КЛЮЧЕВОЕ, тут был баг
    _selectedCity = null;
    _selectedMall = null;
    _selectedMallId = null;
    _isLoading = true;
    _cycleCount = 0;
    _lastShop = null;
    _lastShopId = null;
    _lastCafeDate = null;
    _lastElectronicsDate = null;
    _selectedRouteShop = null;
  });
  try {
    final deleted = await _sb
        .from('user_progress')
        .delete()
        .eq('user_id', _userId)
        .select();
    print('✅ fullReset: удалено ${deleted.length} строк');
  } catch (e) {
    print('❌ fullReset: $e');
  }
  await _loadAll();
}

  Future<bool> _checkBonuses(String trigger, {Shop? currentShop}) async {
    bool anyBonus = false;
    try {
      final userData = await _sb
          .from('user_progress')
          .select()
          .eq('user_id', _userId)
          .maybeSingle();
      if (userData == null) return false;

      final pending = List<dynamic>.from(userData['pending_bonuses'] ?? []);
final claimed = List<dynamic>.from(userData['claimed_bonuses'] ?? []);

// Универсальная проверка: работает и со строкой (старый формат),
// и с объектом (новый формат)
bool isAlreadyInList(List<dynamic> list, String ruleId) {
  for (final item in list) {
    if (item is String && item == ruleId) return true;
    if (item is Map && (item['ruleId'] == ruleId || item['rule_id'] == ruleId)) {
      return true;
    }
  }
  return false;
}
      final cycleCount = (userData['cycle_count'] as num?)?.toInt() ?? 0;
      final completedSteps = (userData['completed_steps'] as num?)?.toInt() ?? 0;

      final rulesSnap = await _sb
          .from('bonus_rules')
          .select()
          .eq('active', true)
          .eq('trigger', trigger);

      for (final doc in rulesSnap as List) {
        final rule = Map<String, dynamic>.from(doc);
        final conditions = rule['conditions'] as Map<String, dynamic>? ?? {};

        if (conditions['cycleCount'] != null && cycleCount != conditions['cycleCount']) continue;
        if (conditions['stepCount'] != null && completedSteps != conditions['stepCount']) continue;
        if (conditions['minStepsCompleted'] != null && completedSteps < conditions['minStepsCompleted']) continue;
        if (conditions['shopId'] != null && currentShop?.id != conditions['shopId']) continue;
        if (conditions['category'] != null && currentShop?.category != conditions['category']) continue;

        if (rule['once_per_user'] == true) {
  if (isAlreadyInList(pending, rule['id'] as String) ||
      isAlreadyInList(claimed, rule['id'] as String)) {
    continue;
  }
}
        final reward = rule['reward'] as Map<String, dynamic>? ?? {};
        final newPending = List<dynamic>.from(pending)
  ..add({
    'ruleId': rule['id'],
    'title': reward['title'] ?? 'Бонус',
    'message': reward['message'] ?? '',
    'icon': reward['icon'] ?? '🎁',
    'targetShopId': reward['targetShopId'] ?? '',
    'coins': (reward['coins'] as num?)?.toInt() ?? 0,
  });
        await _sb.from('user_progress').update({'pending_bonuses': newPending}).eq('user_id', _userId);
        anyBonus = true;

        if (mounted) {
          final reward = rule['reward'] as Map<String, dynamic>? ?? {};
          final title = reward['title'] ?? 'Новый бонус!';
          final message = reward['message'] ?? 'Зайдите в профиль, чтобы получить.';
          final icon = reward['icon'] ?? '🎁';
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text('$icon $title'),
              content: Text(message),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Позже')),
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
    } catch (e) {
      print('❌ _checkBonuses: $e');
    }
    return anyBonus;
  }

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
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
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
                            color: AppColors.surfaceVariant,
                            child: Image.network(
                              infoImage,
                              width: double.infinity,
                              height: imageHeight,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: imageHeight,
                                color: AppColors.surfaceVariant,
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
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(shop.name, style: AppTextStyles.headline),
                          if (shop.description.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(shop.description, style: AppTextStyles.bodyLarge),
                          ],
                          if (shop.discount.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.local_offer, color: AppColors.primary, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      shop.discount,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (shop.location.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Expanded(child: Text(shop.location, style: AppTextStyles.caption)),
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

  List<Shop> _getVisibleShops() {
    return _allShops.where((s) {
      if (_searchQuery.isNotEmpty) {
        return s.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }
      return true;
    }).where((s) {
      if (_selectedCategory != null) {
        return s.category.toLowerCase() == _selectedCategory!.toLowerCase();
      }
      return true;
    }).toList();
  }

  Widget _buildEnhancedMap() {
  final mapUrl = _selectedMallMapUrl ?? '';
  if (mapUrl.isEmpty) {
    return const SizedBox(
      height: 240,
      child: Center(child: Text('Карта ТЦ ещё не загружена')),
    );
  }

  // Берём только магазины с полностью заданной зоной: ниже координаты
  // разыменовываются, и одного null достаточно, чтобы уронить экран.
  final mallStores = _allShops
      .where((s) =>
          s.mapX != null &&
          s.mapY != null &&
          s.mapWidth != null &&
          s.mapHeight != null &&
          s.mapWidth! > 0 &&
          s.mapHeight! > 0)
      .map((s) {
        final entry = (s.entryX != null && s.entryY != null)
            ? Offset(s.entryX!, s.entryY!)
            : null;

        // Ручной якорь подписи: оба поля или ничего.
        final labelOverride = (s.labelX != null && s.labelY != null)
            ? Offset(s.labelX!, s.labelY!)
            : null;

        ShopZone? zone;
        final polygonRaw = s.rawMapPolygon;
        if (polygonRaw != null) {
          zone = ShopZone.fromDb({
            'map_polygon': polygonRaw,
            'entry_x': s.entryX,
            'entry_y': s.entryY,
            'label_x': s.labelX,
            'label_y': s.labelY,
            'label_angle': s.rawLabelAngle,
            'label_rect': s.rawLabelRect,
            'label_polygon': s.rawLabelPolygon,
          });
        }
        // Полигон битый или его нет — падаем назад на прямоугольник.
        zone ??= ShopZone.fromRect(
          ShopZone.clampRectToUnit(Rect.fromCenter(
            center: Offset(s.mapX!, s.mapY!),
            width: s.mapWidth!,
            height: s.mapHeight!,
          )),
          entry: entry,
          labelOverride: labelOverride,
          labelAngle: s.rawLabelAngle,
          labelRect: ShopZone.parseLabelRect(s.rawLabelRect),
          labelPolygon:
              ShopZone.readLabelPolygon({'label_polygon': s.rawLabelPolygon}),
        );
        return MallStore(id: s.id, name: s.name, zone: zone);
      })
      .toList();

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    child: MallMapWidget(
      mapImageUrl: mapUrl,
      stores: mallStores,
      entrancePosition: Offset(_mallEntranceX, _mallEntranceY),

      // Реальные границы плана внутри PNG: строки 336..1183 из 1536 по
      // высоте, вся ширина. Значение привязано к текущему afimall.png —
      // при замене картинки пересчитать.
      planBounds: const Rect.fromLTRB(0.0, 0.22, 1.0, 0.77),

      selectedStoreId: _selectedRouteShop?.id,
      highlightedStoreIds:
          _pendingForkShops?.map((s) => s.id).toSet() ?? const {},
      visitedStoreIds: _allVisitedShopIds,

      // Превью-режим
      interactive: false,
      autoFrame: true,
      showZoomControls: false,
      height: 240,

      // Превью не зумится, но предел держим общий с вкладкой «Карта» и
      // редактором зон — на случай, если режим когда-нибудь включат.
      minScale: 1.0,
      maxScale: 12.0,

      // Тап по карте открывает полноэкранную вкладку «Карта»
      onTapMap: () {
        context.findAncestorStateOfType<_MainScreenState>()?.setTab(1);
      },

      // Коллбэки не нужны в превью, но оставим — на случай, если
      // пользователь не закрыл полностью
      onStoreSelected: (ms) {
        final shop = _shopById[ms.id];
        if (shop != null) setState(() => _selectedRouteShop = shop);
      },
      onSelectionCleared: () =>
          setState(() => _selectedRouteShop = null),
    ),
  );
}

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
                  try {
                    await _saveUserLocation(selectedCity!, selectedMall!, selectedMallId!);
                    if (isChanging) {
                      await _resetProgress();
                    }
                    if (mounted) Navigator.of(context).pop();
                    await _loadShops();
                    if (mounted) setState(() {});
                  } catch (e) {
                    print('❌ dialog submit: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.danger),
                      );
                    }
                  }
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

  List<Shop> _getAvailableForFork(Shop? currentShop) {
  final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

  // Базовый фильтр: не текущий, не использованный в этом цикле,
  // не нарушает дневное ограничение по cafe/electronics
  bool baseFilter(Shop s) {
    if (currentShop != null && s.id == currentShop.id) return false;
    if (_usedShopIds.contains(s.id)) return false;
    if (s.category == 'cafe' && _lastCafeDate == todayStr) return false;
    if (s.category == 'electronics' && _lastElectronicsDate == todayStr) {
      return false;
    }
    return true;
  }

  final allAvailable = _allShops.where(baseFilter).toList();

  // Приоритет — магазины, где клиент ещё не был
  final newOnly = allAvailable
      .where((s) => !_allVisitedShopIds.contains(s.id))
      .toList();

  if (newOnly.length >= 2) return newOnly;

  // Если новых меньше двух — возвращаем все доступные,
  // чтобы квест не сломался
  return allAvailable;
}

  List<Shop> _getNextTwoShops(Shop currentShop) {
    var available = _getAvailableForFork(currentShop);
    if (available.length < 2) return available;

    final weighted = <Shop>[];
    for (var shop in available) {
      int weight = shop.priority;
      if (_favoriteShops.contains(shop.id)) weight += 3;
      for (int i = 0; i < weight; i++) weighted.add(shop);
    }
    weighted.shuffle();

    final selected = <Shop>[];
    final Set<String> usedCategories = {};

    bool isAllowed(Shop shop) {
      if (shop.category == 'cafe' || shop.category == 'electronics') {
        if (usedCategories.contains(shop.category)) return false;
      }
      return true;
    }

    for (var shop in weighted) {
      if (selected.contains(shop)) continue;
      if (!isAllowed(shop)) continue;
      selected.add(shop);
      usedCategories.add(shop.category);
      if (selected.length == 2) break;
    }

    if (selected.length < 2) {
      for (var shop in weighted) {
        if (selected.contains(shop)) continue;
        selected.add(shop);
        usedCategories.add(shop.category);
        if (selected.length == 2) break;
      }
    }
    return selected;
  }

  Future<Map<String, dynamic>?> _getActiveCollab(Shop currentShop) async {
    try {
      final collabList = await _sb
          .from('active_collabs')
          .select()
          .eq('from_shop_id', currentShop.id)
          .gt('expires', DateTime.now().toIso8601String())
          .limit(1);
      if ((collabList as List).isEmpty) return null;
      final collabData = Map<String, dynamic>.from(collabList.first);
      final toShopData = await _sb
          .from('shops')
          .select()
          .eq('firestore_id', collabData['to_shop_id'])
          .maybeSingle();
      if (toShopData == null) return null;
      final toShop = Shop.fromSupabase(Map<String, dynamic>.from(toShopData));
      return {
        'collab': collabData,
        'toShop': toShop,
        'collabDocId': collabData['id'],
      };
    } catch (e) {
      print('❌ _getActiveCollab: $e');
      return null;
    }
  }

Future<void> _showStartQuestDialog() async {
  final isFirstCycle = _cycleCount == 0;

  // Список магазинов с учётом исключений
  final shops = _allShops.where((s) {
    if (!isFirstCycle && _allVisitedShopIds.contains(s.id)) return false;
    return true;
  }).toList();

  // Если по фильтру пусто — показываем все, чтобы не застрять
  final visibleShops = shops.length >= 2 ? shops : _allShops;

  final searchController = TextEditingController();
  String query = '';
  String? selectedCategory = '';

  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        final categories = visibleShops
            .map((s) => s.category)
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        final filtered = visibleShops.where((s) {
          if (query.isNotEmpty &&
              !s.name.toLowerCase().contains(query.toLowerCase())) {
            return false;
          }
          if (selectedCategory != null &&
              selectedCategory!.isNotEmpty &&
              s.category.toLowerCase() != selectedCategory!.toLowerCase()) {
            return false;
          }
          return true;
        }).toList();

        return Dialog(
          backgroundColor: AppColors.background,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: SizedBox(
            width: 700,
            height: 700,
            child: Column(
              children: [
                // Заголовок
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          isFirstCycle
                              ? 'С чего начнём?'
                              : 'Куда дальше?',
                          style: AppTextStyles.headline,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                // Поиск
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Поиск магазина',
                      prefixIcon: const Icon(Icons.search,
                          color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 0, horizontal: 12),
                    ),
                    onChanged: (v) => setDialogState(() => query = v),
                  ),
                ),
                const SizedBox(height: 8),
                // Категории
                if (categories.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: CategoryChip(
                            label: 'Все',
                            selected: selectedCategory == '',
                            onTap: () => setDialogState(
                                () => selectedCategory = ''),
                          ),
                        ),
                        ...categories.map((cat) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: CategoryChip(
                                // Подпись переведённая, selectedCategory
                                // продолжает хранить ключ из БД.
                                label: categoryLabel(cat),
                                selected: selectedCategory == cat,
                                onTap: () => setDialogState(
                                    () => selectedCategory = cat),
                              ),
                            )),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                // Список магазинов
                Expanded(
                  child: filtered.isEmpty
                      ? const EmptyState(
                          icon: Icons.storefront_outlined,
                          title: 'Ничего не найдено',
                          subtitle: 'Измените запрос или категорию',
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: AppSpacing.md,
                            runSpacing: AppSpacing.md,
                            children: filtered
    .map((shop) => _ShopCard(
          shop: shop,
          onTap: () {
            Navigator.pop(ctx);
            _activateShop(shop);
          },
                                      onHover: (id) => setDialogState(
                                          () => _hoveredShopId = id),
                                    ))
                                .toList(),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
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
        const SnackBar(
          content: Text('Нет доступных магазинов для продолжения. Сбросьте прогресс.'),
        ),
      );
    }
    return;
  }

  try {
    await _sb.from('debug_fork_logs').insert({
      'user_id': _userId,
      'current_shop_id': currentShop.id,
      'current_shop_name': currentShop.name,
      'candidate_shops': nextShops
          .map((s) => {
                'shop_id': s.id,
                'name': s.name,
                'priority': s.priority,
                'is_favorite': _favoriteShops.contains(s.id),
              })
          .toList(),
      'collab_shop_id': hasCollab ? toShop!.id : '',
      'collab_shop_name': hasCollab ? toShop!.name : '',
      'selected_shops': nextShops.take(2).map((s) => s.id).toList(),
    });
  } catch (e) {
    print('❌ debug_fork_logs: $e');
  }

  if (!mounted) return;
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      title: const Text(
        'Выбери путь дальше',
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: double.infinity,
            child: Text(
              'Вы получили скидку. Куда отправимся дальше?',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < nextShops.length; i++) ...[
                Flexible(
                  child: _ChoiceButton(
                    shop: nextShops[i],
                    onTap: _activateShop,
                    isCollab: false,
                    onCollabActivated: (trigger, shop) =>
                        _checkBonuses(trigger, currentShop: shop),
                  ),
                ),
                if (i < nextShops.length - 1 || hasCollab)
                  const SizedBox(width: 8),
              ],
              if (hasCollab)
                Flexible(
                  child: _ChoiceButton(
                    shop: toShop!,
                    onTap: _activateShop,
                    isCollab: true,
                    collabDocId: collabDocId,
                    onCollabActivated: (trigger, shop) =>
                        _checkBonuses(trigger, currentShop: shop),
                  ),
                ),
            ],
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      actions: [
        Row(
          children: [
            Expanded(
  child: TextButton(
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
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      padding: const EdgeInsets.symmetric(vertical: 14),
    ),
    child: const Text(
      'Продолжить позже',
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  ),
),
const SizedBox(width: 8),
Expanded(
  child: TextButton(
    onPressed: () async {
      Navigator.pop(context);
      await _resetProgress();
    },
    style: TextButton.styleFrom(
      foregroundColor: AppColors.danger,
      padding: const EdgeInsets.symmetric(vertical: 14),
    ),
    child: const Text(
      'Сбросить путь',
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  ),
),
          ],
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
              final client = _sb;
              try {
                final collabDoc = await client
                    .from('active_collabs')
                    .select()
                    .eq('id', collabDocId)
                    .maybeSingle();
                if (collabDoc != null) {
                  final currentClicks = (collabDoc['clicks'] as num?)?.toInt() ?? 0;
                  await client.from('active_collabs').update({'clicks': currentClicks + 1}).eq('id', collabDocId);

                  final offerId = collabDoc['offer_id'] as String?;
                  final bid = (collabDoc['bid'] as num?)?.toInt();
                  if (offerId != null && bid != null && bid > 0) {
                    final offerDoc = await client
                        .from('auction_offers')
                        .select()
                        .eq('id', offerId)
                        .maybeSingle();
                    if (offerDoc != null) {
                      final remaining = (offerDoc['remaining_budget'] as num?)?.toInt() ?? 0;
                      if (remaining >= bid) {
                        final newRemaining = remaining - bid;
                        final updates = <String, dynamic>{'remaining_budget': newRemaining};
                        if (newRemaining <= 0) updates['status'] = 'exhausted';
                        await client.from('auction_offers').update(updates).eq('id', offerId);
                        if (newRemaining <= 0) {
                          await client.from('active_collabs').delete().eq('id', collabDocId);
                        }
                      } else {
                        await client.from('active_collabs').delete().eq('id', collabDocId);
                      }
                    }
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
            backgroundColor: isCollab ? AppColors.accent : AppColors.surface,
            foregroundColor: isCollab ? Colors.white : AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(color: isCollab ? AppColors.accent : AppColors.border),
            ),
          ),
          child: Column(
            children: [
              Text(shop.icon, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 4),
              Text(shop.name, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
              if (isCollab) const Text('🎁 Спецпредложение!', style: TextStyle(fontSize: 10)),
              Text(discountText, style: const TextStyle(fontSize: 12, color: AppColors.success)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _activateShop(Shop shop) async {
    if (_usedShopIds.contains(shop.id)) return;
    final confirmed = await _showQRDialog(shop);
    if (confirmed == true) {
      await _completeShopActivation(shop);
    } else {
      setState(() => _pendingQRShop = shop);
    }
  }

  Future<void> _completeShopActivation(Shop shop) async {
    final currentStep = _completedSteps + 1;
    setState(() {
      _usedShopIds.add(shop.id);
      if (_completedSteps < _totalSteps) _completedSteps++;
      _pendingForkShops = null;
      _isPathActive = _completedSteps > 0 && _completedSteps < _totalSteps;
      _lastShop = shop;
      _lastShopId = shop.id;
      _pendingQRShop = null;
    });
    await _saveProgress();

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dateUpdates = <String, dynamic>{};
    if (shop.category == 'cafe') {
      _lastCafeDate = todayStr;
      dateUpdates['last_cafe_date'] = todayStr;
    } else if (shop.category == 'electronics') {
      _lastElectronicsDate = todayStr;
      dateUpdates['last_electronics_date'] = todayStr;
    }

    try {
  final userDoc = await _sb
      .from('user_progress')
      .select('all_visited_shop_ids')
      .eq('user_id', _userId)
      .maybeSingle();
  final visited = List<String>.from(userDoc?['all_visited_shop_ids'] ?? []);
  if (!visited.contains(shop.id)) visited.add(shop.id);
  dateUpdates['all_visited_shop_ids'] = visited;
  await _sb.from('user_progress').update(dateUpdates).eq('user_id', _userId);

  // Локально отмечаем ДО вставки в sales, чтобы не потерять при ошибке
  _allVisitedShopIds.add(shop.id);
  _publishVisited();

  await _sb.from('sales').insert({
    'shop_id': shop.id,
    'user_id': _userId,
    'step': currentStep,
  });
} catch (e) {
  print('❌ sales insert: $e');
}

    await _updateTaskProgress('visit_category', category: shop.category);
    await _checkBonuses('step_completed', currentShop: shop);
    await _checkAllShopsBonus();

    if (_completedSteps == _totalSteps) {
      await _startNewCycle();
    } else {
      await _showForkDialog(shop);
    }
  }

  Future<void> _checkAllShopsBonus() async {
    if (_allShopsBonusClaimed) return;
    try {
      final data = await _sb
          .from('user_progress')
          .select('all_visited_shop_ids, pending_bonuses')
          .eq('user_id', _userId)
          .maybeSingle();
      if (data == null) return;
      final visited = (data['all_visited_shop_ids'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toSet();
      final allShopIds = _allShops.map((s) => s.id).toSet();

      if (allShopIds.isNotEmpty && visited.containsAll(allShopIds)) {
        final bonus = {
          'title': 'Исследователь ТЦ',
          'message': 'Вы посетили все магазины этого ТЦ!',
          'icon': '🌟',
        };
        final pending = List<dynamic>.from(data['pending_bonuses'] ?? []);
        pending.add(bonus);
        await _sb.from('user_progress').update({
          'pending_bonuses': pending,
          'all_shops_bonus_claimed': true,
        }).eq('user_id', _userId);
        if (mounted) setState(() => _allShopsBonusClaimed = true);
      }
    } catch (e) {
      print('❌ _checkAllShopsBonus: $e');
    }
  }

  Future<void> _toggleFavorite(Shop shop) async {
    setState(() {
      if (_favoriteShops.contains(shop.id)) {
        _favoriteShops.remove(shop.id);
      } else {
        _favoriteShops.add(shop.id);
      }
    });
    try {
      await _sb.from('user_progress').update({
        'favorite_shops': _favoriteShops.toList(),
      }).eq('user_id', _userId);
    } catch (e) {
      print('❌ _toggleFavorite: $e');
    }
  }

  Future<void> _showWheelOfFortune() async {
    final prizes = getDefaultWheelPrizes();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WheelOfFortuneDialog(prizes: prizes, userId: _userId),
    );
  }

  Future<void> _startNewCycle() async {
    final newCycleCount = _cycleCount + 1;
    try {
      await _sb.from('user_progress').update({
        'cycle_count': newCycleCount,
        'completed_steps': 0,
        'used_shop_ids': <String>[],
        'pending_fork_shops': <String>[],
        'last_shop_id': null,
        'is_path_active': true,
      }).eq('user_id', _userId);

      final userDoc = await _sb
          .from('user_progress')
          .select('referred_by, pending_bonuses')
          .eq('user_id', _userId)
          .maybeSingle();
      final referredBy = userDoc?['referred_by'] as String?;
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
        final referrerDoc = await _sb
            .from('user_progress')
            .select('pending_bonuses')
            .eq('user_id', referredBy)
            .maybeSingle();
        if (referrerDoc != null) {
          final refPending = List<dynamic>.from(referrerDoc['pending_bonuses'] ?? []);
          refPending.add(referrerBonus);
          await _sb.from('user_progress').update({'pending_bonuses': refPending}).eq('user_id', referredBy);
        }
        final selfPending = List<dynamic>.from(userDoc?['pending_bonuses'] ?? []);
        selfPending.add(selfBonus);
        await _sb.from('user_progress').update({
          'pending_bonuses': selfPending,
          'referred_by': null,
        }).eq('user_id', _userId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Поздравляем! Вы и ваш друг получили бонусы!')),
          );
        }
      }
    } catch (e) {
      print('❌ _startNewCycle: $e');
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
    final bool bonusAdded = await _checkBonuses('cycle_completed');
    if (mounted && !bonusAdded) {
      await _showWheelOfFortune();
    }
  }

  Future<void> _updateTaskProgress(String type, {String? category}) async {
    try {
      final data = await _sb
          .from('user_progress')
          .select('daily_tasks, coins')
          .eq('user_id', _userId)
          .maybeSingle();
      if (data == null) return;
      final tasks = List<Map<String, dynamic>>.from(data['daily_tasks'] ?? []);
      bool changed = false;
      int rewardToAdd = 0;

      for (int i = 0; i < tasks.length; i++) {
        final task = Map<String, dynamic>.from(tasks[i]);
        if (task['completed'] == true) continue;
        if (task['type'] == type) {
          if (type == 'visit_category' && category != null && task['category'] != category) continue;
          final currentProgress = (task['progress'] as num?)?.toInt() ?? 0;
          final newProgress = currentProgress + 1;
          task['progress'] = newProgress;
          if (newProgress >= (task['target'] as num? ?? 1)) {
            task['completed'] = true;
            rewardToAdd = (task['reward'] as num?)?.toInt() ?? 0;
          }
          tasks[i] = task;
          changed = true;
          break;
        }
      }
      if (!changed) return;

      final updates = <String, dynamic>{'daily_tasks': tasks};
      if (rewardToAdd > 0) {
        final currentCoins = (data['coins'] as num?)?.toInt() ?? 0;
        updates['coins'] = currentCoins + rewardToAdd;
      }
      await _sb.from('user_progress').update(updates).eq('user_id', _userId);

      if (rewardToAdd > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Задание выполнено! +$rewardToAdd монет'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('❌ _updateTaskProgress: $e');
    }
  }

  Future<bool?> _showQRDialog(Shop shop) async {
  List<String> subscribedShops = [];
  try {
    final userDoc = await _sb
        .from('user_progress')
        .select('subscribed_shops')
        .eq('user_id', _userId)
        .maybeSingle();
    subscribedShops = List<String>.from(userDoc?['subscribed_shops'] ?? []);
  } catch (e) {
    print('❌ _showQRDialog load: $e');
  }

  final isSubscribed = subscribedShops.contains(shop.id);
  final String discountText =
      shop.shortDiscount.isNotEmpty ? shop.shortDiscount : shop.discount;

  // Генерируем уникальный QR-код для этого визита
  final qrToken = '${_userId}_${DateTime.now().millisecondsSinceEpoch}';
  final qrData = 'SHOPX_QUEST:$qrToken:${shop.id}:${_completedSteps + 1}';

  return await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(shop.name, style: AppTextStyles.headline),
      content: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // QR-код
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Скидка
            if (discountText.isNotEmpty)
              Text(
                discountText,
                style: AppTextStyles.title.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

            const SizedBox(height: 12),

            // Подписка
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSubscribed
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    List<String> newSubscribed;
                    if (isSubscribed) {
                      newSubscribed = subscribedShops
                          .where((id) => id != shop.id)
                          .toList();
                    } else {
                      newSubscribed = [...subscribedShops, shop.id];
                    }
                    try {
                      await _sb.from('user_progress').update({
                        'subscribed_shops': newSubscribed,
                      }).eq('user_id', _userId);
                    } catch (e) {
                      print('❌ subscribe: $e');
                    }
                    if (mounted) Navigator.pop(context);
                    _showQRDialog(shop);
                  },
                  child: Text(
                    isSubscribed
                        ? 'Отписаться от уведомлений'
                        : 'Подписаться на акции',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Кнопка "Я использовал промокод"
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.check),
                label: const Text('Я использовал промокод'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Закрыть'),
        ),
      ],
    ),
  );
}

  Future<void> _showFirstChoice() async {
    if (_allShops.isEmpty) return;
    var available = _getAvailableForFork(null);
    if (available.isEmpty) return;
    available.shuffle();
    final first = available.take(2).toList();
    if (first.isEmpty) return;
    final rules = await ContentService.getContent('quest_rules', defaultValue: 'Пройдите 5 магазинов и получите скидки!');
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Начни свой путь!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(rules, style: AppTextStyles.bodyLarge),
            const SizedBox(height: 16),
            const Text('Выбери магазин, с которого начнёшь:', style: TextStyle(fontWeight: FontWeight.w600)),
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
            style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
            child: const Text('Позже (продолжить позже)'),
          ),
        ],
      ),
    );
  }

  Future<void> _resumePath() async {
    if (_pendingQRShop != null) {
      final confirmed = await _showQRDialog(_pendingQRShop!);
      if (confirmed == true) {
        await _completeShopActivation(_pendingQRShop!);
      }
      return;
    }
    if (_completedSteps == 0) {
      _showFirstChoice();
      return;
    }
    if (_lastShop != null) {
      await _showForkDialog(_lastShop!);
      return;
    }
    if (_lastShopId != null) {
      try {
        final data = await _sb
            .from('shops')
            .select()
            .eq('firestore_id', _lastShopId!)
            .maybeSingle();
        if (data != null) {
          final shop = Shop.fromSupabase(Map<String, dynamic>.from(data));
          if (mounted) setState(() => _lastShop = shop);
          await _showForkDialog(shop);
          return;
        }
      } catch (e) {
        print('❌ _resumePath: $e');
      }
    }
    if (_usedShopIds.isNotEmpty) {
      final lastUsedId = _usedShopIds.last;
      try {
        final data = await _sb
            .from('shops')
            .select()
            .eq('firestore_id', lastUsedId)
            .maybeSingle();
        if (data != null) {
          final shop = Shop.fromSupabase(Map<String, dynamic>.from(data));
          setState(() {
            _lastShop = shop;
            _lastShopId = shop.id;
          });
          await _saveProgress();
          await _showForkDialog(shop);
          return;
        }
      } catch (e) {
        print('❌ _resumePath2: $e');
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

  Widget _buildPendingQRView() {
    final shop = _pendingQRShop!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text('Ожидает QR: ${shop.name}', style: AppTextStyles.headline),
            const SizedBox(height: 8),
            const Text('Покажите QR продавцу, затем подтвердите использование', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final confirmed = await _showQRDialog(shop);
                if (confirmed == true) {
                  await _completeShopActivation(shop);
                }
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Показать QR снова'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_pendingQRShop != null) return _buildPendingQRView();
    if (_pendingForkShops != null && _pendingForkShops!.length == 2) {
      return SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text('Продолжите путь, выбрав один из магазинов:',
                  style: AppTextStyles.title, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            Row(
  mainAxisAlignment: MainAxisAlignment.center,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Flexible(
      child: _PendingShopButton(
        shop: _pendingForkShops![0],
        onTap: _activateShop,
        onInfoTap: () => _showShopInfo(_pendingForkShops![0]),
        onHover: (id) => setState(() => _hoveredShopId = id),
        isFavorite: _favoriteShops.contains(_pendingForkShops![0].id),
        onToggleFavorite: () => _toggleFavorite(_pendingForkShops![0]),
      ),
    ),
    const SizedBox(width: 8),
    Flexible(
      child: _PendingShopButton(
        shop: _pendingForkShops![1],
        onTap: _activateShop,
        onInfoTap: () => _showShopInfo(_pendingForkShops![1]),
        onHover: (id) => setState(() => _hoveredShopId = id),
        isFavorite: _favoriteShops.contains(_pendingForkShops![1].id),
        onToggleFavorite: () => _toggleFavorite(_pendingForkShops![1]),
      ),
    ),
  ],
),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _resetProgress(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Остановить путь'),
            ),
          ],
        ),
      );
    }

    if (_isPathActive && _completedSteps > 0) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppCard(
          child: Column(
            children: [
              Text('Продолжайте путь', style: AppTextStyles.headline),
              const SizedBox(height: 8),
              Text('Выбирайте предложенные варианты, чтобы получить скидки.',
                  style: AppTextStyles.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _resumePath,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
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
  final visibleShops = _getVisibleShops();
  if (visibleShops.isEmpty) {
    return const EmptyState(
      icon: Icons.storefront_outlined,
      title: 'Нет магазинов в этом ТЦ',
      subtitle: 'Выберите другой ТЦ или попробуйте позже',
    );
  }

  const int previewCount = 12;
  final isFirstCycle = _cycleCount == 0;
  // На главной не показываем посещённые — они только в каталоге
  final sourceShops = isFirstCycle
      ? visibleShops
      : visibleShops
          .where((s) => !_allVisitedShopIds.contains(s.id))
          .toList();
  final previewShops = sourceShops.take(previewCount).toList();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionTitle(
        title: 'Магазины',
        trailing: Text(
          '${visibleShops.length} шт.',
          style: AppTextStyles.caption,
        ),
      ),
      Padding(
  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
  child: GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 0.62,
    ),
    itemCount: previewShops.length,
    itemBuilder: (context, index) {
      final shop = previewShops[index];
      return _ShopCard(
        shop: shop,
        onTap: () => _activateShop(shop),
        onHover: (id) => setState(() => _hoveredShopId = id),
      );
    },
  ),
),
const SizedBox(height: AppSpacing.md),

      // ---------- Кнопка "Показать все" ----------
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AllShopsScreen(
                  visitedIds: _allVisitedShopIds,
                  onStartQuest: (shop) => _activateShop(shop),
                ),
              ),
            );
          },
          icon: const Icon(Icons.storefront_outlined),
          label: Text('Показать все ${visibleShops.length} магазинов'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.md),

      // ---------- Кнопка "Начать путь" / "Продолжить путь" ----------
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: ElevatedButton.icon(
          onPressed: _showStartQuestDialog,
          icon: const Icon(Icons.directions_walk),
          label: Text(
            isFirstCycle ? 'Начать путь' : 'Продолжить путь',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
    ],
  );
}

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const GradientScaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_selectedMallId == null) {
      return GradientScaffold(
        appBar: AppBar(title: const ShopXLogo(fontSize: 22)),
        body: const EmptyState(
          icon: Icons.location_city,
          title: 'Выберите город и торговый центр',
          subtitle: 'Нажмите на кнопку, чтобы выбрать',
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showLocationPicker(),
          label: const Text('Выбрать ТЦ'),
          icon: const Icon(Icons.location_on),
        ),
      );
    }

    return GradientScaffold(
      appBar: AppBar(
        title: const ShopXLogo(fontSize: 22),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: () => _showLocationPicker(isChanging: true),
            tooltip: 'Сменить город/ТЦ',
          ),
          IconButton(
            onPressed: _fullReset,
            icon: const Icon(Icons.refresh),
            tooltip: 'Сброс прогресса',
          ),
        ],
      ),
      body: SingleChildScrollView(
  physics: _mapPanLocked
      ? const NeverScrollableScrollPhysics()
      : const ClampingScrollPhysics(),
  child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  QuestStepsBar(totalSteps: _totalSteps, completedSteps: _completedSteps),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Цикл $_cycleCount – Прогресс: $_completedSteps / $_totalSteps',
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (_selectedCity != null && _selectedMall != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text('${_selectedCity!}, ${_selectedMall!}', style: AppTextStyles.caption),
                    ),
                ],
              ),
            ),
            FutureBuilder<String>(
              future: ContentService.getContent('home_welcome', defaultValue: 'Добро пожаловать в квест!'),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text(snapshot.data!, textAlign: TextAlign.center, style: AppTextStyles.bodyLarge),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            BannersCarousel(
              banners: _banners,
              shopById: _shopById,
              onActivateShop: (shop) => _activateShop(shop),
              height: 168,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildEnhancedMap(),
            const SizedBox(height: AppSpacing.md),
            _buildMainContent(),
          ],
        ),
      ),
    );
  }
}

// ----- ЭКРАН ПРОФИЛЯ -----
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final String _userId;
  int _pushIntervalHours = 1;
  int _cycleCount = 0;
  List<String> _subscribedShops = [];
  Map<String, String> _shopNames = {};

  String? _referralCode;
  String? _referralStatus;

  List<Map<String, dynamic>> _pendingBonuses = [];

  supa.SupabaseClient get _sb => supa.Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _userId = supa.Supabase.instance.client.auth.currentUser!.id;
    _loadPushSettings();
    _loadSubscribedShops();
    _ensureReferralCode();
    _loadCycleCount();
    _loadPendingBonuses();
  }

  Future<void> _loadPushSettings() async {
    try {
      final data = await _sb
          .from('user_progress')
          .select('push_min_interval_hours')
          .eq('user_id', _userId)
          .maybeSingle();
      if (data != null && data['push_min_interval_hours'] != null) {
        if (mounted) setState(() => _pushIntervalHours = (data['push_min_interval_hours'] as num).toInt());
      }
    } catch (e) {
      print('❌ _loadPushSettings: $e');
    }
  }

  Future<void> _loadSubscribedShops() async {
    try {
      final data = await _sb
          .from('user_progress')
          .select('subscribed_shops')
          .eq('user_id', _userId)
          .maybeSingle();
      if (data != null && data['subscribed_shops'] != null) {
        final ids = List<String>.from(data['subscribed_shops']);
        if (mounted) setState(() => _subscribedShops = ids);
        for (final id in ids) {
          try {
            final shop = await _sb.from('shops').select('name').eq('firestore_id', id).maybeSingle();
            if (shop != null) _shopNames[id] = shop['name'] ?? 'Магазин';
          } catch (_) {}
        }
        if (mounted) setState(() {});
      }
    } catch (e) {
      print('❌ _loadSubscribedShops: $e');
    }
  }

  Future<void> _savePushInterval(int hours) async {
    try {
      await _sb.from('user_progress').update({
        'push_min_interval_hours': hours,
      }).eq('user_id', _userId);
    } catch (e) {
      print('❌ _savePushInterval: $e');
    }
    if (mounted) setState(() => _pushIntervalHours = hours);
  }

  Future<void> _unsubscribeFromShop(String shopId) async {
    try {
      final data = await _sb
          .from('user_progress')
          .select('subscribed_shops')
          .eq('user_id', _userId)
          .maybeSingle();
      final current = List<String>.from(data?['subscribed_shops'] ?? []);
      final updated = current.where((id) => id != shopId).toList();
      await _sb.from('user_progress').update({'subscribed_shops': updated}).eq('user_id', _userId);
      _loadSubscribedShops();
    } catch (e) {
      print('❌ _unsubscribeFromShop: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getPendingBonuses() async {
    final List<Map<String, dynamic>> bonuses = [];
    try {
      final userDoc = await _sb
          .from('user_progress')
          .select('pending_bonuses')
          .eq('user_id', _userId)
          .maybeSingle();
      final pendingRaw = (userDoc?['pending_bonuses'] as List?) ?? [];

      for (final item in pendingRaw) {
        if (item is String) {
          try {
            final ruleDoc = await _sb.from('bonus_rules').select().eq('id', item).maybeSingle();
            if (ruleDoc != null) {
              final reward = ruleDoc['reward'] as Map<String, dynamic>? ?? {};
              bonuses.add({
                'type': 'rule',
                'ruleId': item,
                'title': reward['title'] ?? 'Бонус',
                'message': reward['message'] ?? '',
                'icon': reward['icon'] ?? '🎁',
                'targetShopId': reward['targetShopId'] ?? '',
              });
            }
          } catch (_) {}
        } else if (item is Map) {
          bonuses.add({
            'type': 'direct',
            'ruleId': null,
            'title': item['title'] ?? 'Бонус',
            'message': item['message'] ?? '',
            'icon': item['icon'] ?? '🎁',
            'targetShopId': item['targetShopId'] ?? '',
          });
        }
      }
    } catch (e) {
      print('❌ _getPendingBonuses: $e');
    }
    return bonuses;
  }

  Future<void> _loadPendingBonuses() async {
    final bonuses = await _getPendingBonuses();
    if (mounted) setState(() => _pendingBonuses = bonuses);
  }

  Future<void> _claimBonus(Map<String, dynamic> bonus) async {
    print('🔵 _claimBonus: $bonus');

    final title = (bonus['title'] ?? 'Бонус').toString();
    final message = (bonus['message'] ?? '').toString();
    final icon = (bonus['icon'] ?? '🎁').toString();
    final targetShopId = (bonus['targetShopId'] ?? '').toString();
    final ruleId = bonus['ruleId']?.toString();

    // --- 1. ОПРЕДЕЛЯЕМ МОНЕТЫ ---
    int coinsAmount = (bonus['coins'] as num?)?.toInt()
        ?? (bonus['amount'] as num?)?.toInt()
        ?? 0;

    // Fallback: если поля coins нет, но в title есть «монет» — парсим число
    if (coinsAmount == 0 && title.toLowerCase().contains('монет')) {
      final match = RegExp(r'\d+').firstMatch(title);
      if (match != null) {
        coinsAmount = int.tryParse(match.group(0)!) ?? 0;
      }
    }

    // ============================================================
    // ВАРИАНТ 1: МОНЕТЫ — начислить и сразу выйти
    // ============================================================
    if (coinsAmount > 0) {
      try {
        final userDoc = await _sb
            .from('user_progress')
            .select('coins, pending_bonuses')
            .eq('user_id', _userId)
            .maybeSingle();

        final currentCoins = (userDoc?['coins'] as num?)?.toInt() ?? 0;
        final pending = List<dynamic>.from(userDoc?['pending_bonuses'] ?? []);

        // Убираем этот бонус из pending
        pending.removeWhere((e) {
          if (e is Map) {
            return e['title'] == title && e['message'] == message;
          }
          return false;
        });

        final newCoins = currentCoins + coinsAmount;

        await _sb.from('user_progress').update({
          'coins': newCoins,
          'pending_bonuses': pending,
        }).eq('user_id', _userId);

        print('✅ Начислено $coinsAmount монет, баланс: $newCoins');

        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('$icon $title'),
            content: Text(
              'Зачислено $coinsAmount монет.\n\nВаш баланс: $newCoins монет.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отлично'),
              ),
            ],
          ),
        );

        if (mounted) await _loadPendingBonuses();
        return;
      } catch (e) {
        print('❌ _claimBonus coins: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.danger),
          );
        }
        return;
      }
    }

    // ============================================================
    // ВАРИАНТ 2: QR-БОНУС С ПРИВЯЗКОЙ К МАГАЗИНУ
    // ============================================================
    if (targetShopId.isNotEmpty) {
      final qrToken = '${_userId}_${DateTime.now().millisecondsSinceEpoch}';
      try {
        var shopDoc = await _sb
            .from('shops')
            .select()
            .eq('firestore_id', targetShopId)
            .maybeSingle();

        // Fallback без учёта регистра
        if (shopDoc == null) {
          final candidates = await _sb.from('shops').select();
          for (final row in (candidates as List)) {
            final id = (row['firestore_id'] ?? '').toString();
            if (id.toLowerCase() == targetShopId.toLowerCase()) {
              shopDoc = Map<String, dynamic>.from(row);
              break;
            }
          }
        }

        if (!mounted) return;

        if (shopDoc == null) {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text('$icon $title'),
              content: Text('$message\n\n⚠️ Магазин "$targetShopId" не найден.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Закрыть'),
                ),
              ],
            ),
          );
          return;
        }

        final shopName = shopDoc['name'] ?? targetShopId;
        final qrData = 'SHOPX_BONUS:$qrToken:$targetShopId:${ruleId ?? ""}';

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text('$icon $title'),
            content: SizedBox(
              width: 260,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Магазин: $shopName',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text(
                    'Покажите QR-код на кассе магазина.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Закрыть'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _markBonusUsed(
                    title: title,
                    message: message,
                    targetShopId: targetShopId,
                    ruleId: ruleId,
                  );
                },
                icon: const Icon(Icons.check),
                label: const Text('Я использовал QR-код'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );

        // Помечаем бонус как issued (чтобы остался в списке с пометкой)
        try {
          final userDoc = await _sb
              .from('user_progress')
              .select('pending_bonuses')
              .eq('user_id', _userId)
              .maybeSingle();
          final pending = List<dynamic>.from(userDoc?['pending_bonuses'] ?? []);
          for (int i = 0; i < pending.length; i++) {
            final item = pending[i];
            if (item is Map && item['title'] == title && item['message'] == message) {
              final updated = Map<String, dynamic>.from(item);
              updated['issued_at'] = DateTime.now().toIso8601String();
              updated['qr_token'] = qrToken;
              updated['status'] = 'issued';
              pending[i] = updated;
              break;
            }
          }
          await _sb.from('user_progress').update({
            'pending_bonuses': pending,
          }).eq('user_id', _userId);
        } catch (e) {
          print('❌ _claimBonus update: $e');
        }

        if (mounted) await _loadPendingBonuses();
        return;
      } catch (e) {
        print('❌ _claimBonus shop: $e');
        return;
      }
    }

    // ============================================================
    // ВАРИАНТ 3: УНИВЕРСАЛЬНЫЙ QR (без привязки к магазину)
    // ============================================================
    final universalToken = '${_userId}_${DateTime.now().millisecondsSinceEpoch}';
    final qrData = 'SHOPX_BONUS:$universalToken:ANY:${ruleId ?? ""}';

    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('$icon $title'),
        content: SizedBox(
          width: 260,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Универсальный промокод.\nПокажите QR-код в любом магазине ТЦ.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _markBonusUsed(
                title: title,
                message: message,
                targetShopId: '',
                ruleId: ruleId,
              );
            },
            icon: const Icon(Icons.check),
            label: const Text('Я использовал QR-код'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markBonusUsed({
  required String title,
  required String message,
  required String targetShopId,
  String? ruleId,
}) async {
  // 1. СНАЧАЛА обновляем user_progress (главное)
  try {
    final userDoc = await _sb
        .from('user_progress')
        .select('pending_bonuses, claimed_bonuses')
        .eq('user_id', _userId)
        .maybeSingle();

    final pending = List<dynamic>.from(userDoc?['pending_bonuses'] ?? []);
    final claimed = List<dynamic>.from(userDoc?['claimed_bonuses'] ?? []);

    // Убираем из pending
    pending.removeWhere((e) {
      if (e is Map) {
        return e['title'] == title && e['message'] == message;
      }
      return false;
    });

    // Добавляем в claimed
    claimed.add({
      'title': title,
      'message': message,
      'used_at': DateTime.now().toIso8601String(),
      'targetShopId': targetShopId,
      'ruleId': ruleId,
    });

    await _sb.from('user_progress').update({
      'pending_bonuses': pending,
      'claimed_bonuses': claimed,
    }).eq('user_id', _userId);

    print('✅ Бонус "$title" убран из pending');
  } catch (e) {
    print('❌ _markBonusUsed update: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.danger),
      );
    }
    return;   // ← если не удалось обновить user_progress — не пишем в sales и не обновляем UI
  }

  // 2. Обновляем UI сразу после успешного апдейта
  if (mounted) {
    await _loadPendingBonuses();
  }

  // 3. Только потом пишем в sales (это уже не критично)
  if (targetShopId.isNotEmpty) {
    try {
      await _sb.from('sales').insert({
        'shop_id': targetShopId,
        'user_id': _userId,
        'step': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ _markBonusUsed sales: $e');
    }
  }

  // 4. Показываем снек
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Бонус использован'),
        backgroundColor: AppColors.success,
      ),
    );
  }
}

  Future<void> _ensureReferralCode() async {
    try {
      final data = await _sb
          .from('user_progress')
          .select('referral_code, referred_by')
          .eq('user_id', _userId)
          .maybeSingle();
      if (data == null) return;
      if (data['referral_code'] == null) {
        final code = _generateReferralCode();
        await _sb.from('user_progress').update({'referral_code': code}).eq('user_id', _userId);
        if (mounted) setState(() => _referralCode = code);
      } else {
        if (mounted) setState(() => _referralCode = data['referral_code'] as String);
      }
      if (data['referred_by'] != null) {
        if (mounted) setState(() => _referralStatus = 'pending');
      }
    } catch (e) {
      print('❌ _ensureReferralCode: $e');
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
          decoration: const InputDecoration(hintText: 'ABC123'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              final code = controller.text.trim().toUpperCase();
              if (code.isEmpty) return;
              try {
                final snap = await _sb
                    .from('user_progress')
                    .select('user_id')
                    .eq('referral_code', code)
                    .limit(1);
                if ((snap as List).isEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Код не найден')));
                  }
                  return;
                }
                final referrerId = snap.first['user_id'] as String;
                if (referrerId == _userId) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нельзя использовать свой код')));
                  }
                  return;
                }
                await _sb.from('user_progress').update({'referred_by': referrerId}).eq('user_id', _userId);
                if (mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Код применён! Завершите первый квест, чтобы получить бонус.')),
                  );
                  setState(() => _referralStatus = 'pending');
                }
              } catch (e) {
                print('❌ _showEnterReferralDialog: $e');
              }
            },
            child: const Text('Применить'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadCycleCount() async {
    try {
      final data = await _sb
          .from('user_progress')
          .select('cycle_count')
          .eq('user_id', _userId)
          .maybeSingle();
      if (data != null && mounted) {
        setState(() => _cycleCount = (data['cycle_count'] as num?)?.toInt() ?? 0);
      }
    } catch (e) {
      print('❌ _loadCycleCount: $e');
    }
  }

  double _getLevelProgress() {
    if (_cycleCount >= 7) return 1.0;
    if (_cycleCount >= 3) return (_cycleCount - 3) / 4;
    return _cycleCount / 3;
  }

  String _getLevelProgressText() {
    final currentLevel = LevelSystem.getCurrentLevel(_cycleCount);
    if (currentLevel == 3) return 'Максимальный уровень достигнут';
    final nextCycle = LevelSystem.getNextLevelCycles(_cycleCount);
    final cyclesRemaining = nextCycle - _cycleCount;
    return 'Осталось циклов до следующего уровня: $cyclesRemaining';
  }

    @override
  Widget build(BuildContext context) {
    final user = supa.Supabase.instance.client.auth.currentUser;
    return GradientScaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primaryContainer,
                  child: const Icon(Icons.person, size: 32, color: AppColors.primary),
                ),
                const SizedBox(height: 6),
                Text(user?.email ?? 'Не авторизован', style: AppTextStyles.title),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Уровень: ${LevelSystem.getLevelName(_cycleCount)}',
                      style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.star, size: 14, color: AppColors.warning),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: _getLevelProgress(),
                  minHeight: 4,
                  backgroundColor: AppColors.surfaceVariant,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 2),
                Text(
                  _getLevelProgressText(),
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 12),
                                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const QuestHistoryScreen()),
                          );
                        },
                        icon: const Icon(Icons.history, size: 16),
                        label: const Text('Достижения',
                            style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            supa.Supabase.instance.client.auth.signOut(),
                        icon: const Icon(Icons.logout, size: 16),
                        label: const Text('Выйти',
                            style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _sb
                .from('user_progress')
                .stream(primaryKey: ['user_id'])
                .eq('user_id', _userId),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data!.first;
              final coins = (data['coins'] as num?)?.toInt() ?? 0;
              final tasks = List<Map<String, dynamic>>.from(data['daily_tasks'] ?? []);

              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CoinBadge(amount: coins),
                        const Spacer(),
                        TextButton(
  onPressed: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RewardShopScreen()),
    );
    if (mounted) await _loadPendingBonuses();
  },
  style: TextButton.styleFrom(
    padding: EdgeInsets.zero,
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    foregroundColor: AppColors.primary,
  ),
  child: const Text('Магазин наград'),
),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
  'Ежедневные задания',
  style: AppTextStyles.title.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w700,
  ),
),
const SizedBox(height: 8),   // ← добавь отступ до заданий
                    ...tasks.map((task) => Padding(
  padding: const EdgeInsets.only(bottom: 4),
  child: Row(
    children: [
      Icon(
        task['completed'] == true ? Icons.check_circle : Icons.circle_outlined,
        color: task['completed'] == true ? AppColors.success : AppColors.textDisabled,
        size: 16,
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          task['description'] ?? '',
          style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
        ),
      ),
      Text('+${task['reward'] ?? 0}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.coin)),
      const SizedBox(width: 6),
      Text('${task['progress'] ?? 0}/${task['target'] ?? 1}',
          style: AppTextStyles.caption.copyWith(fontSize: 11)),
    ],
  ),
)),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // ---- Пригласи друга ----
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
  '🎁 Пригласи друга',
  style: AppTextStyles.title.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w700,
  ),
),
const SizedBox(height: 8),
Text('Ваш код:', style: AppTextStyles.caption),
const SizedBox(height: 2),
Text(
  _referralCode ?? '------',
  style: AppTextStyles.title.copyWith(letterSpacing: 4, fontWeight: FontWeight.w700),
),
const SizedBox(height: 4),
Text(
  'Поделитесь кодом с другом — вы оба получите бонус после его первого квеста.',
  style: AppTextStyles.caption.copyWith(fontSize: 11),
),
                if (_referralStatus == 'pending')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Вы ввели код друга. Бонус будет начислен после завершения первого квеста.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.accent),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
  children: [
    Expanded(
      child: ElevatedButton.icon(
        onPressed: () {
          final text = 'Присоединяйся к ShopX и получи скидки!\nМой код: $_referralCode';
          Share.share(text);
        },
        icon: const Icon(Icons.share, size: 14),
        label: const Text('Поделиться', style: TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    ),
    const SizedBox(width: 6),
    Expanded(
      child: ElevatedButton.icon(
        onPressed: _showEnterReferralDialog,
        icon: const Icon(Icons.edit, size: 14),
        label: const Text('Ввести код', style: TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    ),
  ],
),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ---- Мои бонусы ----
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
  'Мои бонусы',
  style: AppTextStyles.title.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w700,
  ),
),
const SizedBox(height: 8),
                if (_pendingBonuses.isEmpty)
                  const EmptyState(
                    icon: Icons.card_giftcard,
                    title: 'У вас пока нет доступных бонусов.',
                  )
                else
                  ..._pendingBonuses.map((bonus) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Text(bonus['icon'] ?? '🎁', style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            bonus['title'] ?? 'Бонус',
            style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 32,
          child: ElevatedButton(
            onPressed: () => _claimBonus(bonus),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Получить', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    ),
  );
}),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ---- Настройки уведомлений ----
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
  'Настройки уведомлений',
  style: AppTextStyles.title.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w700,
  ),
),
                const SizedBox(height: 8),
                Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Expanded(
      child: Text(
        'Минимальный интервал между пушами',
        style: AppTextStyles.bodyMedium,
      ),
    ),
    const SizedBox(width: 8),
    DropdownButton<int>(
      value: _pushIntervalHours,
      items: [1, 3, 6, 12, 24].map((hours) {
        return DropdownMenuItem(value: hours, child: Text('$hours ч'));
      }).toList(),
      onChanged: (val) => _savePushInterval(val!),
    ),
  ],
),
                const SizedBox(height: 16),
                Text('Магазины, на которые вы подписаны:', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 8),
                if (_subscribedShops.isEmpty)
                  Text('Нет подписок', style: AppTextStyles.caption)
                else
                  ..._subscribedShops.map((shopId) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_shopNames[shopId] ?? shopId),
                    trailing: IconButton(
                      icon: const Icon(Icons.notifications_off, color: AppColors.danger),
                      onPressed: () => _unsubscribeFromShop(shopId),
                    ),
                  )),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ---- FAQ ----
          FutureBuilder<String>(
  future: ContentService.getContent('faq',
      defaultValue: 'Здесь скоро появятся часто задаваемые вопросы.'),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const SizedBox.shrink();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
  '❓ FAQ',
  style: AppTextStyles.title.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w700,
  ),
),
          const SizedBox(height: 12),
          _FaqView(raw: snapshot.data!),
        ],
      ),
    );
  },
),
        ],
      ),
    );
  }
}

class LevelSystem {
  static int getCurrentLevel(int cycleCount) {
    if (cycleCount >= 7) return 3;
    if (cycleCount >= 3) return 2;
    return 1;
  }

  static String getLevelName(int cycleCount) {
    if (cycleCount >= 7) return 'Мастер';
    if (cycleCount >= 3) return 'Исследователь';
    return 'Новичок';
  }

  static int getNextLevelCycles(int cycleCount) {
    if (cycleCount >= 7) return -1;
    if (cycleCount >= 3) return 7;
    return 3;
  }
}

// ----- Вспомогательные виджеты -----
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
  if (widget.cropRect != null &&
      !widget.cropRect!.isEmpty &&
      widget.cropRect!.width > 0 &&
      _imageSize != null) {
    // Режим ручного кропа (если задан в админке)
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
              errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  // Обычный режим: картинка на весь баннер
  return SizedBox(
    width: maxW,
    height: maxH,
    child: Image.network(
      widget.imageUrl,
      fit: BoxFit.cover,
      width: maxW,
      height: maxH,
      errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceVariant),
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

class ShopXLogo extends StatelessWidget {
  final double fontSize;
  final Color? color;

  const ShopXLogo({
    super.key,
    this.fontSize = 28,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? AppColors.textPrimary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Shop',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: baseColor,
            letterSpacing: -0.5,
          ),
        ),
        // «Пьяная» X — наклонена и чуть выше базовой линии
        Transform.translate(
          offset: Offset(0, -fontSize * 0.08),
          child: Transform.rotate(
            angle: -18 * math.pi / 180,   // наклон влево на 18°
            child: Text(
              'X',
              style: TextStyle(
                fontSize: fontSize * 1.1,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                color: AppColors.primary,   // акцентный цвет
                letterSpacing: 0,
                height: 1.0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
class _FaqView extends StatelessWidget {
  final String raw;
  const _FaqView({required this.raw});

  @override
  Widget build(BuildContext context) {
    final blocks = raw
        .split('%%')
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();

    if (blocks.isEmpty) return const SizedBox.shrink();

    // Первый блок — вводный текст (всегда виден)
    final intro = blocks.first;
    // Остальные — пары: заголовок, содержимое
    final sections = <Map<String, String>>[];
    for (int i = 1; i < blocks.length - 1; i += 2) {
      sections.add({'title': blocks[i], 'body': blocks[i + 1]});
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Вводный текст
        Text(
          intro,
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 14,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),

        // Раскрывающиеся секции
        ...sections.map((s) => _FaqSection(
              title: s['title'] ?? '',
              body: s['body'] ?? '',
            )),
      ],
    );
  }
}
class _FaqSection extends StatefulWidget {
  final String title;
  final String body;
  const _FaqSection({required this.title, required this.body});

  @override
  State<_FaqSection> createState() => _FaqSectionState();
}

class _FaqSectionState extends State<_FaqSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Заголовок — тап
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTextStyles.title.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Содержимое — раскрывается
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: _buildBody(widget.body),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(String body) {
    final lines = body.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('• ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  ', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Text(
                    trimmed.substring(2),
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              trimmed,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}