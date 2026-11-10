import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/ai/presentation/ai_screen.dart';
import '../features/appointments/presentation/appointment_screen.dart';
import '../features/appointments/presentation/appointments_screen.dart';
import '../features/appointments/presentation/booking_screen.dart';
import '../features/appointments/presentation/specialists_screen.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/presentation/attach_phone_screen.dart';
import '../features/auth/presentation/auth_screens.dart';
import '../features/auth/presentation/consent_screen.dart';
import '../features/cart/presentation/cart_screen.dart';
import '../features/catalog/presentation/catalog_list_screen.dart';
import '../features/catalog/presentation/home_screen.dart';
import '../features/catalog/presentation/product_screen.dart';
import '../features/checkout/presentation/address_form_screen.dart';
import '../features/checkout/presentation/checkout_screen.dart';
import '../features/checkout/presentation/payment_screen.dart';
import '../features/loyalty/presentation/qr_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/orders/presentation/order_detail_screen.dart';
import '../features/orders/presentation/order_success_screen.dart';
import '../features/orders/presentation/orders_screen.dart';
import '../features/profile/presentation/addresses_screen.dart';
import '../features/profile/presentation/change_password_screen.dart';
import '../features/profile/presentation/delete_account_screen.dart';
import '../features/profile/presentation/legal_screen.dart';
import '../features/profile/presentation/sessions_screen.dart';
import '../features/profile/presentation/settings_screen.dart';
import 'shell.dart';

/// Screens a guest may open; everything else asks to sign in first.
bool isPublicLocation(String path) =>
    path == '/catalog' ||
    path.startsWith('/catalog/') ||
    path.startsWith('/product/') ||
    path == '/ai' ||
    path == '/settings' ||
    path.startsWith('/settings/legal/') ||
    path == '/specialists' ||
    path.startsWith('/auth');

int? _id(GoRouterState s, String name) => int.tryParse(s.pathParameters[name] ?? '');

/// Bridges the session state to go_router's redirect.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(sessionProvider.select((s) => s.signedIn), (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthListenable(ref);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: '/catalog',
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = ref.read(sessionProvider).signedIn;
      final path = state.uri.path;
      if (path == '/' ) return '/catalog';
      if (!signedIn && !isPublicLocation(path)) {
        return Uri(path: '/auth', queryParameters: {'next': state.uri.toString()}).toString();
      }
      if (signedIn && path.startsWith('/auth')) {
        final next = state.uri.queryParameters['next'];
        return next != null && next.startsWith('/') && !next.startsWith('/auth') ? next : '/catalog';
      }
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/catalog', builder: (_, _) => const HomeScreen(), routes: [
              GoRoute(
                path: 'list',
                builder: (_, s) => CatalogListScreen(
                  category: s.uri.queryParameters['category'],
                  search: s.uri.queryParameters['q'],
                  promo: s.uri.queryParameters['promo'] == '1',
                ),
              ),
            ]),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/qr', builder: (_, _) => const QrScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/cart', builder: (_, _) => const CartScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/ai', builder: (_, _) => const AiScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen())]),
        ],
      ),
      GoRoute(path: '/product/:id', builder: (_, s) => ProductScreen(id: _id(s, 'id') ?? 0)),
      GoRoute(path: '/checkout', builder: (_, _) => const CheckoutScreen()),
      GoRoute(path: '/checkout/address', builder: (_, _) => const AddressFormScreen()),
      GoRoute(path: '/pay/:orderId', builder: (_, s) => PaymentScreen(orderId: _id(s, 'orderId') ?? 0, returned: s.uri.queryParameters['returned'] == '1')),
      GoRoute(path: '/orders', builder: (_, _) => const OrdersScreen()),
      GoRoute(path: '/orders/:id', builder: (_, s) => OrderDetailScreen(orderId: _id(s, 'id') ?? 0)),
      GoRoute(path: '/orders/:id/success', builder: (_, s) => OrderSuccessScreen(orderId: _id(s, 'id') ?? 0)),
      GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: '/specialists', builder: (_, _) => const SpecialistsScreen()),
      GoRoute(
        path: '/specialists/:id/book',
        builder: (_, s) => BookingScreen(specialistId: _id(s, 'id') ?? 0, rescheduleFrom: int.tryParse(s.uri.queryParameters['reschedule'] ?? '')),
      ),
      GoRoute(path: '/appointments', builder: (_, _) => const AppointmentsScreen()),
      GoRoute(path: '/appointments/:id', builder: (_, s) => AppointmentScreen(id: _id(s, 'id') ?? 0, created: s.uri.queryParameters['created'] == '1')),
      GoRoute(path: '/settings/legal/:doc', builder: (_, s) => LegalScreen(doc: s.pathParameters['doc'] ?? 'terms')),
      GoRoute(path: '/settings/password', builder: (_, _) => const ChangePasswordScreen()),
      GoRoute(path: '/settings/sessions', builder: (_, _) => const SessionsScreen()),
      GoRoute(path: '/settings/addresses', builder: (_, _) => const AddressesScreen()),
      GoRoute(path: '/settings/delete', builder: (_, _) => const DeleteAccountScreen()),
      GoRoute(path: '/settings/phone', builder: (_, _) => const AttachPhoneScreen()),
      GoRoute(path: '/consent', builder: (_, _) => const ConsentScreen()),
      GoRoute(path: '/auth', builder: (_, s) => AuthPhoneScreen(next: s.uri.queryParameters['next'])),
      GoRoute(path: '/auth/otp', builder: (_, s) => OtpScreen(args: s.extra is OtpArgs ? s.extra! as OtpArgs : null)),
      GoRoute(path: '/auth/password', builder: (_, s) => PasswordScreen(args: s.extra is PasswordArgs ? s.extra! as PasswordArgs : null)),
      GoRoute(path: '/auth/register', builder: (_, s) => RegisterScreen(args: s.extra is RegisterArgs ? s.extra! as RegisterArgs : null)),
      GoRoute(path: '/auth/reset', builder: (_, s) => ResetPasswordScreen(args: s.extra is RegisterArgs ? s.extra! as RegisterArgs : null)),
    ],
    errorBuilder: (context, state) => const HomeScreen(),
  );
});

/// Opens the sign-in screen, coming back to [next] afterwards.
void goSignIn(BuildContext context, {String? next}) {
  final target = next ?? GoRouterState.of(context).uri.toString();
  context.push(Uri(path: '/auth', queryParameters: {'next': target}).toString());
}
