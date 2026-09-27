/// Chat limits and timings shared with the server and the Flutter port.
library;

/// Longest message text, in UTF-16 code units (Telegram's value).
const int kunChatTextLimit = 4096;

/// Most photos one album can hold.
const int kunChatAlbumLimit = 10;

/// A client sends at most one typing notification per this interval.
const Duration kunChatTypingInterval = Duration(milliseconds: 5000);

/// A typing notification not renewed within this timeout has expired.
const Duration kunChatTypingTimeout = Duration(milliseconds: 6000);
