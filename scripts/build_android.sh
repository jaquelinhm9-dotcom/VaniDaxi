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
<manifest xmlns:android="http://schemas.android.com/apk/res/android"><uses-permission android:name="android.permission.INTERNET"/><application android:theme="@android:style/Theme.Material.Light.NoActionBar" android:label="$label" android:icon="@drawable/ic"><activity android:name=".MainActivity" android:exported="true" android:screenOrientation="portrait"><intent-filter><action android:name="android.intent.action.MAIN"/><category android:name="android.intent.category.LAUNCHER"/></intent-filter></activity></application></manifest>
EOF
cat >"$d/app/src/main/res/drawable/ic_bg.xml"<<EOF
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle"><corners android:radius="22dp"/><gradient android:angle="135" android:startColor="$a" android:centerColor="$b" android:endColor="$a"/></shape>
EOF
if [[ "$p" == "com.vanidaxi.app" ]]; then
  cat >"$d/app/src/main/res/drawable/ic_fg.xml"<<'EOF'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
<path android:fillColor="#FF151118" android:pathData="M28,35 L80,35 L74,82 L34,82 Z"/>
<path android:fillColor="#FF151118" android:pathData="M39,35 C39,15 69,15 69,35 L62,35 C62,22 46,22 46,35 Z"/>
<path android:fillColor="#FFFFFFFF" android:pathData="M46,48 L54,60 L62,48 L58,47 L54,54 L50,47 Z"/>
</vector>
EOF
else
  cat >"$d/app/src/main/res/drawable/ic_fg.xml"<<'EOF'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
<path android:fillColor="#FF052018" android:pathData="M22,63 L77,63 L70,73 L35,73 Z"/>
<path android:fillColor="#FF052018" android:pathData="M57,38 L77,38 L83,47 L72,47 Z"/>
<path android:fillColor="#FF052018" android:pathData="M49,47 L60,47 L60,65 L49,65 Z"/>
<path android:fillColor="#FFFFFFFF" android:pathData="M23,77 C23,68 36,68 36,77 C36,85 23,85 23,77 Z"/>
<path android:fillColor="#FFFFFFFF" android:pathData="M68,77 C68,68 81,68 81,77 C81,85 68,85 68,77 Z"/>
</vector>
EOF
fi
cat >"$d/app/src/main/res/drawable/ic.xml"<<'EOF'
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
<item android:drawable="@drawable/ic_bg"/>
<item android:drawable="@drawable/ic_fg"/>
</layer-list>
EOF
cat >"$d/app/src/main/java/$q/MainActivity.java"<<'EOF'
package $p;
import android.app.*;import android.os.*;import android.webkit.*;import android.graphics.Color;import java.io.*;import java.nio.charset.StandardCharsets;
public class MainActivity extends Activity{
  WebView w;
  private String asset(String p)throws Exception{InputStream in=getAssets().open(p);ByteArrayOutputStream out=new ByteArrayOutputStream();byte[] b=new byte[8192];int n;while((n=in.read(b))!=-1)out.write(b,0,n);in.close();return out.toString(StandardCharsets.UTF_8.name());}
  private String page()throws Exception{String h=asset("www/index.html");h=h.replace("<script src=\"app-config.js\"></script>","<script>"+asset("www/app-config.js")+"</script>");h=h.replace("<script src=\"supabase-client.js\"></script>","<script>"+asset("www/supabase-client.js")+"</script>");return h;}
  public void onCreate(Bundle b){super.onCreate(b);w=new WebView(this);WebSettings s=w.getSettings();s.setJavaScriptEnabled(true);s.setDomStorageEnabled(true);s.setAllowFileAccess(false);s.setAllowContentAccess(false);w.setBackgroundColor(Color.WHITE);w.setWebViewClient(new WebViewClient(){@Override public void onReceivedError(WebView v,WebResourceRequest r,WebResourceError e){if(r==null||r.isForMainFrame()){v.loadDataWithBaseURL(null,"<html><body style=\"font-family:sans-serif;padding:24px\"><h2>VaniDaxi</h2><p>No se pudo cargar la aplicación.</p></body></html>","text/html","UTF-8",null);}}});setContentView(w,new android.view.ViewGroup.LayoutParams(-1,-1));try{w.loadDataWithBaseURL("https://appassets.androidplatform.net/assets/www/",page(),"text/html","UTF-8",null);}catch(Exception e){w.loadDataWithBaseURL(null,"<html><body style=\"font-family:sans-serif;padding:24px\"><h2>VaniDaxi</h2><p>Error de carga.</p></body></html>","text/html","UTF-8",null);}}
  @Override protected void onDestroy(){if(w!=null)w.destroy();super.onDestroy();}
}
EOF
cp "$src/index.html" "$d/app/src/main/assets/www/index.html";cp "$src/app-config.js" "$d/app/src/main/assets/www/app-config.js";cp "$src/supabase-client.js" "$d/app/src/main/assets/www/supabase-client.js";}
app build/android/VaniDaxi com.vanidaxi.app VaniDaxi web/VaniDaxi "#5B1CFF" "#F046D7"
app build/android/VaniReparte com.vanidaxi.reparte VaniReparte web/VaniReparte "#087E5A" "#20E7A1"
