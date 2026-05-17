import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message_model.dart';
import '../models/user_model.dart';
import '../models/booking_model.dart';
import 'auth_service.dart';
import 'booking_repository.dart';
import '../../core/services/supabase_service.dart';

class BookingChatRepository extends StateNotifier<List<ChatMessage>> {
  final String bookingId;

  BookingChatRepository(this.bookingId, {bool listen = true}) : super([]) {
    if (listen) {
      initStream();
      fetchMessages();
    }
  }

  void initStream() {
    SupabaseConfig.client
        .from('chats')
        .stream(primaryKey: ['id'])
        .eq('booking_id', bookingId)
        .listen((data) {
          if (!mounted) return;
          state = data.map((res) {
            return ChatMessage.fromMap({
              'id': res['id'],
              'bookingId': res['booking_id'],
              'senderId': res['sender_id'],
              'senderRole': res['sender_role'],
              'messageText': res['message'],
              'timestamp': res['created_at'],
              'visibleToTraveler': res['visible_to_traveler'] ?? true,
              'isInternalNote': res['is_internal_note'] ?? false,
            });
          }).toList()
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        });
  }

  /// Send a new message for this booking
  Future<void> sendMessage({
    required String messageText,
    required User currentUser,
    bool isInternalNote = false,
  }) async {
    final messageId = const Uuid().v4();

    ChatMessage newMessage;

    if (currentUser.role == UserRole.traveler) {
      newMessage = ChatMessage.fromTraveler(
        id: messageId,
        bookingId: bookingId,
        travelerId: currentUser.id,
        messageText: messageText,
      );
    } else if (currentUser.role == UserRole.provider ||
        currentUser.role == UserRole.providerHelper) {
      newMessage = ChatMessage.fromProvider(
        id: messageId,
        bookingId: bookingId,
        providerId: currentUser.providerId ?? currentUser.id,
        messageText: messageText,
        isInternalNote: isInternalNote,
        senderRole: currentUser.role,
      );
    } else {
      newMessage = ChatMessage(
        id: messageId,
        bookingId: bookingId,
        senderId: currentUser.id,
        senderRole: currentUser.role,
        messageText: messageText,
        timestamp: DateTime.now(),
        visibleToTraveler: false,
        isInternalNote: isInternalNote,
      );
    }

    // Optimistic Update
    state = [...state, newMessage];

    try {
      await SupabaseConfig.client.from('chats').insert({
        'id': newMessage.id,
        'booking_id': newMessage.bookingId,
        'sender_id': newMessage.senderId,
        'sender_role': newMessage.senderRole.name,
        'message': newMessage.messageText,
        'visible_to_traveler': newMessage.visibleToTraveler,
        'is_internal_note': newMessage.isInternalNote,
        'created_at': newMessage.timestamp.toIso8601String(),
      });
    } catch (e) {
      print('Send message error: $e');
      // Rollback optimistic update on error
      state = state.where((m) => m.id != newMessage.id).toList();
    }
  }

  /// Manually fetch messages for this booking
  Future<void> fetchMessages() async {
    try {
      final data = await SupabaseConfig.client
          .from('chats')
          .select()
          .eq('booking_id', bookingId)
          .order('created_at', ascending: true);

      if (!mounted) return;

      state = data.map((res) {
        return ChatMessage.fromMap({
          'id': res['id'],
          'bookingId': res['booking_id'],
          'senderId': res['sender_id'],
          'senderRole': res['sender_role'],
          'messageText': res['message'],
          'timestamp': res['created_at'],
          'visibleToTraveler': res['visible_to_traveler'] ?? true,
          'isInternalNote': res['is_internal_note'] ?? false,
        });
      }).toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } catch (e) {
      print('Fetch messages error: $e');
    }
  }

  /// Delete a message
  Future<void> deleteMessage(String messageId) async {
    final oldState = [...state];
    if (mounted) state = state.where((m) => m.id != messageId).toList();
    try {
      await SupabaseConfig.client.from('chats').delete().eq('id', messageId);
    } catch (e) {
      print('Delete message error: $e');
      if (mounted) state = oldState;
    }
  }

  /// Update a message
  Future<void> updateMessage(String messageId, String newText) async {
    final oldState = [...state];
    if (mounted) {
      state = [
        for (final m in state)
          if (m.id == messageId) m.copyWith(messageText: newText) else m
      ];
    }
    try {
      await SupabaseConfig.client
          .from('chats')
          .update({'message': newText})
          .eq('id', messageId);
    } catch (e) {
      print('Update message error: $e');
      if (mounted) state = oldState;
    }
  }
}

/// Provider for a specific booking's chat
final bookingChatProvider =
    StateNotifierProvider.family<BookingChatRepository, List<ChatMessage>, String>((
  ref,
  bookingId,
) {
  return BookingChatRepository(bookingId);
});

/// Filtered chat messages provider based on user role
/// (Now uses the specific bookingChatProvider)
final filteredChatMessagesProvider = Provider.family<List<ChatMessage>, String>(
  (ref, bookingId) {
    final user = ref.watch(authProvider);
    final bookingMessages = ref.watch(bookingChatProvider(bookingId));
    final bookings = ref.watch(bookingProvider);

    if (user == null) return [];

    Booking? booking;
    try {
      booking = bookings.firstWhere((b) => b.id == bookingId);
    } catch (_) {
      // If booking not found yet, we might still see messages if RLS allows,
      // but for filtering traveler visibility we need the booking object
      return bookingMessages;
    }

    final isTravelerOfBooking = booking.travelerId == user.id;
    final isProviderOfBooking =
        booking.providerId == (user.providerId ?? user.id);
    final isAdmin = user.role == UserRole.admin;

    if (isAdmin || isProviderOfBooking) {
      return bookingMessages;
    }

    if (isTravelerOfBooking) {
      return bookingMessages
          .where((msg) => msg.visibleToTraveler == true || msg.senderId == user.id)
          .toList();
    }

    return []; // Access denied
  },
);

/// Helper provider to check if user has chat access to a booking
final hasChatAccessProvider = Provider.family<bool, String>((ref, bookingId) {
  final user = ref.watch(authProvider);
  final bookings = ref.watch(bookingProvider);

  if (user == null) return false;

  try {
    final booking = bookings.firstWhere(
      (b) => b.id == bookingId,
      orElse: () => throw Exception('Booking not found'),
    );

    if (user.role == UserRole.admin) return true;

    final isTravelerOfBooking = booking.travelerId == user.id;
    final isProviderOfBooking =
        booking.providerId == (user.providerId ?? user.id);

    return isTravelerOfBooking || isProviderOfBooking;
  } catch (e) {
    return false;
  }
});
