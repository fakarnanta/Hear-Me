import 'package:flutter/material.dart';

class DrawingPath {
  final Path path;
  final Paint paint;
  
  DrawingPath({required this.path, required this.paint});
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPath> paths;

  DrawingPainter({required this.paths});

@override
void paint(Canvas canvas, Size size) {
  for (var drawingPath in paths) {
    canvas.drawPath(drawingPath.path, drawingPath.paint);
  }
}

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    // Tetap `true` agar tidak hilang saat di-zoom
    return true;
  }
}