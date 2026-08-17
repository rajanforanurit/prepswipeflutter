import 'package:prepswipe/Timeline.dart/feed_repository.dart';
import 'package:prepswipe/models/timeline_models.dart';
import '../models/question_model.dart';

class TimelineBuilder {

  static List<TimelineItem> build({

    required TimelineMode mode,

    required List<Question> questions,

    required List<FeedCard> feedCards,

    int questionsBetweenFeeds = 4,

  }) {

    switch(mode){

      case TimelineMode.quizOnly:

        return questions.map(
          (q)=>TimelineItem(
            type: TimelineItemType.question,
            data: q,
          ),
        ).toList();

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
        );

    }

  }

  static List<TimelineItem> _mixedTimeline(

      List<Question> questions,

      List<FeedCard> feeds,

      int spacing,

      ){

    final timeline=<TimelineItem>[];

    int questionCounter=0;

    int feedIndex=0;

    for(final question in questions){

      timeline.add(
        TimelineItem(
          type: TimelineItemType.question,
          data: question,
        ),
      );

      questionCounter++;

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