import 'package:disney_planner/data/providers/themeparks_wiki_live_parser.dart';
import 'package:disney_planner/domain/enums/live_operation_availability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ThemeParks.wiki standby and DPA queue are parsed', () {
    final entries = const ThemeParksWikiLiveParser().parse({
      'liveData': [
        {
          'id': 'source-1',
          'name': 'Enchanted Tale of Beauty and the Beast',
          'entityType': 'ATTRACTION',
          'status': 'OPERATING',
          'lastUpdated': '2026-08-19T00:00:00Z',
          'queue': {
            'STANDBY': {'waitTime': 95},
            'PAID_RETURN_TIME': {
              'state': 'AVAILABLE',
              'returnStart': '2026-08-19T03:00:00Z',
              'returnEnd': '2026-08-19T04:00:00Z',
            },
          },
        },
      ],
    });

    expect(entries, hasLength(1));
    expect(entries.single.standbyMinutes, 95);
    expect(entries.single.paidReturnAvailable, isTrue);
    expect(entries.single.availability, LiveOperationAvailability.operating);
  });

  test('DOWN is treated as temporary suspension', () {
    final entry = const ThemeParksWikiLiveParser().parse({
      'liveData': [
        {
          'id': 'source-2',
          'name': 'Ride',
          'entityType': 'ATTRACTION',
          'status': 'DOWN',
          'queue': {},
        },
      ],
    }).single;
    expect(
      entry.availability,
      LiveOperationAvailability.temporarilySuspended,
    );
  });
}
