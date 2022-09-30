package jp.oyster.camera_stream.camera

import android.content.Context
import android.graphics.*
import android.util.AttributeSet
import android.util.Log
import android.view.View
import androidx.core.content.res.ResourcesCompat
import androidx.core.graphics.ColorUtils
import jp.oyster.camera_stream.R
import android.util.DisplayMetrics
import jp.oyster.camera_stream.utils.dip2px

class FocusView @JvmOverloads constructor(
    context: Context?,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
): View(context, attrs, defStyleAttr) {

    private val paint: Paint = Paint()
    private var holePaint: Paint = Paint()
    private var bitmap: Bitmap? = null
    private var layer: Canvas? = null

    //position of hole
    var focusPosition: FocusPosition = FocusPosition(null)
        set(value) {
            field = value
            //redraw
            this.invalidate()
        }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (bitmap == null) { configureBitmap() }
        focusPosition.rect?.let {
            //draw background
            layer?.drawRect(0.0f, 0.0f, width.toFloat(), height.toFloat(), paint)

            //draw rect
            val offset = dip2px(context, 1f);
            layer?.drawRect(it.left.toFloat(), it.top.toFloat() + offset, it.right.toFloat(), it.bottom.toFloat() - offset, holePaint)

            //draw bitmap
            canvas.drawBitmap(bitmap!!, 0.0f, 0.0f, paint);
        }
    }

    private fun configureBitmap() {
        //create bitmap and layer
        bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        layer = Canvas(bitmap!!)
    }

    init {
        //configure background color
        val backgroundAlpha = 0.7
        paint.color = ColorUtils.setAlphaComponent(ResourcesCompat.getColor(resources, R.color.black, null), (255 * backgroundAlpha).toInt() )

        //configure hole color & mode
        holePaint.color = ResourcesCompat.getColor(resources, android.R.color.transparent, null)
        holePaint.xfermode = PorterDuffXfermode(PorterDuff.Mode.CLEAR)
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        bitmap?.recycle()
        bitmap = null
    }
}

class FocusPosition(var rect: Rect?)
