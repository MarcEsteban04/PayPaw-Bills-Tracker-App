import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// A gallery of every design token, rendered.
///
/// This is a developer tool, not a user-facing screen. It exists because tokens
/// are impossible to review as hex codes: contrast, weight and shadow softness
/// only become judgeable once they are on a real device. Sprint 10 will use this
/// same screen to check the dark theme against the light one.
///
/// Reached from Profile > Developer > Design system.
class DesignSystemScreen extends StatelessWidget {
  const DesignSystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The canvas gradient is painted once in PayPawApp, so this screen needs
    // only a transparent scaffold on top of it. Nothing pads for the bottom
    // navigation here: this route sits above the shell, so there is none.
    return Scaffold(
      appBar: AppBar(title: const Text('Design System')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenInset,
          0,
          AppSpacing.screenInset,
          AppSpacing.xxl,
        ),
        children: const <Widget>[
          _Section(title: 'Colour', child: _ColourGrid()),
          _Section(title: 'Typography', child: _TypeScale()),
          _Section(title: 'Cards & shadows', child: _CardSamples()),
          _Section(title: 'Buttons', child: _ButtonSamples()),
          _Section(title: 'Inputs', child: _InputSamples()),
          _Section(title: 'Chips', child: _ChipSamples()),
          _Section(title: 'Radius & spacing', child: _RadiusAndSpacing()),
        ],
      ),
    );
  }
}

/// A titled block, so every section is spaced identically.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _ColourGrid extends StatelessWidget {
  const _ColourGrid();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        _Swatch(
          label: 'primary',
          color: context.colors.primary,
          onColor: context.colors.textOnPrimary,
        ),
        _Swatch(
          label: 'pressed',
          color: context.colors.primaryPressed,
          onColor: context.colors.textOnPrimary,
        ),
        _Swatch(
          label: 'primaryText',
          color: context.colors.primaryText,
          onColor: context.colors.textOnPrimary,
        ),
        _Swatch(
          label: 'primarySoft',
          color: context.colors.primarySoft,
          onColor: context.colors.primaryText,
        ),
        _Swatch(
          label: 'navSurface',
          color: context.colors.navSurface,
          onColor: context.colors.textOnDark,
        ),
        _Swatch(
          label: 'navPill',
          color: context.colors.navActivePill,
          onColor: context.colors.navOnActivePill,
        ),
        _Swatch(
          label: 'paid',
          color: context.colors.paid,
          onColor: context.colors.textOnPrimary,
        ),
        _Swatch(
          label: 'dueSoon',
          color: context.colors.dueSoon,
          onColor: context.colors.textOnPrimary,
        ),
        _Swatch(
          label: 'overdue',
          color: context.colors.overdue,
          onColor: context.colors.textOnPrimary,
        ),
        _Swatch(
          label: 'canvasStart',
          color: context.colors.canvasStart,
          onColor: context.colors.textPrimary,
        ),
        _Swatch(
          label: 'surfaceMuted',
          color: context.colors.surfaceMuted,
          onColor: context.colors.textPrimary,
        ),
        _Swatch(
          label: 'border',
          color: context.colors.border,
          onColor: context.colors.textPrimary,
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.label,
    required this.color,
    required this.onColor,
  });

  final String label;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 64,
      padding: const EdgeInsets.all(AppSpacing.sm),
      alignment: Alignment.bottomLeft,
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadii.chip,
        border: Border.all(color: context.colors.border),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(color: onColor),
      ),
    );
  }
}

class _TypeScale extends StatelessWidget {
  const _TypeScale();

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Display 28 · hero amount', style: textTheme.displaySmall),
        Text('Headline 24 · screen title', style: textTheme.headlineMedium),
        Text('Headline 20 · card value', style: textTheme.headlineSmall),
        Text('Title 18 · figure', style: textTheme.titleLarge),
        Text('Title 16 · card title', style: textTheme.titleMedium),
        Text('Title 14 · tab label', style: textTheme.titleSmall),
        Text('Body 15 · lead copy', style: textTheme.bodyLarge),
        Text('Body 14 · default copy', style: textTheme.bodyMedium),
        Text('Body 12 · caption, 2h ago', style: textTheme.bodySmall),
        Text('Label 15 · button', style: textTheme.labelLarge),
        Text('Label 12 · chip', style: textTheme.labelMedium),
        Text('Label 11 · nav', style: textTheme.labelSmall),
        const SizedBox(height: AppSpacing.sm),
        // Tabular figures matter here: these two rows must align digit for
        // digit. If they do not, the amount style has lost its font feature.
        Text('₱ 12,480.00', style: AppTypography.amount(context.colors)),
        Text('₱ 98,111.75', style: AppTypography.amount(context.colors)),
      ],
    );
  }
}

class _CardSamples extends StatelessWidget {
  const _CardSamples();

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      children: <Widget>[
        _ShadowCard(
          shadow: context.colors.subtleShadow,
          radius: AppRadii.chip,
          label: 'subtle · chips and inline controls',
          textStyle: textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.cardGap),
        _ShadowCard(
          shadow: context.colors.cardShadow,
          radius: AppRadii.card,
          label: 'card · the default list card',
          textStyle: textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.cardGap),
        _ShadowCard(
          shadow: context.colors.floatingShadow,
          radius: AppRadii.panel,
          label: 'floating · nav, sheets, menus',
          textStyle: textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _ShadowCard extends StatelessWidget {
  const _ShadowCard({
    required this.shadow,
    required this.radius,
    required this.label,
    required this.textStyle,
  });

  final List<BoxShadow> shadow;
  final BorderRadius radius;
  final String label;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardInset),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: radius,
        boxShadow: shadow,
      ),
      child: Text(label, style: textStyle),
    );
  }
}

class _ButtonSamples extends StatelessWidget {
  const _ButtonSamples();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Nothing here passes a style: if these do not already look like the
        // reference, the theme is wrong, not the call site.
        FilledButton(onPressed: () {}, child: const Text('Mark as Paid')),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(onPressed: () {}, child: const Text('Snooze reminder')),
        const SizedBox(height: AppSpacing.md),
        const FilledButton(onPressed: null, child: Text('Disabled')),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: () {}, child: const Text('See all')),
        ),
      ],
    );
  }
}

class _InputSamples extends StatelessWidget {
  const _InputSamples();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        TextField(
          decoration: InputDecoration(
            hintText: 'Search bills',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        SizedBox(height: AppSpacing.md),
        TextField(
          decoration: InputDecoration(labelText: 'Amount', prefixText: '₱ '),
        ),
        SizedBox(height: AppSpacing.md),
        TextField(
          decoration: InputDecoration(
            labelText: 'Due date',
            errorText: 'Pick a date in the future',
          ),
        ),
      ],
    );
  }
}

class _ChipSamples extends StatelessWidget {
  const _ChipSamples();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        Chip(label: Text('Monthly')),
        Chip(label: Text('Electricity')),
        Chip(label: Text('Due in 3 days')),
        Chip(label: Text('Auto-pay'), avatar: Icon(Icons.bolt, size: 14)),
      ],
    );
  }
}

class _RadiusAndSpacing extends StatelessWidget {
  const _RadiusAndSpacing();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _RadiusBox(label: 'xs 8', radius: AppRadii.xs),
            _RadiusBox(label: 'sm 12', radius: AppRadii.sm),
            _RadiusBox(label: 'md 16', radius: AppRadii.md),
            _RadiusBox(label: 'lg 20', radius: AppRadii.lg),
            _RadiusBox(label: 'xl 24', radius: AppRadii.xl),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        _SpacingBar(label: 'xs 4', width: AppSpacing.xs),
        _SpacingBar(label: 'sm 8', width: AppSpacing.sm),
        _SpacingBar(label: 'md 12', width: AppSpacing.md),
        _SpacingBar(label: 'lg 16', width: AppSpacing.lg),
        _SpacingBar(label: 'xl 20', width: AppSpacing.xl),
        _SpacingBar(label: 'xxl 24', width: AppSpacing.xxl),
        _SpacingBar(label: 'xxxl 32', width: AppSpacing.xxxl),
      ],
    );
  }
}

class _RadiusBox extends StatelessWidget {
  const _RadiusBox({required this.label, required this.radius});

  final String label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.colors.primarySoft,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: context.colors.primary),
      ),
      child: Text(label, style: AppTypography.labelSmall),
    );
  }
}

class _SpacingBar extends StatelessWidget {
  const _SpacingBar({required this.label, required this.width});

  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 72,
            child: Text(label, style: AppTypography.labelMedium),
          ),
          Container(width: width, height: 16, color: context.colors.primary),
        ],
      ),
    );
  }
}
