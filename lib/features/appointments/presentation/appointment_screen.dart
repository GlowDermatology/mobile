import 'package:flutter/material.dart';

import '../../../core/widgets/gd_widgets.dart';

// Placeholder: replaced by the feature implementation.
class AppointmentScreen extends StatelessWidget {
  const AppointmentScreen({super.key, required this.id, this.created = false});
  final int id;
  final bool created;
  @override
  Widget build(BuildContext context) => const Scaffold(appBar: GdHeader(title: 'AppointmentScreen'), body: SizedBox.shrink());
}
