import 'package:flutter/material.dart';

import '../../../core/widgets/gd_widgets.dart';

// Placeholder: replaced by the feature implementation.
class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key, required this.orderId, this.returned = false});
  final int orderId;
  final bool returned;
  @override
  Widget build(BuildContext context) => const Scaffold(appBar: GdHeader(title: 'PaymentScreen'), body: SizedBox.shrink());
}
