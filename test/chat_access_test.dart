import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:somsafar_app/shared/services/chat_repository.dart';
import 'package:somsafar_app/shared/services/booking_repository.dart';
import 'package:somsafar_app/shared/services/auth_service.dart';
import 'package:somsafar_app/shared/models/user_model.dart';
import 'package:somsafar_app/shared/models/booking_model.dart';
import 'package:somsafar_app/shared/models/chat_message_model.dart';

// Mock classes - These extend the real service classes to satisfy Riverpod type requirements
class MockAuthService extends AuthService {
  MockAuthService() : super(listen: false);

  // Helper method for tests to directly set the user state
  void setUser(User user) => state = user;
}

class MockBookingRepository extends BookingRepository {
  MockBookingRepository() : super(null, listen: false);

  // Helper method for tests to directly set the bookings state
  void setBookings(List<Booking> bookings) => state = bookings;
}

class MockChatRepository extends BookingChatRepository {
  MockChatRepository(super.bookingId) : super(listen: false);

  @override
  void initStream() {
    // No-op for tests
  }

  @override
  Future<void> fetchMessages() async {
    // No-op for tests
  }

  // Helper method for tests to directly set the messages state
  void setMessages(List<ChatMessage> messages) => state = messages;
}

void main() {
  test('Provider accessing chat as a Traveler for their own booking', () {
    // Create mock instances
    final mockAuth = MockAuthService();
    final mockBooking = MockBookingRepository();
    final mockChat = MockChatRepository('b_test');

    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWith((ref) => mockAuth),
        bookingProvider.overrideWith((ref) => mockBooking),
        bookingChatProvider('b_test').overrideWith((ref) => mockChat),
      ],
    );

    // 1. Setup User: Provider 'Asha' who is also traveling
    final providerUser = User(
      id: 'u5',
      name: 'Asha Omar',
      email: 'asha@test.com',
      role: UserRole.provider,
      providerId: 'p2',
      password: 'pass',
    );
    mockAuth.setUser(providerUser);

    // 2. Setup Booking: Asha (u5) is the traveler, booking 's1' provided by 'p1'
    final booking = Booking(
      id: 'b_test',
      serviceId: 's1',
      providerId: 'p1', // Someone else
      serviceTitle: 'Villa',
      travelerId: 'u5', // Asha is traveler
      travelerName: 'Asha Omar',
      date: DateTime.now(),
      checkIn: DateTime.now(),
      checkOut: DateTime.now(),
      guests: 1,
      rooms: 1,
      totalPrice: 100,
      contactPhone: '123',
      contactEmail: 'asha@test.com',
      status: BookingStatus.confirmed,
      paymentStatus: BookingPaymentStatus.paid,
    );
    mockBooking.setBookings([booking]);

    // 3. Setup Messages
    final msg1 = ChatMessage.fromProvider(
      id: 'm1',
      bookingId: 'b_test',
      providerId: 'p1',
      messageText: 'Hello Asha!',
      timestamp: DateTime.now(),
    );
    final msgInternal = ChatMessage(
      id: 'm2',
      bookingId: 'b_test',
      senderId: 'p1',
      senderRole: UserRole.provider,
      messageText: 'Secret note',
      timestamp: DateTime.now(),
      visibleToTraveler: false,
      isInternalNote: true,
    );

    mockChat.setMessages([msg1, msgInternal]);

    // 4. Verify Access
    final hasAccess = container.read(hasChatAccessProvider('b_test'));
    expect(
      hasAccess,
      true,
      reason: 'Provider user acting as traveler should have access',
    );

    // 5. Verify Message Filtering (Should NOT see internal note)
    final messages = container.read(filteredChatMessagesProvider('b_test'));
    expect(messages.length, 1);
    expect(messages.first.id, 'm1');
    expect(
      messages.any((m) => m.isInternalNote),
      false,
      reason: 'Traveler view should not see internal notes',
    );
  });

  test('Provider accessing chat as Provider for their own service', () {
    // Create mock instances
    final mockAuth = MockAuthService();
    final mockBooking = MockBookingRepository();
    final mockChat = MockChatRepository('b_service');

    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWith((ref) => mockAuth),
        bookingProvider.overrideWith((ref) => mockBooking),
        bookingChatProvider('b_service').overrideWith((ref) => mockChat),
      ],
    );

    // 1. Setup User: Provider 'Asha'
    final providerUser = User(
      id: 'u5',
      name: 'Asha Omar',
      email: 'asha@test.com',
      role: UserRole.provider,
      providerId: 'p2',
      password: 'pass',
    );
    mockAuth.setUser(providerUser);

    // 2. Setup Booking: Someone else (u1) booking Asha's service (p2)
    final booking = Booking(
      id: 'b_service',
      serviceId: 's2',
      providerId: 'p2', // Asha is provider
      serviceTitle: 'Apartment',
      travelerId: 'u1',
      travelerName: 'John',
      date: DateTime.now(),
      checkIn: DateTime.now(),
      checkOut: DateTime.now(),
      guests: 1,
      rooms: 1,
      totalPrice: 100,
      contactPhone: '123',
      contactEmail: 'john@test.com',
      status: BookingStatus.confirmed,
      paymentStatus: BookingPaymentStatus.paid,
    );
    mockBooking.setBookings([booking]);

    // 3. Setup Messages
    final msg1 = ChatMessage.fromTraveler(
      id: 'm1',
      bookingId: 'b_service',
      travelerId: 'u1',
      messageText: 'Hi Asha!',
      timestamp: DateTime.now(),
    );
    final msgInternal = ChatMessage.fromProvider(
      id: 'm2',
      bookingId: 'b_service',
      providerId: 'p2',
      messageText: 'My secret note',
      timestamp: DateTime.now(),
      isInternalNote: true,
    );

    mockChat.setMessages([msg1, msgInternal]);

    // 4. Verify Access
    final hasAccess = container.read(hasChatAccessProvider('b_service'));
    expect(
      hasAccess,
      true,
      reason: 'Provider accessing their own service booking should have access',
    );

    // 5. Verify Message Filtering (Should SEE internal note)
    final messages = container.read(filteredChatMessagesProvider('b_service'));
    expect(messages.length, 2);
    expect(
      messages.any((m) => m.isInternalNote),
      true,
      reason: 'Provider view should see internal notes',
    );
  });
}
