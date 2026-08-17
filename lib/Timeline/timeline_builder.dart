import 'package:prepswipe/Timeline/feed_repository.dart';
import 'package:prepswipe/models/timeline_models.dart';
import '../models/question_model.dart';

class TimelineBuilder {

  static List<TimelineItem> build({
    required TimelineMode mode,
    required List<Question> questions,
    required List<FeedCard> feedCards,
    int questionsBetweenFeeds = 4,
    bool isPremium = false,
  }) {
    switch(mode){
      case TimelineMode.quizOnly:
        final list = <TimelineItem>[];
        int adCounter = 0;
        for (final q in questions) {
          list.add(TimelineItem(type: TimelineItemType.question, data: q));
          adCounter++;
          if (!isPremium && adCounter >= 5) {
            list.add(const TimelineItem(type: TimelineItemType.ad, data: null));
            adCounter = 0;
          }
        }
        return list;

      case TimelineMode.feedOnly:
        return feedCards.map(
          (f)=>TimelineItem(
            type: TimelineItemType.feed,
            data: f,
          ),
        ).toList();

      case TimelineMode.mixed:
        return _mixedTimeline(
          questions,
          feedCards,
          questionsBetweenFeeds,
          isPremium,
        );
    }
  }

  static List<TimelineItem> _mixedTimeline(
      List<Question> questions,
      List<FeedCard> feeds,
      int spacing,
      bool isPremium,
      ){
    final timeline=<TimelineItem>[];
    int questionCounter=0;
    int feedIndex=0;
    int adCounter=0;

    for(final question in questions){
      timeline.add(
        TimelineItem(
          type: TimelineItemType.question,
          data: question,
        ),
      );

      questionCounter++;
      adCounter++;

      if (!isPremium && adCounter >= 5) {
        timeline.add(
          const TimelineItem(
            type: TimelineItemType.ad,
            data: null,
          ),
        );
        adCounter = 0;
      }

      if(questionCounter>=spacing &&
          feedIndex<feeds.length){
        timeline.add(
          TimelineItem(
            type: TimelineItemType.feed,
            data: feeds[feedIndex],
          ),
        );
        questionCounter=0;
        feedIndex++;
      }
    }

    return timeline;
  }
}