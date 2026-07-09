import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The app's brand mark: a gold diamond (a 45°-rotated square outline) with an
/// upright knight glyph inside. Matches the logo used across the Road to 2000
/// design. [size] is the side length of the (un-rotated) square.
class KnightMark extends StatelessWidget {
  const KnightMark({required this.size, super.key});

  final double size;

  static const double _quarterTurn = math.pi / 4; // 45°

  @override
  Widget build(BuildContext context) {
    final Color gold = Theme.of(context).colorScheme.primary;
    return Transform.rotate(
      angle: _quarterTurn,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: gold, width: 1.5),
        ),
        // Counter-rotate the glyph so the knight sits upright in the diamond.
        child: Transform.rotate(
          angle: -_quarterTurn,
          child: Text(
            '♞', // ♞ black chess knight
            style: TextStyle(color: gold, fontSize: size * 0.52, height: 1),
          ),
        ),
      ),
    );
  }
}
