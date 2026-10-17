import 'dart:math' as math;
import 'level.dart';
import 'scene_evidence.dart';
import 'vision.dart';

// Shared with the drawn subject box: the target must stay visibly inside it.
const subjectGuideWidth = .14, subjectGuideHeight = .13;

enum CompositionKind {
  thirds,
  centered,
  golden,
  symmetry,
  leading,
  negativeSpace,
}

extension CompositionText on CompositionKind {
  String get title => switch (this) {
    CompositionKind.thirds => '三分法',
    CompositionKind.centered => '居中构图',
    CompositionKind.golden => '黄金比例',
    CompositionKind.symmetry => '对称构图',
    CompositionKind.leading => '引导线',
    CompositionKind.negativeSpace => '留白构图',
  };
  String get english => switch (this) {
    CompositionKind.thirds => 'RULE OF THIRDS',
    CompositionKind.centered => 'CENTERED',
    CompositionKind.golden => 'GOLDEN RATIO',
    CompositionKind.symmetry => 'SYMMETRY',
    CompositionKind.leading => 'LEADING LINES',
    CompositionKind.negativeSpace => 'NEGATIVE SPACE',
  };
  String get description => switch (this) {
    CompositionKind.thirds => '把主体放在交点附近，让画面有空间、有呼吸。',
    CompositionKind.centered => '把注意力交给中心，适合明确、独立的主体。',
    CompositionKind.golden => '沿螺旋安排视觉重心，让视线自然落到主体。',
    CompositionKind.symmetry => '让左右结构围绕中轴呼应，形成安静的秩序感。',
    CompositionKind.leading => '让道路、栏杆或建筑线条，把视线带向主体。',
    CompositionKind.negativeSpace => '把更多空间留给环境，让较小的主体更突出。',
  };
}

class CompositionPlan {
  const CompositionPlan(
    this.kind,
    this.score,
    this.target,
    this.horizonTarget,
    this.reason, {
    this.useHorizon = false,
  });
  final CompositionKind kind;
  final double score;
  final Point2 target;
  final double horizonTarget;
  final String reason;
  final bool useHorizon;
  String get evidenceLabel => score >= .65
      ? '依据较强'
      : score >= .4
      ? '可以尝试'
      : '依据较少';
}

class CompositionRecommender {
  const CompositionRecommender();
  List<CompositionPlan> recommend(
    SceneFeatures f, {
    Point2? selectedSubject,
    SceneEvidence? evidence,
  }) {
    final e =
        evidence ??
        SceneEvidence(
          detail: 1,
          subject: f.subject ?? selectedSubject,
          subjectConfidence: f.subjectConfidence,
          symmetry: f.symmetry,
          leading: f.leading,
          vanishingPoint: f.vanishingPoint,
          horizon: f.horizonConfidence,
          horizonY: f.horizonY,
        );
    final p = e.subject ?? selectedSubject ?? const Point2(.5, .5);
    double proximity(Point2 target) =>
        math.exp(-math.pow(p.distanceTo(target) / .22, 2));
    Point2 nearest(double a, double b) {
      final points = [Point2(a, a), Point2(a, b), Point2(b, a), Point2(b, b)];
      points.sort((x, y) => x.distanceTo(p).compareTo(y.distanceTo(p)));
      return points.first;
    }

    final third = nearest(1 / 3, 2 / 3), golden = nearest(.382, .618);
    final horizonTarget = e.horizonY < .5 ? 1 / 3 : 2 / 3;
    final hasSubject = e.subject != null && e.subjectConfidence >= .45;
    final horizonOnly =
        !hasSubject &&
        selectedSubject == null &&
        f.horizonConfidence > .65 &&
        e.horizon > .5;
    final area = e.subjectArea;
    final small = area == null ? 0.0 : ((.20 - area) / .16).clamp(0.0, 1.0);
    final large = area == null ? 0.0 : (area / .20).clamp(0.0, 1.0);
    final focal = hasSubject
        ? e.subjectConfidence * (.45 + .55 * e.isolation)
        : 0.0;
    final emptyLeft = (e.leftSpace - e.rightSpace).abs() < .05
        ? p.x > .5
        : e.leftSpace > e.rightSpace;
    final negativeTarget = Point2(
      emptyLeft ? 2 / 3 : 1 / 3,
      p.y < .5 ? 1 / 3 : 2 / 3,
    );
    final empty = math.max(e.leftSpace, e.rightSpace);
    final centeredTarget = const Point2(.5, .5);
    final symmetryTarget = Point2(.5, p.y);
    final thirdsScore =
        (.55 * e.horizon + .45 * focal * e.environment * (1 - large * .55)) *
        (.75 + .25 * proximity(third));
    final centeredScore =
        focal *
        (.45 * large + .3 * e.isolation + .25 * proximity(centeredTarget)) *
        (1 - .25 * e.goldenBalance);
    final goldenScore = hasSubject
        ? e.subjectConfidence *
              (.6 * e.goldenBalance +
                  .15 * e.environment +
                  .25 * proximity(golden)) *
              (.4 + .6 * (1 - large))
        : 0.0;
    final symmetryScore = e.symmetry * (.8 + .2 * proximity(symmetryTarget));
    final leadingScore = e.leading * (.85 + .15 * proximity(e.vanishingPoint));
    final negativeScore = hasSubject
        ? e.subjectConfidence *
              small *
              (.8 * empty + .2 * proximity(negativeTarget))
        : 0.0;
    final plans = <CompositionPlan>[
      CompositionPlan(
        CompositionKind.thirds,
        thirdsScore.clamp(0.0, 1.0),
        third,
        horizonTarget,
        e.horizon > .5
            ? '画面有清晰的横向分界，放在三分线上更均衡。'
            : thirdsScore >= .4
            ? '主体和背景都有看点，放在交点附近能保留环境。'
            : '可以把主体放在交点附近，试试保留更多环境。',
        useHorizon: horizonOnly,
      ),
      CompositionPlan(
        CompositionKind.centered,
        centeredScore.clamp(0.0, 1.0),
        centeredTarget,
        .5,
        centeredScore >= .4 ? '主体较突出，放在画面中央能集中注意力。' : '可以先把主体放在中央，试拍一张。',
      ),
      CompositionPlan(
        CompositionKind.golden,
        goldenScore.clamp(0.0, 1.0),
        golden,
        horizonTarget,
        goldenScore >= .4 ? '另一侧的环境也有看点，主体稍偏一侧能兼顾两边。' : '可以把主体稍偏一侧，试试画面是否更平衡。',
      ),
      CompositionPlan(
        CompositionKind.symmetry,
        symmetryScore.clamp(0.0, 1.0),
        symmetryTarget,
        horizonTarget,
        symmetryScore >= .4 ? '左右两侧相似，沿中线对齐能突出对称感。' : '左右两侧差异较大，建议先试其他构图。',
      ),
      CompositionPlan(
        CompositionKind.leading,
        leadingScore.clamp(0.0, 1.0),
        e.vanishingPoint,
        horizonTarget,
        leadingScore >= .4 ? '两侧线条向同一处汇合，让主体靠近汇合处更醒目。' : '指向主体的线条不明显，建议先试其他构图。',
      ),
      CompositionPlan(
        CompositionKind.negativeSpace,
        negativeScore.clamp(0.0, 1.0),
        negativeTarget,
        horizonTarget,
        negativeScore >= .4
            ? '${emptyLeft ? '左' : '右'}侧较空，让主体留在${emptyLeft ? '右' : '左'}侧更突出。'
            : area == null
            ? '请点选清晰的主体，再试留白构图。'
            : '空白较少，退后一点或换个角度再试。',
      ),
    ];
    plans.sort((a, b) {
      final order = b.score.compareTo(a.score);
      if (order != 0) return order;
      // Explicit, neutral fallback for no evidence; never portray it as optimum.
      if (a.kind == CompositionKind.centered) return -1;
      if (b.kind == CompositionKind.centered) return 1;
      return a.kind.index.compareTo(b.kind.index);
    });
    return plans;
  }
}

class AlignmentResult {
  const AlignmentResult(
    this.ready,
    this.progress,
    this.accuracy,
    this.message,
    this.valid, {
    this.advice,
  });
  final bool ready, valid;
  final double progress, accuracy;
  final String message;
  final String? advice;
}

/// Staying inside the visible subject box for one second decides readiness.
/// Small hand movements inside it are stable; loss, gaps and strong shaking
/// still reset the hold. Aesthetic measurements remain optional advice.
class AlignmentTracker {
  DateTime? _since, _last;
  void reset() {
    _since = null;
    _last = null;
  }

  AlignmentResult update(
    CompositionPlan plan,
    SceneFeatures features,
    DateTime now, {
    LevelReading level = const LevelReading(available: false),
    SceneEvidence? evidence,
  }) {
    if (_last != null && now.difference(_last!).inMilliseconds > 600) {
      _since = null;
    }
    _last = now;
    final p = features.subject;
    final valid = plan.useHorizon
        ? features.horizonConfidence > .65
        : p != null && features.subjectConfidence >= .45;
    if (!valid) {
      _since = null;
      return const AlignmentResult(false, 0, 0, '重新点一下主体', false);
    }
    final dx = plan.useHorizon ? 0.0 : plan.target.x - p!.x;
    final dy = plan.useHorizon
        ? plan.horizonTarget - features.horizonY
        : plan.target.y - p!.y;
    final error = math.sqrt(math.pow(dx * .75, 2) + dy * dy);
    final close = plan.useHorizon
        ? dy.abs() <= .038
        : dx.abs() <= subjectGuideWidth / 2 + 1e-9 &&
              dy.abs() <= subjectGuideHeight / 2 + 1e-9;
    final accuracy = (1 - error / .35).clamp(0.0, 1.0).toDouble();
    if (!close || level.blocksAlignment) {
      _since = null;
      String message;
      if (level.blocksAlignment && close) {
        message = '请稳住手机';
      } else if (dx.abs() / subjectGuideWidth > dy.abs() / subjectGuideHeight) {
        message = dx > 0 ? '手机稍向左，让白框靠近绿圈' : '手机稍向右，让白框靠近绿圈';
      } else {
        final target = plan.useHorizon ? '让横向分界靠近虚线' : '让白框靠近绿圈';
        message = dy > 0 ? '手机稍向上，$target' : '手机稍向下，$target';
      }
      return AlignmentResult(false, 0, accuracy, message, true);
    }
    final advice = switch (plan.kind) {
      CompositionKind.symmetry when features.symmetry < .6 =>
        '也可以调整角度，让左右两侧更对称',
      CompositionKind.leading when features.leading < .4 => '也可以让更多线条指向主体',
      CompositionKind.negativeSpace when features.subjectArea > .18 =>
        '也可以退后一点，给主体周围留出空间',
      CompositionKind.negativeSpace
          when evidence != null &&
              (evidence.subjectArea == null ||
                  math.max(evidence.leftSpace, evidence.rightSpace) < .55) =>
        '也可以换个角度，让主体一侧留出更多空白',
      _ when level.needsLeveling => '也可以轻转手机，让画面更水平',
      _ => null,
    };
    _since ??= now;
    final progress = (now.difference(_since!).inMilliseconds / 1000).clamp(
      0.0,
      1.0,
    );
    return AlignmentResult(
      progress >= 1,
      progress,
      accuracy,
      progress >= 1
          ? '可以拍照了'
          : plan.useHorizon
          ? '已对齐，保持稳定…'
          : '已对齐，保持在框内…',
      true,
      advice: advice,
    );
  }
}
