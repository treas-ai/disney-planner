import 'package:disney_planner/data/mock/mock_live_operation_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const repository = MockLiveOperationRepository();

  test('mock repository returns a marked snapshot', () async {
    final snapshot = await repository.fetchSnapshot(parkId: 'tokyo_disneysea');

    expect(snapshot.parkId, 'tokyo_disneysea');
    expect(snapshot.isMock, isTrue);
    expect(snapshot.parkOperation, isNotNull);
    expect(snapshot.weather, isNotNull);
    expect(snapshot.crowd, isNotNull);
    expect(snapshot.attractions, isNotEmpty);
  });
}
