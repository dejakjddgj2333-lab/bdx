import 'package:flutter/material.dart';
import 'bdx/bdx_loading.dart';

class LoadingIndicator extends StatelessWidget {
  final double size;

  const LoadingIndicator({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return BdxLoading(size: size);
  }
}
