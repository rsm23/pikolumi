import 'dart:math' as math;

import 'package:flutter/material.dart';

List<List<Offset>> tracePoints(List<dynamic> rawStrokes) => rawStrokes.map((
  raw,
) {
  final vertices = (raw as List)
      .map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
      .toList();
  final points = <Offset>[];
  for (var i = 0; i < vertices.length - 1; i++) {
    final count = math.max(
      1,
      ((vertices[i + 1] - vertices[i]).distance / 5).ceil(),
    );
    for (var j = 0; j < count; j++) {
      points.add(Offset.lerp(vertices[i], vertices[i + 1], j / count)!);
    }
  }
  return points..add(vertices.last);
}).toList();

class TraceViewport {
  final Size size;
  TraceViewport(this.size);
  double get scale => math.min(size.width, size.height) / 220;
  Offset get origin =>
      Offset((size.width - 220 * scale) / 2, (size.height - 220 * scale) / 2);
  Offset logical(Offset physical) => (physical - origin) / scale;
  Offset physical(Offset logical) => origin + logical * scale;
}

class TraceCheckpoint {
  final int stroke, at;
  final Map<String, dynamic>? previous;
  const TraceCheckpoint(this.stroke, this.at, [this.previous]);

  static double distance(List<Offset> path, [int? until]) {
    var length = 0.0;
    final end = until ?? path.length - 1;
    for (var i = 1; i <= end; i++) {
      length += (path[i] - path[i - 1]).distance;
    }
    return length;
  }

  static TraceCheckpoint restore(
    Map<String, dynamic> config,
    List<List<Offset>> strokes,
    Map<String, dynamic>? saved,
  ) {
    if (saved == null) return const TraceCheckpoint(0, 0);
    final revision = config['traceRevision'] ?? 1;
    if (revision == (saved['traceRevision'] ?? 1) ||
        config['legacyStrokes'] == null) {
      final stroke = ((saved['stroke'] ?? 0) as int).clamp(
        0,
        strokes.length - 1,
      );
      final at = ((saved['at'] ?? 0) as int).clamp(
        0,
        strokes[stroke].length - 1,
      );
      return TraceCheckpoint(
        stroke,
        at,
        saved['traceMigration'] as Map<String, dynamic>?,
      );
    }
    final previousRevision = (saved['traceRevision'] ?? 1).toString();
    final previousVersions = config['previousTraceRevisions'] as Map?;
    final old = tracePoints(
      (previousVersions?[previousRevision] ?? config['legacyStrokes']) as List,
    );
    var sameGeometry = old.length == strokes.length;
    if (sameGeometry) {
      for (var i = 0; i < old.length && sameGeometry; i++) {
        sameGeometry = old[i].length == strokes[i].length;
        if (sameGeometry) {
          for (var j = 0; j < old[i].length; j++) {
            if (old[i][j] != strokes[i][j]) {
              sameGeometry = false;
              break;
            }
          }
        }
      }
    }
    if (sameGeometry) {
      final stroke = ((saved['stroke'] ?? 0) as int).clamp(
        0,
        strokes.length - 1,
      );
      return TraceCheckpoint(
        stroke,
        ((saved['at'] ?? 0) as int).clamp(0, strokes[stroke].length - 1),
        saved['traceMigration'] as Map<String, dynamic>?,
      );
    }
    final oldStroke = ((saved['stroke'] ?? 0) as int).clamp(0, old.length - 1);
    final oldAt = ((saved['at'] ?? 0) as int).clamp(
      0,
      old[oldStroke].length - 1,
    );
    // Preserve overall path progress when the corrected guide has different pen lifts.
    double weight(List<Offset> path) => math.max(12, distance(path));
    final previousTotal = old.fold(0.0, (sum, path) => sum + weight(path));
    var previousDone = old
        .take(oldStroke)
        .fold(0.0, (sum, path) => sum + weight(path));
    previousDone +=
        weight(old[oldStroke]) * oldAt / math.max(1, old[oldStroke].length - 1);
    var target =
        (previousDone / previousTotal).clamp(0.0, 1.0) *
        strokes.fold(0.0, (sum, path) => sum + weight(path));
    var stroke = 0;
    while (stroke < strokes.length - 1 && target >= weight(strokes[stroke])) {
      target -= weight(strokes[stroke++]);
    }
    final at = (target / weight(strokes[stroke]) * (strokes[stroke].length - 1))
        .round()
        .clamp(0, strokes[stroke].length - 1);
    return TraceCheckpoint(stroke, at, {
      'fromRevision': saved['traceRevision'] ?? 1,
      'stroke': saved['stroke'] ?? 0,
      'at': saved['at'] ?? 0,
      if (saved['traceMigration'] != null)
        'previousMigration': saved['traceMigration'],
    });
  }
}
