import 'package:url_launcher/url_launcher.dart';
import 'text_utils.dart';

String? encodeQueryParameters(Map<String, String> params) {
  return params.entries
      .map((MapEntry<String, String> e) =>
  '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');
}

Future<void> openEmailApp(List<String> emails, String generatedEmailText) async {
  // text_utils.dart ka function use kar ke subject aur body alag karein
  final parts = splitEmail(generatedEmailText);
  final subject = parts[0];
  final body = parts[1];

  final toAddress = emails.join(',');

  final Uri emailLaunchUri = Uri(
    scheme: 'mailto',
    path: toAddress,
    query: encodeQueryParameters(<String, String>{
      'subject': subject,
      'body': body,
    }),
  );

  if (await canLaunchUrl(emailLaunchUri)) {
    await launchUrl(emailLaunchUri);
  }
}