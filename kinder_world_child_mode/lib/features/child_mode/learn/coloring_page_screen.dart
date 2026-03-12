import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/features/child_mode/learn/coloring_progress_storage.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:xml/xml.dart';

class ColoringPageScreen extends StatefulWidget {
  const ColoringPageScreen({
    super.key,
    required this.svgAssetPath,
    this.title = '',
  });

  final String svgAssetPath;
  final String title;

  @override
  State<ColoringPageScreen> createState() => _ColoringPageScreenState();
}

class _ColoringPageScreenState extends State<ColoringPageScreen> {
  late final ColoringPageController _controller;
  final ScrollController _paletteScrollController = ScrollController();
  final TransformationController _canvasTransformController =
      TransformationController();
  SvgColoringTemplate? _template;
  String? _rawSvg;
  String? _error;
  Offset? _sparklePosition;
  Color _sparkleColor = Colors.white;
  int _sparkleTick = 0;
  bool _isCompleted = false;
  bool _completionRewardShown = false;
  Timer? _saveDebounce;

  static const List<Color> _palette = <Color>[
    Color(0xFFFFEB3B), // yellow bright
    Color(0xFFF9A825), // yellow dark
    Color(0xFF4FC3F7), // blue light
    Color(0xFF1565C0), // blue deep
    Color(0xFF66BB6A), // green light
    Color(0xFF2E7D32), // green deep
    Color(0xFFFF5252), // red bright
    Color(0xFFC62828), // red deep
    Color(0xFFBA68C8), // purple light
    Color(0xFF6A1B9A), // purple deep
    Color(0xFFFFA726), // orange bright
    Color(0xFFEF6C00), // orange deep
    Color(0xFFFF6FAE), // pink bright
    Color(0xFFEC407A), // pink deep
    Color(0xFF8D6E63), // brown
    Color(0xFF000000), // black
    Color(0xFFFFFFFF), // white
  ];

  @override
  void initState() {
    super.initState();
    _controller = ColoringPageController(initialColor: _palette.first);
    _controller.addListener(_handleControllerChanged);
    _loadTemplate();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _controller.removeListener(_handleControllerChanged);
    _paletteScrollController.dispose();
    _canvasTransformController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadTemplate() async {
    try {
      final rawSvg = await rootBundle.loadString(widget.svgAssetPath);
      SvgColoringTemplate? template;
      String? parseError;
      try {
        template = SvgColoringTemplate.fromRawSvg(rawSvg);
      } catch (e) {
        parseError = e.toString();
      }

      if (!mounted) return;
      if (template != null) {
        await _restoreProgress(template);
      }
      if (!mounted) return;
      setState(() {
        _template = template;
        _rawSvg = rawSvg;
        _error = parseError;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _restoreProgress(SvgColoringTemplate template) async {
    final progress = await ColoringProgressStorage.load(widget.svgAssetPath);
    _controller.restoreColors(progress.colors);
    final completedNow = template.areas.isNotEmpty &&
        _controller.filledAreasCount >= template.areas.length;
    _isCompleted = progress.isCompleted || completedNow;
    _completionRewardShown = _isCompleted;
  }

  void _handleControllerChanged() {
    final template = _template;
    if (template == null) return;

    final completedNow = template.areas.isNotEmpty &&
        _controller.filledAreasCount >= template.areas.length;
    final becameCompleted = completedNow && !_isCompleted;

    if (_isCompleted != completedNow && mounted) {
      setState(() {
        _isCompleted = completedNow;
      });
    } else {
      _isCompleted = completedNow;
    }

    if (becameCompleted && !_completionRewardShown) {
      _completionRewardShown = true;
      _showCompletionReward();
    }

    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 250), () {
      ColoringProgressStorage.save(
        svgAssetPath: widget.svgAssetPath,
        colors: _controller.colorsByAreaId,
        isCompleted: _isCompleted,
      );
    });
  }

  void _showCompletionReward() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: const _CompletionRewardBadge(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final template = _template;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          widget.title.isEmpty ? l10n.coloringTitle : widget.title,
          style: TextStyle(
            fontFamily: 'Comic Sans MS',
            fontWeight: FontWeight.w900,
            color: colors.onSurface,
          ),
        ),
      ),
      body: Stack(
        children: [
          const _PlayfulCanvasBackground(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow.withValues(alpha: 0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: colors.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          l10n.tapShapeToFill,
                          style: TextStyle(
                            fontFamily: 'Comic Sans MS',
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      if (_isCompleted) ...[
                        const SizedBox(width: 10),
                        const _SunStarBadge(),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: _buildCanvas(template),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildPalette(),
                const SizedBox(height: 10),
                _buildControls(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas(SvgColoringTemplate? template) {
    final l10n = AppLocalizations.of(context)!;
    if (_error != null) {
      return Center(
        child: Text(
          l10n.couldNotLoadColoringPage(_error!),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    if (template == null) {
      if (_rawSvg != null) {
        return Stack(
          children: [
            Positioned.fill(
              child: SvgPicture.string(
                _rawSvg!,
                fit: BoxFit.contain,
              ),
            ),
            if (_error != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    l10n.interactiveFillDisabled(_error!),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final squareSize = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final drawSize = squareSize * 0.90;
        final drawLeft = (squareSize - drawSize) / 2;
        final drawTop = (squareSize - drawSize) * 0.20;
        final scaleX = template.width / drawSize;
        final scaleY = template.height / drawSize;

        return Center(
          child: SizedBox(
            width: squareSize,
            height: squareSize,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRect(
                    child: InteractiveViewer(
                      transformationController: _canvasTransformController,
                      minScale: 1,
                      maxScale: 4,
                      boundaryMargin: const EdgeInsets.all(220),
                      panEnabled: true,
                      scaleEnabled: true,
                      child: Stack(
                        children: [
                          Positioned(
                            left: drawLeft,
                            top: drawTop,
                            width: drawSize,
                            height: drawSize,
                            child: AnimatedBuilder(
                              animation: _controller,
                              builder: (context, _) {
                                return AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 260),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeIn,
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale: Tween<double>(
                                          begin: 0.98,
                                          end: 1,
                                        ).animate(
                                          CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeOutCubic,
                                          ),
                                        ),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: SvgPicture.string(
                                    template.buildAreasSvg(
                                      _controller.colorsByAreaId,
                                    ),
                                    key: ValueKey<int>(
                                        _controller.paintRevision),
                                    fit: BoxFit.fill,
                                  ),
                                );
                              },
                            ),
                          ),
                          Positioned(
                            left: drawLeft,
                            top: drawTop,
                            width: drawSize,
                            height: drawSize,
                            child: RepaintBoundary(
                              child: SvgPicture.string(
                                template.outlineSvg,
                                fit: BoxFit.fill,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapUp: (details) {
                      final scenePoint = _canvasTransformController.toScene(
                        details.localPosition,
                      );
                      if (scenePoint.dx < drawLeft ||
                          scenePoint.dx > drawLeft + drawSize ||
                          scenePoint.dy < drawTop ||
                          scenePoint.dy > drawTop + drawSize) {
                        return;
                      }
                      final svgPoint = Offset(
                        (scenePoint.dx - drawLeft) * scaleX,
                        (scenePoint.dy - drawTop) * scaleY,
                      );
                      final areaId = template.hitTest(svgPoint);
                      if (areaId != null) {
                        final didFill = _controller.fillArea(areaId);
                        if (didFill) {
                          _triggerSparkle(details.localPosition);
                        }
                      }
                    },
                  ),
                ),
                if (_sparklePosition != null)
                  Positioned(
                    left: _sparklePosition!.dx - 14,
                    top: _sparklePosition!.dy - 14,
                    child: _SparkleBurst(
                      key: ValueKey<int>(_sparkleTick),
                      color: _sparkleColor,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPalette() {
    return Container(
      height: 144,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6BC8FF).withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final firstRow = _palette.sublist(0, 9);
          final secondRow = _palette.sublist(9);
          const bubbleSize = 52.0;
          const gap = 10.0;
          final firstRowWidth =
              (firstRow.length * bubbleSize) + ((firstRow.length - 1) * gap);
          final secondRowWidth =
              (secondRow.length * bubbleSize) + ((secondRow.length - 1) * gap);
          final contentMinWidth = (firstRowWidth > secondRowWidth
                  ? firstRowWidth
                  : secondRowWidth) +
              24;

          Widget buildRow(List<Color> colors) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < colors.length; i++) ...[
                  _PaletteBubbleButton(
                    color: colors[i],
                    selected: _controller.selectedColor == colors[i],
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _controller.selectColor(colors[i]);
                    },
                  ),
                  if (i < colors.length - 1) const SizedBox(width: 10),
                ],
              ],
            );
          }

          return Scrollbar(
            controller: _paletteScrollController,
            thumbVisibility: true,
            radius: const Radius.circular(12),
            child: SingleChildScrollView(
              controller: _paletteScrollController,
              scrollDirection: Axis.horizontal,
              primary: false,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: contentMinWidth),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    buildRow(firstRow),
                    const SizedBox(height: 10),
                    buildRow(secondRow),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _triggerSparkle(Offset position) {
    HapticFeedback.lightImpact();
    setState(() {
      _sparklePosition = position;
      _sparkleColor = _controller.selectedColor;
      _sparkleTick++;
    });
  }

  Widget _buildControls() {
    final l10n = AppLocalizations.of(context)!;
    final compact = MediaQuery.sizeOf(context).width < 390;
    final width = MediaQuery.sizeOf(context).width;
    final buttonWidth = compact ? (width - 48) / 2 : (width - 56) / 4;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: buttonWidth,
              child: _ControlButton(
                icon: Icons.undo_rounded,
                label: l10n.undo,
                enabled: _controller.canUndo,
                onTap: _controller.undo,
              ),
            ),
            SizedBox(
              width: buttonWidth,
              child: _ControlButton(
                icon: Icons.redo_rounded,
                label: l10n.redo,
                enabled: _controller.canRedo,
                onTap: _controller.redo,
              ),
            ),
            SizedBox(
              width: buttonWidth,
              child: _ControlButton(
                icon: Icons.refresh_rounded,
                label: l10n.reset,
                enabled: _controller.colorsByAreaId.isNotEmpty,
                onTap: _controller.reset,
              ),
            ),
            SizedBox(
              width: buttonWidth,
              child: _ControlButton(
                icon: Icons.cleaning_services_rounded,
                label: l10n.eraser,
                enabled: true,
                selected: _controller.selectedColor == Colors.white,
                onTap: _controller.enableEraser,
              ),
            ),
          ],
        );
      },
    );
  }
}

class ColoringPageController extends ChangeNotifier {
  ColoringPageController({required Color initialColor})
      : _selectedColor = initialColor;

  final Map<String, Color> _colorsByAreaId = <String, Color>{};
  final List<Map<String, Color>> _undoStack = <Map<String, Color>>[];
  final List<Map<String, Color>> _redoStack = <Map<String, Color>>[];

  Color _selectedColor;
  int _paintRevision = 0;

  Map<String, Color> get colorsByAreaId => _colorsByAreaId;
  Color get selectedColor => _selectedColor;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  int get paintRevision => _paintRevision;
  int get filledAreasCount => _colorsByAreaId.length;

  void selectColor(Color color) {
    if (_selectedColor == color) return;
    _selectedColor = color;
    notifyListeners();
  }

  void enableEraser() {
    selectColor(Colors.white);
  }

  void restoreColors(Map<String, Color> colors) {
    _colorsByAreaId
      ..clear()
      ..addAll(colors);
    _undoStack.clear();
    _redoStack.clear();
    _paintRevision++;
    notifyListeners();
  }

  bool fillArea(String id) {
    final current = _colorsByAreaId[id] ?? Colors.white;
    if (current == _selectedColor) return false;

    _saveUndoSnapshot();
    _colorsByAreaId[id] = _selectedColor;
    _redoStack.clear();
    _paintRevision++;
    notifyListeners();
    return true;
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(Map<String, Color>.from(_colorsByAreaId));
    final previous = _undoStack.removeLast();
    _colorsByAreaId
      ..clear()
      ..addAll(previous);
    _paintRevision++;
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(Map<String, Color>.from(_colorsByAreaId));
    final next = _redoStack.removeLast();
    _colorsByAreaId
      ..clear()
      ..addAll(next);
    _paintRevision++;
    notifyListeners();
  }

  void reset() {
    if (_colorsByAreaId.isEmpty) return;
    _saveUndoSnapshot();
    _colorsByAreaId.clear();
    _redoStack.clear();
    _paintRevision++;
    notifyListeners();
  }

  void _saveUndoSnapshot() {
    _undoStack.add(Map<String, Color>.from(_colorsByAreaId));
  }
}

class SvgColorArea {
  const SvgColorArea({
    required this.id,
    required this.pathData,
    required this.path,
    required this.useEvenOddFill,
  });

  final String id;
  final String pathData;
  final Path path;
  final bool useEvenOddFill;
}

class SvgColoringTemplate {
  SvgColoringTemplate({
    required this.width,
    required this.height,
    required this.outlineSvg,
    required this.areas,
  });

  final double width;
  final double height;
  final String outlineSvg;
  final List<SvgColorArea> areas;

  static SvgColoringTemplate fromRawSvg(String rawSvg) {
    final document = XmlDocument.parse(rawSvg);
    final svgElement = document.rootElement;

    final viewBox = svgElement.getAttribute('viewBox');
    double width = _parseSize(svgElement.getAttribute('width')) ?? 1024;
    double height = _parseSize(svgElement.getAttribute('height')) ?? 1024;

    if (viewBox != null) {
      final parts = viewBox
          .split(RegExp(r'\s+'))
          .where((value) => value.trim().isNotEmpty)
          .toList();
      if (parts.length == 4) {
        width = double.tryParse(parts[2]) ?? width;
        height = double.tryParse(parts[3]) ?? height;
      }
    }

    final outlineGroup = _findGroupById(svgElement, 'outlines') ??
        _findGroupById(svgElement, 'outline') ??
        _findGroupById(svgElement, 'original_lines');
    final colorAreasGroup = _findGroupById(svgElement, 'colorRegions') ??
        _findGroupById(svgElement, 'color_areas');

    final areaElements = colorAreasGroup != null
        ? colorAreasGroup.findAllElements('path').toList()
        : _fallbackAreaElements(svgElement);

    final areas = <SvgColorArea>[];
    final areaIndexByGeometry = <String, int>{};
    for (var i = 0; i < areaElements.length; i++) {
      final node = areaElements[i];
      final d = node.getAttribute('d');
      if (d == null || d.trim().isEmpty) continue;

      try {
        final parsedPath = parseSvgPathData(d);
        final style = node.getAttribute('style')?.toLowerCase() ?? '';
        final fillRule = node.getAttribute('fill-rule')?.toLowerCase() ?? '';
        final useEvenOddFill =
            fillRule == 'evenodd' || style.contains('fill-rule:evenodd');
        parsedPath.fillType =
            useEvenOddFill ? PathFillType.evenOdd : PathFillType.nonZero;
        final bounds = parsedPath.getBounds();
        // Ignore only near-full-canvas shapes (usually background catch-alls).
        final coversCanvas =
            bounds.width * bounds.height >= (width * height * 0.98);
        if (coversCanvas) continue;

        final area = SvgColorArea(
          id: node.getAttribute('id') ?? 'area_$i',
          pathData: d,
          path: parsedPath,
          useEvenOddFill: useEvenOddFill,
        );
        final geometryKey = '${d.trim()}|${useEvenOddFill ? 'eo' : 'nz'}';
        final existingIndex = areaIndexByGeometry[geometryKey];
        if (existingIndex != null) {
          // Keep the latest duplicate so it matches visual top-most order.
          areas[existingIndex] = area;
        } else {
          areaIndexByGeometry[geometryKey] = areas.length;
          areas.add(area);
        }
      } catch (_) {
        // Ignore malformed path data.
      }
    }

    final outlineSvg = _buildOutlineSvg(
      width: width,
      height: height,
      outlineGroup: outlineGroup,
      svgElement: svgElement,
      areaElements: areaElements,
    );

    return SvgColoringTemplate(
      width: width,
      height: height,
      outlineSvg: outlineSvg,
      areas: areas,
    );
  }

  String buildAreasSvg(Map<String, Color> colorsByAreaId) {
    final buffer = StringBuffer()
      ..write('<svg xmlns="http://www.w3.org/2000/svg" width="')
      ..write(width)
      ..write('" height="')
      ..write(height)
      ..write('" viewBox="0 0 ')
      ..write(width)
      ..write(' ')
      ..write(height)
      ..write('">');

    for (final area in areas) {
      final color = colorsByAreaId[area.id] ?? Colors.white;
      buffer
        ..write('<path id="')
        ..write(area.id)
        ..write('" d="')
        ..write(area.pathData)
        ..write('" fill="')
        ..write(_toHex(color))
        ..write('"');
      if (area.useEvenOddFill) {
        buffer.write(' fill-rule="evenodd"');
      }
      buffer.write(' stroke="none"/>');
    }

    buffer.write('</svg>');
    return buffer.toString();
  }

  String? hitTest(Offset point) {
    SvgColorArea? best;
    var bestAreaSize = double.infinity;
    for (final area in areas) {
      if (!area.path.contains(point)) continue;
      final bounds = area.path.getBounds();
      final areaSize = bounds.width * bounds.height;
      // Use <= so if two overlapping areas have same bounds,
      // we prefer the later one (typically top-most in SVG order).
      if (areaSize <= bestAreaSize) {
        bestAreaSize = areaSize;
        best = area;
      }
    }
    if (best != null) return best.id;

    // Fallback for SVGs that use open/complex paths where `contains`
    // may fail: pick the nearest small bounds around the tap point.
    const hitPadding = 10.0;
    for (final area in areas) {
      final bounds = area.path.getBounds();
      if (!bounds.inflate(hitPadding).contains(point)) continue;
      final areaSize = bounds.width * bounds.height;
      if (areaSize <= bestAreaSize) {
        bestAreaSize = areaSize;
        best = area;
      }
    }
    return best?.id;
  }

  static XmlElement? _findGroupById(XmlElement root, String id) {
    for (final node in root.descendants) {
      if (node is XmlElement &&
          node.name.local == 'g' &&
          node.getAttribute('id') == id) {
        return node;
      }
    }
    return null;
  }

  static List<XmlElement> _fallbackAreaElements(XmlElement svgElement) {
    return svgElement.findAllElements('path').where((node) {
      final style = node.getAttribute('style')?.toLowerCase() ?? '';
      final fill = node.getAttribute('fill')?.toLowerCase() ?? '';
      final cssClass = node.getAttribute('class')?.toLowerCase() ?? '';
      final onClick = node.getAttribute('onclick')?.toLowerCase() ?? '';
      return style.contains('fill:#ffffff') ||
          fill == '#ffffff' ||
          fill == 'white' ||
          cssClass.contains('region') ||
          onClick.contains('fill(');
    }).toList();
  }

  static String _buildOutlineSvg({
    required double width,
    required double height,
    required XmlElement? outlineGroup,
    required XmlElement svgElement,
    required List<XmlElement> areaElements,
  }) {
    final buffer = StringBuffer()
      ..write('<svg xmlns="http://www.w3.org/2000/svg" width="')
      ..write(width)
      ..write('" height="')
      ..write(height)
      ..write('" viewBox="0 0 ')
      ..write(width)
      ..write(' ')
      ..write(height)
      ..write('">');

    if (outlineGroup != null) {
      // فحص: هل الـ outline معمول بـ fill+evenodd (يسبب holes شفافة)؟
      // لو آه → نحوّله لـ stroke عشان كل خط يبان أسود صح
      final outlinePaths = outlineGroup.findAllElements('path').toList();
      final usesEvenoddFill = outlinePaths.any((p) =>
          p.getAttribute('fill-rule') == 'evenodd' &&
          (p.getAttribute('fill') ?? '').isNotEmpty &&
          p.getAttribute('fill') != 'none');

      if (usesEvenoddFill) {
        // حوّل كل path لـ stroke بدل fill → مفيش holes
        buffer.write(
          '<g fill="none" stroke="#000000" stroke-width="3" '
          'stroke-linejoin="round" stroke-linecap="round">',
        );
        for (final path in outlinePaths) {
          final d = path.getAttribute('d') ?? '';
          if (d.isEmpty) continue;
          buffer.write('<path d="$d"/>');
        }
        buffer.write('</g>');
      } else {
        // outline سليم → اكتبه كاملاً مع كل attributes
        buffer.write(outlineGroup.toXmlString());
      }
    } else {
      // مفيش outline group → نلف كل الـ paths في <g> بـ stroke أسود سميك
      buffer.write(
        '<g fill="none" stroke="#000000" stroke-width="3" '
        'stroke-linejoin="round" stroke-linecap="round">',
      );
      final skip = areaElements.toSet();
      var wroteAnyPath = false;
      for (final path in svgElement.findAllElements('path')) {
        if (skip.contains(path)) continue;
        final d = path.getAttribute('d') ?? '';
        if (d.isEmpty) continue;
        buffer.write('<path d="$d"/>');
        wroteAnyPath = true;
      }
      if (!wroteAnyPath) {
        for (final area in areaElements) {
          final d = area.getAttribute('d') ?? '';
          if (d.isEmpty) continue;
          buffer.write('<path d="$d"/>');
        }
      }
      buffer.write('</g>');
    }

    buffer.write('</svg>');
    return buffer.toString();
  }

  static double? _parseSize(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned);
  }

  static String _toHex(Color color) {
    final argb = color.toARGB32();
    return '#${argb.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFFFFD66B) : Colors.white;
    final fg = enabled ? const Color(0xFF15507F) : Colors.black26;
    final compact = MediaQuery.sizeOf(context).width < 390;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        elevation: 0,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: compact ? 9 : 11,
              horizontal: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: compact ? 18 : 20, color: fg),
                SizedBox(width: compact ? 4 : 6),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Comic Sans MS',
                      fontSize: compact ? 12 : 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaletteBubbleButton extends StatefulWidget {
  const _PaletteBubbleButton({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_PaletteBubbleButton> createState() => _PaletteBubbleButtonState();
}

class _PaletteBubbleButtonState extends State<_PaletteBubbleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.86 : (widget.selected ? 1.1 : 1),
        curve: Curves.easeOutCubic,
        child: InkWell(
          onTap: widget.onTap,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.selected ? Colors.white : const Color(0xFFE9F6FF),
                width: widget.selected ? 4 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.55),
                  blurRadius: widget.selected ? 16 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SparkleBurst extends StatefulWidget {
  const _SparkleBurst({super.key, required this.color});

  final Color color;

  @override
  State<_SparkleBurst> createState() => _SparkleBurstState();
}

class _SparkleBurstState extends State<_SparkleBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
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
      builder: (context, child) {
        final t = Curves.easeOut.transform(_controller.value);
        return Opacity(
          opacity: 1 - t,
          child: Transform.scale(
            scale: 0.6 + (t * 1.1),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: widget.color.withValues(alpha: 0.9),
              size: 28,
            ),
          ),
        );
      },
    );
  }
}

class _SunStarBadge extends StatelessWidget {
  const _SunStarBadge();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          Icons.wb_sunny_rounded,
          color: Color(0xFFFFC107),
          size: 24,
        ),
        Positioned(
          right: -4,
          top: -5,
          child: Icon(
            Icons.star_rounded,
            color: Color(0xFFFF8F00),
            size: 14,
          ),
        ),
      ],
    );
  }
}

class _CompletionRewardBadge extends StatelessWidget {
  const _CompletionRewardBadge();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SunStarBadge(),
        const SizedBox(height: 8),
        Text(
          l10n.awesomeColoring,
          style: const TextStyle(
            fontFamily: 'Comic Sans MS',
            fontWeight: FontWeight.w900,
            color: Color(0xFF18578C),
          ),
        ),
      ],
    );
  }
}

class _PlayfulCanvasBackground extends StatelessWidget {
  const _PlayfulCanvasBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFD8F3FF), Color(0xFFFFF5B9)],
              ),
            ),
          ),
        ),
        Positioned(
          top: 18,
          left: 18,
          child: Icon(
            Icons.star_rounded,
            color: const Color(0xFFFFD54F).withValues(alpha: 0.9),
            size: 20,
          ),
        ),
        Positioned(
          top: 52,
          right: 30,
          child: Icon(
            Icons.star_rounded,
            color: Colors.white.withValues(alpha: 0.85),
            size: 16,
          ),
        ),
      ],
    );
  }
}
