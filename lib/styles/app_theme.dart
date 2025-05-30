import 'package:flutter/material.dart';

// Similar to styles.css from before
class AppTheme {
  // Colors 
  static const backgroundColor = Color(0xFF2F2E2E);
  static const secondaryColor = Color(0xFF535454);
  static const accentColor = Color(0xFFB89149);
  static const textColor = Color(0xFFADADAD);
  static const buttonColor = Color(0xFF858585);
  static const errorColor = Color(0xFFFF4539);
  static const successColor = Color(0xFF39FF14);

  // Text 
  static const h1Style = TextStyle(
    fontFamily: 'Inter',
    color: accentColor,
    fontSize: 28,
    fontWeight: FontWeight.bold,
  );

  static const h2Style = TextStyle(
    color: accentColor,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  // Container Styles
  static final containerStyle = BoxDecoration(
    color: backgroundColor,
    borderRadius: BorderRadius.circular(15),
  );

  static final listContainerStyle = BoxDecoration(
    color: secondaryColor,
    borderRadius: BorderRadius.circular(15),
  );

  // Button Styles 
  static final buttonStyle = ElevatedButton.styleFrom(
    backgroundColor: textColor,
    foregroundColor: backgroundColor,
    minimumSize: const Size(300, 60),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(30),
    ),
    textStyle: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
  );

  static final squareButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: buttonColor,
    foregroundColor: backgroundColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    padding: const EdgeInsets.all(15),
  );

  // Input Styles
  static const inputDecorationStyle = InputDecoration(
    border: UnderlineInputBorder(
      borderSide: BorderSide(color: Colors.white, width: 2),
    ),
    enabledBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: Colors.white, width: 2),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: Colors.white, width: 2),
    ),
    contentPadding: EdgeInsets.symmetric(vertical: 10),
    hintStyle: TextStyle(
      color: textColor,
      fontWeight: FontWeight.bold,
    ),
  );

  static const loginInputDecorationStyle = InputDecoration(
    filled: true,
    fillColor: textColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(30)),
      borderSide: BorderSide.none,
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
    hintStyle: TextStyle(
      color: backgroundColor,
      fontWeight: FontWeight.bold,
    ),
  );

  // Table Styles 
  static const tableHeaderStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
  );

  static final tableRowDecoration = BoxDecoration(
    border: Border(
      bottom: BorderSide(color: Colors.white.withOpacity(0.2)),
    ),
  );

  static var bodyTextStyle;
}
