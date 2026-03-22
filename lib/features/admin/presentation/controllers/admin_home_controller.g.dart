// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_home_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AdminHomeController)
final adminHomeControllerProvider = AdminHomeControllerProvider._();

final class AdminHomeControllerProvider
    extends $AsyncNotifierProvider<AdminHomeController, Map<String, dynamic>> {
  AdminHomeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'adminHomeControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$adminHomeControllerHash();

  @$internal
  @override
  AdminHomeController create() => AdminHomeController();
}

String _$adminHomeControllerHash() =>
    r'd16bb22ec7f7422ea2e4f60ebdcb19bbb3243386';

abstract class _$AdminHomeController
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
