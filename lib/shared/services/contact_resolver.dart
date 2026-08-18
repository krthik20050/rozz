import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:rozz/shared/utils/phone_normalizer.dart';

/// A minimal contact record decoupled from the plugin, so the resolver is
/// unit-testable with plain data.
class PhoneContact {
  final String name;
  final List<String> phones;

  const PhoneContact({required this.name, required this.phones});
}

/// Loads the device address book once and exposes a phone-number → contact
/// name lookup. The fetch function is injectable for tests; the default reads
/// via flutter_contacts with a permission request.
class ContactResolver {
  final Future<List<PhoneContact>> Function() _fetch;

  Map<String, String>? _phoneToName;

  ContactResolver({Future<List<PhoneContact>> Function()? fetch})
      : _fetch = fetch ?? _fetchFromDevice;

  /// Normalized (last-10-digit) phone → contact display name.
  Future<Map<String, String>> phoneToName() async {
    if (_phoneToName != null) return _phoneToName!;
    final contacts = await _fetch();
    final map = <String, String>{};
    for (final contact in contacts) {
      for (final phone in contact.phones) {
        final digits = lastTenDigits(phone);
        if (digits != null) {
          map.putIfAbsent(digits, () => contact.name);
        }
      }
    }
    _phoneToName = map;
    return map;
  }

  /// Re-fetch contacts (e.g. the user just granted permission in settings) and
  /// rebuild the lookup, discarding any cached result.
  Future<Map<String, String>> refreshPhoneToName() async {
    _phoneToName = null;
    return phoneToName();
  }

  static Future<List<PhoneContact>> _fetchFromDevice() async {
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    if (status != PermissionStatus.granted) return const [];
    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.name, ContactProperty.phone},
    );
    return contacts
        .map((c) => PhoneContact(
              name: (c.displayName?.isEmpty ?? true) ? 'Unknown' : c.displayName!,
              phones: c.phones.map((p) => p.number).toList(),
            ))
        .toList();
  }
}
