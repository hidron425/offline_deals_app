import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Универсальная карточка-контейнер с единым стилем
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin = EdgeInsets.zero,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: content,
    );
  }
}

/// Секционный заголовок (единый стиль для "Мои бонусы", "Настройки" и т.д.)
class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionTitle({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTextStyles.headline),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Чип категории (замена dropdown)
class CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Бейдж с монетами (единый стиль везде)
class CoinBadge extends StatelessWidget {
  final int amount;
  final double iconSize;
  final TextStyle? textStyle;

  const CoinBadge({
    super.key,
    required this.amount,
    this.iconSize = 20,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: const BoxDecoration(color: AppColors.coin, shape: BoxShape.circle),
          child: Icon(Icons.monetization_on, size: iconSize * 0.7, color: Colors.white),
        ),
        const SizedBox(width: 6),
        Text(
          '$amount',
          style: textStyle ?? AppTextStyles.title.copyWith(color: AppColors.coin),
        ),
      ],
    );
  }
}

/// Пустое состояние (единый стиль вместо разрозненных Container+Text)
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.textDisabled),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }
}

/// Прогресс-бар шагов квеста с соединяющей линией (замена старого _stepCircle)
class QuestStepsBar extends StatelessWidget {
  final int totalSteps;
  final int completedSteps;

  const QuestStepsBar({
    super.key,
    required this.totalSteps,
    required this.completedSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: List.generate(totalSteps, (index) {
          final bool completed = index < completedSteps;
          final bool current = index == completedSteps && completedSteps < totalSteps;
          final bool isLast = index == totalSteps - 1;

          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: completed
                            ? AppColors.success
                            : (current ? AppColors.primary : AppColors.surfaceVariant),
                        border: current
                            ? Border.all(color: AppColors.primaryContainer, width: 4)
                            : null,
                      ),
                      child: Center(
                        child: completed
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: current ? Colors.white : AppColors.textDisabled,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Шаг ${index + 1}',
                      style: AppTextStyles.caption.copyWith(fontSize: 9),
                    ),
                  ],
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      height: 2,
                      color: completed ? AppColors.success : AppColors.border,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Persistent Mini-Quest Bar — плавающий виджет активного квеста
class MiniQuestBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final String? shopName;
  final VoidCallback onTap;

  const MiniQuestBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.shopName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.floating,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.flag_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                shopName != null
                    ? 'Шаг $currentStep/$totalSteps · $shopName ждёт вас'
                    : 'Шаг $currentStep/$totalSteps · Продолжить квест',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }
}