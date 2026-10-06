import 'package:example/home_controller.dart';
import 'package:example/home_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';

void main() {
  Get.lazyPut(() => HomeController());
  runApp(
    // material_ui's MaterialApp, not GetMaterialApp: the widgets come from
    // material_ui and look up its MaterialLocalizations, which only its own
    // MaterialApp provides. Get.key keeps Get.dialog / snackbar / back working.
    MaterialApp(
      navigatorKey: Get.key,
      debugShowCheckedModeBanner: false,
      title: "Whatsapp Bot",
      // FlexThemeData builds Flutter's stock ThemeData, which material_ui's
      // MaterialApp can't take; same Genoa green, as a material_ui theme.
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF15786C),
        appBarTheme: const AppBarTheme(elevation: 15),
      ),
      home: const HomeView(),
    ),
  );
}
