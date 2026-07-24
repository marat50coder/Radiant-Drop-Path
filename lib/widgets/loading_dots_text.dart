import 'package:flutter/material.dart';

/// Renders "Loading" followed by an animated cycling sequence of dots
/// (., .., ...), looping continuously.
class LoadingDotsText extends StatefulWidget {
  final TextStyle? style;
  final String label;
  const LoadingDotsText({super.key, this.style, this.label = 'Loading'});

  @override
  State<LoadingDotsText> createState() => _LoadingDotsTextState();
}

class _LoadingDotsTextState extends State<LoadingDotsText> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final dotCount = 1 + (_controller.value * 3).floor().clamp(0, 2);
        return Text('${widget.label}${'.' * dotCount}', style: widget.style);
      },
    );
  }
}
