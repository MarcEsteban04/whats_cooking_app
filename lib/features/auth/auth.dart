/// Public surface of the `auth` feature — sign-up, login, session and recovery.
///
/// Cross-feature code imports this barrel and never a file inside the feature
/// (docs/CODING_STANDARDS.md §3). The session state is exported now because the
/// router's guard reads it (Sprint 09); the screens and the Supabase-backed
/// repository arrive in Sprints 16–17.
library;

export 'package:whats_cooking/features/auth/domain/entities/app_session.dart';
export 'package:whats_cooking/features/auth/presentation/providers/session_provider.dart';
