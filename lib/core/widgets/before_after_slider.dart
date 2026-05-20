import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'evolo_image.dart';

class BeforeAfterSlider extends StatefulWidget {
  const BeforeAfterSlider({
    required this.beforeImagePath,
    required this.afterImagePath,
    super.key,
  });

  final String beforeImagePath;
  final String afterImagePath;

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  double _position = 0.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _position += details.delta.dx / constraints.maxWidth;
              _position = _position.clamp(0.0, 1.0);
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // After Image (Base)
              EvoloImage(source: widget.afterImagePath),
              
              // Before Image (Clipped)
              ClipRect(
                clipper: _SliderClipper(position: _position),
                child: EvoloImage(source: widget.beforeImagePath),
              ),

              // Slider Handle
              Positioned(
                left: constraints.maxWidth * _position - 16,
                top: 0,
                bottom: 0,
                child: const _SliderHandle(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SliderClipper extends CustomClipper<Rect> {
  _SliderClipper({required this.position});

  final double position;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * position, size.height);
  }

  @override
  bool shouldReclip(_SliderClipper oldClipper) {
    return oldClipper.position != position;
  }
}

class _SliderHandle extends StatelessWidget {
  const _SliderHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: double.infinity,
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 2,
            color: AppColors.warmWhite,
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.warmWhite,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.swap_horiz,
              size: 20,
              color: AppColors.black,
            ),
          ),
        ],
      ),
    );
  }
}
