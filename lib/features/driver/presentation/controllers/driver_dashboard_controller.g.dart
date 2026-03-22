// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'driver_dashboard_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DriverDashboardController)
final driverDashboardControllerProvider = DriverDashboardControllerProvider._();

final class DriverDashboardControllerProvider
    extends
        $AsyncNotifierProvider<
          DriverDashboardController,
          Map<String, dynamic>
        > {
  DriverDashboardControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'driverDashboardControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$driverDashboardControllerHash();

  @$internal
  @override
  DriverDashboardController create() => DriverDashboardController();
}

String _$driverDashboardControllerHash() =>
    r'1f15ca6d0c473af8f27346d4fde07d397d8b4101';

abstract class _$DriverDashboardController
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
