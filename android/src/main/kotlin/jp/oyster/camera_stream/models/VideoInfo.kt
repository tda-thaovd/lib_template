package jp.oyster.camera_stream.models

import com.google.gson.annotations.SerializedName

data class VideoInfo(
    @SerializedName("question_id") val questionId: String,
    @SerializedName("video_dir") val videoDir: String?,
    @SerializedName("thumbnail_dir") val thumbnailDir: String
)
