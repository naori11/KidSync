// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'driver_home_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DriverHomeController)
final driverHomeControllerProvider = DriverHomeControllerProvider._();

final class DriverHomeControllerProvider
    extends $AsyncNotifierProvider<DriverHomeController, Map<String, dynamic>> {
  DriverHomeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'driverHomeControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$driverHomeControllerHash();

  @$internal
  @override
  DriverHomeController create() => DriverHomeController();
}

String _$driverHomeControllerHash() =>
    r'a1234d30d6c31aa75bde27c24a374748e2f87bc3';

abstract class _$DriverHomeController
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
