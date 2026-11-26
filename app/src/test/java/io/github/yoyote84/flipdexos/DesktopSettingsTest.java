package io.github.yoyote84.flipdexos;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public final class DesktopSettingsTest {
    @Test
    public void onlyExplicitDesktopSettingsAreAllowed() {
        assertTrue(DesktopSettings.isAllowedGlobalSetting(DesktopSettings.ENABLE_FREEFORM));
        assertTrue(DesktopSettings.isAllowedGlobalSetting(DesktopSettings.FORCE_DESKTOP));
        assertTrue(DesktopSettings.isAllowedGlobalSetting(DesktopSettings.ENABLE_NON_RESIZABLE));
        assertFalse(DesktopSettings.isAllowedGlobalSetting("adb_enabled"));
        assertFalse(DesktopSettings.isAllowedGlobalSetting("secure"));
        assertFalse(DesktopSettings.isAllowedGlobalSetting(null));
    }

    @Test
    public void onlyBooleanValuesCanBeWritten() {
        assertTrue(DesktopSettings.isWritableValue("0"));
        assertTrue(DesktopSettings.isWritableValue("1"));
        assertFalse(DesktopSettings.isWritableValue("null"));
        assertFalse(DesktopSettings.isWritableValue("1;settings put global adb_enabled 0"));
    }

    @Test
    public void storedValuesCanRepresentAnUnsetSetting() {
        assertTrue(DesktopSettings.isStoredValue("null"));
        assertTrue(DesktopSettings.isStoredValue("0"));
        assertTrue(DesktopSettings.isStoredValue("1"));
        assertFalse(DesktopSettings.isStoredValue("2"));
    }

    @Test
    public void formatsSamsungOneUiVersionCode() {
        assertEquals("9.0", DesktopSettings.formatOneUiVersion("90000"));
        assertEquals("8.5", DesktopSettings.formatOneUiVersion("80500"));
        assertEquals("8.5.1", DesktopSettings.formatOneUiVersion("80501"));
        assertEquals("non détectée", DesktopSettings.formatOneUiVersion("unknown"));
    }
}
