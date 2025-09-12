import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

Future<List<Uri>> loadSitemapUris(Uri sitemap) async {
  final res = await http.get(sitemap);
  if (res.statusCode != 200) {
    throw StateError('Sitemap Ladefehler: ${res.statusCode}');
  }
  final doc = XmlDocument.parse(utf8.decode(res.bodyBytes));
  final root = doc.rootElement.name.local;
  if (root == 'sitemapindex') {
    final children = doc.findAllElements('loc').map((e) => Uri.parse(e.text));
    final out = <Uri>[];
    for (final child in children) {
      out.addAll(await loadSitemapUris(child));
    }
    return out;
  }
  if (root == 'urlset') {
    return doc.findAllElements('loc').map((e) => Uri.parse(e.text)).toList();
  }
  // Fallback: versuche loc überall
  return doc.findAllElements('loc').map((e) => Uri.parse(e.text)).toList();
}
