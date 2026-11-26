package io.github.yoyote84.flipdexos;

/** Dependency-free logic checks for the Android module. Run by tests/android-logic-tests.sh. */
public final class AndroidLogicTest {
    private static int checks;

    private AndroidLogicTest() { }

    public static void main(String[] args) {
        onlyExplicitDesktopSettingsAreAllowed();
        onlyBooleanValuesCanBeWritten();
        storedValuesCanRepresentAnUnsetSetting();
        formatsSamsungOneUiVersionCode();
        routesLauncherOnlyOnSecondaryDisplays();
        System.out.println("Tous les tests logiques Android FlipdexOS sont passés (" + checks + ").");
    }

    private static void onlyExplicitDesktopSettingsAreAllowed() {
        assertTrue(DesktopSettings.isAllowedGlobalSetting(DesktopSettings.ENABLE_FREEFORM));
        assertTrue(DesktopSettings.isAllowedGlobalSetting(DesktopSettings.FORCE_DESKTOP));
        assertTrue(DesktopSettings.isAllowedGlobalSetting(DesktopSettings.ENABLE_NON_RESIZABLE));
        assertFalse(DesktopSettings.isAllowedGlobalSetting("adb_enabled"));
        assertFalse(DesktopSettings.isAllowedGlobalSetting("secure"));
        assertFalse(DesktopSettings.isAllowedGlobalSetting(null));
    }

    private static void onlyBooleanValuesCanBeWritten() {
        assertTrue(DesktopSettings.isWritableValue("0"));
        assertTrue(DesktopSettings.isWritableValue("1"));
        assertFalse(DesktopSettings.isWritableValue("null"));
        assertFalse(DesktopSettings.isWritableValue("1;settings put global adb_enabled 0"));
    }

    private static void storedValuesCanRepresentAnUnsetSetting() {
        assertTrue(DesktopSettings.isStoredValue("null"));
        assertTrue(DesktopSettings.isStoredValue("0"));
        assertTrue(DesktopSettings.isStoredValue("1"));
        assertFalse(DesktopSettings.isStoredValue("2"));
    }

    private static void formatsSamsungOneUiVersionCode() {
        assertEquals("9.0", DesktopSettings.formatOneUiVersion("90000"));
        assertEquals("8.5", DesktopSettings.formatOneUiVersion("80500"));
        assertEquals("8.5.1", DesktopSettings.formatOneUiVersion("80501"));
        assertEquals("non détectée", DesktopSettings.formatOneUiVersion("unknown"));
    }

    private static void routesLauncherOnlyOnSecondaryDisplays() {
        assertFalse(DisplayRouting.shouldOpenDesktop("android.intent.action.MAIN", true, 0));
        assertTrue(DisplayRouting.shouldOpenDesktop("android.intent.action.MAIN", true, 2));
        assertFalse(DisplayRouting.shouldOpenDesktop(null, false, 2));
        assertFalse(DisplayRouting.shouldOpenDesktop("android.intent.action.VIEW", false, 2));
    }

    private static void assertTrue(boolean value) {
        checks++;
        if (!value) throw new AssertionError("Une condition attendue vraie est fausse.");
    }

    private static void assertFalse(boolean value) {
        checks++;
        if (value) throw new AssertionError("Une condition attendue fausse est vraie.");
    }

    private static void assertEquals(Object expected, Object actual) {
        checks++;
        if (expected == null ? actual != null : !expected.equals(actual)) {
            throw new AssertionError("Attendu : " + expected + " ; obtenu : " + actual);
        }
    }
}
