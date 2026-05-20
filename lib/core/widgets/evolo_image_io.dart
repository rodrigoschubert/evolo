import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

class EvoloImage extends StatelessWidget {
  const EvoloImage({required this.source, this.fit = BoxFit.cover, super.key});

  final String source;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (source.startsWith('data:image/')) {
      final commaIndex = source.indexOf(',');
      final encoded = commaIndex == -1
          ? source
          : source.substring(commaIndex + 1);

      return Image.memory(base64Decode(encoded), fit: fit);
    }

    return Image.file(File(source), fit: fit);
  }
}
