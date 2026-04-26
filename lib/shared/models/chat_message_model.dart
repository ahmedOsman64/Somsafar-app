import 'user_model.dart';

class ChatMessage {
  final String id;
  final String bookingId;
  final String senderId;
  final UserRole senderRole;
  final String messageText;
  final DateTime timestamp;
  final bool visibleToTraveler;
  final bool isInternalNote;

  const ChatMessage({
    required this.id,
    required this.bookingId,
    required this.senderId,
    required this.senderRole,
    required this.messageText,
    required this.timestamp,
    required this.visibleToTraveler,
    this.isInternalNote = false,
  });

  /// Factory constructor for creating traveler messages
  /// Traveler messages are always visible to traveler
  factory ChatMessage.fromTraveler({
    required String id,
    required String bookingId,
    required String travelerId,
    required String messageText,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      id: id,
      bookingId: bookingId,
      senderId: travelerId,
      senderRole: UserRole.traveler,
      messageText: messageText,
      timestamp: timestamp ?? DateTime.now(),
      visibleToTraveler: true,
      isInternalNote: false,
    );
  }

  /// Factory constructor for creating provider replies
  /// Provider replies are NOT visible to traveler by default
  factory ChatMessage.fromProvider({
    required String id,
    required String bookingId,
    required String providerId,
    required String messageText,
    DateTime? timestamp,
    bool isInternalNote = false,
    UserRole? senderRole,
  }) {
    return ChatMessage(
      id: id,
      bookingId: bookingId,
      senderId: providerId,
      senderRole: senderRole ?? UserRole.provider,
      messageText: messageText,
      timestamp: timestamp ?? DateTime.now(),
      visibleToTraveler: !isInternalNote, // Provider replies visible to traveler unless marked internal
      isInternalNote: isInternalNote,
    );
  }

  /// Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookingId': bookingId,
      'senderId': senderId,
      'senderRole': senderRole.name,
      'messageText': messageText,
      'timestamp': timestamp.toIso8601String(),
      'visibleToTraveler': visibleToTraveler,
      'isInternalNote': isInternalNote,
    };
  }

  /// Create from Map data
  factory ChatMessage.fromMap(Map<String, dynamic> data) {
    return ChatMessage(
      id: data['id'] as String,
      bookingId: data['bookingId'] as String,
      senderId: data['senderId'] as String,
      senderRole: UserRole.values.firstWhere(
        (e) => e.name == data['senderRole'],
        orElse: () => UserRole.traveler,
      ),
      messageText: data['messageText'] as String,
      timestamp: DateTime.parse(data['timestamp'] as String),
      visibleToTraveler: data['visibleToTraveler'] as bool,
      isInternalNote: data['isInternalNote'] as bool? ?? false,
    );
  }

  /// Helper to determine if message is from traveler
  bool get isFromTraveler => senderRole == UserRole.traveler;

  /// Helper to determine if message is from provider
  bool get isFromProvider => senderRole == UserRole.provider;

  /// Copy with method for updates
  ChatMessage copyWith({
    String? id,
    String? bookingId,
    String? senderId,
    UserRole? senderRole,
    String? messageText,
    DateTime? timestamp,
    bool? visibleToTraveler,
    bool? isInternalNote,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      senderId: senderId ?? this.senderId,
      senderRole: senderRole ?? this.senderRole,
      messageText: messageText ?? this.messageText,
      timestamp: timestamp ?? this.timestamp,
      visibleToTraveler: visibleToTraveler ?? this.visibleToTraveler,
      isInternalNote: isInternalNote ?? this.isInternalNote,
    );
  }
}
