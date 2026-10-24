# Fire TV Stick AFTSS cleanup

A tested, reversible way to debloat one specific Fire TV Stick and give it a home screen without ads.
Everything here was run on a real stick, and the results are written down so anyone with the same
stick can repeat it.

- Disables 62 Amazon packages (telemetry, ads, promos, extras). They are disabled, never uninstalled,
  so `pm enable` brings each one back.
- Blocks the loggers Fire OS won't let you disable, using Android Private DNS.
- Turns off Amazon's privacy-invading defaults from the Settings menus.
- Swaps the ad-filled Amazon home for the open-source cleanyourtv launcher, with a small
  accessibility service that sends the Home button there.

No root, no flashing, no bootloader unlock. Fire OS updates still install.

## Device: check yours matches

| | |
|---|---|
| Product | Amazon Fire TV Stick, model code **AFTSS** (codename `sheldon`). Amazon sells it as the *Fire TV Stick Lite (2020)*; some people know it as the "Fire TV Stick HD". |
| Firmware | **Fire OS 7.7.1.7 (PS7717/5741)**, Android 9 / SDK 28 |
| Tested in | Canada |

After you enable ADB (step 0), check:

```bash
adb shell getprop ro.product.model          # must print AFTSS
adb shell getprop ro.build.version.name     # should contain 7.7.1.7 (PS7717/5741)
```

`debloat.sh` checks both and stops if they don't match (set `FORCE=1` to override). On another
model or Fire OS build, package names and protections can differ. Read the list before you run it.

[NikhilSiddhu/firetv-tvos](https://github.com/NikhilSiddhu/firetv-tvos) was built on the
**AFTSSS** (Fire TV Stick 3rd gen) with the same Fire OS build. Its home watcher, used in step 4,
also works on the AFTSS.

## What it does and doesn't do

**Does**

- Gets rid of the sponsored rows, the hero rotator and the promo tiles by replacing the home screen.
- Stops most Amazon telemetry, either by disabling the package or by blocking it at DNS.
- Keeps working: Netflix, Prime Video, Alexa voice search on the remote, casting, the Appstore,
  Fire TV Settings and OTA updates. All of these were tested after a reboot.

**Doesn't**

- Remove Amazon's launcher. It is a protected package and stays installed underneath.
- Remove ads *inside* apps. Prime Video still shows its own in-app promos.
- Replace Fire OS. The bootloader is locked; this only changes what runs on top of it.

## Requirements

- `adb` (Android platform-tools) on a computer on the same network as the stick.
- For step 4: JDK 17, the Android SDK, and `git`, to build two APKs from source.

## Step 0: enable ADB

1. On the TV: **Settings → My Fire TV → About**, then click the device name 7 times until it says
   you are a developer.
2. **Settings → My Fire TV → Developer Options → ADB Debugging → ON**.
3. Find the stick's IP under **Settings → My Fire TV → About → Network**.
4. On the computer:

   ```bash
   export TV_HOST=<stick-ip>        # your stick's IP, for example 192.168.0.42
   adb connect "$TV_HOST:5555"      # then accept the prompt on the TV
   ```

All the scripts read the stick's address from `TV_HOST` and talk to it with
`adb -s "$TV_HOST:5555"`.

## Step 1: debloat

```bash
./debloat.sh            # uses debloat.txt
adb -s "$TV_HOST:5555" reboot
```

[`debloat.txt`](debloat.txt) is one package per line, with `#` comments. The script runs
`pm disable-user --user 0` for each line, skips anything that isn't a bare package name, retries a
failure once, and prints `OK` / `FAIL` / `SKIP` for every line plus a summary.

What's in the list:

- **Sections 1 to 4 (48 packages):** the tested cleanyourtv list for this stick,
  [`examples/amazon-fire-tv-stick-lite-2020/debloat.txt`](https://github.com/Gathin23/cleanyourtv/tree/main/examples/amazon-fire-tv-stick-lite-2020).
  It covers telemetry, ads/recommendations/shopping, preloaded Amazon apps and setup helpers, and
  Alexa extras. `com.amazon.tv.livetv` needed a second attempt, which the script retries for you.
- **Section 5 (14 extras):** the `com.amazon.dummy.*` placeholder stubs, miniTV,
  `com.amazon.stillwatching.activity` (the "Are you still watching?" prompt),
  `com.amazon.spotify.mediabrowserservice` (the Alexa-to-Spotify bridge; the Spotify app still
  works), Matter, the notification center, legal notices/resources and the troubleshooting helper.
- **Section 6 (optional, commented out):** Amazon Kids (`com.amazon.tahoe`), Amazon Music
  (`com.amazon.bueller.music`) and Amazon Photos (`com.amazon.bueller.photos`). Remove the `# `
  in front of any you don't use.

Result on the test stick: all 62 disabled, all still disabled after a reboot.

**Protected packages.** Fire OS refuses both `pm disable-user` and `pm suspend` for these, so they
appear in the list only as comments:

```
com.amazon.minerva.client.api     com.amazon.device.logmanager     com.amazon.device.crashmanager
com.amazon.diode                  com.fireos.usagestats.proxy      com.amazon.ftvads.deeplinking
com.amazon.tv.csapp               com.amazon.tv.launcher
```

Step 2 blocks what they report to.

## Step 2: block the protected loggers at DNS

```bash
./privacy-dns.sh on
```

This sets Android Private DNS (DNS over TLS) to AdGuard DNS:

```bash
settings put global private_dns_specifier dns.adguard-dns.com
settings put global private_dns_mode hostname
```

Then it checks two names. With DNS on, `device-metrics-us.amazon.com` resolves to `127.0.0.1`
(blocked) and Netflix resolves normally. That's what we saw on the test stick. To use another
DNS-over-TLS resolver, set `DNS_HOST=...`.

## Step 3: privacy toggles (with the remote)

These can't be set over ADB on this build: the settings intents are refused or not exported.
Use the remote:

- **Settings → Preferences → Privacy Settings**
  - **Device Usage Data → OFF.** On this build that also turned off *Collect App Usage Data* and
    *Interest-based Ads*. Check that all three are OFF.
  - **Manage Sharing from Apps → Viewing and Content Info → Off.**
- **Settings → Preferences → Featured Content**
  - **Allow Video Autoplay → OFF**
  - **Allow Audio Autoplay → OFF**

## Step 4: home screen without ads

Amazon's launcher (`com.amazon.tv.launcher`) is protected, so you can't disable it.
`cmd package set-home-activity` alone doesn't help either, because Amazon's launcher still takes
Home. The setup uses two apps that you build yourself from source:

| App | Package | Source |
|---|---|---|
| Launcher | `com.gathin.tvhome` | [Gathin23/cleanyourtv](https://github.com/Gathin23/cleanyourtv), `launcher/` (MIT) |
| Home watcher | `com.firetv.tvos` | [NikhilSiddhu/firetv-tvos](https://github.com/NikhilSiddhu/firetv-tvos), `home-watcher/` |

**How the home watcher works** (summarised here; all credit to NikhilSiddhu/firetv-tvos). It is an
accessibility service. When it sees Amazon's *home* screen come to the foreground, it draws a
black overlay so you never see the ad-filled home. Then it schedules an immediate AlarmManager
alarm whose PendingIntent opens the new launcher. Because `system_server` performs the launch, it
skips the roughly 5-second hold that Fire OS puts on app launches right after Home. The overlay
lifts once the launcher is up. The watcher only acts on Amazon's home screen classes, so Fire TV
Settings, which also lives in `com.amazon.tv.launcher`, still opens.

> The firetv-tvos repository has no license, so this repo contains none of its code, APKs, themes
> or lists. Clone it and build it yourself, as shown below.

### Build the two APKs

Both projects use AGP 8.5.2 / Gradle 8.9 and need **JDK 17**. JDK 24 and 25 fail. They also need
Android SDK Platform 34 and Build-Tools 34, which Gradle installs by itself once the SDK licenses
are accepted (`yes | sdkmanager --licenses`). Both release builds are signed with the debug key,
which is fine for sideloading.

```bash
export JAVA_HOME=/path/to/jdk-17
export ANDROID_SDK=/path/to/Android/Sdk

git clone https://github.com/Gathin23/cleanyourtv.git
(cd cleanyourtv/launcher && echo "sdk.dir=$ANDROID_SDK" > local.properties && ./gradlew assembleRelease)
# -> cleanyourtv/launcher/app/build/outputs/apk/release/app-release.apk

git clone https://github.com/NikhilSiddhu/firetv-tvos.git
(cd firetv-tvos/home-watcher && echo "sdk.dir=$ANDROID_SDK" > local.properties && ./gradlew assembleRelease)
# -> firetv-tvos/home-watcher/app/build/outputs/apk/release/app-release.apk
```

Build the watcher from source. Don't use the prebuilt APKs in that repo's `dist/`.

### Install and wire it

```bash
./install-home.sh \
  cleanyourtv/launcher/app/build/outputs/apk/release/app-release.apk \
  firetv-tvos/home-watcher/app/build/outputs/apk/release/app-release.apk \
  [optional-theme-config.json]
```

The script installs both APKs and runs:

```bash
settings put secure enabled_accessibility_services com.firetv.tvos/com.firetv.tvos.HomeWatcherService
settings put secure accessibility_enabled 1
appops set com.firetv.tvos SYSTEM_ALERT_WINDOW allow        # the black overlay
settings put global alarm_manager_constants min_futurity=0   # lets the alarm fire immediately
cmd package set-home-activity com.gathin.tvhome/.MainActivity
```

If other accessibility services are already enabled, the script adds the watcher to them instead
of replacing them. If you pass a third argument, it is pushed as the launcher theme to
`/sdcard/Android/data/com.gathin.tvhome/files/config.json`. See the cleanyourtv launcher docs for
the format.

Verified on the test stick: Home opens the new launcher; Netflix then Home goes back to the new
launcher; after a reboot the stick lands on the new launcher. Fire TV Settings still opens with:

```bash
adb -s "$TV_HOST:5555" shell am start -n com.amazon.tv.launcher/.ui.MainSettingsActivity
```

## Step 5: turn ADB off again

The watcher doesn't need ADB. When you're done:
**Settings → My Fire TV → Developer Options → ADB Debugging → OFF**.

## Undo

| To undo | Run |
|---|---|
| Home screen (step 4) | `./uninstall-home.sh`. Removes the watcher from accessibility, uninstalls both apps, resets `alarm_manager_constants`. Amazon's launcher takes Home again. |
| DNS (step 2) | `./privacy-dns.sh off`, i.e. `settings put global private_dns_mode off` |
| Debloat (step 1) | `./restore.sh`, then reboot. Runs `pm enable --user 0` for every line in the list. |
| Privacy toggles (step 3) | Switch them back on in the same menus. |
| Everything | A factory reset also undoes all of it. |

## Known limits

- **Protected packages** (listed in step 1) can't be disabled or suspended. DNS blocking is the
  only lever for them.
- **Prime Video in-app promos remain.** They're part of the Prime Video app, not the home screen.
- **Home briefly shows black** while the watcher swaps Amazon's home for the new launcher.
- Packages missing from your stick fail with `Unknown package`, which is harmless.
- A Fire OS update could re-enable packages or change what's protected. Run `debloat.sh` again
  after an update and check the output.

## Credits

- [Gathin23/cleanyourtv](https://github.com/Gathin23/cleanyourtv) (MIT): the base debloat list
  for this stick and the `com.gathin.tvhome` launcher.
- [NikhilSiddhu/firetv-tvos](https://github.com/NikhilSiddhu/firetv-tvos): the home watcher
  (`com.firetv.tvos`) and the AlarmManager approach for sending Home to another launcher on Fire OS.
- [AdGuard DNS](https://adguard-dns.io/): the blocking resolver used in step 2.

## License

MIT, see [LICENSE](LICENSE). `debloat.txt` is derived from cleanyourtv and keeps its MIT notice.
