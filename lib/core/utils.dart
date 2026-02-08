String toRoman(int n) {
  const romans = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];
  if (n >= 1 && n <= 10) return romans[n - 1];
  return n.toString();
}

String uniquifyTitle(String title, List<String> existingTitles) {
  if (title.toUpperCase() == "NEW PROJECT") return title;

  String candidate = title;
  int counter = 2;

  // Case-insensitive check
  bool exists(String t) => existingTitles.any(
    (e) => e.trim().toUpperCase() == t.trim().toUpperCase(),
  );

  if (!exists(candidate)) return candidate;

  while (true) {
    String suffix = toRoman(counter);
    candidate = "$title - $suffix";
    if (!exists(candidate)) return candidate;
    counter++;
    if (counter > 100) break; // Safety break
  }
  return candidate;
}

List<List<String>> parseCsv(String input) {
  final List<List<String>> rows = [];
  List<String> currentRow = [];
  final StringBuffer currentField = StringBuffer();
  bool inQuotes = false;
  for (int i = 0; i < input.length; i++) {
    final String char = input[i];
    final String nextChar = (i + 1 < input.length) ? input[i + 1] : "";
    if (inQuotes) {
      if (char == '"') {
        if (nextChar == '"') {
          currentField.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        currentField.write(char);
      }
    } else {
      if (char == '"') {
        inQuotes = true;
      } else if (char == ',') {
        currentRow.add(currentField.toString());
        currentField.clear();
      } else if (char == '\n' || char == '\r') {
        if (char == '\r' && nextChar == '\n') i++;
        currentRow.add(currentField.toString());
        rows.add(currentRow);
        currentRow = [];
        currentField.clear();
      } else {
        currentField.write(char);
      }
    }
  }
  if (currentRow.isNotEmpty || currentField.isNotEmpty) {
    currentRow.add(currentField.toString());
    rows.add(currentRow);
  }
  return rows;
}

String decodeHtmlEntities(String input) {
  return input
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');
}

String indexToLetter(int index) => String.fromCharCode(65 + index);

String extractSheetId(String input) {
  if (input.contains('spreadsheets/d/')) {
    final parts = input.split('spreadsheets/d/');
    if (parts.length > 1) {
      return parts[1].split('/')[0];
    }
  }
  return input.trim();
}
