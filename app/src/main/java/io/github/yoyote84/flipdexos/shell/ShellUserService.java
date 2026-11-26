package io.github.yoyote84.flipdexos.shell;

import android.os.RemoteException;
import android.system.Os;
import io.github.yoyote84.flipdexos.DesktopSettings;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.TimeUnit;

/**
 * Shizuku service with a strict command allow-list. It does not expose arbitrary shell execution.
 */
public final class ShellUserService extends IFlipdexShellService.Stub {
    private static final String[] ALLOWED_PROPERTIES = {
            "ro.product.model", "ro.build.version.release",
            "ro.build.version.sdk", "ro.build.version.oneui"
    };

    @Override public int getUid() { return Os.getuid(); }

    @Override
    public String getProperty(String name) throws RemoteException {
        boolean allowed = false;
        for (String property : ALLOWED_PROPERTIES) {
            if (property.equals(name)) { allowed = true; break; }
        }
        if (!allowed) throw new RemoteException("Propriété système non autorisée.");
        CommandResult result = execute("/system/bin/getprop", name);
        if (result.exitCode != 0) throw new RemoteException("Lecture de propriété impossible.");
        return result.output.trim();
    }

    @Override
    public String getGlobalSetting(String name) throws RemoteException {
        requireAllowedSetting(name);
        CommandResult result = execute("/system/bin/settings", "get", "global", name);
        if (result.exitCode != 0) throw new RemoteException("Lecture du réglage Android impossible.");
        String value = result.output.trim();
        return value.isEmpty() ? "null" : value;
    }

    @Override
    public int putGlobalSetting(String name, String value) throws RemoteException {
        requireAllowedSetting(name);
        if (!DesktopSettings.isWritableValue(value)) throw new RemoteException("Valeur de réglage refusée.");
        return execute("/system/bin/settings", "put", "global", name, value).exitCode;
    }

    @Override
    public int deleteGlobalSetting(String name) throws RemoteException {
        requireAllowedSetting(name);
        return execute("/system/bin/settings", "delete", "global", name).exitCode;
    }

    @Override public void destroy() { System.exit(0); }

    private static void requireAllowedSetting(String name) throws RemoteException {
        if (!DesktopSettings.isAllowedGlobalSetting(name)) {
            throw new RemoteException("Réglage Android non autorisé.");
        }
    }

    private static CommandResult execute(String... command) throws RemoteException {
        Process process = null;
        try {
            process = new ProcessBuilder(command).redirectErrorStream(true).start();
            if (!process.waitFor(5, TimeUnit.SECONDS)) {
                process.destroyForcibly();
                throw new RemoteException("La commande Android a dépassé le délai autorisé.");
            }
            byte[] output = process.getInputStream().readAllBytes();
            return new CommandResult(process.exitValue(), new String(output, StandardCharsets.UTF_8));
        } catch (IOException exception) {
            throw new RemoteException("Impossible de lancer l'outil système Android : " + exception.getMessage());
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            if (process != null) process.destroyForcibly();
            throw new RemoteException("Commande Android interrompue.");
        }
    }

    private static final class CommandResult {
        final int exitCode;
        final String output;
        CommandResult(int exitCode, String output) {
            this.exitCode = exitCode;
            this.output = output == null ? "" : output;
        }
    }
}
