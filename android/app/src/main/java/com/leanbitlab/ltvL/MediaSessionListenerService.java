package com.omeda.arc;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.media.MediaMetadata;
import android.media.session.MediaController;
import android.media.session.MediaSessionManager;
import android.media.session.PlaybackState;
import android.provider.Settings;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;

import androidx.annotation.Nullable;

import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Bridges Android media sessions (Spotify, YouTube Music, any player exposing a
 * MediaSession) to Flutter. Requires the user to grant notification access —
 * without it getActiveSessions() throws SecurityException and we simply report
 * an empty list.
 */
public class MediaSessionListenerService extends NotificationListenerService {

    /** Receives the active-session list whenever it changes. */
    public interface Callback {
        void onActiveSessionsChanged(List<Map<String, Object>> sessions);
    }

    private static final List<Callback> callbacks =
            Collections.synchronizedList(new ArrayList<>());
    private static final List<MediaController> controllers =
            Collections.synchronizedList(new ArrayList<>());

    /** Last known state, served to Dart on connect. */
    private static volatile List<Map<String, Object>> currentSessions = new ArrayList<>();

    private final MediaController.Callback controllerCallback =
            new MediaController.Callback() {
                @Override
                public void onPlaybackStateChanged(@Nullable PlaybackState state) {
                    refresh();
                }

                @Override
                public void onMetadataChanged(@Nullable MediaMetadata metadata) {
                    refresh();
                }
            };

    @Override
    public void onListenerConnected() {
        super.onListenerConnected();
        refresh();
    }

    @Override
    public void onListenerDisconnected() {
        releaseControllers();
        currentSessions = new ArrayList<>();
        notifyCallbacks();
        super.onListenerDisconnected();
    }

    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
    }

    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
    }

    private void refresh() {
        List<Map<String, Object>> sessions;
        try {
            MediaSessionManager manager =
                    (MediaSessionManager) getSystemService(Context.MEDIA_SESSION_SERVICE);
            if (manager == null) {
                sessions = new ArrayList<>();
            } else {
                List<MediaController> active =
                        manager.getActiveSessions(
                                new ComponentName(this, MediaSessionListenerService.class));
                releaseControllers();
                for (MediaController controller : active) {
                    controller.registerCallback(controllerCallback);
                    controllers.add(controller);
                }
                sessions = describeAll(active);
            }
        } catch (Exception e) {
            sessions = new ArrayList<>();
        }
        currentSessions = sessions;
        notifyCallbacks();
    }

    private void releaseControllers() {
        for (MediaController controller : controllers) {
            try {
                controller.unregisterCallback(controllerCallback);
            } catch (Exception ignored) {
            }
        }
        controllers.clear();
    }

    private static void notifyCallbacks() {
        synchronized (callbacks) {
            for (Callback callback : callbacks) {
                callback.onActiveSessionsChanged(currentSessions);
            }
        }
    }

    private static List<Map<String, Object>> describeAll(List<MediaController> active) {
        List<Map<String, Object>> sessions = new ArrayList<>();
        for (MediaController controller : active) {
            try {
                sessions.add(describe(controller));
            } catch (Exception ignored) {
            }
        }
        return sessions;
    }

    private static Map<String, Object> describe(MediaController controller) {
        Map<String, Object> map = new HashMap<>();
        map.put("packageName", controller.getPackageName());

        MediaMetadata metadata = controller.getMetadata();
        if (metadata != null) {
            map.put("title", textOrNull(metadata.getString(MediaMetadata.METADATA_KEY_TITLE)));
            map.put("artist", textOrNull(metadata.getString(MediaMetadata.METADATA_KEY_ARTIST)));
            map.put("album", textOrNull(metadata.getString(MediaMetadata.METADATA_KEY_ALBUM)));
            map.put("durationMs", metadata.getLong(MediaMetadata.METADATA_KEY_DURATION));

            Bitmap art = metadata.getBitmap(MediaMetadata.METADATA_KEY_ART);
            if (art == null) {
                art = metadata.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART);
            }
            if (art == null) {
                art = metadata.getBitmap(MediaMetadata.METADATA_KEY_DISPLAY_ICON);
            }
            map.put("artBytes", bitmapToBytes(art));
        } else {
            map.put("title", null);
            map.put("artist", null);
            map.put("album", null);
            map.put("durationMs", 0L);
            map.put("artBytes", null);
        }

        PlaybackState state = controller.getPlaybackState();
        boolean isPlaying =
                state != null && state.getState() == PlaybackState.STATE_PLAYING;
        map.put("isPlaying", isPlaying);
        map.put("positionMs", state != null ? state.getPosition() : 0L);
        long actions = state != null ? state.getActions() : 0L;
        map.put("supportsNext", (actions & PlaybackState.ACTION_SKIP_TO_NEXT) != 0);
        map.put("supportsPrevious", (actions & PlaybackState.ACTION_SKIP_TO_PREVIOUS) != 0);

        return map;
    }

    private static String textOrNull(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private static byte[] bitmapToBytes(Bitmap bitmap) {
        if (bitmap == null) {
            return null;
        }
        try {
            Bitmap scaled = bitmap;
            int maxEdge = 256;
            if (Math.max(bitmap.getWidth(), bitmap.getHeight()) > maxEdge) {
                float ratio = (float) maxEdge / Math.max(bitmap.getWidth(), bitmap.getHeight());
                scaled = Bitmap.createScaledBitmap(
                        bitmap,
                        Math.max(1, Math.round(bitmap.getWidth() * ratio)),
                        Math.max(1, Math.round(bitmap.getHeight() * ratio)),
                        true);
            }
            ByteArrayOutputStream stream = new ByteArrayOutputStream();
            scaled.compress(Bitmap.CompressFormat.PNG, 100, stream);
            if (scaled != bitmap) {
                scaled.recycle();
            }
            return stream.toByteArray();
        } catch (Exception e) {
            return null;
        }
    }

    // ---- Called from the Flutter MethodChannel ----

    public static List<Map<String, Object>> getCurrentSessions() {
        return currentSessions;
    }

    public static void addCallback(Callback callback) {
        synchronized (callbacks) {
            callbacks.add(callback);
        }
    }

    public static void removeCallback(Callback callback) {
        synchronized (callbacks) {
            callbacks.remove(callback);
        }
    }

    /** Sends a transport command to the session owned by [packageName]. */
    public static boolean transportControl(Context context, String packageName, String action) {
        if (packageName == null || action == null) {
            return false;
        }
        try {
            MediaSessionManager manager =
                    (MediaSessionManager) context.getSystemService(Context.MEDIA_SESSION_SERVICE);
            if (manager == null) {
                return false;
            }
            ComponentName component = new ComponentName(context, MediaSessionListenerService.class);
            for (MediaController controller : manager.getActiveSessions(component)) {
                if (!packageName.equals(controller.getPackageName())) {
                    continue;
                }
                MediaController.TransportControls controls = controller.getTransportControls();
                switch (action) {
                    case "play":
                        controls.play();
                        break;
                    case "pause":
                        controls.pause();
                        break;
                    case "playPause":
                        if (controller.getPlaybackState() != null
                                && controller.getPlaybackState().getState()
                                        == PlaybackState.STATE_PLAYING) {
                            controls.pause();
                        } else {
                            controls.play();
                        }
                        break;
                    case "next":
                        controls.skipToNext();
                        break;
                    case "previous":
                        controls.skipToPrevious();
                        break;
                    case "stop":
                        controls.stop();
                        break;
                    default:
                        return false;
                }
                return true;
            }
        } catch (Exception ignored) {
        }
        return false;
    }

    public static boolean isListenerEnabled(Context context) {
        String enabled = Settings.Secure.getString(
                context.getContentResolver(), "enabled_notification_listeners");
        if (enabled == null || enabled.isEmpty()) {
            return false;
        }
        ComponentName component = new ComponentName(context, MediaSessionListenerService.class);
        return enabled.contains(component.flattenToString())
                || enabled.contains(component.flattenToShortString())
                || enabled.contains(component.getClassName());
    }

    public static void openListenerSettings(Context context) {
        try {
            Intent intent = new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
        } catch (Exception ignored) {
        }
    }
}
