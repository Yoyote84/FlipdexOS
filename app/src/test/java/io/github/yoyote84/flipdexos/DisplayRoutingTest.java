package io.github.yoyote84.flipdexos;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public final class DisplayRoutingTest {
    @Test
    public void launcherOnPhoneOpensCompanion() {
        assertFalse(DisplayRouting.shouldOpenDesktop(
                "android.intent.action.MAIN", true, 0));
    }

    @Test
    public void launcherOnVirtualDisplayOpensDesktop() {
        assertTrue(DisplayRouting.shouldOpenDesktop(
                "android.intent.action.MAIN", true, 2));
    }

    @Test
    public void explicitCompanionIntentOnVirtualDisplayDoesNotRedirect() {
        assertFalse(DisplayRouting.shouldOpenDesktop(
                null, false, 2));
    }

    @Test
    public void nonLauncherActionOnVirtualDisplayDoesNotRedirect() {
        assertFalse(DisplayRouting.shouldOpenDesktop(
                "android.intent.action.VIEW", false, 2));
    }
}
