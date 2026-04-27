
import 'package:flutter/material.dart';
import 'dart:convert';

void showErrorSnackBar(BuildContext context, String errorMessage) {
  String finalMessage = 'An unexpected error occurred.'; // Default message

  try {
    // Attempt to find and parse the JSON part of the error
    final jsonStartIndex = errorMessage.indexOf('{');
    if (jsonStartIndex != -1) {
      final jsonPart = errorMessage.substring(jsonStartIndex);
      final decodedJson = jsonDecode(jsonPart) as Map<String, dynamic>;
      if (decodedJson.containsKey('error')) {
        finalMessage = decodedJson['error'] as String;
      }
    }
  } catch (e) {
    // If parsing fails, we can fall back to a simpler regex or default message
    final RegExp regex = RegExp(r'(?:error|message)[:\s]+"?([^"\n}]+)"?');
    final Match? match = regex.firstMatch(errorMessage);
    if (match != null && match.group(1) != null) {
      finalMessage = match.group(1)!;
    }
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(finalMessage),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    ),
  );
}
