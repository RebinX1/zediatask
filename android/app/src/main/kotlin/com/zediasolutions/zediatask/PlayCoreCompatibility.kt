package com.zediasolutions.zediatask

import android.content.Context
import android.util.Log

/**
 * Dummy class to maintain backward compatibility.
 * Play Core libraries have been removed so this is just a placeholder.
 */
class PlayCoreCompatibility {
    companion object {
        fun initialize(context: Context) {
            Log.d("PlayCore", "Compatibility layer not needed - Play Core removed")
        }
    }
} 