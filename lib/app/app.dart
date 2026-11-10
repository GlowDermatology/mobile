import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/i18n/tr.dart';
import '../core/links/deep_links.dart';
import '../core/links/pending_action.dart';
import '../core/push/push_service.dart';
import '../core/widgets/gd_widgets.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/presentation/update_required_screen.dart';
import '../features/cart/application/cart_controller.dart';
import '../features/notifications/data/unread_count.dart';
import 'providers.dart';
import 'router.dart';
import 'theme/gd_theme.dart';

class GlowDermaApp extends ConsumerStatefulWidget {
  const GlowDermaApp({super.key});

  @override
  ConsumerState<GlowDermaApp> createState() => _GlowDermaAppState();
}

class _GlowDermaAppState extends ConsumerState<GlowDermaApp> with WidgetsBindingObserver {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final router = ref.read(routerProvider);
    // Payment returns and other app links; push taps.
    ref.read(deepLinksProvider).start((location) => router.go(location));
    unawaited(ref.read(pushServiceProvider).start(onOpen: (location) => router.push(location)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && ref.read(sessionProvider).signedIn) {
      unawaited(ref.read(unreadCountProvider.notifier).refresh());
      unawaited(ref.read(cartProvider.notifier).reload());
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    final updateRequired = ref.watch(updateRequiredProvider);

    ref.listen(sessionProvider, (previous, next) {
      final notice = next.notice;
      if (notice != null) {
        _messengerKey.currentState?.showSnackBar(SnackBar(content: Text(notice)));
        ref.read(sessionProvider.notifier).clearNotice();
      }
      if (previous?.signedIn != true && next.signedIn) {
        unawaited(_replayPendingAction());
        unawaited(ref.read(pushServiceProvider).onSignedIn());
      }
    });

    return MaterialApp.router(
      title: 'Glow Derma',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      locale: language.locale,
      supportedLocales: [for (final l in AppLanguage.values) l.locale],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) => updateRequired != null ? UpdateRequiredScreen(error: updateRequired) : child!,
    );
  }

  Future<void> _replayPendingAction() async {
    final action = ref.read(pendingActionProvider.notifier).take();
    if (action is PendingAddToCart) {
      try {
        await ref.read(cartProvider.notifier).add(action.productId);
      } on Object catch (e) {
        final context = _messengerKey.currentContext;
        if (context != null && context.mounted) showError(context, e);
      }
    }
  }
}

/// Convenience for screens: `context.goBack()` falls back to the catalog.
extension GoBack on BuildContext {
  void goBack() => canPop() ? pop() : go('/catalog');
}
