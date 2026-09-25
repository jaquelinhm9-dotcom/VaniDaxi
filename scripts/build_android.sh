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
  local app_version="${APP_VERSION:-4.2.0}"
  local version_code="${APP_VERSION_CODE:-42}"
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
    versionCode $version_code
    versionName '$app_version'
  }
  signingConfigs {
    if (System.getenv("PLAY_KEYSTORE_FILE") && System.getenv("PLAY_KEY_ALIAS") && System.getenv("PLAY_STORE_PASSWORD") && System.getenv("PLAY_KEY_PASSWORD")) {
      playRelease {
        storeFile file(System.getenv("PLAY_KEYSTORE_FILE"))
        storePassword System.getenv("PLAY_STORE_PASSWORD")
        keyAlias System.getenv("PLAY_KEY_ALIAS")
        keyPassword System.getenv("PLAY_KEY_PASSWORD")
      }
    }
  }

  buildTypes {
    debug { minifyEnabled false }
    release {
      minifyEnabled false
      if (System.getenv("PLAY_KEYSTORE_FILE") && System.getenv("PLAY_KEY_ALIAS") && System.getenv("PLAY_STORE_PASSWORD") && System.getenv("PLAY_KEY_PASSWORD")) {
        signingConfig signingConfigs.playRelease
      }
    }
  }
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

  if [[ "$pkg" == "com.vanidaxi.app" ]]; then
    ICON_START="#5B1CFF"; ICON_CENTER="#A42EFF"; ICON_END="#F046D7"
  else
    ICON_START="#087E5A"; ICON_CENTER="#0BBE7F"; ICON_END="#20E7A1"
  fi
  cat > "$dir/app/src/main/res/drawable/ic_launcher_bg.xml" <<EOF
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
  <corners android:radius="24dp"/>
  <gradient android:angle="135" android:startColor="$ICON_START" android:centerColor="$ICON_CENTER" android:endColor="$ICON_END" android:type="linear"/>
</shape>
EOF

  if [[ "$pkg" == "com.vanidaxi.app" ]]; then
    cat > "$dir/app/src/main/res/drawable/ic_launcher_fg.xml" <<'EOF'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
  <path android:fillColor="#FF16111B" android:pathData="M28,38 L80,38 L74,82 L34,82 Z"/>
  <path android:fillColor="#FF16111B" android:pathData="M38,38 C38,18 70,18 70,38 L63,38 C63,25 45,25 45,38 Z"/>
  <path android:fillColor="#FFFFFFFF" android:pathData="M45,50 L54,61 L63,50 L59,49 L54,55 L49,49 Z"/>
</vector>
EOF
  else
    cat > "$dir/app/src/main/res/drawable/ic_launcher_fg.xml" <<'EOF'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
  <path android:fillColor="#FF052018" android:pathData="M24,62 L76,62 L69,73 L35,73 Z"/>
  <path android:fillColor="#FF052018" android:pathData="M61,38 L79,38 L84,46 L73,46 Z"/>
  <path android:fillColor="#FF052018" android:pathData="M50,48 L61,48 L61,65 L49,65 Z"/>
  <path android:fillColor="#FFFFFFFF" android:pathData="M22,75 C22,67 35,67 35,75 C35,83 22,83 22,75 Z"/>
  <path android:fillColor="#FFFFFFFF" android:pathData="M67,75 C67,67 80,67 80,75 C80,83 67,83 67,75 Z"/>
</vector>
EOF
  fi

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

    usingRemote = false;
    web.loadUrl("file:///android_asset/www/index.html");
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
create_app build/android/VaniDaxi com.vanidaxi.app "VaniDaxi" web/VaniDaxi "$BASE/VaniDaxi/index.html?v=4.2.0" true
create_app build/android/VaniReparte com.vanidaxi.reparte "VaniReparte" web/VaniReparte "$BASE/VaniReparte/index.html?v=4.2.0" true

echo "Android projects generated."
