import 'package:data_access/data_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await KidsTaskSupabase.initialize(SupabaseEnv.fromDartDefine());
  runApp(const ProviderScope(child: KidsTaskApp()));
}
