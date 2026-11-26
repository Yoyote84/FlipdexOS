package io.github.yoyote84.flipdexos;

/** Keeps the phone companion on the main display and routes the launcher on virtual displays. */
public final class DisplayRouting {
    private static final String ACTION_MAIN = "android.intent.action.MAIN";
    private static final int DEFAULT_DISPLAY_ID = 0;

    private DisplayRouting() { }

    public static boolean shouldOpenDesktop(
            String action,
            boolean hasLauncherCategory,
            int displayId) {
        return displayId != DEFAULT_DISPLAY_ID
                && hasLauncherCategory
                && ACTION_MAIN.equals(action);
    }
}
