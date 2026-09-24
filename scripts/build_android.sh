#!/usr/bin/env bash
set -euo pipefail

rm -rf build/android
mkdir -p build/android dist

create_app() {
  local dir="$1"
  local pkg="$2"
  local label="$3"
  local src="$4"
  local remote_url="$5"
  local needs_location="$6"
  local pkg_path
  pkg_path="$(echo "$pkg" | tr '.' '/')"

  mkdir -p "$dir/app/src/main/java/$pkg_path"
  mkdir -p "$dir/app/src/main/res/drawable"
  mkdir -p "$dir/app/src/main/assets/www"

  cat > "$dir/settings.gradle" <<'EOF'
pluginManagement {
  repositories {
    google()
    mavenCentral()
    gradlePluginPortal()
  }
}
dependencyResolutionManagement {
  repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
  repositories {
    google()
    mavenCentral()
  }
}
rootProject.name = "VaniApp"
include(":app")
EOF

  cat > "$dir/build.gradle" <<'EOF'
plugins {
  id 'com.android.application' version '9.4.0' apply false
}
EOF

  cat > "$dir/app/build.gradle" <<EOF
plugins { id 'com.android.application' }
android {
  namespace '$pkg'
  compileSdk 36
  defaultConfig {
    applicationId '$pkg'
    minSdk 26
    targetSdk 36
    versionCode 31
    versionName '3.1.0'
  }
  buildTypes { debug { minifyEnabled false } }
  compileOptions {
    sourceCompatibility JavaVersion.VERSION_17
    targetCompatibility JavaVersion.VERSION_17
  }
}
EOF

  cat > "$dir/app/src/main/AndroidManifest.xml" <<EOF
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-permission android:name="android.permission.INTERNET"/>
EOF
  if [[ "$needs_location" == "true" ]]; then
    cat >> "$dir/app/src/main/AndroidManifest.xml" <<'EOF'
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
EOF
  fi
  cat >> "$dir/app/src/main/AndroidManifest.xml" <<EOF
  <application
    android:allowBackup="false"
    android:usesCleartextTraffic="false"
    android:hardwareAccelerated="true"
    android:icon="@drawable/ic_launcher"
    android:roundIcon="@drawable/ic_launcher"
    android:label="$label"
    android:theme="@android:style/Theme.Material.Light.NoActionBar">
    <activity
      android:name=".MainActivity"
      android:exported="true"
      android:screenOrientation="portrait">
      <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
      </intent-filter>
    </activity>
  </application>
</manifest>
EOF

  cat > "$dir/app/src/main/res/drawable/ic_launcher_bg.xml" <<'EOF'
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
  <corners android:radius="24dp"/>
  <gradient android:angle="135" android:startColor="#7B4BE8" android:centerColor="#2E6BF4" android:endColor="#1FC5B7" android:type="linear"/>
</shape>
EOF

  cat > "$dir/app/src/main/res/drawable/ic_launcher_fg.xml" <<'EOF'
<vector xmlns:android="http://schemas.android.com/apk/res/android"
  android:width="108dp"
  android:height="108dp"
  android:viewportWidth="108"
  android:viewportHeight="108">
  <path android:fillColor="#FFFFFFFF"
    android:pathData="M22,29 L37,29 L54,66 L71,29 L86,29 L62,78 L46,78 Z"/>
</vector>
EOF

  cat > "$dir/app/src/main/res/drawable/ic_launcher.xml" <<'EOF'
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
  <item android:drawable="@drawable/ic_launcher_bg"/>
  <item android:drawable="@drawable/ic_launcher_fg"/>
</layer-list>
EOF

  cat > "$dir/app/src/main/java/$pkg_path/MainActivity.java" <<EOF
package $pkg;

import android.app.Activity;
import android.graphics.Color;
import android.os.Bundle;
import android.webkit.CookieManager;
import android.webkit.SslErrorHandler;
import android.net.http.SslError;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.GeolocationPermissions;
import android.content.pm.PackageManager;
import android.Manifest;

public class MainActivity extends Activity {
  private static final int LOCATION_REQUEST = 9001;
  private WebView web;
  private boolean usingRemote = true;
  private String pendingGeoOrigin;
  private GeolocationPermissions.Callback pendingGeoCallback;

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    web = new WebView(this);
    web.setBackgroundColor(Color.WHITE);

    WebSettings settings = web.getSettings();
    settings.setJavaScriptEnabled(true);
    settings.setDomStorageEnabled(true);
    settings.setDatabaseEnabled(true);
    settings.setAllowFileAccess(true);
    settings.setAllowContentAccess(true);
    settings.setGeolocationEnabled(true);
    settings.setJavaScriptCanOpenWindowsAutomatically(true);
    settings.setSupportMultipleWindows(false);
    CookieManager.getInstance().setAcceptCookie(true);
    CookieManager.getInstance().setAcceptThirdPartyCookies(web, true);

    web.setWebViewClient(new WebViewClient() {
      @Override public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
        if (request.isForMainFrame() && usingRemote) {
          usingRemote = false;
          view.loadUrl("file:///android_asset/www/index.html");
        }
      }
      @Override public void onReceivedSslError(WebView view, SslErrorHandler handler, SslError error) {
        handler.cancel();
      }
    });

    web.setWebChromeClient(new WebChromeClient() {
      @Override public void onGeolocationPermissionsShowPrompt(String origin, GeolocationPermissions.Callback callback) {
        if (android.os.Build.VERSION.SDK_INT < 23 ||
            checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
          callback.invoke(origin, true, false);
          return;
        }
        pendingGeoOrigin = origin;
        pendingGeoCallback = callback;
        requestPermissions(
          new String[]{Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION},
          LOCATION_REQUEST
        );
      }
    });

    usingRemote = true;
    web.loadUrl("$remote_url?v=20260924-1");
    setContentView(web);
  }

  @Override
  public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
    super.onRequestPermissionsResult(requestCode, permissions, grantResults);
    if (requestCode == LOCATION_REQUEST && pendingGeoCallback != null) {
      boolean granted = android.os.Build.VERSION.SDK_INT < 23 ||
          checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
          checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED;
      pendingGeoCallback.invoke(pendingGeoOrigin, granted, false);
      pendingGeoOrigin = null;
      pendingGeoCallback = null;
    }
  }

  @Override public void onBackPressed() {
    if (web.canGoBack()) web.goBack(); else super.onBackPressed();
  }
}
EOF

  cp "$src/index.html" "$dir/app/src/main/assets/www/index.html"
  cp "$src/app-config.js" "$dir/app/src/main/assets/www/app-config.js"
  cp "$src/supabase-client.js" "$dir/app/src/main/assets/www/supabase-client.js"
}

BASE="https://jaquelinhm9-dotcom.github.io/VaniDaxi/apps"
create_app build/android/VaniDaxi com.vanidaxi.app "VaniDaxi" web/VaniDaxi "$BASE/VaniDaxi/index.html" true
create_app build/android/VaniReparte com.vanidaxi.reparte "VaniReparte" web/VaniReparte "$BASE/VaniReparte/index.html" true

echo "Android projects generated."
