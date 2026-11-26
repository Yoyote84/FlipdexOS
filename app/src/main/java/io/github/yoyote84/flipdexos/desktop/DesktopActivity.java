package io.github.yoyote84.flipdexos.desktop;

import android.app.Activity;
import android.app.ActivityOptions;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.os.Bundle;
import android.view.Gravity;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.text.Collator;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Locale;

/**
 * Lightweight desktop home screen. App launches are explicitly routed to this Activity's display.
 */
public final class DesktopActivity extends Activity {
    private LinearLayout appGrid;
    private final List<AppEntry> apps = new ArrayList<>();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        buildLayout();
        loadLaunchableApps();
        renderApps("");
    }

    private void buildLayout() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        int pad = dp(24);
        page.setPadding(pad, dp(20), pad, pad);
        scroll.addView(page);

        TextView title = new TextView(this);
        title.setText("FlipdexOS Desktop");
        title.setTextSize(28);
        page.addView(title);

        int displayId = getDisplay() == null ? 0 : getDisplay().getDisplayId();
        TextView subtitle = new TextView(this);
        subtitle.setText("Bureau secondaire · écran " + displayId);
        subtitle.setTextSize(14);
        subtitle.setPadding(0, dp(4), 0, dp(16));
        page.addView(subtitle);

        EditText search = new EditText(this);
        search.setSingleLine(true);
        search.setHint("Rechercher une application");
        page.addView(search, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));
        search.addTextChangedListener(new android.text.TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) { }
            @Override public void onTextChanged(CharSequence s, int start, int before, int count) {
                renderApps(s == null ? "" : s.toString());
            }
            @Override public void afterTextChanged(android.text.Editable s) { }
        });

        TextView section = new TextView(this);
        section.setText("Applications");
        section.setTextSize(19);
        section.setPadding(0, dp(18), 0, dp(8));
        page.addView(section);

        appGrid = new LinearLayout(this);
        appGrid.setOrientation(LinearLayout.VERTICAL);
        page.addView(appGrid, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        Button back = new Button(this);
        back.setText("Retour au panneau FlipdexOS");
        back.setAllCaps(false);
        back.setOnClickListener(view -> launchOnThisDisplay(
                new Intent(this, io.github.yoyote84.flipdexos.MainActivity.class)));
        LinearLayout.LayoutParams backParams = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT);
        backParams.topMargin = dp(20);
        page.addView(back, backParams);

        setContentView(scroll);
    }

    private void loadLaunchableApps() {
        apps.clear();
        Intent query = new Intent(Intent.ACTION_MAIN);
        query.addCategory(Intent.CATEGORY_LAUNCHER);
        List<ResolveInfo> matches = getPackageManager().queryIntentActivities(
                query, PackageManager.MATCH_DEFAULT_ONLY);

        for (ResolveInfo info : matches) {
            if (info.activityInfo == null) continue;
            String packageName = info.activityInfo.packageName;
            if (getPackageName().equals(packageName)) continue;
            CharSequence label = info.loadLabel(getPackageManager());
            apps.add(new AppEntry(label == null ? packageName : label.toString(), packageName));
        }

        Collator collator = Collator.getInstance(Locale.getDefault());
        Collections.sort(apps, (left, right) -> collator.compare(left.label, right.label));
    }

    private void renderApps(String filter) {
        if (appGrid == null) return;
        appGrid.removeAllViews();
        String needle = filter == null ? "" : filter.trim().toLowerCase(Locale.ROOT);
        int shown = 0;
        for (AppEntry app : apps) {
            if (!needle.isEmpty()
                    && !app.label.toLowerCase(Locale.ROOT).contains(needle)
                    && !app.packageName.toLowerCase(Locale.ROOT).contains(needle)) {
                continue;
            }
            Button tile = new Button(this);
            tile.setAllCaps(false);
            tile.setGravity(Gravity.CENTER_VERTICAL | Gravity.START);
            tile.setText(app.label + "\n" + app.packageName);
            tile.setOnClickListener(view -> openApplication(app.packageName));
            LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT);
            params.bottomMargin = dp(7);
            appGrid.addView(tile, params);
            shown++;
        }
        if (shown == 0) {
            TextView empty = new TextView(this);
            empty.setText("Aucune application trouvée.");
            empty.setPadding(0, dp(12), 0, dp(12));
            appGrid.addView(empty);
        }
    }

    private void openApplication(String packageName) {
        Intent launch = getPackageManager().getLaunchIntentForPackage(packageName);
        if (launch == null) {
            Toast.makeText(this, "Cette application ne fournit pas de lanceur.", Toast.LENGTH_SHORT).show();
            return;
        }
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
        launchOnThisDisplay(launch);
    }

    private void launchOnThisDisplay(Intent intent) {
        int displayId = getDisplay() == null ? 0 : getDisplay().getDisplayId();
        try {
            ActivityOptions options = ActivityOptions.makeBasic();
            options.setLaunchDisplayId(displayId);
            startActivity(intent, options.toBundle());
        } catch (RuntimeException exception) {
            Toast.makeText(this,
                    "Android a refusé l'ouverture sur cet écran : " + exception.getMessage(),
                    Toast.LENGTH_LONG).show();
        }
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private static final class AppEntry {
        final String label;
        final String packageName;
        AppEntry(String label, String packageName) {
            this.label = label;
            this.packageName = packageName;
        }
    }
}
