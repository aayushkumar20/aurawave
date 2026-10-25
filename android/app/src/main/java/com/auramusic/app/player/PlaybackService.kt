package com.auramusic.app.player

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat as MediaNotificationCompat
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import com.auramusic.app.MainActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

class PlaybackService : MediaSessionService() {

    companion object {
        const val CHANNEL_ID = "aura_playback_channel"
        const val NOTIFICATION_ID = 1001

        const val ACTION_PLAY = "com.auramusic.app.ACTION_PLAY"
        const val ACTION_PAUSE = "com.auramusic.app.ACTION_PAUSE"
        const val ACTION_TOGGLE = "com.auramusic.app.ACTION_TOGGLE"
        const val ACTION_NEXT = "com.auramusic.app.ACTION_NEXT"
        const val ACTION_PREV = "com.auramusic.app.ACTION_PREV"
        const val ACTION_STOP = "com.auramusic.app.ACTION_STOP"
    }

    private val serviceScope = CoroutineScope(Dispatchers.Main + Job())

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()

        // Observe song and playback state changes to keep Lock Screen notification updated
        serviceScope.launch {
            PlaybackManager.currentSong.collect {
                updateNotification()
            }
        }
        serviceScope.launch {
            PlaybackManager.isPlaying.collect {
                updateNotification()
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> PlaybackManager.play()
            ACTION_PAUSE -> PlaybackManager.pause()
            ACTION_TOGGLE -> PlaybackManager.togglePlayPause()
            ACTION_NEXT -> PlaybackManager.skipNext()
            ACTION_PREV -> PlaybackManager.skipPrevious()
            ACTION_STOP -> {
                PlaybackManager.pause()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        updateNotification()
        return super.onStartCommand(intent, flags, startId)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Aura Music Playback"
            val descriptionText = "Media playback and lock screen controls"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun updateNotification() {
        val song = PlaybackManager.currentSong.value ?: return
        val isPlaying = PlaybackManager.isPlaying.value

        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            this.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            this, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        fun createServicePendingIntent(action: String, requestCode: Int): PendingIntent {
            val intent = Intent(this, PlaybackService::class.java).apply {
                this.action = action
            }
            return PendingIntent.getService(
                this, requestCode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        val prevPendingIntent = createServicePendingIntent(ACTION_PREV, 1)
        val togglePendingIntent = createServicePendingIntent(ACTION_TOGGLE, 2)
        val nextPendingIntent = createServicePendingIntent(ACTION_NEXT, 3)

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(song.title)
            .setContentText(song.artist)
            .setSubText(song.album.ifEmpty { "Aura Music" })
            .setContentIntent(openAppPendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(isPlaying)
            .addAction(android.R.drawable.ic_media_previous, "Previous", prevPendingIntent)
            .addAction(
                if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (isPlaying) "Pause" else "Play",
                togglePendingIntent
            )
            .addAction(android.R.drawable.ic_media_next, "Next", nextPendingIntent)
            .setStyle(
                MediaNotificationCompat.MediaStyle()
                    .setShowActionsInCompactView(0, 1, 2)
            )
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? {
        return PlaybackManager.getMediaSession()
    }
}
