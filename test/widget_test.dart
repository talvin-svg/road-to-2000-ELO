import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/main.dart';

void main() {
  testWidgets('app renders the board screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ChessSensei()));
    expect(find.text('Chess Trainer'), findsOneWidget);
  });
}
