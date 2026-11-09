# CampusHub Mobile Network Connectivity & Troubleshooting Guide

## Mobile login reachability and database-selection conflict — November 9, 2026

### 1. Cause / reason

The reported connection message was not reproduced in credential-free Android checks: both ADB loopback and the current PC Wi-Fi address reached Django's catalog and login validation. A confirmed helper gap was found: ADB exposes the same authorized phone through IP and discovery-name transports, but the old default helper skipped forwarding whenever more than one transport appeared. This can leave mappings unrefreshed after reconnecting; the helper now resolves verified aliases safely.

Database intent also conflicts across local sessions. At the start, both private files selected PC PostgreSQL :5432. The user's mention of a live database prompted read-only verification and restoration of the previously authorized Kamatera :15432 selection. It connected successfully, but another session then restored :5432 again and documented a deliberate local-development/loading request. The later active-file timestamps and current project notes confirm the second change. **Latest observed selection is PC PostgreSQL; further switches are paused pending the user's choice.** Do not describe the earlier successful Kamatera test as proof that it remains active.

### 2. Exact files changed / current anchors

| File / current line | Anchor | Change |
| --- | --- | --- |
| `campushub/scripts/connect_android.py:18` | `adb_command` | Close inherited stdin, decode UTF-8 and retain bounded literal arguments. |
| `campushub/scripts/connect_android.py:39` | `resolve_single_phone` | Resolve aliases only when every reported hardware identity matches; prefer USB, IP, then discovery. |
| `campushub/scripts/connect_android.py:66` | `main` | Use the verified single-phone resolver by default; preserve explicit `--device`. |
| `campushub/scripts/test_connect_android.py:14` | `AndroidForwardingSelectionTests` | Add alias, distinct/unknown hardware and unresponsive-transport regressions. |
| Private `backend/core/.env`, `backend/chat_service/.env` | Active `DATABASE_URL` | This task temporarily restored saved Kamatera URLs; another session subsequently restored local URLs. Latest local layout uses lines 11/2 with private inactive online comments. |
| This guide (`:3`), root `CAMPUSHUB_CONTEXT.md:3` | Current diagnostics note | Record scope, confirmed results and unresolved database intent. |

No Dart screens, AuthService, authentication rules, model, API route, migration or dependencies changed. No new APK is required for this helper-only code fix. The separate earlier monitor changes remain local and are not overwritten here.

### 3. Changes made

Restored both phone reverse mappings and tested actual Android HTTP requests. Improved the helper so two transports for a verified single phone do not cause automatic forwarding to skip. Different, unknown or unresponsive hardware identities remain ambiguous; no arbitrary second phone is selected and no transport is disconnected.

For the temporary Kamatera selection, saved exact previous settings in restricted `C:/Users/leste/.campushub-secrets/before-reconnect-kamatera-20261108T170044Z/` (UTC filename; November 9 locally). Only active `DATABASE_URL` values changed in that switch. Restarted only verified local Django/chat trees, including a leftover Uvicorn child whose port ownership/parent PID matched the inspected chat tree. The later separate local restoration remains in place; no further runtime change is made while clarification is pending.

### 4. How it works / functions, inputs, outputs and data flow

`connected_phone_serials(output)` preserves spaces in complete authorized serials. `resolve_single_phone(adb, devices)` immediately returns the only transport when one exists. With multiple transports, it reads each `ro.serialno` through literal, bounded ADB arguments. Matching nonempty, non-placeholder identities can be grouped; different or unknown values and probe timeouts return no automatic choice. USB is preferred over IP, then discovery. `main()` applies only the existing 8000/8001 reverse mappings; `--device` still selects one authorized transport explicitly. Tests mock ADB, so they do not touch a real phone.

Annotated example: `192.0.2.1:12345` and `adb-example (2)._adb-tls-connect._tcp` can resolve to one candidate only if both report the same hardware identity. That example uses a documentation/test address, not a real project server. Two different identities remain separate even when their model names match.

```text
Phone -> existing Django API on PC :8000 -> selected PostgreSQL database
       -> ADB loopback forwarding or existing PC Wi-Fi route
PC database mode: Django -> PC :5432/campushub
Kamatera mode:    Django -> SSH loopback :15432 -> existing Kamatera :5432/campushub
```

The existing Django `.env` loader/URL parser and chat Settings/SQLAlchemy engine select the database. The phone continues to call Django, never PostgreSQL directly. Service restarts are necessary after a URL change because running processes can retain old connections. Configuration comments alone do not select a database; the un-commented key does.

### 5. Backend / API behavior

An empty login POST `{}` returns 400 with `Username/email and password are required.` before account lookup/audit writes; this is deliberate validation, not failed connectivity or a successful sign-in. A temporary Java HTTP probe ran on the physical Android phone using the existing JDK/Android tools. Both `http://127.0.0.1:8000` via forwarding and current PC Wi-Fi `http://192.168.1.187:8000` returned recognized catalog JSON (200) and that login validation (400). The temporary diagnostic DEX was removed afterward; no application was replaced and no credentials were sent.

This probe ran under Android's shell, not through the Flutter login form. It verifies the network/route but does not establish actual credential acceptance. Earlier netcat probes returned no data and are inconclusive; a live Dart-origin probe did not find a usable VM endpoint. Those are not counted as successful checks. Existing AuthService, password checks, suspended-account rules and token issuance are unchanged.

### 6. Database / migration impact

During the temporary online selection, fresh active Django checks verified the original Kamatera `campushub`/role through client 15432, 48 tables/108 applied migrations, no pending migrations and no missing model tables/columns under enforced read-only mode. Chat's async driver independently confirmed the same destination in a read-only transaction. These are dated online-readiness results. The latest active URLs subsequently returned to local port 5432 through the other session's work.

No database creation, schema migration, restore, synchronization, account/password modification or order/payment/inventory write was performed. PC-only accounts and records were not copied online. Neither destination's credentials were moved into Flutter or Git.

### 7. Tests performed / safe practice

- **10 Python forwarding regressions passed:** USB/spaced-name/explicit/unauthorized handling, multiple-phone refusal, verified aliases, distinct/unknown hardware, unresponsive aliases and default forwarding arguments.
- Actual default forwarding succeeded while both matching phone aliases remained attached.
- Physical Android catalog/login validation checks passed over both routes. PC catalog/chat-health checks returned 200; PC empty-login validation returned 400 as expected.
- Original saved Kamatera and the temporary active Django/chat online checks passed. Fresh database/migration/schema checks made no writes.
- No real credential login, registration, password reset, application-data clear, Flutter-wide test rerun or public API deployment was performed in this task. Prior broader Flutter failures remain recorded below.

Ignored evidence is under root `scratch/mobile-login-20261109/`, including `CampusHubApiProbe.java`, `android-api-probe-live.log`, `phone-login-probe.json` and `live-http.json`. The latter filenames describe the moment tested, not an immutable ongoing database selection.

Safe exercise: run `backend/core/venv/Scripts/python.exe -m unittest discover -s campushub/scripts -p test_connect_android.py -v` from the project root, then the normal forwarding helper and `adb -s <device_id> reverse --list`. Expect passing mocked tests and both mappings. For login reachability, send only `{}` and expect required-field validation; use credentials only in the normal app. Confirm the selected database before testing accounts; do not create or copy users merely to conceal a destination mismatch.

### 8. Remaining limitations / troubleshooting

The exact earlier error text and real credential sign-in remain unverified; the user was asked for the error message without credentials. The latest local database choice is retained until the conflicting request is clarified. Once a mode is chosen, avoid simultaneous tasks selecting different databases, then verify both files and running processes consistently. An account existing only in one independent database may not authenticate in the other. Both current modes depend on PC Django being available to the phone; selecting an online database does not make the PC API a public hosted deployment.

## Ctrl+F5 build and launch repairs — November 8–9, 2026

### 1. Cause / reason

The earlier runtime recovery below started an already-installed APK; it did not rebuild current source. A real Flutter launch now reproduced a build failure: hosted `lucide_icons 0.257.0` declares `LucideIconData extends IconData`, while the installed Flutter 3.47.9 SDK declares `IconData` final. The compiler rejected that inheritance, so Ctrl+F5 could not produce a new application. This matches the [official IconData API](https://api.flutter.dev/flutter/widgets/IconData-class.html).

Two launch/setup issues were also confirmed. VS Code's read-only workspace state remembered `campushub (Flutter)`, but that name was absent from the root launch file. The phone's authorized wireless serial contains spaces, and `connect_android.py` incorrectly split it into separate fields and skipped forwarding. Both IP and discovery-name connections initially represented the same phone. After retaining discovery alone, the old helper still skipped; the repaired parser recognized it.

**Final follow-up on November 9: Flutter launch passed with exit code 0, and the rebuilt app's Home screen was visually verified on the unlocked phone.** The existing saved account session restored normally; product cards, facilities and navigation were visible. Earlier wireless startup checks were interrupted by a stale ADB transport and the phone relocking. Reconnecting only the confirmed phone restored shell commands. After the user unlocked again, a bounded read-only keyguard check confirmed `showing=false`, native cold launch succeeded, and the subsequent Flutter launch completed. No unlock/authentication was automated. A physical Ctrl+F5 keypress in VS Code remains untested because its Windows automation helper was unavailable; the configured build/install/Flutter-launch path was verified separately.

### 2. Exact files changed / current anchors

| File / current line | Anchor | Change |
| --- | --- | --- |
| Root `.vscode/launch.json:8` | `campushub (Flutter)` | Restore the remembered configuration with explicit mobile entrypoint, working directory and existing pre-launch task; preserve the other configurations. |
| `campushub/.vscode/launch.json:6` | `preLaunchTask` | Run the shared forwarding helper for all four Flutter-folder launch options too. |
| `campushub/.vscode/tasks.json:7` | `command` | Add the matching task using the existing Django Python interpreter and shared script. |
| `campushub/scripts/connect_android.py:25`, `:47` | `connected_phone_serials`, `devices` | Parse the final ADB state separately while retaining the entire serial. |
| `campushub/scripts/test_connect_android.py:13` | `AndroidForwardingSelectionTests` | Five isolated device-selection/forwarding regressions. |
| `campushub/pubspec.yaml:42` | `lucide_icons` | Select the local compatibility package. |
| `campushub/pubspec.lock:467` | `lucide_icons` | Record only this dependency change relative to the pre-task lock snapshot; preserve prior unrelated lockfile changes. |
| `campushub/packages/lucide_icons/pubspec.yaml:1` | `name: lucide_icons` | Local package identity, compatible SDK constraints and unchanged font-family/asset declaration. |
| `campushub/packages/lucide_icons/lib/lucide_icons.dart:5` | `class LucideIcons` | Preserve all 1,191 constants, constructing IconData directly in const contexts. |
| `campushub/packages/lucide_icons/assets/lucide.ttf` | Original binary font | Byte-identical upstream font; no regenerated glyphs. |
| `campushub/packages/lucide_icons/LICENSE:1`, `README.md:1` | ISC attribution / compatibility notes | Preserve upstream licensing and explain the narrow adaptation. |
| `campushub/docs/mobile_network_connectivity_guide.md:3`, root `CAMPUSHUB_CONTEXT.md:3` | This report / current context | Evidence, functions/data flow, exact limits and safe exercise. |

The `.vscode` files are local Git-ignored settings in these existing repositories; they were updated on disk, not committed. Include the local package directory with future application-source changes. No application-screen imports, business logic, database settings, global Pub cache or Flutter SDK files were edited.

### 3. Changes made

Restored the named launch configuration so the HTML file currently open in the editor does not become the Flutter entrypoint. Both workspace layouts use the same forwarding script. Its parser now preserves wireless names with spaces while keeping the existing refusal to automatically choose among multiple physical transports. Disconnected the verified redundant manual IP transport instead of repeatedly removing an automatically rediscovered alias.

Copied only the original Lucide constants, font and license into a small project-local package, changed constant construction to direct `IconData`, and selected it as a path dependency. `flutter pub get --offline` changed only Lucide relative to the saved pre-task lock snapshot. Did not upgrade other packages, change icons, edit the shared cache or bypass compiler checks. Tested actual debug builds/installs against the connected phone. Reset the stalled ADB server without deleting app data; its original IP transport later reconnected. Follow-up stale shell commands were repaired by disconnecting/reconnecting only the confirmed endpoint, without another global server reset. After the user physically unlocked and kept the phone awake, restored forwarding and launched the freshly built APK through Flutter successfully. No unlock/authentication was automated and no new source/configuration change was needed in this follow-up.

### 4. How it works / functions, inputs, outputs and data flow

`connected_phone_serials(output)` takes normal `adb devices` text and splits each line from the right only once. For `adb-example phone (2)._adb-tls-connect._tcp\tdevice`, the complete left part is the serial and the final word is the state. It returns only authorized physical serials; offline/unauthorized entries and emulators are excluded. `main()` keeps the existing optional `--device` selection, then `adb_command` forwards 8000/8001 using literal arguments. The tests replace these commands with mocks, so they never modify a real phone.

The local `LucideIcons` constants remain `IconData` objects with their original code points, `fontFamily: 'Lucide'` and `fontPackage: 'lucide_icons'`. For example, `static const IconData activity = IconData(0xf101, fontFamily: 'Lucide', fontPackage: 'lucide_icons')` uses an implicit const constructor because its initializer is const. This retains the prior glyph without extending a final class. The package name, font family and font bytes stay the same, so existing imports, tests and asset-loading paths still work. Source provenance: [published upstream 0.257.0 package](https://pub.dev/packages/lucide_icons/versions/0.257.0).

```text
Ctrl+F5 -> explicit Flutter launch configuration -> forwarding pre-task
 -> Flutter compiles lib/main.dart -> local compatible Lucide package
 -> Gradle builds debug APK -> ADB installs -> phone activity starts
```

F5 uses the same entrypoint with the debugger; Ctrl+F5 requests a run without debugger attachment. No hardcoded physical-device ID was added. Select the current phone in VS Code's device picker when its wireless endpoint changes.

### 5. Backend / API behavior

No Django/FastAPI/API, authentication, RBAC, fulfillment, payment or inventory behavior changed. Flutter continues to call Django over HTTP; forwarding still maps only existing Django 8000/chat 8001. The icon package contains no credentials or API configuration. On the final successful launch, the existing saved user session restored and normal Home/catalog reads occurred automatically; no login form or order/booking/stock/payment action was submitted. Visible Home cards verify actual startup, not every authenticated workflow or image/data source.

### 6. Database / migration impact

None. No database selection, credential, migration or direct database operation was part of this Ctrl+F5 repair. The previous approved Kamatera migration remains separate. The native app was updated in place through Flutter's normal install flow; no uninstall or app-data clear was used.

### 7. Tests performed

- November 9 pre-push full-suite check (`flutter test --no-pub`): **526 passed, 88 failed, 4 skipped**, exit 1 in 1m29s. This broader run is not a clean test result and does not replace the focused launch checks below. One confirmed example is `test/auth_form_responsive_test.dart:113`, which expects `Montserrat` while the actual style is `Inter`; the remaining failures were not all diagnosed in this Git publication task. Detailed ignored output: root `scratch/ctrl-f5-20261108/pre-push-mobile-tests.log`. No application typography or other business behavior was changed to suppress failures. Safe troubleshooting exercise: rerun only `flutter test --no-pub test/auth_form_responsive_test.dart`, compare its expected font with the current typography guide/implementation and establish the intended contract before proposing a separate fix.
- Five Python regressions passed: spaced wireless name, USB selection alongside nonready/emulator entries, multiple-device refusal, explicit spaced-name selection and unauthorized-device refusal. The live helper then restored both mappings using the full wireless name.
- Both workspace launch/task files parsed successfully; all eight Flutter configurations resolve an existing `main.dart`, working directory, matching pre-launch task and existing Python interpreter.
- All **1,191 icon-name/code-point pairs** match upstream. Original font and ISC license match byte-for-byte. Font SHA-256: `e21a594c69719165def809613bc595e526660d99deab628e04ea52c0b44e2127` (413,764 bytes).
- Focused Flutter tests: **10 passed, 4 intentionally skipped**, covering API configuration, product cards and dashboard header/layout/font loading.
- Final full analyzer run: **no errors or warnings**, four informational deprecation notices in existing `dashboard_screen.dart`, `facility_screen.dart`, `signup_screen.dart` and `campus_home_banners.dart`; analyzer exit 1, so a completely clean analysis is not claimed.
- Actual `flutter run --no-pub --debug --no-start-paused --no-resident`: original compile failure reproduced; fixed APK built (Gradle 162.8 seconds) and installed (9.2 seconds). After ADB recovery, a second launch also built incrementally (19.2 seconds) and installed (8.5 seconds), confirming the final source compiles. Device process remained alive; its log recorded a Dart VM service and no fatal/unhandled/Flutter errors in the captured window. Initial power/keyguard state was `Dozing`/locked. A temporary read-only VM-service probe timed out and is not counted as successful; its temporary forwarding was removed.
- November 9 unlocked follow-up: confirmed `showing=false`; native `.MainActivity` cold launch returned `Status: ok` in 1.882 seconds. Restored 8000/8001 forwarding with the shared helper. Ran `flutter run --no-pub --debug --no-start-paused --no-resident --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk -d <current_phone>` against the already-built final APK: installation 9.1 seconds, file sync 79ms, **launch exit code 0**. Actual screenshot inspected: authenticated Home with existing account, product cards/facilities/navigation. Final evidence: `scratch/ctrl-f5-20261108/{unlocked-verification.json,flutter-unlocked-launch.log,phone-confirmed.png}`. No app data was cleared.
- Direct Windows UI verification was unavailable: the computer-use helper repeatedly reported `native pipe is unavailable ... system cannot find the file specified`. This prevented an actual Ctrl+F5 keypress test; it did not prevent the file/CLI checks above. Ignored logs and aggregate evidence are in root `scratch/ctrl-f5-20261108/`.

### 8. Remaining limitations / safe practice

Final Flutter launch and visible Home are verified; the successful non-resident test exited normally and leaves the app installed/running. Choose **campushub (Flutter)** in the root workspace (or **CampusHub (selected device)** in the Flutter-folder workspace), select the current Infinix phone and press Ctrl+F5. Keep the phone unlocked/awake while wireless builds and startup complete. A physical VS Code shortcut test and full authenticated business workflows were not performed. If a future wireless endpoint changes, use the current address from the phone rather than a historical port. A stale wireless connection can need a disconnect/reconnect even while ADB's cached inventory says `device`; verify a bounded shell command before assuming live connectivity. Four existing analyzer deprecations and Gradle/AGP/Kotlin future-support warnings are outside this launch fix.

Safe exercise: run `python -m unittest discover -s campushub/scripts -p test_connect_android.py -v` from the project root using the existing Python interpreter. Change only the mocked wireless serial to another string containing spaces, rerun and confirm both `reverse` calls preserve the complete serial. Then inspect the preferred launch configuration's `program`/`cwd` fields. Do not edit device permissions, clear app data, create orders or change the database to test a keyboard shortcut. Do not remove the local compatibility package without a deliberate alternative that preserves existing glyphs.

## Physical-phone startup recovery — November 8, 2026

### 1. Cause / reason

The connected Infinix X6873 appeared twice in both ADB and Flutter: one IP-address wireless transport and one wireless discovery-name transport. Reading `ro.serialno` through both verified they represented the same physical phone. Unqualified ADB commands failed with `more than one device/emulator`, and the existing forwarding helper safely skipped automatic selection. The installed CampusHub process also showed a blank screen; an ordinary activity launch timed out while bringing that existing task forward. A cold launch fixed it. No fatal/unhandled Flutter exception was found in the collected process logs; the internal reason for the blank process is unconfirmed.

A separate API issue was confirmed during verification: local Django was not accepting connections and the Kamatera tunnel had dropped again. Restored the existing tunnel, then restarted only this checkout's failed Django development process. Chat was healthy and was not restarted.

### 2. Exact files changed / inspected anchors

- `campushub/docs/mobile_network_connectivity_guide.md:3`: this eight-part runtime recovery report.
- `CAMPUSHUB_CONTEXT.md:3`: current phone/backend recovery note.
- Inspected, unchanged: `campushub/scripts/connect_android.py:9` (`find_adb`), `:18` (`adb_command`), `:25` (`main`) and `:50` (forwarding loop); `.vscode/tasks.json` pre-launch task; `campushub/android/app/build.gradle.kts:28` (`applicationId`); `campushub/lib/module_app/config/api_config.dart:42` (loopback fallback).

No Dart, native Android, launch configuration, Python helper, database setting or migration source changed. Ignored evidence is under root `scratch/android-startup-20261108/`; private Django runtime metadata/logs are under `C:/Users/leste/.campushub-secrets/android-startup-20261108/`.

### 3. Changes made

Selected the verified IP transport explicitly and restored reverse mappings for ports 8000/8001. Disconnected only the redundant discovery-name transport after proving it was the same phone. Stopped only the installed `com.ustp.campushub` process and launched its existing `.MainActivity` again. Did not uninstall, reinstall, clear application data, rebuild the APK, submit a login or change permissions. Restored the existing database tunnel and restarted the verified local Django process tree with its existing `0.0.0.0:8000`/auto-reload command after confirming the local listener was down. No hosted source/service deployment occurred.

### 4. How it works / functions, inputs, outputs and data flow

`find_adb()` returns an existing ADB executable. `adb_command(adb, *arguments)` executes literal arguments with a timeout and returns standard output. `main()` accepts optional `--device <device_id>`; without it, it requires exactly one authorized physical transport. It then maps phone ports 8000/8001 back to the corresponding PC ports. A discovery alias counts as a separate transport even when it is the same hardware, so keep one verified connection or specify the intended device. No automatic deduplication code was added.

```text
ADB selects verified phone -> existing package/MainActivity -> Flutter login screen
Phone loopback :8000 -> ADB reverse -> PC Django -> SSH :15432 -> Kamatera PostgreSQL
Phone loopback :8001 -> ADB reverse -> PC FastAPI messaging service
```

Example from the Flutter folder: `python scripts/connect_android.py --device <device_id>` selects one authorized transport without changing Flutter's API configuration. `adb -s <device_id> shell am start -W -n com.ustp.campushub/.MainActivity` launches the existing package; `Status: ok`/`LaunchState: COLD` indicates Android accepted that launch. It does not by itself prove Flutter rendered, so a real device screenshot was also inspected and showed the normal Login screen.

### 5. Backend / API behavior

Existing API origins/fallbacks, authentication, permissions, marketplace and booking behavior remain unchanged. After restoring the tunnel/backend, PC HTTP checks for approved products and chat health returned 200. Reverse mappings for both services were verified. Direct phone-shell HTTP probes using Android netcat returned no response and are **inconclusive**; they are not recorded as successful device API checks. No login or authenticated phone workflow was submitted. The installed build's API origin was not rebuilt or changed.

### 6. Database / migration impact

No direct database, schema, migration, account, stock, order or payment changes were performed. The existing Kamatera selection and previously approved/applied migration 0052 remain in place. Native app data was retained. Normal optional app-startup behavior remains unchanged.

### 7. Tests performed

- ADB and Flutter device inventories reproduced two aliases; hardware-serial comparison confirmed the same device. After disconnecting only the duplicate, ADB listed one authorized physical connection.
- Existing forwarding helper succeeded with explicit selection and then without `--device`; reverse mappings include Django 8000 and chat 8001.
- Cold activity launch: `Status: ok`, `LaunchState: COLD`, approximately 1.3 seconds. Existing CampusHub process stayed alive and its activity had window focus.
- Actual after-restart screenshot inspected: the normal CampusHub Login screen is visible. New process log contained no `FATAL EXCEPTION`, `Unhandled Exception` or `E/flutter` entries in the captured window.
- PC product API and chat health checks returned 200 after backend recovery. Phone-shell API probe remained inconclusive, as above.
- No application code changes, APK build, automated suite or authenticated phone workflow was required or claimed. Documentation whitespace check performed.

### 8. Remaining limitations / safe practice

The app is left open at Login for the user's normal sign-in. Wireless-debugging ports can change and duplicate discovery connections can return; use the current device ID from `adb devices -l`, not a historical IP/port. Do not disconnect an unidentified second device merely because it has the same model. The exact blank-screen cause is not proven. The SSH tunnel still needs its normal restart after connection loss, and failed Django startup may then need a local service restart.

Safe exercise: run `adb devices -l`, confirm the intended single phone, then run the existing forwarding helper and `adb -s <device_id> reverse --list`. Expect both port mappings. Open the already-installed CampusHub app and confirm Login is visible; do not clear its data or create an account/order to test startup. With multiple legitimate phones, keep both connected and use `--device`/the IDE device picker rather than disconnecting one automatically. The older network examples below are historical; their IPs and unqualified ADB commands assume the corresponding single-device setup.

## 1. Overview & Context
This guide explains how the Flutter mobile application locates and connects to the Django backend server running on your computer (`0.0.0.0:8000`), why network disconnections occur when testing on a physical phone, and how the automatic fallback mechanism and ADB reverse tethering resolve connection failures.

---

## 2. Root Cause Analysis: Why the Mobile Phone Could Not Reach Django
When you run `python manage.py runserver 0.0.0.0:8000` on your PC, Django binds to all network interfaces on the computer. However, the mobile phone was failing to load data due to three specific issues:

1. **Dynamic IP Assignment (DHCP)**:
   - Your PC previously had IPv4 address `192.168.0.159`, which was hardcoded as the default in [api_config.dart](file:///c:/Users/leste/Desktop/CAMPUSHUB/campushub/lib/module_app/config/api_config.dart#L11-L15).
   - Upon reconnecting to the Wi-Fi network, your Wi-Fi router assigned your computer a new IP: **`192.168.0.122`**.
   - Because `192.168.0.122` was not in the configuration, the mobile app was still sending requests to the dead IP address `192.168.0.159`, resulting in connection timeouts (`nc: Timeout`).
2. **Missing Localhost Loopback Fallback (`127.0.0.1`)**:
   - When a phone is connected via USB or wireless ADB, running `adb reverse tcp:8000 tcp:8000` routes `http://127.0.0.1:8000` on the phone directly into the PC's Django server, bypassing Wi-Fi routers entirely.
   - [api_config.dart](file:///c:/Users/leste/Desktop/CAMPUSHUB/campushub/lib/module_app/config/api_config.dart#L18-L28) was missing `127.0.0.1` in its fallback candidate list.
3. **Public Network Category & Campus Wi-Fi AP Isolation**:
   - The current Wi-Fi connection (`USTP Library_5G 2`) is categorized as **Public** in Windows, and university Wi-Fi routers frequently enforce **AP Client Isolation** (blocking communication between two connected devices).

---

## 3. Data Flow & Network Architecture

### How the Flutter App Discovers the Working Server
```
[Flutter Mobile App]
        │
        ▼
[ApiConfig.serverBaseUrls]
  ├── 1. Try hostIp (http://192.168.0.122:8000)
  ├── 2. Try fallback 1 (http://127.0.0.1:8000 via ADB reverse)
  ├── 3. Try fallback 2 (http://192.168.137.1:8000 via Mobile Hotspot)
  └── 4. Try other historical fallback IPs
        │
  (First server responding with HTTP 200)
        │
        ▼
[ApiConfig.recordWorkingBaseUrl(workingUrl)]
        │
        ▼
[Subsequent API calls, Facility images & Chat WebSockets use effectiveBaseUrl]
```

### Relevant Classes and Functions

#### 1. `ApiConfig` ([api_config.dart](file:///c:/Users/leste/Desktop/CAMPUSHUB/campushub/lib/module_app/config/api_config.dart#L6-L85))
- **`hostIp`**: Primary IPv4 address used to construct the default `baseUrl`. Updated to default to `'192.168.0.122'`.
- **`fallbackHostIps`**: Ordered list of backup addresses tried sequentially or concurrently when the primary host is unreachable. Now includes `'127.0.0.1'` at index 0.
- **`serverBaseUrls`**: Computed getter that returns an ordered set of base URLs: `_activeBaseUrl` (if known), followed by `http://$hostIp:8000`, followed by all fallbacks.
- **`recordWorkingBaseUrl(String url)`**: Caches the confirmed live backend URL into `_activeBaseUrl` so subsequent requests do not have to rediscover the server.

#### 2. `FacilityService` ([facility_service.dart](file:///c:/Users/leste/Desktop/CAMPUSHUB/campushub/lib/module_app/services/facility_service.dart#L19-L54))
- **`fetchFacilities()`**: Queries `_baseUrls` in order. Upon receiving a 200 response, it now invokes `ApiConfig.recordWorkingBaseUrl(baseUrl)` to ensure facility photos and subsequent interactions immediately know the working server.

---

## 4. Connection Options for Physical Phones

### Option 1: Direct Wi-Fi Connection (Recommended when on same home or personal router)
1. Verify PC IPv4:
   ```powershell
   ipconfig
   ```
   Look for the `Wireless LAN adapter Wi-Fi` -> `IPv4 Address` (e.g. `192.168.0.122`).
2. Verify Django is running with `0.0.0.0`:
   ```powershell
   python manage.py runserver 0.0.0.0:8000
   ```

### Option 2: ADB Reverse Tethering (Most Reliable — Bypasses Wi-Fi & Firewalls)
If your phone is plugged in via USB (or paired over wireless debugging):
1. Run in your PC terminal:
   ```powershell
   adb reverse tcp:8000 tcp:8000
   adb reverse tcp:8001 tcp:8001
   ```
2. The phone can now reach Django at `http://127.0.0.1:8000` directly through the ADB cable/link, completely unaffected by router isolation or firewall restrictions.

### Option 3: Windows Mobile Hotspot (Best on University/Public Wi-Fi)
If university Wi-Fi has AP client isolation enabled:
1. Turn on **Mobile Hotspot** in Windows Settings.
2. Connect your phone to your PC's hotspot Wi-Fi.
3. The PC hotspot gateway is always `192.168.137.1`, which is already built into `ApiConfig.fallbackHostIps`.

---

## 5. Verification Steps & Hands-on Practice

### Quick Test from PC:
Check if phone's port forward is responding:
```powershell
adb shell "nc -z -w 2 127.0.0.1 8000; echo EXIT_CODE=$?"
```
Expected output: `EXIT_CODE=True`.

### Hands-on Learning Exercise:
1. Open [api_config.dart](file:///c:/Users/leste/Desktop/CAMPUSHUB/campushub/lib/module_app/config/api_config.dart#L11-L15).
2. Notice `defaultValue: '192.168.0.122'`.
3. Try launching the Flutter app with a specific IP override from the command line without editing files:
   ```powershell
   flutter run -d <device_id> --dart-define=CAMPUSHUB_HOST_IP=192.168.0.122
   ```
4. Confirm in the phone's login and dashboard screens that products and facilities load instantly.
