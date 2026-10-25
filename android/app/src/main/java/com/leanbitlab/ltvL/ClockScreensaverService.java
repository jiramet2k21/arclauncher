package com.omeda.arc;

import android.animation.Animator;
import android.animation.AnimatorListenerAdapter;
import android.animation.AnimatorSet;
import android.animation.ObjectAnimator;
import android.animation.PropertyValuesHolder;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.Typeface;
import android.os.Handler;
import android.os.Looper;
import android.service.dreams.DreamService;
import android.util.DisplayMetrics;
import android.util.Log;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.animation.AccelerateDecelerateInterpolator;
import android.view.animation.OvershootInterpolator;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.TextView;

import java.io.File;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.Random;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class ClockScreensaverService extends DreamService {
    private static final String TAG = "ClockScreensaver";

    private FrameLayout container;
    private Handler handler;
    private Runnable updateTimeRunnable;
    private Runnable moveClockRunnable;
    private Random random;
    private int screenWidth;
    private int screenHeight;
    private final List<Animator> runningAnimators = new ArrayList<>();

    private List<TextView> timeCharViews = new ArrayList<>();
    private List<TextView> dateCharViews = new ArrayList<>();
    private List<TextView> amPmCharViews = new ArrayList<>();

    private float currentCenterX;
    private float currentCenterY;
    private float targetCenterX;
    private float targetCenterY;

    private static final int TIME_FONT_SIZE = 80; // sp
    private static final int DATE_FONT_SIZE = 32; // sp
    private static final int AMPM_FONT_SIZE = 32; // sp (~40% of TIME_FONT_SIZE)
    private static final int CHAR_ANIMATION_DURATION = 800; // ms per character
    private static final int CHAR_STAGGER_DELAY = 100; // ms between characters

    // "No clock - slideshow photo" style: full-screen slideshow of the same
    // images the launcher's background slideshow uses.
    private static final String STYLE_SLIDESHOW = "slideshow";
    private static final int SLIDESHOW_FADE_DURATION = 800; // ms crossfade
    private static final String SLIDESHOW_HINT =
            "Set a slideshow folder in Settings > Interface > Wallpaper";

    private boolean slideshowMode = false;
    private ImageView slideshowViewA;
    private ImageView slideshowViewB;
    private TextView slideshowHintView;
    private final Bitmap[] slideshowBitmaps = new Bitmap[2];
    private final List<File> slideshowFiles = new ArrayList<>();
    private int slideshowIndex = 0;
    private long slideshowIntervalMs = 30000L;
    private boolean slideshowShuffle = true;
    private boolean slideshowFrontIsA = true;
    private boolean slideshowActive = false;
    private int slideshowGeneration = 0;
    private Runnable slideshowRunnable;
    private ExecutorService slideshowExecutor;

    @Override
    public void onAttachedToWindow() {
        super.onAttachedToWindow();

        setInteractive(false);
        setFullscreen(true);

        // Create container
        container = new FrameLayout(this);
        container.setBackgroundColor(Color.BLACK);
        setContentView(container);

        handler = new Handler(Looper.getMainLooper());
        random = new Random();

        // Get screen dimensions
        DisplayMetrics metrics = getResources().getDisplayMetrics();
        screenWidth = metrics.widthPixels;
        screenHeight = metrics.heightPixels;

        // Initial position at center
        currentCenterX = screenWidth / 2f;
        currentCenterY = screenHeight / 2f;
        targetCenterX = currentCenterX;
        targetCenterY = currentCenterY;

        // Update time every minute
        updateTimeRunnable = () -> {
            updateTime();
            handler.postDelayed(updateTimeRunnable, 60000);
        };

        // Move clock every 30 seconds
        moveClockRunnable = () -> {
            animateToNewPosition();
            handler.postDelayed(moveClockRunnable, 30000);
        };

        // Initial setup: either the moving clock or the photo slideshow.
        try {
            SharedPreferences prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE);
            slideshowMode = STYLE_SLIDESHOW.equals(
                    prefs.getString("flutter.screensaver_clock_style", "minimal"));
            if (slideshowMode) {
                setupSlideshowViews();
            } else {
                createCharacterViews();
                updateTime();
            }
        } catch (RuntimeException e) {
            Log.e(TAG, "Failed to build screensaver content", e);
        }
    }

    @Override
    public void onDreamingStarted() {
        super.onDreamingStarted();
        if (handler == null) {
            return;
        }
        if (slideshowMode) {
            startSlideshow();
            return;
        }
        // Start the update/motion loops only while the dream is actually
        // active. Starting them at attach time can leave timers running during
        // a preview or a re-attach, which makes the service look frozen.
        handler.removeCallbacks(updateTimeRunnable);
        handler.removeCallbacks(moveClockRunnable);
        handler.post(updateTimeRunnable);
        handler.postDelayed(moveClockRunnable, 30000);
    }

    @Override
    public void onDreamingStopped() {
        stopLoops();
        super.onDreamingStopped();
    }

    /** Cancels pending timers and in-flight character animations. */
    private void stopLoops() {
        if (handler != null) {
            handler.removeCallbacks(updateTimeRunnable);
            handler.removeCallbacks(moveClockRunnable);
            handler.removeCallbacksAndMessages(null);
        }
        for (Animator animator : runningAnimators) {
            animator.cancel();
        }
        runningAnimators.clear();
        stopSlideshow();
    }

    // ------------------------------------------------------------------
    // "No clock - slideshow photo" mode
    // ------------------------------------------------------------------

    private void setupSlideshowViews() {
        slideshowViewA = createSlideshowImageView();
        slideshowViewB = createSlideshowImageView();
        container.addView(slideshowViewA);
        container.addView(slideshowViewB);

        slideshowHintView = new TextView(this);
        slideshowHintView.setText(SLIDESHOW_HINT);
        slideshowHintView.setTextColor(0xB3FFFFFF);
        slideshowHintView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 24);
        slideshowHintView.setGravity(Gravity.CENTER);
        slideshowHintView.setPadding(48, 0, 48, 0);
        slideshowHintView.setVisibility(View.GONE);
        container.addView(slideshowHintView, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));
    }

    private ImageView createSlideshowImageView() {
        ImageView view = new ImageView(this);
        view.setScaleType(ImageView.ScaleType.CENTER_CROP);
        view.setAlpha(1f);
        view.setLayoutParams(new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));
        return view;
    }

    private void startSlideshow() {
        if (!slideshowMode || container == null || handler == null) {
            return;
        }
        stopSlideshow();

        SharedPreferences prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE);
        int intervalSeconds = prefs.getInt("flutter.slideshow_interval_seconds", 30);
        slideshowIntervalMs = Math.max(5, intervalSeconds) * 1000L;
        slideshowShuffle = prefs.getBoolean("flutter.slideshow_shuffle", true);

        File directory = resolveSlideshowDirectory();
        if (directory != null && directory.isDirectory()) {
            File[] files = directory.listFiles();
            if (files != null) {
                for (File file : files) {
                    if (file.isFile()) {
                        slideshowFiles.add(file);
                    }
                }
            }
        }
        Collections.sort(slideshowFiles, (a, b) -> a.getName().compareTo(b.getName()));

        if (slideshowFiles.isEmpty()) {
            Log.w(TAG, "Slideshow style selected but no images in " + directory);
            if (slideshowHintView != null) {
                slideshowHintView.setVisibility(View.VISIBLE);
            }
            return;
        }

        if (slideshowShuffle) {
            Collections.shuffle(slideshowFiles, random);
        }
        slideshowIndex = 0;
        slideshowActive = true;
        slideshowExecutor = Executors.newSingleThreadExecutor();

        showSlide(0);

        slideshowRunnable = () -> {
            if (!slideshowActive) {
                return;
            }
            advanceSlide();
            if (handler != null) {
                handler.postDelayed(slideshowRunnable, slideshowIntervalMs);
            }
        };
        handler.postDelayed(slideshowRunnable, slideshowIntervalMs);
    }

    private void advanceSlide() {
        if (slideshowFiles.isEmpty()) {
            return;
        }
        if (slideshowIndex + 1 < slideshowFiles.size()) {
            slideshowIndex++;
        } else if (slideshowShuffle && slideshowFiles.size() > 1) {
            // New shuffled cycle; make sure the first photo is not the one
            // that was just on screen.
            File lastShown = slideshowFiles.get(slideshowIndex);
            Collections.shuffle(slideshowFiles, random);
            if (slideshowFiles.get(0).getName().equals(lastShown.getName())) {
                int swapIndex = 1 + random.nextInt(slideshowFiles.size() - 1);
                Collections.swap(slideshowFiles, 0, swapIndex);
            }
            slideshowIndex = 0;
        } else {
            slideshowIndex = 0;
        }
        showSlide(slideshowIndex);
    }

    private void showSlide(int index) {
        if (!slideshowActive || index < 0 || index >= slideshowFiles.size()) {
            return;
        }
        final File file = slideshowFiles.get(index);
        final int generation = ++slideshowGeneration;
        final ExecutorService executor = slideshowExecutor;
        if (executor == null) {
            return;
        }
        try {
            executor.execute(() -> {
                Bitmap bitmap = decodeSlide(file);
                if (bitmap == null) {
                    return;
                }
                if (handler == null) {
                    bitmap.recycle();
                    return;
                }
                handler.post(() -> {
                    if (!slideshowActive || generation != slideshowGeneration) {
                        bitmap.recycle();
                        return;
                    }
                    applySlideBitmap(bitmap);
                });
            });
        } catch (RuntimeException e) {
            // The executor may have been shut down while the dream was exiting.
            Log.w(TAG, "Slideshow decode skipped", e);
        }
    }

    private void applySlideBitmap(Bitmap bitmap) {
        ImageView incoming = slideshowFrontIsA ? slideshowViewB : slideshowViewA;
        int slot = slideshowFrontIsA ? 1 : 0;
        if (incoming == null) {
            bitmap.recycle();
            return;
        }
        Bitmap previous = slideshowBitmaps[slot];
        slideshowBitmaps[slot] = bitmap;
        // The incoming view must sit on top of the one that is still visible,
        // otherwise the crossfade happens behind an opaque image and the
        // slideshow looks frozen after the first photo.
        incoming.bringToFront();
        incoming.setImageBitmap(bitmap);
        incoming.setAlpha(0f);
        incoming.animate().alpha(1f).setDuration(SLIDESHOW_FADE_DURATION).start();
        if (previous != null && previous != bitmap) {
            previous.recycle();
        }
        slideshowFrontIsA = !slideshowFrontIsA;
    }

    private Bitmap decodeSlide(File file) {
        try {
            BitmapFactory.Options bounds = new BitmapFactory.Options();
            bounds.inJustDecodeBounds = true;
            BitmapFactory.decodeFile(file.getAbsolutePath(), bounds);
            int sampleSize = 1;
            int width = bounds.outWidth;
            int height = bounds.outHeight;
            while (width / (sampleSize * 2) >= screenWidth
                    && height / (sampleSize * 2) >= screenHeight) {
                sampleSize *= 2;
            }
            BitmapFactory.Options options = new BitmapFactory.Options();
            options.inSampleSize = sampleSize;
            return BitmapFactory.decodeFile(file.getAbsolutePath(), options);
        } catch (OutOfMemoryError | RuntimeException e) {
            Log.e(TAG, "Failed to decode slideshow image " + file, e);
            return null;
        }
    }

    /**
     * path_provider's application documents directory on Android is
     * &lt;app data dir&gt;/app_flutter, which is where the launcher copies the
     * background slideshow images.
     */
    private File resolveSlideshowDirectory() {
        try {
            File dataDir = new File(getApplicationInfo().dataDir);
            File directory = new File(dataDir, "app_flutter/slideshow");
            if (directory.isDirectory()) {
                return directory;
            }
            File filesDir = getFilesDir();
            if (filesDir != null && filesDir.getParentFile() != null) {
                File alternate = new File(filesDir.getParentFile(), "app_flutter/slideshow");
                if (alternate.isDirectory()) {
                    return alternate;
                }
            }
            return directory;
        } catch (RuntimeException e) {
            Log.e(TAG, "Failed to resolve slideshow directory", e);
            return null;
        }
    }

    private void stopSlideshow() {
        slideshowActive = false;
        slideshowGeneration++;
        if (handler != null && slideshowRunnable != null) {
            handler.removeCallbacks(slideshowRunnable);
        }
        slideshowRunnable = null;
        if (slideshowExecutor != null) {
            slideshowExecutor.shutdownNow();
            slideshowExecutor = null;
        }
        for (int i = 0; i < slideshowBitmaps.length; i++) {
            if (slideshowBitmaps[i] != null) {
                slideshowBitmaps[i].recycle();
                slideshowBitmaps[i] = null;
            }
        }
        if (slideshowViewA != null) {
            slideshowViewA.setImageDrawable(null);
            slideshowViewA.setAlpha(1f);
        }
        if (slideshowViewB != null) {
            slideshowViewB.setImageDrawable(null);
            slideshowViewB.setAlpha(1f);
        }
        if (slideshowHintView != null) {
            slideshowHintView.setVisibility(View.GONE);
        }
        slideshowFiles.clear();
        slideshowIndex = 0;
        slideshowFrontIsA = true;
    }

    private void createCharacterViews() {
        // Get current time and date strings
        SharedPreferences prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE);
        String timeFormatString = prefs.getString("flutter.time_format", "H:mm");
        String dateFormatString = prefs.getString("flutter.date_format", "EEEE d");

        SimpleDateFormat timeFormat = createFormatter(timeFormatString, "H:mm");
        SimpleDateFormat dateFormat = createFormatter(dateFormatString, "EEEE d");

        String timeStr = timeFormat.format(new Date());
        String dateStr = dateFormat.format(new Date());

        // Clear existing views
        container.removeAllViews();
        timeCharViews.clear();
        dateCharViews.clear();
        amPmCharViews.clear();

        // Detect AM/PM in time string
        String amPmSuffix = "";
        String timeDigits = timeStr;
        if (timeStr.toUpperCase().endsWith("AM") || timeStr.toUpperCase().endsWith("PM")) {
            amPmSuffix = timeStr.substring(timeStr.length() - 2);
            timeDigits = timeStr.substring(0, timeStr.length() - 2).trim();
        }

        // Create time character views (digits at full size)
        float timeWidth = 0;
        for (int i = 0; i < timeDigits.length(); i++) {
            TextView charView = createCharView(String.valueOf(timeDigits.charAt(i)), TIME_FONT_SIZE);
            timeCharViews.add(charView);
            container.addView(charView);
            timeWidth += getCharWidth(charView);
        }

        // Create AM/PM characters at smaller size (tracked separately for
        // bottom-alignment)
        if (!amPmSuffix.isEmpty()) {
            // Add a small space (counted in time width for centering)
            TextView spaceView = createCharView(" ", AMPM_FONT_SIZE);
            amPmCharViews.add(spaceView);
            container.addView(spaceView);
            timeWidth += getCharWidth(spaceView);

            for (int i = 0; i < amPmSuffix.length(); i++) {
                TextView charView = createCharView(String.valueOf(amPmSuffix.charAt(i)), AMPM_FONT_SIZE);
                amPmCharViews.add(charView);
                container.addView(charView);
                timeWidth += getCharWidth(charView);
            }
        }

        // Create date character views
        float dateWidth = 0;
        for (int i = 0; i < dateStr.length(); i++) {
            TextView charView = createCharView(String.valueOf(dateStr.charAt(i)), DATE_FONT_SIZE);
            dateCharViews.add(charView);
            container.addView(charView);
            dateWidth += getCharWidth(charView);
        }

        // Position characters at center
        positionCharacters(currentCenterX, currentCenterY, false);
    }

    /**
     * Builds a SimpleDateFormat from a Flutter pattern preference. Flutter and
     * Java use different pattern alphabets, so a stored pattern can be invalid
     * here; fall back to the default instead of crashing the dream service.
     */
    private SimpleDateFormat createFormatter(String pattern, String fallbackPattern) {
        try {
            return new SimpleDateFormat(pattern, Locale.getDefault());
        } catch (IllegalArgumentException e) {
            return new SimpleDateFormat(fallbackPattern, Locale.getDefault());
        }
    }

    private TextView createCharView(String character, int fontSize) {
        SharedPreferences prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE);
        String clockStyle = prefs.getString("flutter.screensaver_clock_style", "minimal");

        TextView tv = new TextView(this);
        tv.setText(character);
        tv.setTextColor(Color.WHITE);
        tv.setTextSize(TypedValue.COMPLEX_UNIT_SP, fontSize);

        switch (clockStyle) {
            case "bold":
                tv.setTypeface(Typeface.create("sans-serif", Typeface.BOLD));
                break;
            case "retro":
                tv.setTypeface(Typeface.create("monospace", Typeface.NORMAL));
                break;
            case "elegant":
                tv.setTypeface(Typeface.create("serif", Typeface.NORMAL));
                break;
            case "neon":
                tv.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
                break;
            case "pixel":
                tv.setTypeface(Typeface.create("monospace", Typeface.BOLD));
                break;
            case "digital":
                tv.setTypeface(Typeface.create("monospace", Typeface.NORMAL));
                break;
            default: // "minimal"
                tv.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
                break;
        }

        tv.setGravity(Gravity.CENTER);
        tv.setShadowLayer(15, 0, 0, 0x60FFFFFF);
        tv.setLayoutParams(new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT));
        return tv;
    }

    private float getCharWidth(TextView tv) {
        tv.measure(0, 0);
        return tv.getMeasuredWidth();
    }

    private float getCharHeight(TextView tv) {
        tv.measure(0, 0);
        return tv.getMeasuredHeight();
    }

    private void positionCharacters(float centerX, float centerY, boolean animate) {
        // Calculate total widths
        float timeWidth = 0;
        for (TextView tv : timeCharViews) {
            timeWidth += getCharWidth(tv);
        }

        float dateWidth = 0;
        for (TextView tv : dateCharViews) {
            dateWidth += getCharWidth(tv);
        }

        float timeHeight = timeCharViews.isEmpty() ? 0 : getCharHeight(timeCharViews.get(0));
        float dateHeight = dateCharViews.isEmpty() ? 0 : getCharHeight(dateCharViews.get(0));
        float totalHeight = timeHeight + dateHeight + 20; // 20px gap

        // Calculate total width including AM/PM for centering
        float totalTimeWidth = timeWidth;
        for (TextView tv : amPmCharViews) {
            totalTimeWidth += getCharWidth(tv);
        }

        // Position time characters (digits only)
        float timeStartX = centerX - totalTimeWidth / 2;
        float timeY = centerY - totalHeight / 2;
        float currentX = timeStartX;

        for (TextView tv : timeCharViews) {
            float charWidth = getCharWidth(tv);
            if (animate) {
                tv.setTag(new float[] { currentX, timeY });
            } else {
                tv.setX(currentX);
                tv.setY(timeY);
            }
            currentX += charWidth;
        }

        // Position AM/PM characters at the BOTTOM of the time row
        float amPmHeight = amPmCharViews.isEmpty() ? 0 : getCharHeight(amPmCharViews.get(0));
        float amPmY = timeY + timeHeight - amPmHeight;
        for (TextView tv : amPmCharViews) {
            float charWidth = getCharWidth(tv);
            if (animate) {
                tv.setTag(new float[] { currentX, amPmY });
            } else {
                tv.setX(currentX);
                tv.setY(amPmY);
            }
            currentX += charWidth;
        }

        // Position date characters
        float dateStartX = centerX - dateWidth / 2;
        float dateY = centerY - totalHeight / 2 + timeHeight + 20;
        currentX = dateStartX;

        for (TextView tv : dateCharViews) {
            float charWidth = getCharWidth(tv);
            if (animate) {
                tv.setTag(new float[] { currentX, dateY });
            } else {
                tv.setX(currentX);
                tv.setY(dateY);
            }
            currentX += charWidth;
        }
    }

    private void updateTime() {
        try {
            updateTimeInternal();
        } catch (RuntimeException e) {
            Log.e(TAG, "Failed to update screensaver clock", e);
        }
    }

    private void updateTimeInternal() {
        SharedPreferences prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE);
        String timeFormatString = prefs.getString("flutter.time_format", "H:mm");
        String dateFormatString = prefs.getString("flutter.date_format", "EEEE d");

        SimpleDateFormat timeFormat = createFormatter(timeFormatString, "H:mm");
        SimpleDateFormat dateFormat = createFormatter(dateFormatString, "EEEE d");

        String timeStr = timeFormat.format(new Date());
        String dateStr = dateFormat.format(new Date());

        // Detect AM/PM in time string
        String amPmSuffix = "";
        String timeDigits = timeStr;
        if (timeStr.toUpperCase().endsWith("AM") || timeStr.toUpperCase().endsWith("PM")) {
            amPmSuffix = timeStr.substring(timeStr.length() - 2);
            timeDigits = timeStr.substring(0, timeStr.length() - 2).trim();
        }

        // Update time digit characters
        for (int i = 0; i < timeCharViews.size() && i < timeDigits.length(); i++) {
            timeCharViews.get(i).setText(String.valueOf(timeDigits.charAt(i)));
        }

        // Update AM/PM characters (index 0=space, 1=A/P, 2=M)
        if (!amPmSuffix.isEmpty() && amPmCharViews.size() >= 3) {
            amPmCharViews.get(1).setText(String.valueOf(amPmSuffix.charAt(0)));
            amPmCharViews.get(2).setText(String.valueOf(amPmSuffix.charAt(1)));
        }

        // Check if we need to recreate views (text length changed)
        int expectedAmPmCount = amPmSuffix.isEmpty() ? 0 : 3; // space + 2 chars
        if (timeDigits.length() != timeCharViews.size()
                || expectedAmPmCount != amPmCharViews.size()
                || dateStr.length() != dateCharViews.size()) {
            createCharacterViews();
        } else {
            // Update date characters
            for (int i = 0; i < dateCharViews.size() && i < dateStr.length(); i++) {
                dateCharViews.get(i).setText(String.valueOf(dateStr.charAt(i)));
            }
        }
    }

    private void animateToNewPosition() {
        // Calculate new random position
        float margin = 150;
        float maxWidth = 0;
        for (TextView tv : timeCharViews) {
            maxWidth += getCharWidth(tv);
        }
        for (TextView tv : amPmCharViews) {
            maxWidth += getCharWidth(tv);
        }
        float totalHeight = (timeCharViews.isEmpty() ? 0 : getCharHeight(timeCharViews.get(0))) +
                (dateCharViews.isEmpty() ? 0 : getCharHeight(dateCharViews.get(0))) + 20;

        float maxX = screenWidth - maxWidth / 2 - margin;
        float minX = maxWidth / 2 + margin;
        float maxY = screenHeight - totalHeight / 2 - margin;
        float minY = totalHeight / 2 + margin;

        if (maxX <= minX || maxY <= minY)
            return;

        targetCenterX = minX + random.nextFloat() * (maxX - minX);
        targetCenterY = minY + random.nextFloat() * (maxY - minY);

        // Store target positions in tags
        positionCharacters(targetCenterX, targetCenterY, true);

        // Combine all character views
        List<TextView> allChars = new ArrayList<>();
        allChars.addAll(timeCharViews);
        allChars.addAll(amPmCharViews);
        allChars.addAll(dateCharViews);

        // Shuffle to randomize animation order
        List<Integer> indices = new ArrayList<>();
        for (int i = 0; i < allChars.size(); i++) {
            indices.add(i);
        }
        Collections.shuffle(indices, random);

        // Animate characters one by one in random order
        for (int i = 0; i < indices.size(); i++) {
            int charIndex = indices.get(i);
            TextView tv = allChars.get(charIndex);
            float[] targetPos = (float[]) tv.getTag();

            if (targetPos == null)
                continue;

            int delay = i * CHAR_STAGGER_DELAY;

            handler.postDelayed(() -> {
                animateCharacter(tv, targetPos[0], targetPos[1]);
            }, delay);
        }

        // Update current position after animation completes
        int totalAnimationTime = indices.size() * CHAR_STAGGER_DELAY + CHAR_ANIMATION_DURATION;
        handler.postDelayed(() -> {
            currentCenterX = targetCenterX;
            currentCenterY = targetCenterY;
        }, totalAnimationTime);
    }

    private void animateCharacter(TextView tv, float targetX, float targetY) {
        // Get current position
        float startX = tv.getX();
        float startY = tv.getY();

        // Create curved path animation
        PropertyValuesHolder pvhX = PropertyValuesHolder.ofFloat("x", startX, targetX);
        PropertyValuesHolder pvhY = PropertyValuesHolder.ofFloat("y", startY, targetY);

        ObjectAnimator moveAnim = ObjectAnimator.ofPropertyValuesHolder(tv, pvhX, pvhY);
        moveAnim.setDuration(CHAR_ANIMATION_DURATION);
        moveAnim.setInterpolator(new OvershootInterpolator(0.8f));

        // Scale animation - shrink then grow
        ObjectAnimator scaleXDown = ObjectAnimator.ofFloat(tv, "scaleX", 1f, 0.5f);
        ObjectAnimator scaleYDown = ObjectAnimator.ofFloat(tv, "scaleY", 1f, 0.5f);
        scaleXDown.setDuration(CHAR_ANIMATION_DURATION / 3);
        scaleYDown.setDuration(CHAR_ANIMATION_DURATION / 3);

        ObjectAnimator scaleXUp = ObjectAnimator.ofFloat(tv, "scaleX", 0.5f, 1f);
        ObjectAnimator scaleYUp = ObjectAnimator.ofFloat(tv, "scaleY", 0.5f, 1f);
        scaleXUp.setDuration(CHAR_ANIMATION_DURATION * 2 / 3);
        scaleYUp.setDuration(CHAR_ANIMATION_DURATION * 2 / 3);
        scaleXUp.setInterpolator(new OvershootInterpolator(1.5f));
        scaleYUp.setInterpolator(new OvershootInterpolator(1.5f));

        // Alpha animation - fade slightly during movement
        ObjectAnimator alphaDown = ObjectAnimator.ofFloat(tv, "alpha", 1f, 0.6f);
        alphaDown.setDuration(CHAR_ANIMATION_DURATION / 3);

        ObjectAnimator alphaUp = ObjectAnimator.ofFloat(tv, "alpha", 0.6f, 1f);
        alphaUp.setDuration(CHAR_ANIMATION_DURATION * 2 / 3);

        // Combine animations
        AnimatorSet scaleDown = new AnimatorSet();
        scaleDown.playTogether(scaleXDown, scaleYDown, alphaDown);

        AnimatorSet scaleUp = new AnimatorSet();
        scaleUp.playTogether(scaleXUp, scaleYUp, alphaUp);

        AnimatorSet scaleSet = new AnimatorSet();
        scaleSet.playSequentially(scaleDown, scaleUp);

        AnimatorSet fullAnim = new AnimatorSet();
        fullAnim.playTogether(moveAnim, scaleSet);
        fullAnim.addListener(new AnimatorListenerAdapter() {
            @Override
            public void onAnimationEnd(Animator animation) {
                runningAnimators.remove(animation);
            }
        });
        runningAnimators.add(fullAnim);
        fullAnim.start();
    }

    @Override
    public void onDetachedFromWindow() {
        super.onDetachedFromWindow();

        stopLoops();
    }
}
