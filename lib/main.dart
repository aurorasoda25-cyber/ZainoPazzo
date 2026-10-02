import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();

  await Supabase.initialize(
    url: 'https://ulbsxksysnmdwkgrrarx.supabase.co',
    anonKey: 'sb_publishable_axjcgMxYf_Yq_7iXbuL-oA_N6dznWY6',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'App Compiti',
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}