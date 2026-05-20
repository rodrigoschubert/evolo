import 'package:evolo/app.dart';
import 'package:evolo/core/constants/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('Evolo renders the Portuguese onboarding experience', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: EvoloApp()));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.appName), findsNothing);
    expect(find.text(AppStrings.onboardingTitle), findsOneWidget);
    expect(find.text(AppStrings.onboardingCta), findsOneWidget);
  });
}
