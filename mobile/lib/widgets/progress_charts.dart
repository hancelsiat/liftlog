import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/progress.dart';
import 'gym/gym.dart';

/// One plotted value and the date it was logged.
class ChartPoint {
  const ChartPoint(this.date, this.value);

  final DateTime date;
  final double value;
}

/// Pulls one metric out of [history] (any order) and returns it oldest first.
List<ChartPoint> chartPoints(
  List<Progress> history,
  double? Function(Progress p) pick,
) {
  final points = <ChartPoint>[
    for (final p in history)
      if (pick(p) case final v?) ChartPoint(p.date, v),
  ];
  points.sort((a, b) => a.date.compareTo(b.date));
  return points;
}

/// Which direction of change counts as progress for a metric.
enum TrendGood { up, down, neutral }

// ---------------------------------------------------------------------------
// Formatting
// ---------------------------------------------------------------------------

final NumberFormat _grouped = NumberFormat.decimalPattern();
final DateFormat _shortDate = DateFormat('d MMM');
final DateFormat _longDate = DateFormat('EEE d MMM, HH:mm');

String _whole(double v) => _grouped.format(v.round());

String _oneDecimal(double v) => v.toStringAsFixed(1);

String _short(DateTime d) => _shortDate.format(d).toUpperCase();

/// Signed value with a real minus sign: +0.4 / −120.
String _signed(double v, String Function(double) format) {
  if (v > 0) return '+${format(v)}';
  if (v < 0) return '\u2212${format(-v)}';
  return format(0);
}

/// Compact axis label: 1500 -> 1.5K, 24.0 -> 24, 24.5 -> 24.5.
String _axis(double v) {
  if (v.abs() >= 1000) {
    final k = v / 1000;
    return k == k.roundToDouble()
        ? '${k.toInt()}K'
        : '${k.toStringAsFixed(1)}K';
  }
  final r = double.parse(v.toStringAsFixed(1));
  return r == r.roundToDouble() ? r.toInt().toString() : r.toStringAsFixed(1);
}

double _average(List<ChartPoint> pts) =>
    pts.fold<double>(0, (sum, p) => sum + p.value) / pts.length;

// ---------------------------------------------------------------------------
// Scale: padded min/max on a "nice" step, so data never touches the frame.
// ---------------------------------------------------------------------------

class _Scale {
  const _Scale(this.min, this.max, this.step);

  final double min;
  final double max;
  final double step;

  factory _Scale.of(Iterable<double> values, {bool includeZero = false}) {
    var lo = values.reduce(math.min);
    var hi = values.reduce(math.max);
    if (includeZero) {
      lo = math.min(lo, 0);
      hi = math.max(hi, 0);
    }

    var span = hi - lo;
    if (span == 0) span = hi == 0 ? 1 : hi.abs() * 0.2;
    final step = _niceStep(span / 3);

    var min = (lo / step).floor() * step;
    var max = (hi / step).ceil() * step;
    // Keep at least a quarter step of air above and below the data,
    // except when the floor is a meaningful zero.
    if (max - hi < step * 0.25) max += step;
    final zeroFloor = includeZero && min == 0;
    if (!zeroFloor && lo - min < step * 0.25) min -= step;
    return _Scale(min, max, step);
  }

  bool isFloor(double v) => (v - min).abs() < step * 0.01;

  static double _niceStep(double raw) {
    final exp = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final f = raw / exp;
    final double nice;
    if (f <= 1) {
      nice = 1;
    } else if (f <= 2) {
      nice = 2;
    } else if (f <= 2.5) {
      nice = 2.5;
    } else if (f <= 5) {
      nice = 5;
    } else {
      nice = 10;
    }
    return nice * exp;
  }
}

// ---------------------------------------------------------------------------
// Shared chart pieces
// ---------------------------------------------------------------------------

const double _chartHeight = 176;

/// Dashed hairline grid with a solid floor.
FlGridData _grid(_Scale s) => FlGridData(
  show: true,
  drawVerticalLine: false,
  horizontalInterval: s.step,
  getDrawingHorizontalLine: (v) => FlLine(
    color: AuthColors.line,
    strokeWidth: 1,
    dashArray: s.isFloor(v) ? null : const [2, 4],
  ),
);

const AxisTitles _hidden = AxisTitles(
  sideTitles: SideTitles(showTitles: false),
);

AxisTitles _valueTitles(_Scale s) => AxisTitles(
  sideTitles: SideTitles(
    showTitles: true,
    reservedSize: 34,
    interval: s.step,
    getTitlesWidget: (v, meta) {
      // The floor label would sit on top of the date labels.
      if (s.isFloor(v) || v > s.max) return const SizedBox.shrink();
      return SideTitleWidget(
        axisSide: meta.axisSide,
        space: 6,
        child: Text(
          _axis(v),
          style: AuthType.mono(color: AuthColors.textFaint),
        ),
      );
    },
  ),
);

/// Date labels on an index axis: first, last and (for longer series) the
/// middle point. Labels that repeat one already shown are skipped.
AxisTitles _dateTitles(List<ChartPoint> pts) {
  final n = pts.length;
  final wanted = <int>{0, if (n >= 5) (n - 1) ~/ 2, n - 1}.toList()..sort();
  final shown = <int, String>{};
  final seen = <String>{};
  for (final i in wanted) {
    final label = _short(pts[i].date);
    if (seen.add(label)) shown[i] = label;
  }

  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 26,
      interval: 1,
      getTitlesWidget: (value, meta) {
        if (value != value.roundToDouble()) return const SizedBox.shrink();
        final label = shown[value.toInt()];
        if (label == null) return const SizedBox.shrink();
        return SideTitleWidget(
          axisSide: meta.axisSide,
          space: 8,
          fitInside: SideTitleFitInsideData.fromTitleMeta(
            meta,
            distanceFromEdge: 0,
          ),
          child: Text(label, style: AuthType.mono(color: AuthColors.textFaint)),
        );
      },
    ),
  );
}

TextStyle get _tooltipValue =>
    AuthType.display(20).copyWith(color: AuthColors.textPrimary, height: 1);

List<TextSpan> _tooltipFooter(String unit, DateTime date) => [
  TextSpan(
    text: ' $unit\n',
    style: AuthType.mono(color: AuthColors.textMuted),
  ),
  TextSpan(
    text: _longDate.format(date).toUpperCase(),
    style: AuthType.mono(color: AuthColors.textFaint),
  ),
];

/// Touch styling for the line and step charts. Spots at index >= the number
/// of points are decorative (the step chart's tail) and get no tooltip, and
/// zero-width series (fill-only layers) are ignored.
LineTouchData _lineTouch({
  required List<ChartPoint> pts,
  required Color color,
  required String Function(double) format,
  required String unit,
}) {
  bool skip(LineChartBarData bar, int i) =>
      bar.barWidth == 0 || i >= pts.length;

  return LineTouchData(
    getTouchedSpotIndicator: (bar, indexes) => [
      for (final i in indexes)
        skip(bar, i)
            ? null
            : TouchedSpotIndicatorData(
                FlLine(
                  color: color.withValues(alpha: 0.5),
                  strokeWidth: 1,
                  dashArray: const [3, 3],
                ),
                FlDotData(
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                        radius: 6,
                        color: color,
                        strokeWidth: 3,
                        strokeColor: AuthColors.surface,
                      ),
                ),
              ),
    ],
    touchTooltipData: LineTouchTooltipData(
      tooltipBgColor: AuthColors.surfaceHi,
      tooltipRoundedRadius: AuthRadius.thumb,
      tooltipBorder: const BorderSide(color: AuthColors.line),
      tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      maxContentWidth: 170,
      fitInsideHorizontally: true,
      fitInsideVertically: true,
      getTooltipItems: (spots) => [
        for (final s in spots)
          skip(s.bar, s.spotIndex)
              ? null
              : LineTooltipItem(
                  format(s.y),
                  _tooltipValue,
                  textAlign: TextAlign.left,
                  children: _tooltipFooter(unit, pts[s.spotIndex].date),
                ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Card shell
// ---------------------------------------------------------------------------

/// Change since the previous entry, coloured by whether it is progress.
class _DeltaTag extends StatelessWidget {
  const _DeltaTag({
    required this.delta,
    required this.format,
    required this.good,
  });

  final double delta;
  final String Function(double) format;
  final TrendGood good;

  @override
  Widget build(BuildContext context) {
    final flat = format(delta.abs()) == format(0);
    final Color color;
    if (flat || good == TrendGood.neutral) {
      color = AuthColors.textMuted;
    } else {
      final improving = (delta < 0) == (good == TrendGood.down);
      color = improving ? AuthColors.accent : AuthColors.danger;
    }
    final IconData icon;
    if (flat) {
      icon = Icons.remove;
    } else {
      icon = delta > 0 ? Icons.north_east : Icons.south_east;
    }
    return GymTag(
      label: flat ? 'No change' : _signed(delta, format),
      color: color,
      icon: icon,
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value);

  final String label;
  final String value;
}

List<_Stat> _lowAvgHigh(List<ChartPoint> pts, String Function(double) format) =>
    [
      _Stat('LOW', format(pts.map((p) => p.value).reduce(math.min))),
      _Stat('AVG', format(_average(pts))),
      _Stat('HIGH', format(pts.map((p) => p.value).reduce(math.max))),
    ];

/// Low / avg / high strip under the plot.
class _StatRow extends StatelessWidget {
  const _StatRow(this.stats);

  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    CrossAxisAlignment align(int i) {
      if (i == 0) return CrossAxisAlignment.start;
      if (i == stats.length - 1) return CrossAxisAlignment.end;
      return CrossAxisAlignment.center;
    }

    return Row(
      children: [
        for (var i = 0; i < stats.length; i++)
          Expanded(
            child: Column(
              crossAxisAlignment: align(i),
              children: [
                Text(
                  stats[i].label,
                  style: AuthType.mono(color: AuthColors.textFaint),
                ),
                const SizedBox(height: 4),
                Text(
                  stats[i].value,
                  style: AuthType.display(
                    20,
                  ).copyWith(height: 1, letterSpacing: 0),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Placeholder plot: a faint dashed baseline under a short hint.
class _EmptyPlot extends StatelessWidget {
  const _EmptyPlot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'NOTHING TO PLOT YET',
            style: AuthType.mono(color: AuthColors.textFaint),
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(
              40,
              (i) => Expanded(
                child: Container(
                  height: 1,
                  color: i.isEven ? AuthColors.line : Colors.transparent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.index,
    required this.title,
    required this.kind,
    required this.unit,
    required this.points,
    required this.format,
    required this.good,
    required this.emptyHint,
    required this.chartBuilder,
    this.badge,
    this.caption,
    this.stats = const [],
  });

  final int index;
  final String title;

  /// Chart type shown next to the title, e.g. `WEEKLY · LINE`.
  final String kind;
  final String unit;
  final List<ChartPoint> points;
  final String Function(double) format;
  final TrendGood good;
  final String emptyHint;
  final WidgetBuilder chartBuilder;
  final Widget? badge;
  final String? caption;
  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    final latest = points.isEmpty ? null : points.last;
    final delta = points.length < 2
        ? null
        : points.last.value - points[points.length - 2].value;
    final count = points.length;
    final subline = latest == null
        ? emptyHint
        : caption ??
              'Last logged ${_short(latest.date)} · '
                  '$count ${count == 1 ? 'entry' : 'entries'}';

    return Semantics(
      container: true,
      label: latest == null
          ? '$title: no entries yet'
          : '$title: latest ${format(latest.value)} $unit, '
                'logged ${_short(latest.date)}',
      child: PressableSurface(
        padding: const EdgeInsets.fromLTRB(
          AuthSpace.s,
          AuthSpace.s,
          AuthSpace.s,
          14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 01  BMI ················ WEEKLY · LINE
            Row(
              children: [
                Text(
                  index.toString().padLeft(2, '0'),
                  style: AuthType.mono(color: AuthColors.accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuthType.label(color: AuthColors.textPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                Text(kind, style: AuthType.mono(color: AuthColors.textFaint)),
              ],
            ),
            const SizedBox(height: 14),

            // Latest value, unit, and change since the previous entry.
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Value + unit shrink before they can collide with the tags.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          latest == null ? '\u2014' : format(latest.value),
                          style: AuthType.display(44).copyWith(height: 0.9),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            unit.toUpperCase(),
                            style: AuthType.mono(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    children: [
                      if (badge != null) badge!,
                      if (delta != null)
                        _DeltaTag(delta: delta, format: format, good: good),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subline,
              style: AuthType.body(size: 12, color: AuthColors.textFaint),
            ),
            const SizedBox(height: AuthSpace.s),

            if (latest == null)
              const _EmptyPlot()
            else
              SizedBox(
                height: _chartHeight,
                child: WipeReveal(child: Builder(builder: chartBuilder)),
              ),

            if (latest != null && stats.isNotEmpty) ...[
              const SizedBox(height: 12),
              const SizedBox(
                height: 1,
                child: ColoredBox(color: AuthColors.line),
              ),
              const SizedBox(height: 12),
              _StatRow(stats),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 01 BMI: curved line over WHO category bands
// ---------------------------------------------------------------------------

class _BmiBand {
  const _BmiBand(this.label, this.from, this.to, this.color);

  final String label;
  final double from;
  final double to;
  final Color color;
}

const List<_BmiBand> _bmiBands = [
  _BmiBand('Under', 0, 18.5, AuthColors.textMuted),
  _BmiBand('Healthy', 18.5, 25, AuthColors.accent),
  _BmiBand('Over', 25, 30, GymColors.warn),
  _BmiBand('Obese', 30, 100, AuthColors.danger),
];

_BmiBand _bandFor(double bmi) =>
    _bmiBands.firstWhere((b) => bmi < b.to, orElse: () => _bmiBands.last);

/// Moving toward the healthy band is progress; inside it, neither is.
TrendGood _bmiGood(double latest) {
  if (latest >= 25) return TrendGood.down;
  if (latest < 18.5) return TrendGood.up;
  return TrendGood.neutral;
}

Widget _bmiChart(List<ChartPoint> pts) {
  final s = _Scale.of(pts.map((p) => p.value));
  final last = pts.length - 1;
  final single = pts.length == 1;

  return LineChart(
    duration: Duration.zero,
    LineChartData(
      minX: single ? -0.5 : 0,
      maxX: single ? 0.5 : last.toDouble(),
      minY: s.min,
      maxY: s.max,
      gridData: _grid(s),
      borderData: FlBorderData(show: false),
      rangeAnnotations: RangeAnnotations(
        horizontalRangeAnnotations: [
          for (final b in _bmiBands)
            if (b.to > s.min && b.from < s.max)
              HorizontalRangeAnnotation(
                y1: math.max(b.from, s.min),
                y2: math.min(b.to, s.max),
                color: b.color.withValues(alpha: 0.05),
              ),
        ],
      ),
      extraLinesData: ExtraLinesData(
        extraLinesOnTop: false,
        horizontalLines: [
          // Edges of the healthy band, labelled at the right.
          for (final y in const [18.5, 25.0])
            if (y > s.min && y < s.max)
              HorizontalLine(
                y: y,
                color: AuthColors.accent.withValues(alpha: 0.25),
                strokeWidth: 1,
                dashArray: const [4, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 2, bottom: 2),
                  style: AuthType.mono(
                    color: AuthColors.accent.withValues(alpha: 0.6),
                  ),
                  labelResolver: (l) => l.y.toString(),
                ),
              ),
        ],
      ),
      titlesData: FlTitlesData(
        topTitles: _hidden,
        rightTitles: _hidden,
        leftTitles: _valueTitles(s),
        bottomTitles: _dateTitles(pts),
      ),
      lineTouchData: _lineTouch(
        pts: pts,
        color: AuthColors.accent,
        format: _oneDecimal,
        unit: 'BMI',
      ),
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var i = 0; i < pts.length; i++)
              FlSpot(i.toDouble(), pts[i].value),
          ],
          isCurved: true,
          curveSmoothness: 0.3,
          preventCurveOverShooting: true,
          color: AuthColors.accent,
          barWidth: 2.5,
          isStrokeCapRound: true,
          shadow: Shadow(
            color: AuthColors.accent.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AuthColors.accent.withValues(alpha: 0.22),
                AuthColors.accent.withValues(alpha: 0),
              ],
            ),
          ),
          // Small hollow ticks on history, a haloed dot on the latest entry.
          dotData: FlDotData(
            getDotPainter: (spot, percent, bar, index) => index == last
                ? FlDotCirclePainter(
                    radius: 5,
                    color: AuthColors.accent,
                    strokeWidth: 4,
                    strokeColor: AuthColors.accent.withValues(alpha: 0.25),
                  )
                : FlDotCirclePainter(
                    radius: 2.5,
                    color: AuthColors.surface,
                    strokeWidth: 1.5,
                    strokeColor: AuthColors.accent.withValues(alpha: 0.7),
                  ),
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// 02 Calories intake: one bar per entry, latest highlighted, average line
// ---------------------------------------------------------------------------

/// Bars stay readable on a phone up to about two weeks.
const int _maxBars = 14;

Widget _caloriesChart(List<ChartPoint> all) {
  final pts = all.length > _maxBars ? all.sublist(all.length - _maxBars) : all;
  final s = _Scale.of(pts.map((p) => p.value), includeZero: true);
  final avg = _average(pts);
  final last = pts.length - 1;

  return LayoutBuilder(
    builder: (context, box) {
      // Slot width minus a gap; clamp so 1 bar is not a slab and 14 still fit.
      final slot = (box.maxWidth - 34) / pts.length;
      final width = (slot * 0.56).clamp(4.0, 22.0);

      return BarChart(
        swapAnimationDuration: Duration.zero,
        BarChartData(
          minY: s.min,
          maxY: s.max,
          alignment: BarChartAlignment.spaceAround,
          gridData: _grid(s),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (pts.length > 1)
                HorizontalLine(
                  y: avg,
                  color: AuthColors.textMuted.withValues(alpha: 0.7),
                  strokeWidth: 1,
                  dashArray: const [4, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    padding: const EdgeInsets.only(right: 2, bottom: 3),
                    style: AuthType.mono(color: AuthColors.textMuted),
                    labelResolver: (_) => 'AVG ${_axis(avg)}',
                  ),
                ),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: _hidden,
            rightTitles: _hidden,
            leftTitles: _valueTitles(s),
            bottomTitles: _dateTitles(pts),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: AuthColors.surfaceHi,
              tooltipRoundedRadius: AuthRadius.thumb,
              tooltipBorder: const BorderSide(color: AuthColors.line),
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              maxContentWidth: 170,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                  BarTooltipItem(
                    _whole(rod.toY),
                    _tooltipValue,
                    textAlign: TextAlign.left,
                    children: _tooltipFooter('kcal', pts[group.x].date),
                  ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < pts.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: pts[i].value,
                    width: width,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: i == last
                          ? const [AuthColors.accent, AuthColors.accent]
                          : [
                              AuthColors.textMuted.withValues(alpha: 0.55),
                              AuthColors.textMuted.withValues(alpha: 0.2),
                            ],
                    ),
                    // Faint full-height track behind each bar.
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      fromY: s.min,
                      toY: s.max,
                      color: AuthColors.line.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// 03 Calorie deficit: step line (value holds until the next update),
//    deficit filled in accent above zero, surplus in danger below.
// ---------------------------------------------------------------------------

Color _deficitColor(double v) => v < 0 ? AuthColors.danger : AuthColors.accent;

Widget _deficitChart(List<ChartPoint> pts) {
  final s = _Scale.of(pts.map((p) => p.value), includeZero: true);
  final last = pts.length - 1;
  // Extend the final step half a slot so the current value reads as a level.
  final tailX = last + 0.5;
  const step = LineChartStepData(
    stepDirection: LineChartStepData.stepDirectionForward,
  );

  List<FlSpot> spots(double Function(double v) map) => [
    for (var i = 0; i < pts.length; i++)
      FlSpot(i.toDouble(), map(pts[i].value)),
    FlSpot(tailX, map(pts[last].value)),
  ];

  // Fill-only series: zero-width stroke, area clipped at y = 0.
  LineChartBarData fill(double Function(double) map, Color c, bool above) {
    final area = BarAreaData(
      show: true,
      applyCutOffY: true,
      cutOffY: 0,
      gradient: LinearGradient(
        begin: above ? Alignment.topCenter : Alignment.bottomCenter,
        end: above ? Alignment.bottomCenter : Alignment.topCenter,
        colors: [c.withValues(alpha: 0.28), c.withValues(alpha: 0.04)],
      ),
    );
    return LineChartBarData(
      spots: spots(map),
      isStepLineChart: true,
      lineChartStepData: step,
      barWidth: 0,
      color: Colors.transparent,
      dotData: const FlDotData(show: false),
      belowBarData: above ? area : BarAreaData(show: false),
      aboveBarData: above ? BarAreaData(show: false) : area,
    );
  }

  return LineChart(
    duration: Duration.zero,
    LineChartData(
      minX: pts.length == 1 ? -0.5 : 0,
      maxX: tailX,
      minY: s.min,
      maxY: s.max,
      gridData: _grid(s),
      borderData: FlBorderData(show: false),
      extraLinesData: ExtraLinesData(
        extraLinesOnTop: false,
        horizontalLines: [
          // Break-even baseline.
          HorizontalLine(
            y: 0,
            color: AuthColors.textMuted.withValues(alpha: 0.6),
            strokeWidth: 1,
          ),
        ],
      ),
      titlesData: FlTitlesData(
        topTitles: _hidden,
        rightTitles: _hidden,
        leftTitles: _valueTitles(s),
        bottomTitles: _dateTitles(pts),
      ),
      // The fill layers have zero width, so only the step line answers.
      lineTouchData: _lineTouch(
        pts: pts,
        color: AuthColors.textPrimary,
        format: (v) => _signed(v, _whole),
        unit: 'kcal',
      ),
      lineBarsData: [
        fill((v) => math.max(v, 0), AuthColors.accent, true),
        fill((v) => math.min(v, 0), AuthColors.danger, false),
        LineChartBarData(
          spots: spots((v) => v),
          isStepLineChart: true,
          lineChartStepData: step,
          color: AuthColors.textPrimary,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: FlDotData(
            checkToShowDot: (spot, bar) => spot.x <= last,
            getDotPainter: (spot, percent, bar, index) {
              final c = _deficitColor(spot.y);
              return index == last
                  ? FlDotCirclePainter(
                      radius: 5,
                      color: c,
                      strokeWidth: 4,
                      strokeColor: c.withValues(alpha: 0.25),
                    )
                  : FlDotSquarePainter(
                      size: 5,
                      color: AuthColors.surface,
                      strokeWidth: 1.5,
                      strokeColor: c,
                    );
            },
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

/// The three progress charts (BMI line, calories bars, deficit steps),
/// built from the raw history in any order.
class ProgressCharts extends StatelessWidget {
  const ProgressCharts({super.key, required this.history});

  final List<Progress> history;

  @override
  Widget build(BuildContext context) {
    final bmi = chartPoints(history, (p) => p.bmi);
    final intake = chartPoints(history, (p) => p.caloriesIntake);
    final deficit = chartPoints(history, (p) => p.calorieDeficit);

    final cards = <Widget>[
      _bmiCard(bmi),
      _intakeCard(intake),
      _deficitCard(deficit),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cards.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == cards.length - 1 ? 0 : 12),
            child: StaggeredReveal(index: i, child: cards[i]),
          ),
      ],
    );
  }

  Widget _bmiCard(List<ChartPoint> pts) {
    final band = pts.isEmpty ? null : _bandFor(pts.last.value);
    return _ChartCard(
      index: 1,
      title: 'BMI',
      kind: 'WEEKLY · LINE',
      unit: 'BMI',
      points: pts,
      format: _oneDecimal,
      good: pts.isEmpty ? TrendGood.neutral : _bmiGood(pts.last.value),
      emptyHint: 'Log your BMI above to start the trend line.',
      badge: band == null ? null : GymTag(label: band.label, color: band.color),
      stats: pts.isEmpty ? const [] : _lowAvgHigh(pts, _oneDecimal),
      chartBuilder: (_) => _bmiChart(pts),
    );
  }

  Widget _intakeCard(List<ChartPoint> pts) {
    final shown = math.min(pts.length, _maxBars);
    return _ChartCard(
      index: 2,
      title: 'Calories Intake',
      kind: 'DAILY · BARS',
      unit: 'kcal',
      points: pts,
      format: _whole,
      good: TrendGood.neutral,
      emptyHint: 'Log a day of calories above to see your bars.',
      caption: pts.length > _maxBars
          ? 'Last $shown of ${pts.length} entries · dashed line is the average'
          : null,
      stats: pts.isEmpty
          ? const []
          : _lowAvgHigh(pts.sublist(pts.length - shown), _whole),
      chartBuilder: (_) => _caloriesChart(pts),
    );
  }

  Widget _deficitCard(List<ChartPoint> pts) {
    final inDeficit = pts.where((p) => p.value > 0).length;
    final latest = pts.isEmpty ? null : pts.last.value;
    return _ChartCard(
      index: 3,
      title: 'Calorie Deficit',
      kind: 'DAILY · STEP',
      unit: 'kcal',
      points: pts,
      format: _whole,
      good: TrendGood.up,
      emptyHint: 'Log your deficit above to track it against break-even.',
      badge: latest == null
          ? null
          : GymTag(
              label: latest < 0 ? 'Surplus' : 'Deficit',
              color: _deficitColor(latest),
            ),
      caption: latest == null
          ? null
          : 'Above the line is a deficit, below is a surplus',
      stats: pts.isEmpty
          ? const []
          : [
              _Stat('AVG', _signed(_average(pts), _whole)),
              _Stat('IN DEFICIT', '$inDeficit/${pts.length}'),
              _Stat(
                'BEST',
                _signed(pts.map((p) => p.value).reduce(math.max), _whole),
              ),
            ],
      chartBuilder: (_) => _deficitChart(pts),
    );
  }
}
