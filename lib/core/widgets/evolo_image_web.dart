import 'package:flutter/material.dart';

class EvoloImage extends StatelessWidget {
  const EvoloImage({required this.source, this.fit = BoxFit.cover, super.key});

  final String source;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(source, fit: fit);
  }
}
