import 'package:flutter/material.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../core/i18n/tr.dart';
import '../data/addresses_api.dart';

/// Whether an address is pinned on the map (a courier service needs it).
abstract final class PinNoteText {
  static const pinned = Tr(
    'Xaritada belgilangan',
    'Отмечен на карте',
    'Pinned on the map',
  );
  static const missing = Tr(
    'Xaritada belgilanmagan — kuryer uchun nuqta qo‘ying',
    'Не отмечен на карте — поставьте точку для курьера',
    'Not pinned on the map — add a point for the courier',
  );
}

/// "📍 Pinned on the map" / "Not pinned on the map — …", shown under an
/// address in the address list and at checkout.
class AddressPinNote extends StatelessWidget {
  const AddressPinNote({super.key, required this.address});
  final Address address;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final pinned = address.hasPin;
    final color = pinned ? c.success : c.warning;
    return Row(
      children: [
        Icon(
          pinned ? Icons.location_on : Icons.location_off_outlined,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            (pinned ? PinNoteText.pinned : PinNoteText.missing).of(context),
            style: context.gdText.caption.copyWith(
              color: pinned ? c.inkMuted : c.warning,
            ),
          ),
        ),
      ],
    );
  }
}
