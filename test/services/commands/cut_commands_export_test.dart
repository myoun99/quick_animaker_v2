import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/services/commands/cut_commands.dart';

void main() {
  test('exports user-level cut command types', () {
    expect(
      <Type>[
        CreateCutCommand,
        RenameCutCommand,
        DeleteCutCommand,
        DuplicateCutCommand,
      ],
      containsAll(<Type>[
        CreateCutCommand,
        RenameCutCommand,
        DeleteCutCommand,
        DuplicateCutCommand,
      ]),
    );
  });
}
