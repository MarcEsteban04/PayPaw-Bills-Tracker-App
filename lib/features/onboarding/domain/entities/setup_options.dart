import 'package:meta/meta.dart';

/// The choices onboarding offers, and a best guess at the right one.
///
/// Curated lists rather than every ISO currency and all six hundred IANA zones:
/// a dropdown nobody can scroll is worse than a short one plus a settings screen
/// later. These cover PayPaw's users and the places they work.
@immutable
class CurrencyOption {
  const CurrencyOption({
    required this.code,
    required this.label,
    required this.symbol,
  });

  final String code;
  final String label;
  final String symbol;

  /// `PHP · ₱ · Philippine peso`, as the dropdown shows it.
  String get description => '$code · $symbol · $label';
}

@immutable
class TimeZoneOption {
  const TimeZoneOption({required this.name, required this.label});

  /// IANA name, which is what `profiles.time_zone` stores.
  final String name;

  /// A city a person recognises, rather than the zone identifier.
  final String label;
}

abstract final class SetupOptions {
  /// PHP first, deliberately — it is the default and the overwhelmingly common
  /// answer, and putting it at the top means most users never open the list.
  static const List<CurrencyOption> currencies = <CurrencyOption>[
    CurrencyOption(code: 'PHP', label: 'Philippine peso', symbol: '₱'),
    CurrencyOption(code: 'USD', label: 'US dollar', symbol: r'$'),
    CurrencyOption(code: 'EUR', label: 'Euro', symbol: '€'),
    CurrencyOption(code: 'GBP', label: 'Pound sterling', symbol: '£'),
    CurrencyOption(code: 'JPY', label: 'Japanese yen', symbol: '¥'),
    CurrencyOption(code: 'SGD', label: 'Singapore dollar', symbol: r'S$'),
    CurrencyOption(code: 'HKD', label: 'Hong Kong dollar', symbol: r'HK$'),
    CurrencyOption(code: 'AUD', label: 'Australian dollar', symbol: r'A$'),
    CurrencyOption(code: 'CAD', label: 'Canadian dollar', symbol: r'C$'),
    CurrencyOption(code: 'AED', label: 'UAE dirham', symbol: 'AED'),
    CurrencyOption(code: 'SAR', label: 'Saudi riyal', symbol: 'SAR'),
    CurrencyOption(code: 'KRW', label: 'South Korean won', symbol: '₩'),
  ];

  /// Ordered by how likely a PayPaw user is to be in one, not alphabetically.
  /// The overseas zones are here because working abroad while paying bills at
  /// home is the norm for a large share of Filipino households.
  static const List<TimeZoneOption> timeZones = <TimeZoneOption>[
    TimeZoneOption(name: 'Asia/Manila', label: 'Manila'),
    TimeZoneOption(name: 'Asia/Singapore', label: 'Singapore'),
    TimeZoneOption(name: 'Asia/Hong_Kong', label: 'Hong Kong'),
    TimeZoneOption(name: 'Asia/Tokyo', label: 'Tokyo'),
    TimeZoneOption(name: 'Asia/Seoul', label: 'Seoul'),
    TimeZoneOption(name: 'Asia/Dubai', label: 'Dubai'),
    TimeZoneOption(name: 'Asia/Riyadh', label: 'Riyadh'),
    TimeZoneOption(name: 'Australia/Sydney', label: 'Sydney'),
    TimeZoneOption(name: 'Europe/London', label: 'London'),
    TimeZoneOption(name: 'Europe/Paris', label: 'Paris'),
    TimeZoneOption(name: 'America/New_York', label: 'New York'),
    TimeZoneOption(name: 'America/Chicago', label: 'Chicago'),
    TimeZoneOption(name: 'America/Los_Angeles', label: 'Los Angeles'),
    TimeZoneOption(name: 'Pacific/Honolulu', label: 'Honolulu'),
    TimeZoneOption(name: 'UTC', label: 'UTC'),
  ];

  /// The reminder offsets a bill can be announced at, furthest first.
  static const List<int> reminderDayChoices = <int>[7, 3, 1, 0];

  /// Best guess at a currency from a locale's country code.
  ///
  /// Returns null when there is no confident answer, so the caller falls back to
  /// the column default rather than to a wrong guess. A wrong currency is worse
  /// than the default one: the default is obviously wrong to a user in London,
  /// while `USD` quietly *looks* plausible.
  static String? currencyForCountry(String? countryCode) =>
      _currencyByCountry[countryCode?.toUpperCase()];

  /// Best guess at a zone from the device's current UTC offset.
  ///
  /// Offsets are ambiguous — Manila, Singapore, Hong Kong and Perth all sit at
  /// +08:00 — so this is a starting point the user confirms, never a silent
  /// decision. Ambiguity is resolved towards Manila, because that is who this app
  /// is for.
  ///
  /// Reading a real IANA name needs a platform channel. That arrives with
  /// notification scheduling in Phase 8, which needs the zone for correctness
  /// rather than as a default; guessing here is not worth a dependency.
  static String? timeZoneForOffset(Duration offset) =>
      _zoneByOffsetMinutes[offset.inMinutes];

  static const Map<String, String> _currencyByCountry = <String, String>{
    'PH': 'PHP',
    'US': 'USD',
    'GB': 'GBP',
    'JP': 'JPY',
    'SG': 'SGD',
    'HK': 'HKD',
    'AU': 'AUD',
    'CA': 'CAD',
    'AE': 'AED',
    'SA': 'SAR',
    'KR': 'KRW',
    'DE': 'EUR',
    'FR': 'EUR',
    'ES': 'EUR',
    'IT': 'EUR',
    'NL': 'EUR',
    'IE': 'EUR',
    'PT': 'EUR',
  };

  static const Map<int, String> _zoneByOffsetMinutes = <int, String>{
    480: 'Asia/Manila', // +08:00 — also Singapore, Hong Kong, Perth.
    540: 'Asia/Tokyo', // +09:00 — also Seoul.
    240: 'Asia/Dubai',
    180: 'Asia/Riyadh',
    600: 'Australia/Sydney', // AEST; +11:00 in summer, handled below.
    660: 'Australia/Sydney',
    0: 'Europe/London', // GMT. UTC is also 0; London is the likelier device.
    60: 'Europe/Paris', // BST is also +01:00, hence a confirm step.
    120: 'Europe/Paris',
    -300: 'America/New_York',
    -240: 'America/New_York', // EDT.
    -360: 'America/Chicago',
    -480: 'America/Los_Angeles',
    -420: 'America/Los_Angeles', // PDT.
    -600: 'Pacific/Honolulu',
  };
}
