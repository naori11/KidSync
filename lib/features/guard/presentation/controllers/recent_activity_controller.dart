import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/guard_repository.dart';
import '../../data/models/guard_models.dart';

part 'recent_activity_controller.g.dart';

@riverpod
class RecentActivityController extends _$RecentActivityController {
  @override
  FutureOr<List<Activity>> build(String timePeriod) async {
    return await _fetchActivities(timePeriod);
  }

  Future<List<Activity>> _fetchActivities(String timePeriod) async {
    final repository = ref.read(guardRepositoryProvider);
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (timePeriod) {
      case 'Today':
        start = DateTime(now.year, now.month, now.day);
        end = start.add(Duration(days: 1));
        break;
      case 'This Week':
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        end = start.add(Duration(days: 7));
        break;
      case 'This Month':
        start = DateTime(now.year, now.month, 1);
        end = (now.month < 12)
            ? DateTime(now.year, now.month + 1, 1)
            : DateTime(now.year + 1, 1, 1);
        break;
      default:
        start = DateTime(now.year, now.month, now.day);
        end = start.add(Duration(days: 1));
    }

    return await repository.fetchRecentActivities(
      start: start,
      end: end,
    );
  }

  Future<void> refresh(String timePeriod) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchActivities(timePeriod));
  }
}
