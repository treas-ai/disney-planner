import '../entities/crowd_factor_profile.dart';
import '../entities/time_band_wait_profile.dart';

abstract interface class CrowdFactorRepository {
  Future<List<CrowdFactorProfile>> loadCrowdFactors({required String parkId});

  Future<List<TimeBandWaitProfile>> loadWaitProfiles({required String parkId});
}
