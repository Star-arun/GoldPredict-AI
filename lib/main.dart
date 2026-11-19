import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'modules/dashboard/dashboard_binding.dart';
import 'modules/dashboard/dashboard_screen.dart';

void main() => runApp(const GoldPredictApp());

class GoldPredictApp extends StatelessWidget {
  const GoldPredictApp({super.key});
  @override
  Widget build(BuildContext context) => GetMaterialApp(
      title: 'GoldPredict AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB88932)),
          scaffoldBackgroundColor: const Color(0xFFF7F7F5)),
      initialBinding: DashboardBinding(),
      home: const DashboardScreen());
}
