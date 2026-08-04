import 'package:disney_planner/domain/services/share_payload_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = SharePayloadCodec();

  test('plan link round-trips without data loss', () {
    const json =
        '{"shareSchemaVersion":1,"kind":"plan","tripSettings":{},'
        '"daySchedule":{"id":"a","parkId":"tokyo_disneyland",'
        '"items":[],"createdAt":"2026-08-04T00:00:00.000"}}';

    final link = codec.encodePlanLink(json);
    final decoded = codec.decode(link);

    expect(decoded['kind'], 'plan');
    expect(decoded['daySchedule'], isA<Map>());
  });

  test('raw JSON is accepted', () {
    final decoded = codec.decode('{"shareSchemaVersion":1,"kind":"plan"}');

    expect(decoded['kind'], 'plan');
  });

  test('invalid text is rejected', () {
    expect(() => codec.decode('not-a-share-code'), throwsFormatException);
  });
}
