#!/usr/bin/env bash
set -euo pipefail

rm -rf build/android
mkdir -p build/android dist

create_app() {
  local dir="$1"
  local pkg="$2"
  local label="$3"
  local src="$4"
  local pkg_path
  pkg_path="$(echo "$pkg" | tr '.' '/')"

  mkdir -p "$dir/app/src/main/java/$pkg_path"
  mkdir -p "$dir/app/src/main/res/drawable"
  mkdir -p "$dir/app/src/main/res/mipmap-anydpi-v26"
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
plugins {
  id 'com.android.application'
}

android {
  namespace '$pkg'
  compileSdk 36

  defaultConfig {
    applicationId '$pkg'
    minSdk 26
    targetSdk 36
    versionCode 1
    versionName '1.0.0'
  }

  buildTypes {
    debug {
      minifyEnabled false
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
  <application
    android:allowBackup="false"
    android:usesCleartextTraffic="false"
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
  <path
    android:fillColor="#FFFFFFFF"
    android:pathData="M28,78 L54,25 L80,78 L68,78 L61,63 L47,63 L40,78 Z"/>
  <path
    android:fillColor="#FFFFFFFF"
    android:pathData="M50,54 L58,54 L54,44 Z"/>
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
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

public class MainActivity extends Activity {
  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);

    WebView web = new WebView(this);
    web.setBackgroundColor(Color.WHITE);

    WebSettings settings = web.getSettings();
    settings.setJavaScriptEnabled(true);
    settings.setDomStorageEnabled(true);
    settings.setAllowFileAccess(true);
    settings.setAllowContentAccess(true);
    settings.setDatabaseEnabled(true);

    web.setWebViewClient(new WebViewClient());
    web.setWebChromeClient(new WebChromeClient());
    web.loadUrl("file:///android_asset/www/index.html");

    setContentView(web);
  }
}
EOF

  cp "$src/index.html" "$dir/app/src/main/assets/www/index.html"
  cp "$src/app-config.js" "$dir/app/src/main/assets/www/app-config.js"
  cp "$src/supabase-client.js" "$dir/app/src/main/assets/www/supabase-client.js"

  cat > "$dir/app/src/main/assets/www/manifest.webmanifest" <<'EOF'
{"name":"VaniApp","short_name":"VaniApp","start_url":"./index.html","display":"standalone"}
EOF

  cat > "$dir/app/src/main/assets/www/sw.js" <<'EOF'
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));
EOF
}

create_app build/android/VaniDaxi com.vanidaxi.app "VaniDaxi" web/VaniDaxi
create_app build/android/VaniReparte com.vanidaxi.reparte "VaniReparte" web/VaniReparte
create_app build/android/Panel-Principal com.vanidaxi.admin "VaniDaxi Panel" web/Panel-Principal

echo "Android projects generated."
