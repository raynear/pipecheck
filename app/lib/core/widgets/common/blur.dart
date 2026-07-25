import 'package:flutter/material.dart';

enum BlurOption { square, circle }

class Blur extends StatelessWidget {
  const Blur({super.key, required this.option, required this.child});
  final BlurOption option;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    switch (option) {
      case BlurOption.circle:
        return ShaderMask(
          shaderCallback: (Rect bounds) {
            return const RadialGradient(
              center: Alignment.center,
              radius: 0.5,
              colors: [Colors.transparent, Colors.blueGrey], // Start with transparent and end with the background color
              stops: [0.8, 1.0], // Adjust stops to control the fading effect
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstOut, // Use dstOut to create the fading effect
          child: child,
        );
      case BlurOption.square:
        return ShaderMask(
          shaderCallback: (Rect bounds) {
            // Vertical gradient
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
              stops: [0.0, 0.1, 0.9, 1.0], // Adjust these stops for vertical fade
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              // Horizontal gradient
              return const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
                stops: [0.0, 0.1, 0.9, 1.0], // Adjust these stops for horizontal fade
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: child,
          ),
        );
    }
  }
}
