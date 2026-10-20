/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

package com.omeda.arc;

import android.content.Context;
import android.net.Uri;
import android.util.SparseArray;
import android.view.View;

import androidx.media3.common.MediaItem;
import androidx.media3.common.Player;
import androidx.media3.exoplayer.DefaultRenderersFactory;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.ui.AspectRatioFrameLayout;
import androidx.media3.ui.PlayerView;

import io.flutter.plugin.platform.PlatformView;

import java.io.File;
import java.util.Map;

/**
 * Full-screen looping muted video rendered natively (media3 ExoPlayer + PlayerView)
 * and embedded into Flutter as a platform view.
 *
 * The stock video_player plugin fails on some TVs (e.g. Realtek OMX decoders crash
 * when initialized from Flutter's SurfaceTexture pipeline) and offers no fallback.
 * Here we enable media3's decoder fallback so playback automatically switches to
 * the software decoder when the hardware one refuses to start.
 */
public class VideoWallpaperPlatformView implements PlatformView {

    private static final SparseArray<ExoPlayer> ACTIVE_PLAYERS = new SparseArray<>();

    private final int viewId;
    private final PlayerView view;
    private final ExoPlayer player;

    VideoWallpaperPlatformView(Context context, int viewId, Map<String, Object> creationParams) {
        this.viewId = viewId;
        String path = creationParams != null ? (String) creationParams.get("path") : null;

        DefaultRenderersFactory renderersFactory = new DefaultRenderersFactory(context)
                .setEnableDecoderFallback(true)
                .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_ON);

        player = new ExoPlayer.Builder(context, renderersFactory).build();
        player.setRepeatMode(Player.REPEAT_MODE_ONE);
        player.setVolume(0f);
        if (path != null && new File(path).exists()) {
            player.setMediaItem(MediaItem.fromUri(Uri.fromFile(new File(path))));
        }

        view = new PlayerView(context);
        view.setUseController(false);
        view.setResizeMode(AspectRatioFrameLayout.RESIZE_MODE_ZOOM);
        view.setPlayer(player);

        player.prepare();
        player.play();

        synchronized (ACTIVE_PLAYERS) {
            ACTIVE_PLAYERS.put(viewId, player);
        }
    }

    @Override
    public View getView() {
        return view;
    }

    @Override
    public void dispose() {
        synchronized (ACTIVE_PLAYERS) {
            ACTIVE_PLAYERS.remove(viewId);
        }
        try {
            player.release();
        } catch (Throwable ignored) {
        }
    }

    public static void pauseAll() {
        synchronized (ACTIVE_PLAYERS) {
            for (int i = 0; i < ACTIVE_PLAYERS.size(); i++) {
                try {
                    ACTIVE_PLAYERS.valueAt(i).pause();
                } catch (Throwable ignored) {
                }
            }
        }
    }

    public static void resumeAll() {
        synchronized (ACTIVE_PLAYERS) {
            for (int i = 0; i < ACTIVE_PLAYERS.size(); i++) {
                try {
                    ACTIVE_PLAYERS.valueAt(i).play();
                } catch (Throwable ignored) {
                }
            }
        }
    }
}
