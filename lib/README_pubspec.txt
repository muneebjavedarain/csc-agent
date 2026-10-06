pubspec.yaml mein yeh dependencies hone chahiye:

  firebase_core
  cloud_firestore
  shared_preferences
  http
  web

Command (ek dafa):
  flutter pub add http web shared_preferences
  flutter pub remove google_generative_ai url_launcher

Run:
  flutter run -d web-server --web-port 5000
