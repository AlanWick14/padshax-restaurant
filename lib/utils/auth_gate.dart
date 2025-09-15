import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../ui/pages/admin_login_page.dart';

Future<bool> ensureAdminSignedIn(BuildContext context) async {
  if (FirebaseAuth.instance.currentUser != null) return true;
  final ok = await Navigator.of(
    context,
  ).push<bool>(MaterialPageRoute(builder: (_) => const AdminLoginPage()));
  return ok == true && FirebaseAuth.instance.currentUser != null;
}
