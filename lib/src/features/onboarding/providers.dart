import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/api_service.dart';
import '../../core/providers/shared_preferences_provider.dart';
import 'data/onboarding_repository.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
OnboardingRepository onboardingRepository(Ref ref) {
  return OnboardingRepository(
    ref.read(sharedPreferencesProvider),
    ref.read(apiServiceProvider),
  );
}

@Riverpod(keepAlive: true)
class OnboardingState extends _$OnboardingState {
  OnboardingRepository get _repo => ref.read(onboardingRepositoryProvider);

  @override
  bool build() => _repo.isCompleted;

  Future<void> complete() async {
    await _repo.completeOnboarding();
    state = true;
  }

  Future<void> reset() async {
    await _repo.reset();
    state = false;
  }
}

@Riverpod(keepAlive: true)
class SelectedInterests extends _$SelectedInterests {
  OnboardingRepository get _repo => ref.read(onboardingRepositoryProvider);

  @override
  List<String> build() => _repo.selectedInterests;

  Future<void> save(List<String> interests) async {
    await _repo.saveInterests(interests);
    state = interests;
  }
}
