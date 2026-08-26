import 'notification_channel.dart';

/// A scheduler id for [key], stable across releases.
///
/// Android notification ids are 32-bit ints and the things PayPaw notifies about
/// are UUIDs, so the key has to be hashed. FNV-1a rather than `String.hashCode`,
/// which Dart does not promise is stable between releases.
///
/// Stability is not load-bearing — the scheduler cancels every pending
/// notification before laying down a new set, so an id only has to be unique
/// within one pass — but a specified hash is reproducible in a test, and a
/// collision would drop a notice with no sign that it happened.
///
/// **The key must name the kind as well as the subject.** Without it, a bill
/// reminder three days out and an overdue notice three days late would collide
/// on the same bill, and one of them would vanish.
int noticeIdFor(String key) {
  int hash = 0x811C9DC5;

  for (final int unit in key.codeUnits) {
    hash ^= unit;
    // Multiply by the FNV prime, kept inside 32 bits. Dart ints are 64-bit, so
    // the mask is what makes this the specified algorithm rather than something
    // that merely resembles it.
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }

  return hash & 0x7FFFFFFF;
}

/// Everything the platform scheduler needs to lay down one notification.
///
/// ## Why this exists
///
/// `replaceScheduledNotices` cancels every pending notification and lays down
/// the set it is given. That makes it the *whole* schedule, which means a second
/// call for a second kind of notice would wipe the first — and the failure would
/// be silent, discovered days later by a reminder that never arrived.
///
/// So there is one call, and it takes anything schedulable. Bills implement this
/// and so do subscriptions, and neither knows the other exists.
abstract interface class ScheduledNotice {
  /// A unique id for the platform scheduler.
  ///
  /// Unique across *every* kind, not just within one. Two notices sharing an id
  /// is one notice: the second silently replaces the first.
  int get notificationId;

  /// What it says on the lock screen.
  String get title;

  /// The line beneath it.
  String get body;

  /// Local wall-clock time it should arrive. Not a UTC instant — see the note in
  /// `LocalNotificationService` on why the fields are read individually.
  DateTime get firesAt;

  /// Which category it posts under, and therefore which toggle silences it.
  NotificationChannel get channel;

  /// What the tap handler receives. See [NoticeTarget].
  String get payload;
}

/// What a notification opens when it is tapped.
///
/// ## Why the payload is typed now
///
/// It used to be a bare bill id, which was unambiguous while bills were the only
/// thing that notified. Subscriptions are a second kind, their ids are UUIDs
/// too, and routing to the wrong screen because a string could be either would
/// be a bug with no signature.
///
/// An unprefixed payload is read as a bill. That is not politeness to old data
/// so much as to *pending* data: a notification scheduled by a previous build is
/// sitting in Android's alarm table with a bare id in it, and it will fire.
/// (The schedule is rebuilt at every launch, so this heals itself — but it heals
/// after the notification, not before.)
enum NoticeTargetKind {
  bill('bill'),
  subscription('subscription');

  const NoticeTargetKind(this.prefix);

  final String prefix;
}

/// Reading and writing notification payloads.
abstract final class NoticeTarget {
  /// Builds a payload for [id] of [kind].
  static String encode(NoticeTargetKind kind, String id) =>
      '${kind.prefix}:$id';

  /// Reads a payload, defaulting to a bill. Null when there is nothing usable.
  static (NoticeTargetKind, String)? decode(String? payload) {
    final String raw = payload?.trim() ?? '';

    if (raw.isEmpty) {
      return null;
    }

    for (final NoticeTargetKind kind in NoticeTargetKind.values) {
      final String prefix = '${kind.prefix}:';

      if (raw.startsWith(prefix)) {
        final String id = raw.substring(prefix.length);

        return id.isEmpty ? null : (kind, id);
      }
    }

    // No prefix: a payload from a build that only knew about bills.
    return (NoticeTargetKind.bill, raw);
  }
}
