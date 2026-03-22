// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guard_dashboard_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GuardDashboardController)
final guardDashboardControllerProvider = GuardDashboardControllerProvider._();

final class GuardDashboardControllerProvider
    extends
        $AsyncNotifierProvider<GuardDashboardController, Map<String, dynamic>> {
  GuardDashboardControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'guardDashboardControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$guardDashboardControllerHash();

  @$internal
  @override
  GuardDashboardController create() => GuardDashboardController();
}

String _$guardDashboardControllerHash() =>
    r'0c14d369e56e22f193c095d1843402aa3ffa9755';

abstract class _$GuardDashboardController
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
