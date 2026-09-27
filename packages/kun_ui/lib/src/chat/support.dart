/// Chat helpers ported from the web's `packages/vue/src/utils/chat.ts`.
/// Internal: components and tests import this by its `src/` path; it is not
/// exported from `kun_ui.dart`.
library;

import 'package:flutter/foundation.dart';
import 'package:kun_ui_messages/kun_ui_messages.dart';

import '../components/avatar.dart';
import '../foundation/calendar.dart';
import 'entities.dart';
import 'grouping.dart';
import 'types.dart';

final RegExp _scheme = RegExp(r'^[a-z][a-z\d+.-]*:', caseSensitive: false);

const Set<String> _safeSchemes = <String>{'http', 'https', 'mailto'};

bool _isZh(String locale) => locale == 'zh-CN';

String _pad2(int n) => n.toString().padLeft(2, '0');

KunCalendarLocale _calendarLocale(String locale) =>
    _isZh(locale) ? KunCalendarLocale.zhCN : KunCalendarLocale.en;

/// A user after [resolveKunChatUser]: a missing or deleted account becomes
/// the locale's "deleted" label with an empty avatar.
@immutable
class KunChatResolvedUser {
  /// Creates a resolved user.
  const KunChatResolvedUser({
    required this.id,
    required this.name,
    required this.avatar,
    required this.deleted,
    required this.avatarUser,
  });

  /// The requested id, or `''` when none was given.
  final String id;

  /// Display name, or the deleted-account string.
  final String name;

  /// Avatar URL, or `''` when deleted.
  final String avatar;

  /// Whether this is a missing or deleted account.
  final bool deleted;

  /// What [KunAvatar] takes. Its id is always `0` so the avatar itself
  /// never links — chat components own the profile tap.
  final KunUser avatarUser;
}

/// Id → user map for [resolveKunChatUser]. A null or empty list is empty.
Map<String, KunChatUser> kunChatUserMap(List<KunChatUser>? users) {
  return <String, KunChatUser>{
    for (final KunChatUser user in users ?? const <KunChatUser>[])
      user.id: user,
  };
}

/// The user [id] in [users]; a missing or `deleted` account becomes
/// "Deleted account" with an empty avatar, as the server ships it.
KunChatResolvedUser resolveKunChatUser(
  Map<String, KunChatUser> users,
  String? id,
  KunMessages messages,
) {
  final KunChatUser? user = id != null && id.isNotEmpty ? users[id] : null;
  final bool deleted = user == null || user.deleted == true;
  final String name = deleted ? messages.chat.deletedUser : user.name;
  final String avatar = deleted ? '' : user.avatar;
  return KunChatResolvedUser(
    id: id ?? '',
    name: name,
    avatar: avatar,
    deleted: deleted,
    avatarUser: KunUser(
      id: 0,
      name: deleted ? '' : name,
      avatar: avatar,
    ),
  );
}

/// Normalizes [value] to local time. The web also accepts a string or epoch;
/// Dart callers already hold a [DateTime].
DateTime kunChatDate(DateTime value) => value.toLocal();

String _formatTime(DateTime local, String locale) {
  if (_isZh(locale)) {
    return '${_pad2(local.hour)}:${_pad2(local.minute)}';
  }
  final int hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final String period = local.hour < 12 ? 'AM' : 'PM';
  return '$hour12:${_pad2(local.minute)} $period';
}

/// Date and time in full, for a tooltip: `2026年9月27日 14:05`.
///
/// Formats [value] in the device's local zone. Locales other than `'zh-CN'`
/// use the `'en'` shape. [locale] is typically
/// [KunMessagesScope.of]`(context).code`.
String formatKunChatFullTime(DateTime value, String locale) {
  final DateTime local = kunChatDate(value);
  if (_isZh(locale)) {
    return '${local.year}年${local.month}月${local.day}日 ${_formatTime(local, locale)}';
  }
  final String month =
      kunMonthAbbreviated[KunCalendarLocale.en]![local.month - 1];
  return '$month ${local.day}, ${local.year}, ${_formatTime(local, 'en')}';
}

/// Clock time in the locale's own short form: `14:05`, `2:05 PM`.
String formatKunChatTime(DateTime value, String locale) {
  return _formatTime(kunChatDate(value), _isZh(locale) ? 'zh-CN' : 'en');
}

/// The date pill over a day of messages: today, yesterday, `9月27日`, and the
/// year only when it is not this one.
String formatKunChatDay(
  DateTime value,
  String locale,
  KunMessages messages, {
  DateTime? now,
}) {
  final DateTime date = kunChatDate(value);
  final DateTime clock = now == null ? DateTime.now() : kunChatDate(now);
  final String key = kunChatDayKey(date);
  final String today = kunChatDayKey(clock);
  if (key == today) {
    return messages.chat.today;
  }
  if (key ==
      kunChatDayKey(
        DateTime.fromMillisecondsSinceEpoch(
          clock.millisecondsSinceEpoch - 86400000,
        ),
      )) {
    return messages.chat.yesterday;
  }
  final bool sameYear = key.substring(0, 4) == today.substring(0, 4);
  if (_isZh(locale)) {
    final String day = '${date.month}月${date.day}日';
    return sameYear ? day : '${date.year}年$day';
  }
  final String month = kunMonthWide[KunCalendarLocale.en]![date.month - 1];
  return sameYear ? '$month ${date.day}' : '$month ${date.day}, ${date.year}';
}

/// The time on a conversation row: clock time today, the weekday within a
/// week, then a short date.
String formatKunChatListTime(
  DateTime value,
  String locale, {
  DateTime? now,
}) {
  final DateTime date = kunChatDate(value);
  final DateTime clock = now == null ? DateTime.now() : kunChatDate(now);
  final String key = kunChatDayKey(date);
  final String today = kunChatDayKey(clock);
  final String tag = _isZh(locale) ? 'zh-CN' : 'en';
  if (key == today) {
    return formatKunChatTime(date, tag);
  }
  final double days =
      (clock.millisecondsSinceEpoch - date.millisecondsSinceEpoch) / 86400000;
  if (days < 6.5) {
    return kunWeekdayAbbreviated[_calendarLocale(tag)]![date.weekday % 7];
  }
  final bool sameYear = key.substring(0, 4) == today.substring(0, 4);
  if (_isZh(tag)) {
    return sameYear
        ? '${date.month}/${date.day}'
        : '${date.year}/${date.month}/${date.day}';
  }
  return sameYear
      ? '${date.month}/${date.day}'
      : '${date.month}/${date.day}/${date.year}';
}

/// Conjunction list: en `A and B` / `A, B, and C`; zh-CN `A和B` / `A、B和C`.
///
/// Locales other than `'zh-CN'` use the English shape.
String kunChatListJoin(List<String> names, String locale) {
  if (names.isEmpty) {
    return '';
  }
  if (names.length == 1) {
    return names.single;
  }
  if (_isZh(locale)) {
    if (names.length == 2) {
      return '${names[0]}和${names[1]}';
    }
    return '${names.sublist(0, names.length - 1).join('、')}和${names.last}';
  }
  if (names.length == 2) {
    return '${names[0]} and ${names[1]}';
  }
  return '${names.sublist(0, names.length - 1).join(', ')}, and ${names.last}';
}

const int _punyBase = 36;
const int _punyTmin = 1;
const int _punyTmax = 26;
const int _punySkew = 38;
const int _punyDamp = 700;
const int _punyInitialBias = 72;
const int _punyInitialN = 128;

int _punyDigit(int d) => d < 26 ? 97 + d : 22 + d;

int _punyAdapt(int delta, int numPoints, bool firstTime) {
  int next = firstTime ? delta ~/ _punyDamp : delta ~/ 2;
  next += next ~/ numPoints;
  int k = 0;
  while (next > ((_punyBase - _punyTmin) * _punyTmax) ~/ 2) {
    next ~/= _punyBase - _punyTmin;
    k += _punyBase;
  }
  return k + (((_punyBase - _punyTmin + 1) * next) ~/ (next + _punySkew));
}

String _punycodeEncode(String input) {
  final List<int> cps = input.runes.toList();
  final StringBuffer output = StringBuffer();
  int n = _punyInitialN;
  int delta = 0;
  int bias = _punyInitialBias;
  int basic = 0;
  for (final int c in cps) {
    if (c < 0x80) {
      output.writeCharCode(c);
      basic++;
    }
  }
  int h = basic;
  if (basic > 0) {
    output.write('-');
  }
  while (h < cps.length) {
    int m = 0x10FFFF;
    for (final int c in cps) {
      if (c >= n && c < m) {
        m = c;
      }
    }
    delta += (m - n) * (h + 1);
    n = m;
    for (final int c in cps) {
      if (c < n) {
        delta++;
      }
      if (c == n) {
        int q = delta;
        for (int k = _punyBase;; k += _punyBase) {
          final int t = k <= bias
              ? _punyTmin
              : (k >= bias + _punyTmax ? _punyTmax : k - bias);
          if (q < t) {
            break;
          }
          output.writeCharCode(
            _punyDigit(t + ((q - t) % (_punyBase - t))),
          );
          q = (q - t) ~/ (_punyBase - t);
        }
        output.writeCharCode(_punyDigit(q));
        bias = _punyAdapt(delta, h + 1, h == basic);
        delta = 0;
        h++;
      }
    }
    delta++;
    n++;
  }
  return output.toString();
}

bool _labelHasNonAscii(String label) {
  for (final int c in label.runes) {
    if (c > 0x7F) {
      return true;
    }
  }
  return false;
}

String _labelToAscii(String label) {
  if (label.isEmpty) {
    return label;
  }
  final String lower = label.toLowerCase();
  if (!_labelHasNonAscii(lower)) {
    return lower;
  }
  return 'xn--${_punycodeEncode(lower)}';
}

String _hostToAscii(String host) {
  if (host.contains(':')) {
    return host;
  }
  String decoded = host;
  try {
    decoded = Uri.decodeComponent(host);
  } on FormatException {
    decoded = host;
  } on ArgumentError {
    decoded = host;
  }
  return decoded.split('.').map(_labelToAscii).join('.');
}

String? _httpHref(Uri uri) {
  final String scheme = uri.scheme.toLowerCase();
  Uri current = uri;
  if (current.host.isEmpty && current.path.startsWith('//')) {
    final StringBuffer rest = StringBuffer('$scheme:${current.path}');
    if (current.hasQuery) {
      rest.write('?${current.query}');
    }
    if (current.hasFragment) {
      rest.write('#${current.fragment}');
    }
    current = Uri.parse(rest.toString());
  }
  if (current.host.isEmpty) {
    return null;
  }
  if (current.host.contains('%20')) {
    return null;
  }
  if (current.hasPort && (current.port < 0 || current.port > 65535)) {
    return null;
  }
  final String asciiHost = _hostToAscii(current.host);
  if (asciiHost != current.host) {
    current = current.replace(host: asciiHost);
  }
  if (current.hasEmptyPath) {
    current = current.replace(path: '/');
  }
  return current.toString();
}

/// An href safe to render from another user's message, or null. A bare
/// `moyu.moe/x` gets `https://`; anything but http(s) and mailto is refused.
///
/// Uses [Uri], not the WHATWG parser. Scheme and host are lowercased, an
/// http(s) URL with an empty path gets `/`, and a host label that contains
/// non-ASCII is encoded with RFC 3492 Punycode (`xn--`), matching `URL.href`
/// for IDN. There is no NFC or UTS 46 mapping. `host:port` without a scheme
/// is refused, as on the web.
String? kunChatSafeUrl(String raw) {
  final String value = raw.trim();
  if (value.isEmpty) {
    return null;
  }
  final String withScheme = _scheme.hasMatch(value) ? value : 'https://$value';
  final Uri uri;
  try {
    uri = Uri.parse(withScheme);
  } on FormatException {
    return null;
  }
  final String scheme = uri.scheme.toLowerCase();
  if (!_safeSchemes.contains(scheme)) {
    return null;
  }
  if (scheme == 'mailto') {
    return uri.toString();
  }
  return _httpHref(uri);
}

/// "Photo" for photos, "Media" otherwise — including a missing [media].
String kunChatMediaLabel(KunChatMedia? media, KunMessages messages) {
  return media is KunChatPhoto ? messages.chat.photo : messages.chat.media;
}

/// One line of plain text standing for a message: its text, or what it
/// carries. Spoilers become a `⠿` mask of 3–12 code points.
String kunChatPlainText(KunChatMessage message, KunMessages messages) {
  if (message.text.isEmpty) {
    return message.media == null
        ? ''
        : kunChatMediaLabel(message.media, messages);
  }
  String text = message.text;
  final List<KunChatEntity> spoilers = normalizeKunChatEntities(
    text,
    message.entities,
  ).where((KunChatEntity e) => e.type == KunChatEntityType.spoiler).toList();
  for (final KunChatEntity entity in spoilers.reversed) {
    final String slice =
        text.substring(entity.offset, entity.offset + entity.length);
    final int size = (slice.runes.length).clamp(3, 12);
    text = text.substring(0, entity.offset) +
        '⠿' * size +
        text.substring(entity.offset + entity.length);
  }
  return text;
}

String _truncate(String text, int max) {
  final String flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final List<int> chars = flat.runes.toList();
  if (chars.length > max) {
    return '${String.fromCharCodes(chars.sublist(0, max))}…';
  }
  return flat;
}

/// Argument bag for [kunChatServiceText].
@immutable
class KunChatServiceContext {
  /// Creates a service-text context.
  const KunChatServiceContext({
    required this.users,
    this.currentUserId,
    required this.messages,
    this.resolveMessage,
  });

  /// Id → user map, from [kunChatUserMap].
  final Map<String, KunChatUser> users;

  /// The viewer's id; they are named "You" in the sentence.
  final String? currentUserId;

  /// Catalog for `chat.*` / `chatService.*` strings. Its [KunMessages.code]
  /// selects the list-join locale.
  final KunMessages messages;

  /// Looks up a pinned message by seq; missing → the media fallback.
  final KunChatMessage? Function(int seq)? resolveMessage;
}

/// The sentence a service message stands for.
String kunChatServiceText(
  KunChatMessage message,
  KunChatServiceContext ctx,
) {
  final KunMessages messages = ctx.messages;
  String nameOf(String id) {
    if (id.isNotEmpty && id == ctx.currentUserId) {
      return messages.chat.you;
    }
    return resolveKunChatUser(ctx.users, id, messages).name;
  }

  final String actor = nameOf(message.senderId);
  final KunChatServiceAction? action = message.serviceAction;
  switch (action) {
    case KunChatGroupCreatedAction(:final String? title):
      return title != null && title.isNotEmpty
          ? messages.chatService.groupCreatedTitled(actor: actor, title: title)
          : messages.chatService.groupCreated(actor: actor);
    case KunChatMembersAddedAction(:final List<String> userIds):
      if (userIds.length == 1 && userIds[0] == message.senderId) {
        return messages.chatService.memberJoined(actor: actor);
      }
      final String users = kunChatListJoin(
        <String>[for (final String id in userIds) nameOf(id)],
        messages.code,
      );
      return messages.chatService.membersAdded(actor: actor, users: users);
    case KunChatMemberLeftAction():
      return messages.chatService.memberLeft(actor: actor);
    case KunChatMemberRemovedAction(:final String userId):
      return messages.chatService
          .memberRemoved(actor: actor, user: nameOf(userId));
    case KunChatTitleChangedAction(:final String title):
      return messages.chatService.titleChanged(actor: actor, title: title);
    case KunChatPhotoChangedAction():
      return messages.chatService.photoChanged(actor: actor);
    case KunChatMessagePinnedAction(:final int seq):
      final KunChatMessage? pinned = ctx.resolveMessage?.call(seq);
      final String text = pinned == null
          ? ''
          : _truncate(kunChatPlainText(pinned, messages), 30);
      return text.isNotEmpty
          ? messages.chatService.messagePinned(actor: actor, text: text)
          : messages.chatService.messagePinnedMedia(actor: actor);
    case KunChatJoinedByLinkAction():
      return messages.chatService.joinedByLink(actor: actor);
    case KunChatUnknownAction():
    case null:
      return message.text;
  }
}
