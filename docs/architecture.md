# Architecture

## Layers

```
presentation (screens, widgets)  ─ watches ─▶  application (Riverpod notifiers)  ─ calls ─▶  data (API + models)
                                                                                              │
                                                                         core/network/ApiClient ─▶ Django /api/v1/
```

- **State:** Riverpod 3 (`Notifier`, `AsyncNotifier`, `FutureProvider`), no code generation. App-wide providers
  are in `lib/app/providers.dart`; the session in `lib/features/auth/application/session_controller.dart`; the
  server cart (also the tab badge) in `lib/features/cart/application/cart_controller.dart`.
- **Navigation:** go_router (`lib/app/router.dart`): a five-tab `StatefulShellRoute` plus full-screen routes. Guests
  can open the catalog, product pages, specialists, settings and legal texts; any other route redirects to
  `/auth?next=…` and returns there after sign-in. "Add to cart" by a guest is replayed after sign-in
  (`lib/core/links/pending_action.dart`).
- **Models:** small hand-written classes with `fromJson` (`lib/core/network/json.dart`), one file per feature.

## Talking to the API (`lib/core/network/api_client.dart`)

- Every request carries the device headers of the contract (§1.2): `X-GD-Device-Id` (random id created once per
  install, `lib/core/device/device_identity.dart`), `X-GD-Platform`, `X-GD-App-Version`, and `Accept-Language`.
  `X-GD-Device-Key` (issued once per verified sign-in; it lets a password sign-in on this phone skip the SMS
  step) is sent on `auth/login/` only.
- **Tokens:** the 15-minute access token lives in memory; the rotating refresh token, the device key and the device
  id are in the Keychain (this device only, no iCloud sync) / Android Keystore (no backups). A refresh rotates the
  refresh token, so refresh is **single-flight**: concurrent requests wait for one `auth/refresh/`, the new token
  is stored before any retry.
- 401 `SESSION_EXPIRED` / `password_changed` (or a refused refresh) sign the user out (with the server's message
  for `password_changed`); 426 shows the "update the app" screen.
- Writes that can be repeated by a network retry carry an `Idempotency-Key` (`idempotencyProvider`: one key per
  user intent, reused on retries).
- Errors become `ApiException` (code, localized message, field errors, details); screens branch on the code.

## Delivery (Yandex courier, BTS post)

`settings/public/` lists the carriers (`delivery.providers`); delivery is offered when any is listed. With
delivery selected, checkout asks `delivery/calculate/` **with options** and shows one card per carrier and method
(Yandex Standard, Yandex Express, BTS) with the server's label, price, delivery window and, for a refused option,
the reason and what to do (add the map pin, complete the address, try again). A Yandex price is a **quote** valid
for 15 minutes: checkout sends its `delivery_quote_id`, the app re-quotes silently when it runs out (measured on the
server's clock) and asks the customer to confirm whenever the fee or total changed. A refused checkout
(`quote_expired`, a delivery `price_changed`, `delivery_unavailable`) is handled the same way. The decisions are pure
functions in `lib/features/checkout/application/delivery_flow.dart`, ported from the website's `delivery-flow.ts`.

Yandex needs the address's **map pin**. The address form has an OpenStreetMap map (`flutter_map`, tiles from
`MAP_TILE_URL`): tap or drag to set the pin, "my location" through `geolocator` (optional permission), or pin the map
centre. An order shipped by Yandex shows its courier stage, expected window, courier and Yandex's tracking page,
re-reading itself every 30 s while the parcel moves.

## Unpaid orders

The cart answer carries the customer's unpaid (or just expired) checkout. The cart shows it on top: continue
payment, or edit it (`reorder` with `cancel_unpaid`: the order is cancelled and its lines return to the cart). A new
checkout waits until it is resolved.

## Images

Lists and rows load the 400 px variants, cards, banners and the product gallery the 1000 px ones; each falls back to
the original when a variant is missing (`GdImage.fallbackUrl`).

## Payments

Checkout creates the order (stock reserved for `reservation_minutes`), the payment screen asks the API for the
Click, Payme or Uzum page and opens it in the **system browser** (never a web view); a `web_url` that is not https is
never opened. Uzum is Uzum Bank's hosted card form (Uzcard, Humo, Visa, Mastercard): the customer does not need the
Uzum Bank app, and its `pay_by` may end before the reservation (the form's session). The providers come from
`payment_providers` in `GET settings/public/`; values the app does not know are dropped, so a provider added on the
server later never reaches the picker or the checkout body. The provider sends the customer to
`https://glowderma.uz/pay/return?order_id=N`, which opens the app (App Links / universal links, configured by the
website's `.well-known` files) or, failing that, the website page hands over through `glowderma://payment/return`.
The app then polls the order every 2 s for up to a minute, and again whenever it comes back to the foreground.
Only the order id is taken from the link; the order is always re-read from the API.

## Push notifications

`lib/core/push/push_service.dart`: Firebase Cloud Messaging when `FIREBASE_ENABLED=true` (off by default). The app
registers its token with `PUT me/device/` on every start and sign-in, shows foreground messages on the backend's
Android channels (`orders`, `appointments`, `promo`, `general`), opens the right screen on a tap and acknowledges
delivery with `POST me/notifications/ack/`. Without Firebase the inbox still works (it is read from the API).

## Design system

`lib/app/theme/` mirrors the website's tokens (`frontend/src/app/globals.css`): gold/ink/surface palette in light
and dark, Cormorant Garamond for display sizes and Manrope for text, 8/12/20 px radii. Shared widgets are in
`lib/core/widgets/`. Strings: `Tr('uz', 'ru', 'en')` constants per feature; texts the server renders (statuses,
errors, ledger lines) are shown as they come, in the language sent in `Accept-Language`.

## Decisions

| Decision | Why |
|---|---|
| Device id generated by the app, not the Firebase installation id | the API binds sessions to it; a rotating id would end sessions, and the app must work without Firebase |
| No code generation (freezed, riverpod_generator) | fewer tools for a small team; models are simple |
| Firebase initialised from Dart only | builds work without any Firebase file; `flutterfire configure --no-apply-gradle-plugins` |
| AI tab is a placeholder | the backend has no AI endpoints yet (contract: "Phase 2") |
| Cart checkboxes remove selected lines | the API always checks out the whole cart |
| "Mashhur mahsulotlar" = promo products, then newest | the API has no popularity ordering |
| No cash payment | the API offers Click, Payme and Uzum only; the row is shown disabled ("Tez orada") |
| OpenStreetMap tiles, no geocoding | no API key needed, same as the website; a paid tile provider can be set with `MAP_TILE_URL` |
| The app never adds up a delivery fee | every price and total comes from the server's quote |
