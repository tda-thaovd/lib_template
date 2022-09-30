class VideoInfo {
  String? questionId;
  String? videoDir;
  String? thumbnailDir;

  VideoInfo({
    this.questionId,
    this.videoDir,
    this.thumbnailDir,
  });

  Map toJson() => {
        'question_id': questionId,
        'video_dir': videoDir,
        'thumbnail_dir': thumbnailDir
      };

  factory VideoInfo.fromJson(Map<String, dynamic> json) {
    return VideoInfo(
        questionId: json['question_id'],
        videoDir: json['video_dir'],
        thumbnailDir: json['thumbnail_dir']);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoInfo &&
          runtimeType == other.runtimeType &&
          questionId == other.questionId &&
          videoDir == other.videoDir &&
          thumbnailDir == other.thumbnailDir;

  @override
  int get hashCode =>
      questionId.hashCode ^ videoDir.hashCode ^ thumbnailDir.hashCode;
}
