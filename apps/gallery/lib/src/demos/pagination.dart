import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

Widget _caption(BuildContext context, String text) {
  return Text(
    text,
    style: KunText.sm.copyWith(
      color: KunTheme.of(context).colors.neutral.shade600,
    ),
  );
}

class _PaginationHost extends StatefulWidget {
  const _PaginationHost({
    required this.totalPage,
    this.initialPage = 1,
    this.isLoading = false,
    this.showPage = false,
  });

  final int totalPage;
  final int initialPage;
  final bool isLoading;
  final bool showPage;

  @override
  State<_PaginationHost> createState() => _PaginationHostState();
}

class _PaginationHostState extends State<_PaginationHost> {
  late int _page = widget.initialPage;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 3,
      children: <Widget>[
        KunPagination(
          currentPage: _page,
          totalPage: widget.totalPage,
          isLoading: widget.isLoading,
          onCurrentPageChanged: (int page) => setState(() => _page = page),
        ),
        if (widget.showPage)
          Text(
            'Page: $_page',
            style: KunText.sm.copyWith(
              color: KunTheme.of(context).colors.neutral.shade600,
            ),
          ),
      ],
    );
  }
}

Widget paginationBasic(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(context, 'Twenty pages. The first page opens the window.'),
        const _PaginationHost(totalPage: 20, showPage: true),
      ],
    ),
  );
}

Widget paginationFew(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _PaginationHost(totalPage: 5),
  );
}

Widget paginationLoading(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(
          context,
          'Every control is disabled while a page is in flight.',
        ),
        const _PaginationHost(totalPage: 20, initialPage: 3, isLoading: true),
      ],
    ),
  );
}

Widget paginationMiddle(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(
          context,
          'A centred page keeps ellipses on both sides of the window.',
        ),
        const _PaginationHost(totalPage: 20, initialPage: 10),
      ],
    ),
  );
}

Widget paginationLast(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(context, 'The last page closes the window against the end.'),
        const _PaginationHost(totalPage: 20, initialPage: 20),
      ],
    ),
  );
}
