import 'package:flutter/material.dart';
import 'package:stego_snap/screens/landing_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stego_snap/services/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Supabase.initialize(
    url: 'https://kbhvqpsxizpxjiqgkwal.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtiaHZxcHN4aXpweGppcWdrd2FsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcyNjc5MzcsImV4cCI6MjA5Mjg0MzkzN30.ecqRDxcqYXm2epfGIfQpZXYykqaKQUwSKbhBI-kHsB0',
  );
  await NotificationService.initializeNotification();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return (MaterialApp(
      title: 'Stego Snap',
      theme: ThemeData(visualDensity: VisualDensity.adaptivePlatformDensity),
      home: LandingPage(),
      debugShowCheckedModeBanner: false,
    ));
  }
}
