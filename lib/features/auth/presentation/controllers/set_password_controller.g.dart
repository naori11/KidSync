// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_password_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SetPasswordController)
final setPasswordControllerProvider = SetPasswordControllerProvider._();

final class SetPasswordControllerProvider
    extends $AsyncNotifierProvider<SetPasswordController, void> {
  SetPasswordControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'setPasswordControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$setPasswordControllerHash();

  @$internal
  @override
  SetPasswordController create() => SetPasswordController();
}

String _$setPasswordControllerHash() =>
    r'152c09beba75c384d1f979db9f6682a978cb23d1';

abstract class _$SetPasswordController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
