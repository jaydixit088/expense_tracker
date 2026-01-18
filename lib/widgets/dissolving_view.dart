import 'package:flutter/material.dart';
import 'dart:math';

class DissolvingView extends StatefulWidget {
  final Widget child;
  final Function() onDissolved;
  final Duration duration;

  const DissolvingView({
    super.key,
    required this.child,
    required this.onDissolved,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  State<DissolvingView> createState() => DissolvingViewState();
}

class DissolvingViewState extends State<DissolvingView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _rotationAnimation;
  bool _isDissolving = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 1.0, curve: Curves.easeOut)),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.2 * (Random().nextBool() ? 1 : -1)).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeIn)
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void dissolve() {
    if (_isDissolving) return;
    setState(() => _isDissolving = true);
    _controller.forward().then((_) {
      widget.onDissolved();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDissolving) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}
