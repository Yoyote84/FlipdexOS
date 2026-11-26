package io.github.yoyote84.flipdexos;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

/** Narrow allow-list for the Android settings FlipdexOS may inspect or adjust. */
public final class DesktopSettings {
    public static final String ENABLE_FREEFORM = "enable_freeform_support";
    public static final String FORCE_DESKTOP = "force_desktop_mode_on_external_displays";
    public static final String ENABLE_NON_RESIZABLE = "enable_non_resizable_multi_window";
    private static final Set<String> ALLOWED = Collections.unmodifiableSet(new HashSet<>(Arrays.asList(
            ENABLE_FREEFORM, FORCE_DESKTOP, ENABLE_NON_RESIZABLE)));

    private DesktopSettings() { }

    public static boolean isAllowedGlobalSetting(String name) {
        return name != null && ALLOWED.contains(name);
    }

    public static boolean isStoredValue(String value) {
        return "null".equals(value) || "0".equals(value) || "1".equals(value);
    }

    public static boolean isWritableValue(String value) {
        return "0".equals(value) || "1".equals(value);
    }

    public static String formatOneUiVersion(String rawCode) {
        if (rawCode == null || !rawCode.matches("[0-9]{1,8}")) return "non détectée";
        try {
            int code = Integer.parseInt(rawCode);
            if (code <= 0) return "non détectée";
            int major = code / 10000;
            int minor = (code / 100) % 100;
            int patch = code % 100;
            return patch == 0 ? major + "." + minor : major + "." + minor + "." + patch;
        } catch (NumberFormatException ignored) {
            return "non détectée";
        }
    }
}
