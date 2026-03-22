// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'parent_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(parentRepository)
final parentRepositoryProvider = ParentRepositoryProvider._();

final class ParentRepositoryProvider
    extends
        $FunctionalProvider<
          ParentRepository,
          ParentRepository,
          ParentRepository
        >
    with $Provider<ParentRepository> {
  ParentRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'parentRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$parentRepositoryHash();

  @$internal
  @override
  $ProviderElement<ParentRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ParentRepository create(Ref ref) {
    return parentRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ParentRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ParentRepository>(value),
    );
  }
}

String _$parentRepositoryHash() => r'3f59eccec20410a8d92e3d3dc6e17abbbec10f8e';
