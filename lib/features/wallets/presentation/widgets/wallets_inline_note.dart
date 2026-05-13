import 'package:flutter/material.dart';

class WalletsInlineNote extends StatelessWidget {
  const WalletsInlineNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEDF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF72685A),
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    );
  }
}
