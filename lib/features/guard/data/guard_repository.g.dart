// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guard_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(guardRepository)
final guardRepositoryProvider = GuardRepositoryProvider._();

final class GuardRepositoryProvider
    extends
        $FunctionalProvider<GuardRepository, GuardRepository, GuardRepository>
    with $Provider<GuardRepository> {
  GuardRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'guardRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$guardRepositoryHash();

  @$internal
  @override
  $ProviderElement<GuardRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GuardRepository create(Ref ref) {
    return guardRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GuardRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GuardRepository>(value),
    );
  }
}

String _$guardRepositoryHash() => r'4736d355711f711c923f6112592cb269fb1c6988';
