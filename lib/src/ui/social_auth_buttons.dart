import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../facades/social_auth.dart';
import 'social_provider_icons.dart';

/// Social auth mode — determines button label text.
enum SocialAuthMode { signIn, signUp }

/// Config-driven social authentication buttons.
///
/// Reads `social_auth.providers` from config, filters by
/// `enabled` flag and platform support, then renders a button
/// per provider with the correct icon and label.
///
/// ```dart
/// SocialAuthButtons(
///   onAuthenticate: (provider) => controller.doSocialLogin(provider),
///   loadingProvider: controller.socialLoginProvider,
/// )
/// ```
class SocialAuthButtons extends StatelessWidget {
  /// Called when user taps a provider button.
  final Future<void> Function(String provider) onAuthenticate;

  /// Currently loading provider name (for per-button loading state).
  /// Pass empty string to disable all buttons without showing any spinner.
  final String? loadingProvider;

  /// Sign-in or sign-up mode (determines label text).
  final SocialAuthMode mode;

  /// Override className for the outer container.
  final String? className;

  /// Override className for individual buttons.
  final String? buttonClassName;

  /// Custom label builder. When null, uses trans('auth.sign_in_with'/'auth.sign_up_with').
  final String Function(String provider, SocialAuthMode mode)? labelBuilder;

  const SocialAuthButtons({
    super.key,
    required this.onAuthenticate,
    this.loadingProvider,
    this.mode = SocialAuthMode.signIn,
    this.className,
    this.buttonClassName,
    this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final providers = _getEnabledProviders();

    if (providers.isEmpty) return const SizedBox.shrink();

    return WDiv(
      className: className ?? 'flex flex-col items-stretch',
      children: _buildButtons(providers),
    );
  }

  /// Get enabled and platform-supported providers from config.
  List<_ResolvedProvider> _getEnabledProviders() {
    final providersConfig =
        Config.get<Map<String, dynamic>>('social_auth.providers');
    if (providersConfig == null) return [];

    final resolved = <_ResolvedProvider>[];
    var insertionIndex = 0;

    for (final entry in providersConfig.entries) {
      final name = entry.key;
      final config = entry.value as Map<String, dynamic>? ?? {};

      // Skip disabled providers
      final enabled = config['enabled'] as bool? ?? true;
      if (!enabled) continue;

      // Skip unsupported platforms
      if (!SocialAuth.supports(name)) continue;

      // Resolve UI metadata: config overrides > registry > built-in
      final defaults = SocialProviderIcons.forProvider(name);

      final label =
          config['label'] as String? ?? defaults?.label ?? _capitalize(name);
      final iconSvg = config['icon_svg'] as String? ?? defaults?.iconSvg;
      final iconClassName =
          config['icon_class'] as String? ?? defaults?.iconClassName;
      final order =
          config['order'] as int? ?? defaults?.order ?? (100 + insertionIndex);

      resolved.add(_ResolvedProvider(
        name: name,
        label: label,
        iconSvg: iconSvg,
        iconClassName: iconClassName,
        order: order,
      ));

      insertionIndex++;
    }

    // Sort by order
    resolved.sort((a, b) => a.order.compareTo(b.order));
    return resolved;
  }

  List<Widget> _buildButtons(List<_ResolvedProvider> providers) {
    final widgets = <Widget>[];

    for (var i = 0; i < providers.length; i++) {
      if (i > 0) widgets.add(const WSpacer(className: 'h-3'));
      widgets.add(_buildButton(providers[i]));
    }

    return widgets;
  }

  Widget _buildButton(_ResolvedProvider provider) {
    final isThisLoading = loadingProvider == provider.name;
    final isAnyLoading = loadingProvider != null;
    final isDisabled = isAnyLoading && !isThisLoading;

    final label = labelBuilder != null
        ? labelBuilder!(provider.label, mode)
        : mode == SocialAuthMode.signIn
            ? trans('auth.sign_in_with', {'provider': provider.label})
            : trans('auth.sign_up_with', {'provider': provider.label});

    return WButton(
      onTap: isDisabled ? null : () => onAuthenticate(provider.name),
      isLoading: isThisLoading,
      className: buttonClassName ??
          '''
        w-full p-3 rounded-xl
        bg-white dark:bg-slate-800
        border border-slate-200 dark:border-slate-700
        hover:bg-slate-50 dark:hover:bg-slate-700/50
        ${isDisabled ? 'opacity-50 cursor-not-allowed' : ''}
      ''',
      child: WDiv(
        className:
            'flex flex-row items-center justify-center gap-3 text-slate-900 dark:text-white',
        children: [
          if (provider.iconSvg != null)
            WSvg.string(
              provider.iconSvg!,
              className: provider.iconClassName ?? 'w-5 h-5',
            ),
          WText(label, className: 'text-base font-medium'),
        ],
      ),
    );
  }

  /// Capitalize first letter of provider name as fallback label.
  static String _capitalize(String name) {
    if (name.isEmpty) return name;
    return name[0].toUpperCase() + name.substring(1);
  }
}

/// Internal: Resolved provider metadata for rendering.
class _ResolvedProvider {
  final String name;
  final String label;
  final String? iconSvg;
  final String? iconClassName;
  final int order;

  const _ResolvedProvider({
    required this.name,
    required this.label,
    this.iconSvg,
    this.iconClassName,
    required this.order,
  });
}
