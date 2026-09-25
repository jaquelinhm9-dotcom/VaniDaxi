#!/usr/bin/env bash
set -euo pipefail
rm -rf build/android
mkdir -p build/android
V="${APP_VERSION:-1.0.0}"; C="${APP_VERSION_CODE:-1}"
app(){ d="$1"; p="$2"; label="$3"; src="$4"; a="$5"; b="$6"; q=$(echo "$p"|tr . /); mkdir -p "$d/app/src/main/java/$q" "$d/app/src/main/res/drawable" "$d/app/src/main/assets/www"; cat >"$d/settings.gradle"<<'EOF'
pluginManagement{repositories{google();mavenCentral();gradlePluginPortal()}}
dependencyResolutionManagement{repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS);repositories{google();mavenCentral()}}
rootProject.name="VaniClean";include(":app")
EOF
cat >"$d/build.gradle"<<'EOF'
plugins{ id 'com.android.application' version '9.4.0' apply false }
EOF
cat >"$d/app/build.gradle"<<EOF
plugins{ id 'com.android.application' }
android{ namespace '$p'; compileSdk 36
defaultConfig{applicationId '$p';minSdk 26;targetSdk 36;versionCode $C;versionName '$V'}
buildTypes { debug { minifyEnabled false }; release { minifyEnabled false } }
compileOptions{sourceCompatibility JavaVersion.VERSION_17;targetCompatibility JavaVersion.VERSION_17}}
EOF
cat >"$d/app/src/main/AndroidManifest.xml"<<EOF
<manifest xmlns:android="http://schemas.android.com/apk/res/android"><uses-permission android:name="android.permission.INTERNET"/><uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/><uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/><application android:theme="@android:style/Theme.Material.Light.NoActionBar" android:label="$label" android:icon="@drawable/ic"><activity android:name=".MainActivity" android:exported="true" android:screenOrientation="portrait"><intent-filter><action android:name="android.intent.action.MAIN"/><category android:name="android.intent.category.LAUNCHER"/></intent-filter></activity></application></manifest>
EOF
cat >"$d/app/src/main/res/drawable/ic.xml"<<EOF
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle"><corners android:radius="22dp"/><gradient android:angle="135" android:startColor="$a" android:centerColor="$b" android:endColor="$a"/></shape>
EOF
cat >"$d/app/src/main/java/$q/MainActivity.java"<<EOF
package $p;
import android.app.*;import android.os.*;import android.webkit.*;import android.Manifest;import android.content.pm.PackageManager;
public class MainActivity extends Activity{WebView w;String po;GeolocationPermissions.Callback cb;final int R=12;public void onCreate(Bundle b){super.onCreate(b);w=new WebView(this);WebSettings s=w.getSettings();s.setJavaScriptEnabled(true);s.setDomStorageEnabled(true);s.setAllowFileAccess(true);s.setAllowContentAccess(true);s.setAllowUniversalAccessFromFileURLs(true);s.setAllowFileAccessFromFileURLs(true);s.setGeolocationEnabled(true);w.setWebChromeClient(new WebChromeClient(){public void onGeolocationPermissionsShowPrompt(String o,GeolocationPermissions.Callback c){if(checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED||checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)==PackageManager.PERMISSION_GRANTED)c.invoke(o,true,false);else{po=o;cb=c;requestPermissions(new String[]{Manifest.permission.ACCESS_FINE_LOCATION,Manifest.permission.ACCESS_COARSE_LOCATION},R);}}});w.loadUrl("file:///android_asset/www/index.html");setContentView(w);}}
EOF
cp "$src/index.html" "$d/app/src/main/assets/www/index.html";cp "$src/app-config.js" "$d/app/src/main/assets/www/app-config.js";cp "$src/supabase-client.js" "$d/app/src/main/assets/www/supabase-client.js";}
app build/android/VaniDaxi com.vanidaxi.app VaniDaxi web/VaniDaxi "#5B1CFF" "#F046D7"
app build/android/VaniReparte com.vanidaxi.reparte VaniReparte web/VaniReparte "#087E5A" "#20E7A1"
