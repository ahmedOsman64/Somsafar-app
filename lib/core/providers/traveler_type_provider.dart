import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/user_model.dart';

class TravelerTypeState {
  final TravelerType? selectedType;
  final bool isLoading;
  final String? error;

  const TravelerTypeState({
    this.selectedType,
    this.isLoading = false,
    this.error,
  });

  TravelerTypeState copyWith({
    TravelerType? selectedType,
    bool? isLoading,
    String? error,
  }) {
    return TravelerTypeState(
      selectedType: selectedType ?? this.selectedType,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class TravelerTypeNotifier extends StateNotifier<TravelerTypeState> {
  TravelerTypeNotifier() : super(const TravelerTypeState());

  Future<void> selectTravelerType(TravelerType type) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 300));
      
      state = state.copyWith(
        selectedType: type,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  String getTravelerTypeDisplayName(TravelerType? type) {
    switch (type) {
      case TravelerType.leisure:
        return 'Leisure Traveler';
      case TravelerType.business:
        return 'Business Traveler';
      case TravelerType.family:
        return 'Family Traveler';
      case TravelerType.solo:
        return 'Solo Traveler';
      case TravelerType.adventure:
        return 'Adventure Seeker';
      case null:
        return 'Traveler';
    }
  }

  String getTravelerTypeGreeting(TravelerType? type) {
    switch (type) {
      case TravelerType.leisure:
        return 'Ready to relax?';
      case TravelerType.business:
        return 'Productive travels!';
      case TravelerType.family:
        return 'Family adventures await!';
      case TravelerType.solo:
        return 'Explore on your terms!';
      case TravelerType.adventure:
        return 'Adventure calls!';
      case null:
        return 'Welcome back';
    }
  }
}

// Provider
final travelerTypeProvider = StateNotifierProvider<TravelerTypeNotifier, TravelerTypeState>((ref) {
  return TravelerTypeNotifier();
});

// Convenience getters
final selectedTravelerTypeProvider = Provider<TravelerType?>((ref) {
  return ref.watch(travelerTypeProvider).selectedType;
});

final travelerTypeDisplayNameProvider = Provider<String>((ref) {
  final notifier = ref.watch(travelerTypeProvider.notifier);
  final selectedType = ref.watch(selectedTravelerTypeProvider);
  return notifier.getTravelerTypeDisplayName(selectedType);
});

final travelerTypeGreetingProvider = Provider<String>((ref) {
  final notifier = ref.watch(travelerTypeProvider.notifier);
  final selectedType = ref.watch(selectedTravelerTypeProvider);
  return notifier.getTravelerTypeGreeting(selectedType);
});
