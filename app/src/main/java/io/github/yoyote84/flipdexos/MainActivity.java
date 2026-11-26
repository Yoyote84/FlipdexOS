package io.github.yoyote84.flipdexos;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Intent;
import android.content.ServiceConnection;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import io.github.yoyote84.flipdexos.desktop.DesktopActivity;
import io.github.yoyote84.flipdexos.shell.IFlipdexShellService;
import io.github.yoyote84.flipdexos.shell.ShellUserService;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import rikka.shizuku.Shizuku;

/** Phone-side companion and Shizuku diagnostics for FlipdexOS Desktop. */
public final class MainActivity extends Activity {
    private static final int SHIZUKU_PERMISSION_REQUEST = 4107;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final ExecutorService worker = Executors.newSingleThreadExecutor();

    private TextView deviceSummary;
    private TextView shizukuStatus;
    private TextView serviceDetails;
    private Button connectButton;

    private IFlipdexShellService shellService;
    private boolean serviceBinding;
    private Shizuku.UserServiceArgs userServiceArgs;

    private final Shizuku.OnBinderReceivedListener binderReceivedListener =
            this::postRefreshShizukuStatus;
    private final Shizuku.OnBinderDeadListener binderDeadListener = () ->
            mainHandler.post(() -> {
                if (isFinishing() || isDestroyed()) return;
                shellService = null;
                serviceBinding = false;
                refreshShizukuStatus();
            });
    private final Shizuku.OnRequestPermissionResultListener permissionResultListener =
            (requestCode, grantResult) -> {
                if (requestCode != SHIZUKU_PERMISSION_REQUEST) return;
                if (grantResult == PackageManager.PERMISSION_GRANTED) {
                    bindShellService();
                } else {
                    showStatus("Autorisation Shizuku refusée. Aucune action privilégiée n'a été effectuée.");
                }
            };

    private final ServiceConnection shellServiceConnection = new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName name, IBinder binder) {
            shellService = IFlipdexShellService.Stub.asInterface(binder);
            serviceBinding = false;
            showStatus("Service Shizuku connecté. Vérification des capacités…");
            inspectShellService(shellService);
        }

        @Override
        public void onServiceDisconnected(ComponentName name) {
            shellService = null;
            serviceBinding = false;
            refreshShizukuStatus();
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        int displayId = getDisplay() == null ? 0 : getDisplay().getDisplayId();
        if (DisplayRouting.shouldOpenDesktop(
                getIntent().getAction(),
                getIntent().hasCategory(Intent.CATEGORY_LAUNCHER),
                displayId)) {
            startActivity(new Intent(this, DesktopActivity.class));
            finish();
            return;
        }

        buildInterface();
        deviceSummary.setText(BuildInfo.deviceLine()
                + "\nAndroid " + android.os.Build.VERSION.RELEASE
                + " · API " + android.os.Build.VERSION.SDK_INT);

        Shizuku.addBinderReceivedListenerSticky(binderReceivedListener);
        Shizuku.addBinderDeadListener(binderDeadListener);
        Shizuku.addRequestPermissionResultListener(permissionResultListener);
        refreshShizukuStatus();
    }

    @Override
    protected void onDestroy() {
        Shizuku.removeBinderReceivedListener(binderReceivedListener);
        Shizuku.removeBinderDeadListener(binderDeadListener);
        Shizuku.removeRequestPermissionResultListener(permissionResultListener);

        if (userServiceArgs != null && Shizuku.pingBinder()) {
            try {
                Shizuku.unbindUserService(userServiceArgs, shellServiceConnection, true);
            } catch (RuntimeException ignored) {
                // Shizuku may already have stopped while the Activity is being destroyed.
            }
        }
        worker.shutdownNow();
        super.onDestroy();
    }

    private void buildInterface() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        int horizontal = dp(22);
        page.setPadding(horizontal, dp(28), horizontal, dp(28));
        scroll.addView(page);

        TextView title = new TextView(this);
        title.setText("FlipdexOS");
        title.setTextSize(30);
        title.setPadding(0, 0, 0, dp(8));
        page.addView(title);

        TextView subtitle = new TextView(this);
        subtitle.setText("Bureau Android indépendant · Galaxy Z Flip6");
        subtitle.setTextSize(16);
        page.addView(subtitle);

        deviceSummary = section(page, "Appareil");
        shizukuStatus = section(page, "Shizuku");
        shizukuStatus.setText("État en cours de vérification…");

        serviceDetails = section(page, "Diagnostic du service");
        serviceDetails.setText("Le service n'est pas encore connecté. Il expose des lectures système "
                + "et une liste fermée de trois réglages Android.");

        connectButton = button(page, "Vérifier et connecter Shizuku");
        connectButton.setOnClickListener(view -> requestShizukuAccess());

        Button previewButton = button(page, "Aperçu du bureau sur ce téléphone");
        previewButton.setOnClickListener(view ->
                startActivity(new Intent(this, DesktopActivity.class)));

        Button shizukuHelp = button(page, "Installer / ouvrir Shizuku");
        shizukuHelp.setOnClickListener(view -> {
            Intent intent = new Intent(Intent.ACTION_VIEW,
                    Uri.parse("https://shizuku.rikka.app/download/"));
            startActivity(intent);
        });

        TextView note = new TextView(this);
        note.setText("Le bureau définitif est lancé sur l'écran virtuel créé par le Chromebook. "
                + "L'écran principal du téléphone reste indépendant. "
                + "Cette application ne modifie aucun réglage système automatiquement.");
        note.setTextSize(14);
        note.setPadding(0, dp(18), 0, 0);
        page.addView(note);

        setContentView(scroll);
    }

    private TextView section(LinearLayout parent, String heading) {
        TextView title = new TextView(this);
        title.setText(heading);
        title.setTextSize(19);
        title.setPadding(0, dp(22), 0, dp(7));
        parent.addView(title);
        TextView body = new TextView(this);
        body.setTextSize(15);
        parent.addView(body);
        return body;
    }

    private Button button(LinearLayout parent, String text) {
        Button button = new Button(this);
        button.setText(text);
        button.setAllCaps(false);
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT);
        params.topMargin = dp(12);
        parent.addView(button, params);
        return button;
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private void postRefreshShizukuStatus() {
        mainHandler.post(() -> {
            if (!isFinishing() && !isDestroyed()) {
                refreshShizukuStatus();
            }
        });
    }

    private void refreshShizukuStatus() {
        if (shizukuStatus == null || connectButton == null || isDestroyed()) {
            return;
        }
        boolean binderAlive = Shizuku.pingBinder();
        if (!binderAlive) {
            shizukuStatus.setText("Serveur indisponible · démarre Shizuku puis vérifie de nouveau.");
            connectButton.setEnabled(true);
            return;
        }
        try {
            int permission = Shizuku.checkSelfPermission();
            if (permission == PackageManager.PERMISSION_GRANTED) {
                shizukuStatus.setText("Binder actif · autorisation FlipdexOS accordée.");
                connectButton.setText("Reconnecter le service Shizuku");
            } else {
                shizukuStatus.setText("Binder actif · autorisation FlipdexOS à accorder.");
                connectButton.setText("Autoriser FlipdexOS dans Shizuku");
            }
        } catch (RuntimeException exception) {
            shizukuStatus.setText("Binder détecté, mais l'état de permission n'a pas pu être lu.");
        }
        connectButton.setEnabled(true);
    }

    private void requestShizukuAccess() {
        if (!Shizuku.pingBinder()) {
            showStatus("Shizuku n'est pas actif. Ouvre Shizuku, démarre le serveur en mode ADB, puis réessaie.");
            return;
        }
        try {
            if (Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED) {
                Shizuku.requestPermission(SHIZUKU_PERMISSION_REQUEST);
                showStatus("Demande d'autorisation envoyée à Shizuku.");
                return;
            }
            bindShellService();
        } catch (RuntimeException exception) {
            showStatus("Connexion Shizuku impossible : " + safeMessage(exception));
        }
    }

    private void bindShellService() {
        if (shellService != null || serviceBinding) {
            if (shellService != null) inspectShellService(shellService);
            return;
        }
        try {
            ComponentName component = new ComponentName(this, ShellUserService.class);
            userServiceArgs = new Shizuku.UserServiceArgs(component)
                    .processNameSuffix("flipdexos")
                    .tag("flipdexos-shell-service")
                    .debuggable(BuildConfig.DEBUG)
                    .version(1)
                    .daemon(false);
            serviceBinding = true;
            connectButton.setEnabled(false);
            Shizuku.bindUserService(userServiceArgs, shellServiceConnection);
            showStatus("Démarrage du service Shizuku…");
        } catch (RuntimeException exception) {
            serviceBinding = false;
            connectButton.setEnabled(true);
            showStatus("Impossible de lier le service Shizuku : " + safeMessage(exception));
        }
    }

    private void inspectShellService(IFlipdexShellService service) {
        worker.execute(() -> {
            try {
                int uid = service.getUid();
                String model = service.getProperty("ro.product.model");
                String release = service.getProperty("ro.build.version.release");
                String api = service.getProperty("ro.build.version.sdk");
                String oneUi = DesktopSettings.formatOneUiVersion(
                        service.getProperty("ro.build.version.oneui"));

                String freeform = service.getGlobalSetting(DesktopSettings.ENABLE_FREEFORM);
                String desktop = service.getGlobalSetting(DesktopSettings.FORCE_DESKTOP);
                String resizable = service.getGlobalSetting(DesktopSettings.ENABLE_NON_RESIZABLE);

                String report = "Identité du service : UID " + uid
                        + ("2000".equals(String.valueOf(uid)) ? " (shell ADB)" : "")
                        + "\nTéléphone : " + model
                        + "\nAndroid : " + release + " · API " + api
                        + "\nOne UI : " + oneUi
                        + "\nFreeform : " + freeform
                        + "\nBureau sur écran externe : " + desktop
                        + "\nFenêtres non redimensionnables : " + resizable;

                mainHandler.post(() -> {
                    serviceDetails.setText(report);
                    connectButton.setEnabled(true);
                    connectButton.setText("Actualiser le diagnostic Shizuku");
                });
            } catch (Exception exception) {
                showStatus("Service connecté, mais le diagnostic a échoué : " + safeMessage(exception));
            }
        });
    }

    private void showStatus(String message) {
        mainHandler.post(() -> {
            if (shizukuStatus != null) shizukuStatus.setText(message);
            if (connectButton != null) connectButton.setEnabled(true);
        });
    }

    private String safeMessage(Throwable throwable) {
        String message = throwable.getMessage();
        return message == null || message.trim().isEmpty()
                ? throwable.getClass().getSimpleName() : message;
    }

    private static final class BuildInfo {
        private static String deviceLine() {
            return android.os.Build.MANUFACTURER + " " + android.os.Build.MODEL;
        }
    }
}
