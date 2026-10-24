import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'components.dart' show Surface;
import '../art/raster_assets.dart';

/// Fixed pages for non-list content. No Scrollable, clipping, text reduction,
/// duplicate measurement widgets, or scroll gestures are used.
abstract interface class GamePageContent {
  List<Widget> pageParts(BuildContext context, double width);
}

class GamePages extends StatefulWidget {
  const GamePages({
    super.key,
    this.child,
    this.children,
    this.padding = const EdgeInsets.all(12),
    this.framed = false,
    this.shrinkWrap = false,
    this.centerContent = false,
  });
  final bool framed;

  /// Short dialogs use their actual content height; long content still pages.
  final bool shrinkWrap;

  /// Center the current notice and its page controls as one group, even when
  /// the parent gives this pager a fixed height. Lists/forms can stay anchored.
  final bool centerContent;
  final Widget? child;
  final List<Widget>? children;
  final EdgeInsetsGeometry padding;
  @override
  State<GamePages> createState() => _GamePagesState();
}

class _GamePagesState extends State<GamePages> {
  Widget arrow(String label, String key, IconData icon, VoidCallback? action) =>
      Semantics(
        label: tr(label),
        button: true,
        enabled: action != null,
        onTap: audible(action),
        excludeSemantics: true,
        child: Tooltip(
          message: tr(label),
          excludeFromSemantics: true,
          child: IconButton(
            key: Key(key),
            onPressed: audible(action),
            icon: RasterIcon(icon, size: 28),
          ),
        ),
      );
  int page = 0, total = 1;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final content = Padding(
      padding: widget.padding,
      child: LayoutBuilder(
        builder: (context, box) {
          final bodyHeight = math.max(80.0, box.maxHeight - 52);
          final parts = <Widget>[];
          for (final root
              in widget.children ?? [if (widget.child != null) widget.child!]) {
            parts.addAll(_parts(context, root, box.maxWidth, bodyHeight));
          }
          return Column(
            mainAxisAlignment: widget.centerContent
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            mainAxisSize: widget.shrinkWrap
                ? MainAxisSize.min
                : MainAxisSize.max,
            children: [
              Flexible(
                fit: widget.shrinkWrap || widget.centerContent
                    ? FlexFit.loose
                    : FlexFit.tight,
                child: _PagedLayout(
                  page: page,
                  shrinkWrap: widget.shrinkWrap || widget.centerContent,
                  onCount: (count) {
                    if (mounted && (count != total || page >= count)) {
                      setState(() {
                        total = count;
                        page = page.clamp(0, count - 1);
                      });
                    }
                  },
                  children: parts,
                ),
              ),
              if ((!widget.shrinkWrap && !widget.centerContent) || total > 1)
                SizedBox(
                  height: 52,
                  child: total <= 1
                      ? const SizedBox()
                      : Row(
                          children: [
                            arrow(
                              '이전 페이지',
                              'game-page-previous',
                              Icons.arrow_back,
                              page > 0 ? () => setState(() => page--) : null,
                            ),
                            Expanded(
                              child: Text(
                                message("{0} / {1}", [page + 1, total]),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            arrow(
                              '다음 페이지',
                              'game-page-next',
                              Icons.arrow_forward,
                              page + 1 < total
                                  ? () => setState(() => page++)
                                  : null,
                            ),
                          ],
                        ),
                ),
            ],
          );
        },
      ),
    );
    return SizedBox(
      width: 440,
      height: widget.shrinkWrap ? null : MediaQuery.sizeOf(context).height,
      child: widget.framed ? RasterPanel(child: content) : content,
    );
  }
}

Iterable<Widget> _parts(
  BuildContext context,
  Widget widget,
  double width,
  double height,
) sync* {
  if (widget is GamePageContent) {
    for (final item in (widget as GamePageContent).pageParts(context, width)) {
      yield* _parts(context, item, width, height);
    }
  } else if (widget is Column) {
    for (final item in widget.children) {
      yield* _parts(context, item, width, height);
    }
  } else if (widget is Wrap) {
    for (final item in widget.children) {
      yield Center(child: item);
      yield const SizedBox(height: 8);
    }
  } else if (widget is GamePages) {
    for (final item
        in widget.children ?? [if (widget.child != null) widget.child!]) {
      yield* _parts(context, item, width, height);
    }
  } else if (widget is Expanded || widget is Flexible) {
    yield* _parts(context, (widget as Flexible).child, width, height);
  } else if (widget is Surface) {
    yield* _parts(context, widget.child, width, height);
  } else if (widget is Center) {
    if (widget.child != null) {
      for (final part in _parts(context, widget.child!, width, height)) {
        yield Center(child: part);
      }
    }
  } else if (widget is SizedBox &&
      widget.child != null &&
      widget.height == null) {
    yield* _parts(
      context,
      widget.child!,
      math.min(widget.width ?? width, width),
      height,
    );
  } else if (widget is Padding) {
    final inset = widget.padding.resolve(Directionality.of(context));
    for (final part in _parts(
      context,
      widget.child!,
      math.max(1, width - inset.horizontal),
      math.max(1, height - inset.vertical),
    )) {
      yield Padding(padding: widget.padding, child: part);
    }
  } else if (widget is DefaultTextStyle) {
    for (final part in _parts(context, widget.child, width, height)) {
      yield DefaultTextStyle(style: widget.style, child: part);
    }
  } else if (widget is Text && widget.data != null) {
    var remaining = tr(widget.data!);
    final style = DefaultTextStyle.of(context).style
        .copyWith(fontSize: 16)
        .merge(widget.style);
    while (remaining.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(text: tr(remaining), style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: width);
      if (painter.height <= height) {
        yield Text(tr(remaining), style: style, textAlign: TextAlign.center);
        break;
      }
      final lines = painter
          .computeLineMetrics()
          .where((line) => line.baseline + line.descent <= height)
          .toList();
      if (lines.isEmpty) {
        yield widget;
        break;
      }
      final offset = painter
          .getPositionForOffset(Offset(0, lines.last.baseline))
          .offset;
      final end = painter
          .getLineBoundary(TextPosition(offset: offset))
          .end
          .clamp(1, remaining.length);
      yield Text(
        tr(remaining.substring(0, end)),
        style: style,
        textAlign: TextAlign.center,
      );
      remaining = remaining.substring(end);
    }
  } else {
    yield widget;
  }
}

class _PageData extends ContainerBoxParentData<RenderBox> {
  int page = 0;
}

class _PagedLayout extends MultiChildRenderObjectWidget {
  const _PagedLayout({
    required this.page,
    required this.shrinkWrap,
    required this.onCount,
    required super.children,
  });
  final int page;
  final bool shrinkWrap;
  final ValueChanged<int> onCount;
  @override
  MultiChildRenderObjectElement createElement() => _PagedElement(this);
  @override
  _PageRender createRenderObject(BuildContext context) =>
      _PageRender(page, onCount, shrinkWrap);
  @override
  void updateRenderObject(BuildContext context, _PageRender renderObject) {
    renderObject
      ..page = page
      ..shrinkWrap = shrinkWrap
      ..onCount = onCount
      ..markNeedsLayout()
      ..markNeedsSemanticsUpdate();
  }
}

class _PagedElement extends MultiChildRenderObjectElement {
  _PagedElement(_PagedLayout super.widget);
  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    final render = renderObject as _PageRender;
    visitChildren((element) {
      final data = element.findRenderObject()?.parentData;
      if (data is _PageData && data.page == render.page) visitor(element);
    });
  }
}

class _PageRender extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PageData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PageData> {
  _PageRender(this.page, this.onCount, this.shrinkWrap);
  bool shrinkWrap;
  int page, _lastCount = 0;
  ValueChanged<int> onCount;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PageData) child.parentData = _PageData();
  }

  @override
  void performLayout() {
    final available = constraints.biggest;
    var y = 0.0, index = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      child.layout(
        BoxConstraints(maxWidth: available.width),
        parentUsesSize: true,
      );
      assert(
        child.size.height <= available.height + .5,
        'Fixed page item is too tall: ${child.runtimeType} ${child.size.height} > ${available.height}',
      );
      final data = child.parentData! as _PageData;
      if (y > 0 && y + child.size.height > available.height + .1) {
        index++;
        y = 0;
      }
      data
        ..page = index
        ..offset = Offset((available.width - child.size.width) / 2, y);
      y += child.size.height;
      child = data.nextSibling;
    }
    final count = index + 1;
    page = page.clamp(0, count - 1);
    // Measure the visible page, including the last page of a long dialog.
    // Page capacity always uses the incoming maximum, never the previous size.
    var visibleHeight = 0.0;
    child = firstChild;
    while (child != null) {
      final data = child.parentData! as _PageData;
      if (data.page == page) {
        visibleHeight = math.max(
          visibleHeight,
          data.offset.dy + child.size.height,
        );
      }
      child = data.nextSibling;
    }
    size = constraints.constrain(
      Size(available.width, shrinkWrap ? visibleHeight : available.height),
    );
    if (_lastCount != count) {
      _lastCount = count;
      SchedulerBinding.instance.addPostFrameCallback((_) => onCount(count));
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    RenderBox? child = firstChild;
    while (child != null) {
      final data = child.parentData! as _PageData;
      if (data.page == page) context.paintChild(child, offset + data.offset);
      child = data.nextSibling;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    RenderBox? child = lastChild;
    while (child != null) {
      final data = child.parentData! as _PageData;
      if (data.page == page &&
          result.addWithPaintOffset(
            offset: data.offset,
            position: position,
            hitTest: (result, transformed) =>
                child!.hitTest(result, position: transformed),
          )) {
        return true;
      }
      child = data.previousSibling;
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    RenderBox? child = firstChild;
    while (child != null) {
      final data = child.parentData! as _PageData;
      if (data.page == page) visitor(child);
      child = data.nextSibling;
    }
  }
}

/// Scrolls actual repeated items, never a fixed overview or a detail dialog.
class GameItemList extends StatelessWidget {
  const GameItemList({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return ListView(padding: padding, children: [child]);
  }
}
