import 'package:flutter_test/flutter_test.dart';
import 'package:mactouch_mobile/core/protocol/input_protocol.dart';

void main() {
  test('shortcut and system event builders produce the wire format the Mac parses', () {
    expect(InputEvents.shortcut(17, 8), {'e': 'shortcut', 'c': 17, 'm': 8});
    expect(InputEvents.shortcut(36, 0), {'e': 'shortcut', 'c': 36});
    expect(InputEvents.shortcut(48, 8, 600), {'e': 'shortcut', 'c': 48, 'm': 8, 'h': 600});
    expect(InputEvents.system('mission_control'), {'e': 'sys', 'a': 'mission_control'});
  });
}
