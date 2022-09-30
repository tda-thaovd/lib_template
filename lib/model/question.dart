class QuestionData {
  String? id;
  String? questionLink;
  String? title;
  int? answerTime;
  int? position;

  QuestionData(
    this.id,
    this.questionLink,
    this.title,
    this.answerTime,
    this.position,
  );

  Map toJson() => {
        'id': id,
        'question_link': questionLink,
        'title': title,
        'answer_time': answerTime,
        'position': position,
      };
}
