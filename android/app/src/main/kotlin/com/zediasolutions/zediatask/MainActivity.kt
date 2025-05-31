package com.zediasolutions.zediatask

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.util.Log

class MainActivity : FlutterActivity() {
    private val TAG = "MainActivity"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Initialize our Play Core workaround
        PlayCoreWorkaround.initialize(applicationContext)
        
        Log.d(TAG, "App initialized with Play Core compatibility workaround")
    }
} 