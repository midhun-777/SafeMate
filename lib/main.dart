import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/database/local_database_service.dart';
import 'core/network/supabase_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase foundation
  await SupabaseService.initialize();

  // Initialize local SQLite database for offline-first persistence
  await LocalDatabaseService().init();

  runApp(
    const ProviderScope(
      child: SafeMateApp(),
    ),
  );
}
