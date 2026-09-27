/// The message list's row model, as data: day sections, sender groups, albums
/// merged into one row, and the unread divider. The Vue list renders it, the
/// Flutter port computes the same rows from the same function.
library;

import 'package:flutter/foundation.dart';

import 'constants.dart';
import 'types.dart';

/// The row identity of a message: its `client_message_id` when it has one, so
/// a pending message keeps its row when the server confirms it.
String kunChatMessageKey(KunChatMessage message) =>
    message.clientMessageId != null && message.clientMessageId!.isNotEmpty
        ? 'c:${message.clientMessageId}'
        : 'm:${message.id}';

String _pad(int n) => n.toString().padLeft(2, '0');

/// `YYYY-MM-DD` of an instant in the device's local zone. Keys sort
/// chronologically as strings.
String kunChatDayKey(DateTime date) {
  final DateTime local = date.toLocal();
  return '${local.year}-${_pad(local.month)}-${_pad(local.day)}';
}

/// A row in the message list: the unread divider, a service message, or an
/// ordinary (possibly album) message.
@immutable
sealed class KunChatListRow {
  /// Creates a list row.
  const KunChatListRow();

  /// Stable row identity.
  String get key;
}

/// The unread divider.
@immutable
class KunChatUnreadRow extends KunChatListRow {
  /// Creates an unread divider.
  const KunChatUnreadRow({required this.key});

  @override
  final String key;

  @override
  bool operator ==(Object other) =>
      other is KunChatUnreadRow && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'KunChatUnreadRow($key)';
}

/// A service-message row.
@immutable
class KunChatServiceRow extends KunChatListRow {
  /// Creates a service row.
  const KunChatServiceRow({required this.key, required this.message});

  @override
  final String key;

  /// The service message.
  final KunChatMessage message;

  @override
  bool operator ==(Object other) =>
      other is KunChatServiceRow &&
      other.key == key &&
      other.message == message;

  @override
  int get hashCode => Object.hash(key, message);

  @override
  String toString() => 'KunChatServiceRow($key)';
}

/// An ordinary message row, possibly an album.
@immutable
class KunChatMessageRow extends KunChatListRow {
  /// Creates a message row.
  const KunChatMessageRow({
    required this.key,
    required this.message,
    required this.messages,
    required this.own,
    required this.groupStart,
    required this.groupEnd,
  });

  @override
  final String key;

  /// The message the row acts as: an album's first message with a
  /// caption, else its first; the message itself otherwise.
  final KunChatMessage message;

  /// Every message the row shows — an album's photos, in order.
  final List<KunChatMessage> messages;

  /// Whether the viewer sent this row.
  final bool own;

  /// First of consecutive messages from one sender: the name goes here.
  final bool groupStart;

  /// Last of the run: the avatar and the bubble tail go here.
  final bool groupEnd;

  @override
  bool operator ==(Object other) =>
      other is KunChatMessageRow &&
      other.key == key &&
      other.message == message &&
      listEquals(other.messages, messages) &&
      other.own == own &&
      other.groupStart == groupStart &&
      other.groupEnd == groupEnd;

  @override
  int get hashCode => Object.hash(
        key,
        message,
        Object.hashAll(messages),
        own,
        groupStart,
        groupEnd,
      );

  @override
  String toString() =>
      'KunChatMessageRow($key, own: $own, start: $groupStart, end: $groupEnd)';
}

/// One calendar day's worth of rows.
@immutable
class KunChatDaySection {
  /// Creates a day section.
  const KunChatDaySection({
    required this.key,
    required this.date,
    required this.rows,
  });

  /// `YYYY-MM-DD` in the device's local zone.
  final String key;

  /// The first message's instant, for formatting the date pill.
  final DateTime date;

  /// Rows in this day, in display order.
  final List<KunChatListRow> rows;

  @override
  bool operator ==(Object other) =>
      other is KunChatDaySection &&
      other.key == key &&
      other.date.isAtSameMomentAs(date) &&
      listEquals(other.rows, rows);

  @override
  int get hashCode =>
      Object.hash(key, date.microsecondsSinceEpoch, Object.hashAll(rows));

  @override
  String toString() => 'KunChatDaySection($key, ${rows.length} rows)';
}

KunChatMessage _albumRepresentative(List<KunChatMessage> messages) {
  for (final KunChatMessage m in messages) {
    if (m.text.isNotEmpty) return m;
  }
  return messages[0];
}

class _Prev {
  _Prev({
    required this.sender,
    required this.at,
    required this.row,
    required this.rows,
  });

  final String sender;
  final int at;
  KunChatMessageRow row;
  final List<KunChatListRow> rows;
}

/// Arrange messages — already in display order — into day sections and rows.
/// A sender group breaks on another sender, a new day, a gap longer than
/// [groupWindow], the unread divider, and any service message.
List<KunChatDaySection> groupKunChatMessages(
  List<KunChatMessage> messages, {
  required String currentUserId,
  int? lastReadSeq,
  Duration groupWindow = const Duration(minutes: 10),
}) {
  final int windowMs = groupWindow.inMilliseconds;
  final List<KunChatDaySection> sections = <KunChatDaySection>[];
  bool dividerPlaced = lastReadSeq == null;
  _Prev? prev;

  void closeGroup() {
    if (prev == null) return;
    final KunChatMessageRow row = prev!.row;
    final KunChatMessageRow closed = KunChatMessageRow(
      key: row.key,
      message: row.message,
      messages: row.messages,
      own: row.own,
      groupStart: row.groupStart,
      groupEnd: true,
    );
    final int i =
        prev!.rows.indexWhere((KunChatListRow r) => identical(r, row));
    prev!.rows[i] = closed;
    prev = null;
  }

  for (int i = 0; i < messages.length; i++) {
    final KunChatMessage message = messages[i];
    final int at = message.createdAt.millisecondsSinceEpoch;
    final DateTime date = message.createdAt;
    final String key = kunChatDayKey(date);

    KunChatDaySection? section =
        sections.isEmpty ? null : sections[sections.length - 1];
    // Only ever forward: a pending message stamped by a slow local clock
    // joins the current day instead of reopening an earlier one.
    if (section == null || key.compareTo(section.key) > 0) {
      closeGroup();
      section = KunChatDaySection(
        key: key,
        date: date,
        rows: <KunChatListRow>[],
      );
      sections.add(section);
    }

    final bool own = message.senderId == currentUserId;
    if (!dividerPlaced &&
        !own &&
        message.seq > lastReadSeq! &&
        message.seq > 0) {
      closeGroup();
      section.rows.add(const KunChatUnreadRow(key: 'unread'));
      dividerPlaced = true;
    }

    if (message.kind == KunChatMessageKind.service) {
      closeGroup();
      section.rows.add(
        KunChatServiceRow(key: kunChatMessageKey(message), message: message),
      );
      continue;
    }

    List<KunChatMessage> group = <KunChatMessage>[message];
    if (message.mediaGroupId != null) {
      while (group.length < kunChatAlbumLimit &&
          i + 1 < messages.length &&
          messages[i + 1].kind == KunChatMessageKind.message &&
          messages[i + 1].mediaGroupId == message.mediaGroupId &&
          messages[i + 1].senderId == message.senderId) {
        i++;
        group = <KunChatMessage>[...group, messages[i]];
      }
    }

    final bool continues = prev != null &&
        prev!.sender == message.senderId &&
        at - prev!.at <= windowMs;
    if (!continues) closeGroup();

    final KunChatMessageRow row = KunChatMessageRow(
      key: kunChatMessageKey(message),
      message: group.length > 1 ? _albumRepresentative(group) : message,
      messages: group,
      own: own,
      groupStart: !continues,
      groupEnd: false,
    );
    section.rows.add(row);
    final KunChatMessage last = group[group.length - 1];
    final int lastAt = last.createdAt.millisecondsSinceEpoch;
    prev = _Prev(
      sender: message.senderId,
      at: lastAt,
      row: row,
      rows: section.rows,
    );
  }
  closeGroup();
  return sections;
}
