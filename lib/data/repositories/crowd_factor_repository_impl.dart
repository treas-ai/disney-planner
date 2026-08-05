import '../../domain/entities/crowd_factor_profile.dart';
import '../../domain/entities/time_band_wait_profile.dart';
import '../../domain/repositories/crowd_factor_repository.dart';
import '../local/json_crowd_factor_data_source.dart';

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
}
