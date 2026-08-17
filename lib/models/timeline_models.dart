enum TimelineMode {
  quizOnly,
  feedOnly,
  mixed,
}

enum TimelineItemType {
  question,
  feed,
  ad,
}

class TimelineItem {

  final TimelineItemType type;

  final dynamic data;

  const TimelineItem({
    required this.type,
    required this.data,
  });

}