import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  String topic = 'Explain the Software Life Cycle Models (Classical Waterfall, Iterative, Prototyping, Evo1-1.4';
  
  // Try using different cleaning methods.
  String cleanTopic = topic.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ').trim();
  if (cleanTopic.length > 50) {
      cleanTopic = cleanTopic.substring(0, 50);
  }
  
  // Let's print the clean topic
  print("Cleaned: \$cleanTopic");
  
  var searchUrl = Uri.parse('https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=\${Uri.encodeComponent(cleanTopic)}&utf8=&format=json');
  var searchResponse = await http.get(searchUrl);
  print(searchResponse.body);
}
