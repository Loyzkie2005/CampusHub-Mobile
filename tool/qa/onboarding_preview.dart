// Optional standalone QA target; normal flutter run starts the real app.
import 'package:campushub/dev/onboarding_preview.dart';

// Preserve the existing QA/test import path.
export 'package:campushub/dev/onboarding_preview.dart';

Future<void> main() => runOnboardingPreview();
