package com.yacoursetable.ya_coursetable

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import com.toner.app.widget.flutter_app_widget.FlutterAppWidgetProvider

/**
 * 桌面小部件 Provider：把 App 内保存的课程数据（SharedPreferences）
 * 渲染到桌面小部件（下一节课的课程名 + 时间）。
 */
class YaWidgetProvider : FlutterAppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.ya_widget)
            views.setTextViewText(
                R.id.next_class_name,
                widgetData.getString("course_name", "暂无课程")
            )
            views.setTextViewText(
                R.id.next_class_time,
                widgetData.getString("course_time", "")
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
