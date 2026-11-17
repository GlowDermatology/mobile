import 'package:flutter/material.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/i18n/tr.dart';
import '../../profile/data/addresses_api.dart';
import '../application/delivery_flow.dart';
import '../data/checkout_api.dart';
import 'checkout_text.dart';
import 'checkout_widgets.dart';

int _dayIndex(DateTime instant) {
  final t = tashkent(instant);
  return DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
}

/// The server's delivery window in Tashkent time: "Bugun, 14:30–16:00",
/// "26-oktabr, 14:30–16:00", "26-oktabr, 18:00 – 27-oktabr, 10:00". With
/// [now] (when the quote arrived) today and tomorrow read "Bugun"/"Ertaga".
/// Null when the server sent no window.
String? formatEtaWindow(
  DateTime? from,
  DateTime? to,
  AppLanguage language, {
  DateTime? now,
}) {
  final start = from ?? to;
  final end = to ?? from;
  if (start == null || end == null) return null;
  String day(DateTime d) {
    if (now != null) {
      final offset = _dayIndex(d) - _dayIndex(now);
      if (offset == 0) return DeliveryText.today.get(language);
      if (offset == 1) return DeliveryText.tomorrow.get(language);
    }
    return formatDayMonth(d, language);
  }

  if (_dayIndex(start) == _dayIndex(end)) {
    final a = formatTime(start);
    final b = formatTime(end);
    return a == b ? '${day(start)}, $a' : '${day(start)}, $a–$b';
  }
  return '${day(start)}, ${formatTime(start)} – ${day(end)}, ${formatTime(end)}';
}

String _fill(String text, Map<String, String> values) {
  var out = text;
  values.forEach((k, v) => out = out.replaceAll('{$k}', v));
  return out;
}

/// "The delivery price changed: now {to} (was {from})…".
String deliveryPriceChangedText(int from, int to, AppLanguage language) =>
    _fill(CheckoutText.deliveryPriceChanged.get(language), {
      'from': formatMoney(from, language: language),
      'to': formatMoney(to, language: language),
    });

/// What the page says after a re-quote that differs from what the customer
/// saw (null when nothing changed).
String? requoteNotice(RequoteOutcome outcome, AppLanguage language) =>
    switch (outcome) {
      RequoteSame() => null,
      RequoteFeeChanged(:final from, :final to) => deliveryPriceChangedText(
        from,
        to,
        language,
      ),
      RequoteTotalChanged() => CheckoutText.priceChanged.get(language),
      RequoteReplaced(:final label) =>
        label.isEmpty
            ? CheckoutText.quoteExpired.get(language)
            : _fill(CheckoutText.optionReplaced.get(language), {
                'label': label,
              }),
      RequoteNone() => DeliveryText.none.get(language),
    };

/// `yandex.standard`, `yandex.express`, `bts` (Semantics identifiers).
String optionKey(DeliveryChoice choice) => choice.method == null
    ? choice.provider
    : '${choice.provider}.${choice.method}';

/// The carrier options of checkout (Yandex Standard / Express, BTS), each
/// with the server's label, fee and window. A refused option is a disabled
/// card with its reason and, where the customer can fix it, the way to.
class DeliveryOptionsList extends StatelessWidget {
  const DeliveryOptionsList({
    super.key,
    required this.options,
    required this.chosen,
    required this.address,
    required this.pending,
    required this.now,
    required this.onChoose,
    required this.onFixAddress,
    required this.onRetry,
  });

  final List<DeliveryOption> options;
  final DeliveryChoice? chosen;
  final Address? address;
  final bool pending;

  /// When the quote arrived ("Bugun" / "Ertaga" are read against it).
  final DateTime? now;
  final ValueChanged<DeliveryChoice> onChoose;
  final VoidCallback onFixAddress;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final t = context.gdText;
    final lang = context.language;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: pending ? 0.8 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _card(context, c, t, lang, o),
            ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context,
    GdColors c,
    GdText t,
    AppLanguage lang,
    DeliveryOption o,
  ) {
    final key = optionKey(o.choice);
    final problem = optionProblem(
      o,
      hasAddress: address != null,
      addressHasRegion: address?.hasRegion ?? false,
    );
    final window = o.available
        ? formatEtaWindow(o.etaFrom, o.etaTo, lang, now: now)
        : null;
    final detail = problem != null
        ? DeliveryText.reason(problem.reason).get(lang)
        : window != null
        ? DeliveryText.eta.get(lang).replaceAll('{window}', window)
        : null;
    final price = !o.available
        ? DeliveryText.unavailable.get(lang)
        : o.fee == 0
        ? DeliveryText.free.get(lang)
        : o.fee != null
        ? formatMoney(o.fee!, language: lang)
        : '—';
    final action = problem?.action;
    final footer = <Widget>[
      if (o.available && o.scheduled)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 58),
          child: Text(DeliveryText.scheduled.get(lang), style: t.caption),
        ),
      if (action != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              identifier: 'checkout.option.$key.action',
              button: true,
              child: TextButton.icon(
                onPressed: action == OptionAction.retry
                    ? (pending ? null : onRetry)
                    : onFixAddress,
                icon: Icon(switch (action) {
                  OptionAction.pin => Icons.add_location_alt_outlined,
                  OptionAction.edit => Icons.edit_outlined,
                  OptionAction.retry => Icons.refresh_rounded,
                }, size: 18),
                label: Text(switch (action) {
                  OptionAction.pin => DeliveryText.addPin.get(lang),
                  OptionAction.edit => DeliveryText.editAddress.get(lang),
                  OptionAction.retry => DeliveryText.retry.get(lang),
                }),
              ),
            ),
          ),
        ),
    ];
    return GdOptionCard(
      selected: o.available && sameChoice(o.choice, chosen),
      dimmed: !o.available,
      icon: o.isYandex ? Icons.local_shipping_outlined : Icons.send_outlined,
      title: o.label,
      subtitle: detail,
      trailing: Text(
        price,
        style: o.available
            ? t.label.copyWith(color: o.fee == 0 ? c.success : c.ink)
            : t.caption,
      ),
      footer: footer.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: footer,
            ),
      semanticsId: 'checkout.option.$key',
      onTap: o.available ? () => onChoose(o.choice) : null,
    );
  }
}
