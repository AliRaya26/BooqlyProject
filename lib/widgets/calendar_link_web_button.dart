import 'package:flutter/material.dart';

import 'calendar_link_web_button_stub.dart'
    if (dart.library.html) 'calendar_link_web_button_web.dart' as impl;

/// Google Sign-In button for web Calendar linking (GIS renderButton).
Widget buildGoogleSignInButton() => impl.buildGoogleSignInButton();
