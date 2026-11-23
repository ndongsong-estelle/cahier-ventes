import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/session.dart';
import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/telemetry/telemetry.dart';
import '../../core/ui/contact.dart';

/// Relancer sur WhatsApp. Numéro inconnu : demandé une fois puis gardé.
Future<void> remind(
  BuildContext context,
  WidgetRef ref,
  Person person,
  int owed,
) async {
  var phone = person.phone;
  if (phone == null) {
    phone = await askPhone(context, person.name);
    if (phone == null) return;
    await ref.read(ledgerProvider).updatePerson(person.id, phone: phone);
  }
  final shop = ref.read(sessionProvider).shopName ?? '';
  trackWith(ref.read(telemetryProvider), 'reminder_sent');
  await ref.read(urlOpenerProvider)(
    whatsAppUri(
      phone,
      reminderText(name: person.name, shop: shop, amount: owed),
    ),
  );
}

Future<void> callPerson(
  BuildContext context,
  WidgetRef ref,
  Person person,
) async {
  var phone = person.phone;
  if (phone == null) {
    phone = await askPhone(context, person.name);
    if (phone == null) return;
    await ref.read(ledgerProvider).updatePerson(person.id, phone: phone);
  }
  trackWith(ref.read(telemetryProvider), 'call_made');
  await ref.read(urlOpenerProvider)(callUri(phone));
}
