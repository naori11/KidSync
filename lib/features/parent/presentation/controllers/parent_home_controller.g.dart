// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'parent_home_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ParentHomeController)
final parentHomeControllerProvider = ParentHomeControllerProvider._();

final class ParentHomeControllerProvider
    extends $AsyncNotifierProvider<ParentHomeController, Map<String, dynamic>> {
  ParentHomeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'parentHomeControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$parentHomeControllerHash();

  @$internal
  @override
  ParentHomeController create() => ParentHomeController();
}

String _$parentHomeControllerHash() =>
    r'49db61d39b0f9ef4e7ec13722ae70abc88373020';

abstract class _$ParentHomeController
    extends $AsyncNotifier<Map<String, dynamic>> {
  FutureOr<Map<String, dynamic>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<Map<String, dynamic>>, Map<String, dynamic>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<Map<String, dynamic>>,
                Map<String, dynamic>
              >,
              AsyncValue<Map<String, dynamic>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
