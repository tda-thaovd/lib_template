package jp.oyster.camera_stream.models

import com.google.gson.annotations.SerializedName

data class Question(
    @SerializedName("id") val id: String,
    @SerializedName("title") val name: String?,
    @SerializedName("question_link") val audioLink: String?,
    @SerializedName("answer_time") val answerTime: Int? = 30,
    @SerializedName("position") val position: Int?
)
