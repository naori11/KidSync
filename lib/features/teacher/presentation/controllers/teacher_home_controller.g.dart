// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'teacher_home_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TeacherHomeController)
final teacherHomeControllerProvider = TeacherHomeControllerProvider._();

final class TeacherHomeControllerProvider
    extends
        $AsyncNotifierProvider<TeacherHomeController, Map<String, dynamic>> {
  TeacherHomeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'teacherHomeControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$teacherHomeControllerHash();

  @$internal
  @override
  TeacherHomeController create() => TeacherHomeController();
}

String _$teacherHomeControllerHash() =>
    r'2c806526d362c11152a60d216c276c552d55edbe';

abstract class _$TeacherHomeController
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
