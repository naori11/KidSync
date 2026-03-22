// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'driver_assignments_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DriverAssignmentsController)
final driverAssignmentsControllerProvider =
    DriverAssignmentsControllerProvider._();

final class DriverAssignmentsControllerProvider
    extends
        $AsyncNotifierProvider<
          DriverAssignmentsController,
          List<DriverAssignment>
        > {
  DriverAssignmentsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'driverAssignmentsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$driverAssignmentsControllerHash();

  @$internal
  @override
  DriverAssignmentsController create() => DriverAssignmentsController();
}

String _$driverAssignmentsControllerHash() =>
    r'34ca0ca750b6b648a3dacf90bc1ee0dad5d349d0';

abstract class _$DriverAssignmentsController
    extends $AsyncNotifier<List<DriverAssignment>> {
  FutureOr<List<DriverAssignment>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<DriverAssignment>>, List<DriverAssignment>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<DriverAssignment>>,
                List<DriverAssignment>
              >,
              AsyncValue<List<DriverAssignment>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
