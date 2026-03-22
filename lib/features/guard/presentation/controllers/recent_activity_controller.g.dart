// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_activity_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RecentActivityController)
final recentActivityControllerProvider = RecentActivityControllerFamily._();

final class RecentActivityControllerProvider
    extends $AsyncNotifierProvider<RecentActivityController, List<Activity>> {
  RecentActivityControllerProvider._({
    required RecentActivityControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'recentActivityControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$recentActivityControllerHash();

  @override
  String toString() {
    return r'recentActivityControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  RecentActivityController create() => RecentActivityController();

  @override
  bool operator ==(Object other) {
    return other is RecentActivityControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$recentActivityControllerHash() =>
    r'7fd35e3c341e1892ae2310ca77bf3252ef309518';

final class RecentActivityControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          RecentActivityController,
          AsyncValue<List<Activity>>,
          List<Activity>,
          FutureOr<List<Activity>>,
          String
        > {
  RecentActivityControllerFamily._()
    : super(
        retry: null,
        name: r'recentActivityControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RecentActivityControllerProvider call(String timePeriod) =>
      RecentActivityControllerProvider._(argument: timePeriod, from: this);

  @override
  String toString() => r'recentActivityControllerProvider';
}

abstract class _$RecentActivityController
    extends $AsyncNotifier<List<Activity>> {
  late final _$args = ref.$arg as String;
  String get timePeriod => _$args;

  FutureOr<List<Activity>> build(String timePeriod);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Activity>>, List<Activity>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Activity>>, List<Activity>>,
              AsyncValue<List<Activity>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
