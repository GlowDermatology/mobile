import 'package:flutter/material.dart';

import '../../../core/widgets/gd_widgets.dart';

// Placeholder: replaced by the feature implementation.
class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key, required this.specialistId, this.rescheduleFrom});
  final int specialistId;

  /// Appointment being moved: it is cancelled once the new one is booked.
  final int? rescheduleFrom;
  @override
  Widget build(BuildContext context) => const Scaffold(appBar: GdHeader(title: 'BookingScreen'), body: SizedBox.shrink());
}
