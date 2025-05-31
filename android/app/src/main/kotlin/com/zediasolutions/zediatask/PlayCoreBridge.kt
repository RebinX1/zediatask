package com.zediasolutions.zediatask

import android.util.Log

/**
 * Dummy bridge class since we've removed all Play Core dependencies.
 */
class PlayCoreBridge {
    companion object {
        fun logMethodCall(methodName: String) {
            Log.d("PlayCore", "Method called but Play Core is not used: $methodName")
        }
    }
} 