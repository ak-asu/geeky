import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../analytics/domain/topic_progress.dart';

class ExpertiseRadarChart extends StatelessWidget {
  const ExpertiseRadarChart({super.key, required this.topics});

  final List<TopicProgress> topics;

  @override
  Widget build(BuildContext context) {
    // Take top 6 topics for readability
    final chartTopics = topics.take(6).toList();
    if (chartTopics.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Expertise',
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.gapV16,
        SizedBox(
          height: 240,
          child: RadarChart(
            RadarChartData(
              radarShape: RadarShape.polygon,
              dataSets: [
                RadarDataSet(
                  dataEntries: chartTopics
                      .map((t) => RadarEntry(value: t.mastery * 100))
                      .toList(),
                  fillColor: AppColors.primary.withValues(alpha: 0.15),
                  borderColor: AppColors.primary,
                  borderWidth: 2,
                  entryRadius: 3,
                ),
              ],
              radarBackgroundColor: Colors.transparent,
              borderData: FlBorderData(show: false),
              radarBorderData: BorderSide(
                color: context.colorScheme.outlineVariant,
                width: 0.5,
              ),
              tickBorderData: BorderSide(
                color: context.colorScheme.outlineVariant,
                width: 0.5,
              ),
              gridBorderData: BorderSide(
                color: context.colorScheme.outlineVariant,
                width: 0.5,
              ),
              titlePositionPercentageOffset: 0.2,
              tickCount: 4,
              ticksTextStyle: const TextStyle(fontSize: 0),
              getTitle: (index, _) {
                if (index >= chartTopics.length) {
                  return const RadarChartTitle(text: '');
                }
                final topic = chartTopics[index].topic;
                final label = topic.length > 10
                    ? '${topic.substring(0, 10)}…'
                    : topic;
                return RadarChartTitle(text: label, angle: 0);
              },
              titleTextStyle: context.textTheme.labelSmall!.copyWith(
                color: context.colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
