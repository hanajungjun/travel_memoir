package com.hanajungjun.travelmemoir

import android.os.Bundle
import android.view.Window
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.android.RenderMode

class MainActivity : FlutterFragmentActivity() {
    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 항상 최고 프레임레이트 유지
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}