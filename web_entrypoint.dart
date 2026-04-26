import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'lib/main.dart' as app;

void registerPlugins(Registrar registrar) {
  // Register web plugins here if needed
}

void main() {
  // Set web plugin registration
  registerPlugins(webPluginRegistrar);
  // Start the app
  app.main();
}
