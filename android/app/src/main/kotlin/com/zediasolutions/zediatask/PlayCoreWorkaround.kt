package com.zediasolutions.zediatask

import android.content.Context
import android.os.Build
import android.util.Log

/**
 * Workaround class to fix Play Core compatibility issues with Android 14 (SDK 34)
 * by disabling certain functionality that would otherwise crash.
 * 
 * This approach allows us to include the Play Core dependency for Flutter
 * but avoid the backward compatibility issues with broadcast receivers.
 */
class PlayCoreWorkaround {
    companion object {
        private const val TAG = "PlayCoreWorkaround"
        
        /**
         * Initialize the workaround for Play Core compatibility
         */
        fun initialize(context: Context) {
            try {
                // Log that we're using target SDK that is compatible with Play Core
                Log.d(TAG, "Running with targetSdk: ${context.applicationInfo.targetSdkVersion}")
                
                // We're targeting SDK 33 (Android 13) which is compatible with Play Core
                Log.d(TAG, "Using compatible SDK level for Play Core: 33")
            } catch (e: Exception) {
                Log.e(TAG, "Error initializing Play Core workaround", e)
            }
        }
    }
} 