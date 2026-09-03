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

import 'theme/app_theme.dart';
import 'widgets/app_widgets.dart';
import 'package:intl/intl.dart';
import 'wheel_of_fortune.dart';
import 'package:flutter/gestures.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
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

class OfflineDealsApp extends StatelessWidget {
  const OfflineDealsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Deals',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            final user = snapshot.data;
            if (user == null) return const AuthScreen();
            return const MainScreen();
          }
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
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
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля'), backgroundColor: AppColors.danger),
      );
      return;
    }

    setState(() => _isSubmitting = true);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
              Text('Offline Deals', style: AppTextStyles.display),
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
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Center(
            child: Text('Нет активных баннеров', style: AppTextStyles.bodyMedium),
          ),
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
                              borderRadius: BorderRadius.circular(AppRadius.pill),
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

// ----- КАРТОЧКА МАГАЗИНА -----
class _ShopCard extends StatefulWidget {
  final Shop shop;
  final Function(Shop) onTap;
  final VoidCallback? onInfoTap;
  final ValueChanged<String?> onHover;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  const _ShopCard({
    required this.shop,
    required this.onTap,
    this.onInfoTap,
    required this.onHover,
    this.isFavorite = false,
    this.onToggleFavorite,
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
          curve: Curves.easeOut,
          transform: _isHovered ? Matrix4.translationValues(0, -4, 0) : Matrix4.identity(),
          child: Container(
            width: 140,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: widget.isFavorite ? AppColors.accent.withOpacity(0.4) : AppColors.border,
                width: widget.isFavorite ? 1.5 : 1,
              ),
              boxShadow: _isHovered ? AppShadows.cardHover : AppShadows.card,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    children: [
                      if (widget.shop.imageUrl.isNotEmpty)
                        ClipRect(
                          child: Transform(
                            transform: transformMatrix,
                            child: Image.network(
                              widget.shop.imageUrl,
                              width: double.infinity,
                              height: 96,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 96,
                                color: AppColors.surfaceVariant,
                                child: Center(child: Text(widget.shop.icon, style: const TextStyle(fontSize: 40))),
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 96,
                          color: AppColors.surfaceVariant,
                          child: Center(child: Text(widget.shop.icon, style: const TextStyle(fontSize: 40))),
                        ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Row(
                          children: [
                            if (widget.onToggleFavorite != null)
                              _CircleIconButton(
                                icon: widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                                iconColor: widget.isFavorite ? AppColors.danger : Colors.white,
                                onTap: widget.onToggleFavorite!,
                              ),
                            if (widget.onToggleFavorite != null) const SizedBox(width: 6),
                            if (widget.onInfoTap != null)
                              _CircleIconButton(
                                icon: Icons.info_outline,
                                iconColor: Colors.white,
                                onTap: widget.onInfoTap!,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.shop.name,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (cardDiscount.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.successContainer,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              cardDiscount,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                              textAlign: TextAlign.center,
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
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: _hovered ? Colors.black87 : Colors.black.withOpacity(0.45),
            shape: BoxShape.circle,
          ),
          child: Icon(widget.icon, size: 14, color: widget.iconColor),
        ),
      ),
    );
  }
}

// ----- КНОПКА ОТЛОЖЕННОГО МАГАЗИНА (используется в развилке пути) -----
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
          transform: _isHovered ? Matrix4.translationValues(0, -4, 0) : Matrix4.identity(),
          child: Container(
            width: 160,
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
                  Stack(
                    children: [
                      if (widget.shop.imageUrl.isNotEmpty)
                        ClipRect(
                          child: Transform(
                            transform: transformMatrix,
                            child: Image.network(
                              widget.shop.imageUrl,
                              width: double.infinity,
                              height: 110,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 110,
                                color: AppColors.surfaceVariant,
                                child: Center(child: Text(widget.shop.icon, style: const TextStyle(fontSize: 44))),
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 110,
                          color: AppColors.surfaceVariant,
                          child: Center(child: Text(widget.shop.icon, style: const TextStyle(fontSize: 44))),
                        ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Row(
                          children: [
                            if (widget.onToggleFavorite != null)
                              _CircleIconButton(
                                icon: widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                                iconColor: widget.isFavorite ? AppColors.danger : Colors.white,
                                onTap: widget.onToggleFavorite!,
                              ),
                            if (widget.onToggleFavorite != null) const SizedBox(width: 6),
                            if (widget.onInfoTap != null)
                              _CircleIconButton(
                                icon: Icons.info_outline,
                                iconColor: Colors.white,
                                onTap: widget.onInfoTap!,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    child: Column(
                      children: [
                        Text(
                          widget.shop.name,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (cardDiscount.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.successContainer,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              cardDiscount,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                              textAlign: TextAlign.center,
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
        ),
      ),
    );
  }
}

// ----- КНОПКА ВЫБОРА В ДИАЛОГЕ (развилка) -----
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
          Navigator.pop(context);

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
          transform: _isHovered ? Matrix4.translationValues(0, -4, 0) : Matrix4.identity(),
          child: Container(
            width: 140,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.isCollab ? AppColors.accentContainer : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: widget.isCollab ? AppColors.accent : AppColors.border,
                width: widget.isCollab ? 1.5 : 1,
              ),
              boxShadow: _isHovered ? AppShadows.cardHover : AppShadows.card,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.shop.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Image.network(widget.shop.imageUrl, height: 72, width: 72, fit: BoxFit.cover),
                  )
                else
                  Text(widget.shop.icon, style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 10),
                Text(
                  widget.shop.name,
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                if (widget.isCollab)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '🎁 Спецпредложение',
                      style: AppTextStyles.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                    ),
                  ),
                if (discountText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.successContainer,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        discountText,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success),
                        textAlign: TextAlign.center,
                      ),
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

// ----- ГЛАВНЫЙ ИГРОВОЙ ЭКРАН -----
class DealsGameScreen extends StatefulWidget {
  const DealsGameScreen({super.key});

  @override
  State<DealsGameScreen> createState() => _DealsGameScreenState();
}

class _DealsGameScreenState extends State<DealsGameScreen> {
  final _firestore = FirebaseFirestore.instance;
  String? _hoveredShopId;
  String _searchQuery = '';
  String? _selectedCategory;
  Shop? _selectedRouteShop;
  final TextEditingController _mapSearchController = TextEditingController();

  Offset _entrancePosition = const Offset(0.5, 0.8);

  int _completedSteps = 0;
  final int _totalSteps = 5;
  final Set<String> _usedShopIds = {};
  Set<String> _favoriteShops = {};
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
  final TransformationController _mapTransformationController = TransformationController();
  double _mapScale = 1.0;

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

    ContentService.preload(['home_welcome', 'quest_rules']);
  }

  @override
void dispose() {
  _mapSearchController.dispose();
  _mapTransformationController.dispose();
  super.dispose();
}

  Future<void> _ensureDailyTasks() async {
  final doc = await _firestore.collection('user_progress').doc(_userId).get();
  final data = doc.data() ?? {};
  final lastGenerated = (data['dailyTasksGeneratedAt'] as Timestamp?)?.toDate();
  final now = DateTime.now();

  if (lastGenerated == null ||
      lastGenerated.year != now.year ||
      lastGenerated.month != now.month ||
      lastGenerated.day != now.day) {
    final tasks = _generateDailyTasks();
    await _firestore.collection('user_progress').doc(_userId).update({
      'dailyTasks': tasks,
      'dailyTasksGeneratedAt': Timestamp.fromDate(now),
    });
    print('✅ Ежедневные задания сгенерированы: $tasks');
  } else {
    print('ℹ️ Задания уже существуют на сегодня');
  }
}

  List<Map<String, dynamic>> _generateDailyTasks() {
  final categories = _allShops.map((s) => s.category).where((c) => c.isNotEmpty).toSet().toList();
  final randomCategory = categories.isNotEmpty ? categories[math.Random().nextInt(categories.length)] : 'cafe';

  final tasks = [
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
  print('✅ Сгенерированы задачи: $tasks');
  return tasks;
}

 Future<void> _updateTaskProgress(String type, {String? category}) async {
  print('🔔 _updateTaskProgress called: type=$type, category=$category');
  final docRef = _firestore.collection('user_progress').doc(_userId);
  final doc = await docRef.get();
  if (!doc.exists) {
    print('❌ user_progress документ не найден');
    return;
  }
  final data = doc.data()!;
  final tasks = List<Map<String, dynamic>>.from(data['dailyTasks'] ?? []);
  print('📋 Текущие задачи: $tasks');

  bool changed = false;
  int rewardToAdd = 0;

  for (int i = 0; i < tasks.length; i++) {
    final task = Map<String, dynamic>.from(tasks[i]);
    if (task['completed'] == true) continue;

    if (task['type'] == type) {
      if (type == 'visit_category' && category != null && task['category'] != category) continue;

      final currentProgress = (task['progress'] as int?) ?? 0;
      final newProgress = currentProgress + 1;
      task['progress'] = newProgress;
      if (newProgress >= (task['target'] as int? ?? 1)) {
        task['completed'] = true;
        rewardToAdd = task['reward'] as int? ?? 0;
        print('✅ Задание "$type" выполнено, начисляем $rewardToAdd монет');
      }
      tasks[i] = task;
      changed = true;
      break;
    }
  }

  if (!changed) {
    print('ℹ️ Нет незавершённых задач типа $type');
    return;
  }

  // Обновляем задачи
  await docRef.update({'dailyTasks': tasks});

  // Начисляем монеты, если есть награда
  if (rewardToAdd > 0) {
    await docRef.update({'coins': FieldValue.increment(rewardToAdd)});
    print('💰 Монеты начислены: +$rewardToAdd');
  }

  if (mounted && rewardToAdd > 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Задание выполнено! +$rewardToAdd монет'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }
}

  Future<void> _loadAll() async {
    await _loadUserLocation();
    await _loadShops();
    await _loadBanners();
    await _loadProgress();
    await _ensureDailyTasks();
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
      final favList = List<String>.from(data['favoriteShops'] ?? []);
      _allShopsBonusClaimed = data['allShopsBonusClaimed'] == true;
      _favoriteShops = favList.toSet();
      _lastCafeDate = data['lastCafeDate'] as String?;
      _lastElectronicsDate = data['lastElectronicsDate'] as String?;
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
        'favoriteShops': [],
        'allShopsBonusClaimed': false,
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
    _lastCafeDate = null;
    _lastElectronicsDate = null;
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
    'coins': 0,
    'subscribedShops': [],
    'favoriteShops': [],
    'dailyTasks': [],
    'purchasedRewards': [],
    'allVisitedShopIds': [],
    'allShopsBonusClaimed': false,
    'lastCafeDate': FieldValue.delete(),
    'lastElectronicsDate': FieldValue.delete(),
    'referredBy': FieldValue.delete(),
    'dailyTasksGeneratedAt': FieldValue.delete(),
  });

  // Заново загружаем всё и генерируем задания
  await _loadAll();
}

  Future<bool> _checkBonuses(String trigger, {Shop? currentShop}) async {
  bool anyBonus = false;

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

    anyBonus = true;   // <-- обязательно!

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

  return anyBonus;
}

  // ----- ИНФОРМАЦИОННОЕ ОКНО МАГАЗИНА -----
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

  // ----- МИНИ-КАРТА (логика карты НЕ ТРОНУТА, только контейнер вокруг) -----
  Widget _buildEnhancedMap() {
  final categories = _allShops
      .map((s) => s.category)
      .where((c) => c.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  List<Shop> visibleShops = _getVisibleShops();

  return Column(
  children: [
    // ============================================================
    // ПОИСК
    // ============================================================

    Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
      ),
      child: TextField(
        controller: _mapSearchController,
        decoration: InputDecoration(
          hintText: 'Поиск магазина',
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.textSecondary,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    _mapSearchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
        onChanged: (val) {
          setState(() => _searchQuery = val);
        },
      ),
    ),

    const SizedBox(height: AppSpacing.sm),

    // ============================================================
    // КАТЕГОРИИ
    // ============================================================

    if (categories.isNotEmpty)
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CategoryChip(
                label: 'Все',
                selected: _selectedCategory == null,
                onTap: () {
                  setState(() {
                    _selectedCategory = null;
                  });
                },
              ),
            ),

            ...categories.map(
              (cat) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CategoryChip(
                  label: cat,
                  selected: _selectedCategory == cat,
                  onTap: () {
                    setState(() {
                      _selectedCategory = cat;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),

    const SizedBox(height: AppSpacing.sm),

    // ============================================================
    // ИНТЕРАКТИВНАЯ КАРТА
    // ============================================================

    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: LayoutBuilder(
        builder: (context, viewportConstraints) {
          // --------------------------------------------------------
          // Исходный размер изображения
          // --------------------------------------------------------

          const double imageWidth = 2700;
          const double imageHeight = 1536;

          // Максимальная ширина карты на PC.
          // На телефоне карта займёт всю доступную ширину.
          const double maxMapWidth = 1000;

          final double mapWidth = math.min(
            viewportConstraints.maxWidth,
            maxMapWidth,
          );

          // Сохраняем пропорции оригинальной карты.
          final double mapHeight =
              mapWidth * imageHeight / imageWidth;

          // --------------------------------------------------------
          // Размер изображения внутри InteractiveViewer
          // --------------------------------------------------------

          final double containScale = math.min(
            mapWidth / imageWidth,
            mapHeight / imageHeight,
          );

          final double renderedWidth =
              imageWidth * containScale;

          final double renderedHeight =
              imageHeight * containScale;

          return Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                AppRadius.xl,
              ),
              child: Container(
                width: mapWidth,
                height: mapHeight,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  border: Border.all(
                    color: AppColors.border,
                  ),
                ),
                child: Stack(
                  children: [
                    // ==================================================
                    // INTERACTIVE VIEWER
                    // ==================================================

                    Positioned.fill(
                      child: Listener(
                        onPointerSignal: (event) {
                          if (event is PointerScrollEvent) {
                            final double delta =
                                event.scrollDelta.dy;

                            final double currentScale =
                                _mapTransformationController
                                    .value
                                    .getMaxScaleOnAxis();

                            double newScale;

                            if (delta < 0) {
                              // Колесо вверх — приближение
                              newScale =
                                  currentScale * 1.15;
                            } else {
                              // Колесо вниз — отдаление
                              newScale =
                                  currentScale / 1.15;
                            }

                            newScale = newScale.clamp(
                              1.0,
                              4.0,
                            );

                            final Offset focalPoint =
                                event.localPosition;

                            final Matrix4 currentMatrix =
                                _mapTransformationController
                                    .value;

                            final double scale =
                                currentMatrix
                                    .getMaxScaleOnAxis();

                            final Offset translation =
                                Offset(
                              currentMatrix.storage[12],
                              currentMatrix.storage[13],
                            );

                            final Offset focalInContent =
                                (focalPoint - translation) /
                                    scale;

                            final double newTranslationX =
                                focalPoint.dx -
                                    focalInContent.dx *
                                        newScale;

                            final double newTranslationY =
                                focalPoint.dy -
                                    focalInContent.dy *
                                        newScale;

                            final Matrix4 newMatrix =
                                Matrix4.identity()
                                  ..translate(
                                    newTranslationX,
                                    newTranslationY,
                                  )
                                  ..scale(newScale);

                            _mapTransformationController
                                .value = newMatrix;

                            setState(() {
                              _mapScale = newScale;
                            });
                          }
                        },

                        child: InteractiveViewer(
                          transformationController:
                              _mapTransformationController,

                          // Перемещение
                          panEnabled: true,

                          // Pinch zoom
                          scaleEnabled: true,

                          // Минимальный масштаб
                          minScale: 1.0,

                          // Максимальный zoom
                          maxScale: 4.0,

                          // Позволяем двигать карту
                          // за пределы области просмотра.
                          boundaryMargin:
                              const EdgeInsets.all(300),

                          clipBehavior: Clip.hardEdge,

                          panAxis: PanAxis.free,

                          child: SizedBox(
                            width: renderedWidth,
                            height: renderedHeight,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // ========================================
                                // КАРТА
                                // ========================================

                                Positioned.fill(
                                  child: Image.asset(
                                    'assets/images/mall_map.png',
                                    fit: BoxFit.fill,
                                  ),
                                ),

                                // ========================================
                                // МАГАЗИНЫ
                                // ========================================

                                ...visibleShops
                                    .where(
                                      (s) =>
                                          s.mapX != null &&
                                          s.mapY != null &&
                                          s.mapWidth != null &&
                                          s.mapHeight != null &&
                                          s.mapWidth! > 0 &&
                                          s.mapHeight! > 0,
                                    )
                                    .map((shop) {
                                  final bool isHovered =
                                      _hoveredShopId ==
                                          shop.id;

                                  final bool isRouteTarget =
                                      _selectedRouteShop?.id ==
                                          shop.id;

                                  // Координаты относительно
                                  // РЕАЛЬНОГО размера карты.
                                  final double x =
                                      shop.mapX! *
                                          renderedWidth;

                                  final double y =
                                      shop.mapY! *
                                          renderedHeight;

                                  final double w =
                                      shop.mapWidth! *
                                          renderedWidth;

                                  final double h =
                                      shop.mapHeight! *
                                          renderedHeight;

                                  return Positioned(
                                    left: x - w / 2,
                                    top: y - h / 2,
                                    width: w,
                                    height: h,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedRouteShop =
                                              shop;

                                          _hoveredShopId =
                                              shop.id;
                                        });
                                      },
                                      child: MouseRegion(
                                        onEnter: (_) {
                                          setState(() {
                                            _hoveredShopId =
                                                shop.id;
                                          });
                                        },
                                        onExit: (_) {
                                          setState(() {
                                            _hoveredShopId =
                                                null;
                                          });
                                        },
                                        child:
                                            AnimatedContainer(
                                          duration:
                                              const Duration(
                                            milliseconds: 200,
                                          ),
                                          decoration:
                                              BoxDecoration(
                                            color:
                                                (isHovered ||
                                                        isRouteTarget)
                                                    ? AppColors
                                                        .primary
                                                        .withOpacity(
                                                        0.35,
                                                      )
                                                    : Colors
                                                        .transparent,
                                            border:
                                                Border.all(
                                              color:
                                                  isRouteTarget
                                                      ? AppColors
                                                          .accent
                                                      : isHovered
                                                          ? AppColors
                                                              .primary
                                                          : Colors
                                                              .transparent,
                                              width: 2,
                                            ),
                                            borderRadius:
                                                BorderRadius
                                                    .circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),

                                // ========================================
                                // МАРШРУТ
                                // ========================================

                                if (_selectedRouteShop !=
                                        null &&
                                    _selectedRouteShop!.mapX !=
                                        null &&
                                    _selectedRouteShop!.mapY !=
                                        null)
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _RoutePainter(
                                        from: Offset(
                                          _entrancePosition.dx *
                                              renderedWidth,
                                          _entrancePosition.dy *
                                              renderedHeight,
                                        ),
                                        to: Offset(
                                          _selectedRouteShop!
                                                  .mapX! *
                                              renderedWidth,
                                          _selectedRouteShop!
                                                  .mapY! *
                                              renderedHeight,
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

                    // ==================================================
                    // КНОПКИ ZOOM
                    // ==================================================

                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Column(
                        children: [
                          // PLUS
                          Material(
                            elevation: 3,
                            borderRadius:
                                BorderRadius.circular(10),
                            color: Colors.white,
                            child: InkWell(
                              borderRadius:
                                  BorderRadius.circular(10),
                              onTap: () {
                                final double currentScale =
                                    _mapTransformationController
                                        .value
                                        .getMaxScaleOnAxis();

                                final double newScale =
                                    (currentScale * 1.25)
                                        .clamp(1.0, 4.0);

                                final double centerX =
                                    mapWidth / 2;

                                final double centerY =
                                    mapHeight / 2;

                                final Matrix4 matrix =
                                    _mapTransformationController
                                        .value;

                                final double oldScale =
                                    matrix
                                        .getMaxScaleOnAxis();

                                final Offset translation =
                                    Offset(
                                  matrix.storage[12],
                                  matrix.storage[13],
                                );

                                final Offset focal =
                                    Offset(
                                  centerX,
                                  centerY,
                                );

                                final Offset contentPoint =
                                    (focal - translation) /
                                        oldScale;

                                final double tx =
                                    focal.dx -
                                        contentPoint.dx *
                                            newScale;

                                final double ty =
                                    focal.dy -
                                        contentPoint.dy *
                                            newScale;

                                _mapTransformationController
                                    .value =
                                    Matrix4.identity()
                                      ..translate(tx, ty)
                                      ..scale(newScale);

                                setState(() {
                                  _mapScale =
                                      newScale;
                                });
                              },
                              child: const SizedBox(
                                width: 42,
                                height: 42,
                                child: Icon(
                                  Icons.add,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 6),

                          // MINUS
                          Material(
                            elevation: 3,
                            borderRadius:
                                BorderRadius.circular(10),
                            color: Colors.white,
                            child: InkWell(
                              borderRadius:
                                  BorderRadius.circular(10),
                              onTap: () {
                                final double currentScale =
                                    _mapTransformationController
                                        .value
                                        .getMaxScaleOnAxis();

                                final double newScale =
                                    (currentScale / 1.25)
                                        .clamp(1.0, 4.0);

                                if (newScale == 1.0) {
                                  _resetMapZoom();
                                  return;
                                }

                                final Matrix4 matrix =
                                    _mapTransformationController
                                        .value;

                                final double oldScale =
                                    matrix
                                        .getMaxScaleOnAxis();

                                final Offset translation =
                                    Offset(
                                  matrix.storage[12],
                                  matrix.storage[13],
                                );

                                final Offset focal =
                                    Offset(
                                  mapWidth / 2,
                                  mapHeight / 2,
                                );

                                final Offset contentPoint =
                                    (focal - translation) /
                                        oldScale;

                                final double tx =
                                    focal.dx -
                                        contentPoint.dx *
                                            newScale;

                                final double ty =
                                    focal.dy -
                                        contentPoint.dy *
                                            newScale;

                                _mapTransformationController
                                    .value =
                                    Matrix4.identity()
                                      ..translate(tx, ty)
                                      ..scale(newScale);

                                setState(() {
                                  _mapScale =
                                      newScale;
                                });
                              },
                              child: const SizedBox(
                                width: 42,
                                height: 42,
                                child: Icon(
                                  Icons.remove,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 6),

                          // RESET
                          Material(
                            elevation: 3,
                            borderRadius:
                                BorderRadius.circular(10),
                            color: Colors.white,
                            child: InkWell(
                              borderRadius:
                                  BorderRadius.circular(10),
                              onTap: _resetMapZoom,
                              child: const SizedBox(
                                width: 42,
                                height: 42,
                                child: Icon(
                                  Icons.refresh,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),

    // ============================================================
    // КНОПКА СБРОСА МАРШРУТА
    // ============================================================

    if (_selectedRouteShop != null)
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: TextButton.icon(
          icon: const Icon(
            Icons.close,
            size: 16,
          ),
          label: Text(
            'Сбросить маршрут до '
            '${_selectedRouteShop!.name}',
          ),
          onPressed: () {
            setState(() {
              _selectedRouteShop = null;
              _hoveredShopId = null;
            });
          },
        ),
      ),

    // ============================================================
    // ИНФОРМАЦИЯ О ВЫБРАННОМ МАГАЗИНЕ
    // ============================================================

    if (_selectedRouteShop != null)
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: AppCard(
          color: AppColors.accentContainer,
          child: Row(
            children: [
              Text(
                _selectedRouteShop!.icon,
                style: const TextStyle(
                  fontSize: 32,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedRouteShop!.name,
                      style: AppTextStyles.title,
                    ),
                    Text(
                      _selectedRouteShop!.discount,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),

              ElevatedButton(
                onPressed: () {
                  _activateShop(
                    _selectedRouteShop!,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      AppColors.accent,
                ),
                child: const Text('В путь'),
              ),
            ],
          ),
        ),
      ),
  ],
);
}
  // ----- ОСТАЛЬНЫЕ МЕТОДЫ КВЕСТА -----
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

List<Shop> _getAvailableForFork(Shop? currentShop) {
  final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
  var available = _allShops.where((s) {
    if (currentShop != null && s.id == currentShop.id) return false;
    if (_usedShopIds.contains(s.id)) return false;
    if (s.category == 'cafe' && _lastCafeDate == todayStr) return false;
    if (s.category == 'electronics' && _lastElectronicsDate == todayStr) return false;
    return true;
  }).toList();

  // Если после фильтрации осталось меньше двух, возвращаем без ограничения по датам,
  // но всё ещё исключая использованные и текущий магазин.
  if (available.length < 2) {
    available = _allShops.where((s) {
      if (currentShop != null && s.id == currentShop.id) return false;
      if (_usedShopIds.contains(s.id)) return false;
      return true;
    }).toList();
  }
  return available;
}

  List<Shop> _getNextTwoShops(Shop currentShop) {
  var available = _getAvailableForFork(currentShop);
  if (available.length < 2) return available;

  // Взвешенный список (как раньше)
  final weighted = <Shop>[];
  for (var shop in available) {
    int weight = shop.priority;
    if (_favoriteShops.contains(shop.id)) {
      weight += 3;
    }
    for (int i = 0; i < weight; i++) weighted.add(shop);
  }
  weighted.shuffle();

  final selected = <Shop>[];
  final Set<String> usedCategories = {}; // для контроля нежелательных категорий

  // Функция проверки: можно ли добавить магазин с учётом ограничения
  bool isAllowed(Shop shop) {
    if (shop.category == 'cafe' || shop.category == 'electronics') {
      if (usedCategories.contains(shop.category)) return false;
    }
    return true;
  }

  // Основной проход с ограничением
  for (var shop in weighted) {
    if (selected.contains(shop)) continue;
    if (!isAllowed(shop)) continue;
    selected.add(shop);
    usedCategories.add(shop.category);
    if (selected.length == 2) break;
  }

  // Если не набрали двух из-за ограничений, добавляем любых оставшихся
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

  // 🆕 Логирование для отладки (исправлен null)
  try {
    await _firestore.collection('debug_fork_logs').add({
      'timestamp': FieldValue.serverTimestamp(),
      'userId': _userId,
      'currentShopId': currentShop.id,
      'currentShopName': currentShop.name ?? 'Unknown',
      'candidateShops': nextShops.map((s) {
        return {
          'shopId': s.id,
          'name': s.name,
          'priority': s.priority,
          'isFavorite': _favoriteShops.contains(s.id),
        };
      }).toList(),
      'collabShopId': hasCollab ? toShop!.id : '',
      'collabShopName': hasCollab ? (toShop?.name ?? '') : '',
      'selectedShops': nextShops.take(2).map((s) => s.id).toList(),
    });
  } catch (e) {
    print('❌ Ошибка записи debug_fork_logs: $e');
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
          style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
          child: const Text('Закончить путь (продолжить позже)'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await _resetProgress();
          },
          style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
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
      setState(() {
        _pendingQRShop = shop;
      });
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
Map<String, dynamic> dateUpdates = {};
if (shop.category == 'cafe') {
  _lastCafeDate = todayStr;
  dateUpdates['lastCafeDate'] = todayStr;
} else if (shop.category == 'electronics') {
  _lastElectronicsDate = todayStr;
  dateUpdates['lastElectronicsDate'] = todayStr;
}
if (dateUpdates.isNotEmpty) {
  await _firestore.collection('user_progress').doc(_userId).update(dateUpdates);
}

    await _firestore.collection('user_progress').doc(_userId).update({
      'allVisitedShopIds': FieldValue.arrayUnion([shop.id]),
    });

    await _firestore.collection('sales').add({
      'shopId': shop.id,
      'userId': _userId,
      'step': currentStep,
      'timestamp': FieldValue.serverTimestamp(),
    });
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

    final doc = await _firestore.collection('user_progress').doc(_userId).get();
    final data = doc.data() ?? {};
    final visited = (data['allVisitedShopIds'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toSet();
    final allShopIds = _allShops.map((s) => s.id).toSet();

    if (allShopIds.isNotEmpty && visited.containsAll(allShopIds)) {
      final bonus = {
        'title': 'Исследователь ТЦ',
        'message': 'Вы посетили все магазины этого ТЦ!',
        'icon': '🌟',
      };

      await _firestore.collection('user_progress').doc(_userId).update({
        'pendingBonuses': FieldValue.arrayUnion([bonus]),
        'allShopsBonusClaimed': true,
      });

      setState(() => _allShopsBonusClaimed = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Поздравляем! Вы посетили все магазины ТЦ!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        );
      }
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
    await _firestore.collection('user_progress').doc(_userId).update({
      'favoriteShops': _favoriteShops.toList(),
    });
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
  await _firestore.collection('user_progress').doc(_userId).update({
    'cycleCount': newCycleCount,
    'completedSteps': 0,
    'usedShopIds': [],
    'pendingForkShops': [],
    'lastShopId': null,
    'isPathActive': true,
  });

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

  final bool bonusAdded = await _checkBonuses('cycle_completed');

  if (mounted && !bonusAdded) {
    await _showWheelOfFortune();
  }
}

  Future<bool?> _showQRDialog(Shop shop) async {
    final userDoc = await _firestore.collection('user_progress').doc(_userId).get();
    final subscribedShops = List<String>.from(userDoc.data()?['subscribedShops'] ?? []);
    final isSubscribed = subscribedShops.contains(shop.id);
    final String discountText = shop.shortDiscount.isNotEmpty ? shop.shortDiscount : shop.discount;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(shop.name, style: AppTextStyles.headline),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, size: 96, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(discountText, style: AppTextStyles.title.copyWith(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isSubscribed ? Icons.notifications_active : Icons.notifications_off,
                    color: AppColors.textSecondary),
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
                  child: Text(isSubscribed ? 'Отписаться от уведомлений' : 'Подписаться на акции'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Тестовая кнопка подтверждения использования промокода
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.check),
              label: const Text('Я использовал промокод'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            ),
          ],
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
            Text('Ожидает QR: ${shop.name}',
                style: AppTextStyles.headline),
            const SizedBox(height: 8),
            const Text('Покажите QR продавцу, затем подтвердите использование',
                textAlign: TextAlign.center),
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
    if (_pendingQRShop != null) {
      return _buildPendingQRView();
    }
    if (_pendingForkShops != null && _pendingForkShops!.length == 2) {
      return SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'Продолжите путь, выбрав один из магазинов:',
                style: AppTextStyles.title,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PendingShopButton(
                  shop: _pendingForkShops![0],
                  onTap: _activateShop,
                  onInfoTap: () => _showShopInfo(_pendingForkShops![0]),
                  onHover: (id) => setState(() => _hoveredShopId = id),
                  isFavorite: _favoriteShops.contains(_pendingForkShops![0].id),
                  onToggleFavorite: () => _toggleFavorite(_pendingForkShops![0]),
                ),
                const SizedBox(width: 20),
                _PendingShopButton(
                  shop: _pendingForkShops![1],
                  onTap: _activateShop,
                  onInfoTap: () => _showShopInfo(_pendingForkShops![1]),
                  onHover: (id) => setState(() => _hoveredShopId = id),
                  isFavorite: _favoriteShops.contains(_pendingForkShops![1].id),
                  onToggleFavorite: () => _toggleFavorite(_pendingForkShops![1]),
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

    if (_isPathActive) {
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
  final visibleShops = _getVisibleShops();   // <-- добавить

  if (visibleShops.isEmpty) {
    return const EmptyState(
      icon: Icons.storefront_outlined,
      title: 'Нет магазинов в этом ТЦ',
      subtitle: 'Выберите другой ТЦ или попробуйте позже',
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionTitle(
        title: 'Магазины',
        trailing: Text('${visibleShops.length} шт.', style: AppTextStyles.caption),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: visibleShops.map((shop) => _ShopCard(   // <-- используем visibleShops
            shop: shop,
            onTap: _activateShop,
            onInfoTap: () => _showShopInfo(shop),
            onHover: (id) => setState(() => _hoveredShopId = id),
            isFavorite: _favoriteShops.contains(shop.id),
            onToggleFavorite: () => _toggleFavorite(shop),
          )).toList(),
        ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: ElevatedButton(
            onPressed: _showFirstChoice,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Начать путь', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

void _resetMapZoom() {
  _mapTransformationController.value = Matrix4.identity();
  setState(() => _mapScale = 1.0);
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
        appBar: AppBar(title: const Text('Offline Deals')),
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
        title: const Text('Offline Deals'),
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
                      child: Text(
                        '${_selectedCity!}, ${_selectedMall!}',
                        style: AppTextStyles.caption,
                      ),
                    ),
                ],
              ),
            ),
            // Приветственный текст из CMS
            FutureBuilder<String>(
              future: ContentService.getContent('home_welcome', defaultValue: 'Добро пожаловать в квест!'),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text(
                    snapshot.data!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyLarge,
                  ),
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
  final _firestore = FirebaseFirestore.instance;
  late final String _userId;
  int _pushIntervalHours = 1;
  int _cycleCount = 0;
  List<String> _subscribedShops = [];
  Map<String, String> _shopNames = {};

  String? _referralCode;
  String? _referralStatus;

  List<Map<String, dynamic>> _pendingBonuses = [];

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser!.uid;
    _loadPushSettings();
    _loadSubscribedShops();
    _ensureReferralCode();
    _loadCycleCount();
    _loadPendingBonuses();
  }

  // ==================== ЗАГРУЗКА ДАННЫХ ====================

  Future<void> _loadPushSettings() async {
    final doc = await _firestore.collection('user_progress').doc(_userId).get();
    final data = doc.data();
    if (data != null && data['pushMinIntervalHours'] != null) {
      if (mounted) setState(() => _pushIntervalHours = data['pushMinIntervalHours']);
    }
  }

  Future<void> _loadSubscribedShops() async {
    final doc = await _firestore.collection('user_progress').doc(_userId).get();
    final data = doc.data();
    if (data != null && data['subscribedShops'] != null) {
      final ids = List<String>.from(data['subscribedShops']);
      if (mounted) setState(() => _subscribedShops = ids);
      for (final id in ids) {
        final shopDoc = await _firestore.collection('shops').doc(id).get();
        if (shopDoc.exists) {
          _shopNames[id] = shopDoc.data()?['name'] ?? 'Магазин';
        }
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _savePushInterval(int hours) async {
    await _firestore.collection('user_progress').doc(_userId).update({
      'pushMinIntervalHours': hours,
    });
    if (mounted) setState(() => _pushIntervalHours = hours);
  }

  Future<void> _unsubscribeFromShop(String shopId) async {
    final doc = await _firestore.collection('user_progress').doc(_userId).get();
    final current = List<String>.from(doc.data()?['subscribedShops'] ?? []);
    final updated = current.where((id) => id != shopId).toList();
    await doc.reference.update({'subscribedShops': updated});
    _loadSubscribedShops();
  }

  // ==================== БОНУСЫ ====================

  Future<List<Map<String, dynamic>>> _getPendingBonuses() async {
    final userDoc = await _firestore.collection('user_progress').doc(_userId).get();
    final data = userDoc.data() ?? {};
    final pendingRaw = data['pendingBonuses'] ?? [];
    final List<Map<String, dynamic>> bonuses = [];

    for (final item in pendingRaw) {
      if (item is String) {
        final ruleDoc = await _firestore.collection('bonus_rules').doc(item).get();
        if (ruleDoc.exists) {
          final ruleData = ruleDoc.data() as Map<String, dynamic>? ?? {};
          final reward = ruleData['reward'] as Map<String, dynamic>? ?? {};
          bonuses.add({
            'type': 'rule',
            'ruleId': item,
            'title': reward['title'] ?? 'Бонус',
            'message': reward['message'] ?? '',
            'icon': reward['icon'] ?? '🎁',
            'targetShopId': reward['targetShopId'] ?? '',
          });
        }
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
    return bonuses;
  }

  Future<void> _loadPendingBonuses() async {
    final bonuses = await _getPendingBonuses();
    if (mounted) setState(() => _pendingBonuses = bonuses);
  }

  Future<void> _claimBonus(Map<String, dynamic> bonus) async {
    final title = bonus['title'] ?? 'Бонус';
    final message = bonus['message'] ?? '';
    final icon = bonus['icon'] ?? '🎁';
    final targetShopId = bonus['targetShopId'] ?? '';
    final ruleId = bonus['ruleId'] as String?;

    if (targetShopId.isNotEmpty) {
      final shopDoc = await _firestore.collection('shops').doc(targetShopId).get();
      if (shopDoc.exists) {
        final targetShop = Shop.fromFirestore(shopDoc);
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text('$icon $title'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_scanner_rounded, size: 96, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(message),
                const SizedBox(height: 8),
                Text('Магазин: ${targetShop.name}'),
              ],
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
    } else {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('$icon $title'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    }

    if (ruleId != null) {
      await _firestore.collection('user_progress').doc(_userId).update({
        'pendingBonuses': FieldValue.arrayRemove([ruleId]),
        'claimedBonuses': FieldValue.arrayUnion([ruleId]),
      });
    } else {
      final userDoc = await _firestore.collection('user_progress').doc(_userId).get();
      final currentPending = List<dynamic>.from(userDoc.data()?['pendingBonuses'] ?? []);
      currentPending.removeWhere((item) =>
          item is Map && item['title'] == title && item['message'] == message);
      await userDoc.reference.update({
        'pendingBonuses': currentPending,
        'claimedBonuses': FieldValue.arrayUnion([
          {'title': title, 'message': message, 'icon': icon}
        ]),
      });
    }

    if (mounted) await _loadPendingBonuses();
  }

  // ==================== РЕФЕРАЛЬНАЯ СИСТЕМА ====================

  Future<void> _ensureReferralCode() async {
    final doc = await _firestore.collection('user_progress').doc(_userId).get();
    final data = doc.data() ?? {};
    if (data['referralCode'] == null) {
      final code = _generateReferralCode();
      await _firestore.collection('user_progress').doc(_userId).set({
        'referralCode': code,
      }, SetOptions(merge: true));
      if (mounted) setState(() => _referralCode = code);
    } else {
      if (mounted) setState(() => _referralCode = data['referralCode'] as String);
    }
    if (data['referredBy'] != null) {
      if (mounted) setState(() => _referralStatus = 'pending');
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

  // ==================== УРОВНИ ====================

  Future<void> _loadCycleCount() async {
    final doc = await _firestore.collection('user_progress').doc(_userId).get();
    if (doc.exists && mounted) {
      setState(() {
        _cycleCount = (doc.data()?['cycleCount'] as num?)?.toInt() ?? 0;
      });
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

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return GradientScaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // ---- Карточка профиля ----
          AppCard(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primaryContainer,
                  child: const Icon(Icons.person, size: 48, color: AppColors.primary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(user?.email ?? 'Не авторизован', style: AppTextStyles.headline),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Уровень: ${LevelSystem.getLevelName(_cycleCount)}', style: AppTextStyles.bodyMedium),
                    const SizedBox(width: 8),
                    Icon(Icons.star, size: 18, color: AppColors.warning),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                LinearProgressIndicator(
                  value: _getLevelProgress(),
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceVariant,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 4),
                Text(_getLevelProgressText(), style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QuestHistoryScreen()),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('Мои достижения'),
                ),
                const SizedBox(height: AppSpacing.sm),
                ElevatedButton.icon(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Выйти'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ---- Монеты и ежедневные задания (StreamBuilder) ----
          StreamBuilder<DocumentSnapshot>(
            stream: _firestore.collection('user_progress').doc(_userId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data == null) {
                return const SizedBox.shrink();
              }
              final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
              final coins = data['coins'] as int? ?? 0;
              final tasks = List<Map<String, dynamic>>.from(data['dailyTasks'] ?? []);

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
                          child: const Text('Магазин наград'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SectionTitle(
                      title: 'Ежедневные задания',
                      padding: EdgeInsets.zero,
                    ),
                    ...tasks.map((task) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            task['completed'] == true ? Icons.check_circle : Icons.circle_outlined,
                            color: task['completed'] == true ? AppColors.success : AppColors.textDisabled,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(task['description'] ?? '')),
                          Text('+${task['reward'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.coin)),
                          const SizedBox(width: 8),
                          Text('${task['progress'] ?? 0}/${task['target'] ?? 1}', style: AppTextStyles.caption),
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
                SectionTitle(title: '🎁 Пригласи друга', padding: EdgeInsets.zero),
                const SizedBox(height: 4),
                Text('Ваш персональный код:', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  _referralCode ?? '------',
                  style: AppTextStyles.headline.copyWith(letterSpacing: 4),
                ),
                const SizedBox(height: 8),
                Text(
                  'Поделитесь кодом с другом. Когда он завершит первый квест, вы оба получите бонус!',
                  style: AppTextStyles.caption,
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
                          final text = 'Присоединяйся к OfflineDeals и получи скидки!\nМой код: $_referralCode';
                          Share.share(text);
                        },
                        icon: const Icon(Icons.share),
                        label: const Text('Поделиться'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showEnterReferralDialog,
                        icon: const Icon(Icons.edit),
                        label: const Text('Ввести код'),
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
                SectionTitle(title: 'Мои бонусы', padding: EdgeInsets.zero),
                if (_pendingBonuses.isEmpty)
                  EmptyState(
                    icon: Icons.card_giftcard,
                    title: 'У вас пока нет доступных бонусов.',
                  )
                else
                  ..._pendingBonuses.map((bonus) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(bonus['icon'] ?? '🎁', style: const TextStyle(fontSize: 32)),
                      title: Text(bonus['title'] ?? 'Бонус'),
                      trailing: ElevatedButton(
                        onPressed: () => _claimBonus(bonus),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: const Text('Получить'),
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
                SectionTitle(title: 'Настройки уведомлений', padding: EdgeInsets.zero),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Минимальный интервал между пушами', style: AppTextStyles.bodyMedium),
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
            future: ContentService.getContent('faq', defaultValue: 'Здесь скоро появятся часто задаваемые вопросы.'),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(title: '❓ FAQ', padding: EdgeInsets.zero),
                    const SizedBox(height: 8),
                    Text(snapshot.data!, style: AppTextStyles.bodyLarge),
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
    if (cycleCount >= 7) return -1; // максимальный уровень
    if (cycleCount >= 3) return 7;
    return 3;
  }
}

// ----- Вспомогательные виджеты (BannerImagePreview и _RoutePainter) -----
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
        errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceVariant),
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
              errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceVariant),
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
      ..color = AppColors.accent
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(from, to, paint);

    final circlePaint = Paint()..color = AppColors.accent;
    canvas.drawCircle(from, 6, circlePaint);
    canvas.drawCircle(to, 6, circlePaint);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.from != from || oldDelegate.to != to;
}