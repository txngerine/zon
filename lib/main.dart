import 'package:flutter/material.dart';

import 'app.dart';
import 'data/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final state = AppState();
  runApp(ZonApp(state: state));
  state.startTicking();
}
