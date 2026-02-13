import 'package:flutter/material.dart';

typedef CardBuilder<T> =
    Widget Function(BuildContext context, T item, int index);

class HorizontalCardFeed<T> extends StatefulWidget {
  const HorizontalCardFeed({
    super.key,
    required this.items,
    required this.cardBuilder,
    this.onPageChanged,
    this.initialPage = 0,
    this.controller,
  });

  final List<T> items;
  final CardBuilder<T> cardBuilder;
  final ValueChanged<int>? onPageChanged;
  final int initialPage;
  final PageController? controller;

  @override
  State<HorizontalCardFeed<T>> createState() => _HorizontalCardFeedState<T>();
}

class _HorizontalCardFeedState<T> extends State<HorizontalCardFeed<T>> {
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    return PageView.builder(
      controller: _controller,
      reverse: true,
      itemCount: widget.items.length,
      onPageChanged: widget.onPageChanged,
      itemBuilder: (context, index) {
        return widget.cardBuilder(context, widget.items[index], index);
      },
    );
  }
}
