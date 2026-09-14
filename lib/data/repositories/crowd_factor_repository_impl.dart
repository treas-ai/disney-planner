import '../../domain/entities/crowd_factor_profile.dart';
import '../../domain/entities/time_band_wait_profile.dart';
import '../../domain/repositories/crowd_factor_repository.dart';
import '../local/json_crowd_factor_data_source.dart';
import '../local/local_visit_day_context_repository.dart';
import '../../domain/services/visit_day_wait_profile_adjuster.dart';

class CrowdFactorRepositoryImpl implements CrowdFactorRepository {
  const CrowdFactorRepositoryImpl({
    this.dataSource = const JsonCrowdFactorDataSource(),
  });

  final JsonCrowdFactorDataSource dataSource;

  @override
  Future<List<CrowdFactorProfile>> loadCrowdFactors({required String parkId}) {
    return dataSource.loadCrowdFactors(parkId: parkId);
  }

  @override
  Future<List<TimeBandWaitProfile>> loadWaitProfiles({required String parkId}) {
    return dataSource.loadWaitProfiles(parkId: parkId);
  }

  Future<List<TimeBandWaitProfile>> loadWaitProfilesForDate({
    required String parkId,
    required DateTime targetDate,
  }) async {
    final profiles = await dataSource.loadWaitProfiles(parkId: parkId);
    final factors = await dataSource.loadCrowdFactors(parkId: parkId);
    final context = await const LocalVisitDayContextRepository()
        .loadContext(targetDate);
    return const VisitDayWaitProfileAdjuster().apply(
      profiles: profiles,
      factors: factors,
      context: context,
    );
  }
}
