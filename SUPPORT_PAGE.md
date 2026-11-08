# ASMR Walk Support

_Last updated: November 8, 2026 — Version 1.1.0_

ASMR Walk records GPS walks on iPhone and Apple Watch, and optional video walks on iPhone. The separate Mac tools prepare routes for a map overlay in Final Cut Pro or Motion.

## Contact Support

Email [dave@bald-traveler.com](mailto:dave@bald-traveler.com). Include your device model, operating system version, ASMR Walk version/build, steps to reproduce the problem, and any error message. For Mac overlay problems, include your Final Cut Pro or Motion version; for audio problems, include the microphone model and connection type.

Please do not email private route files, location histories, videos, or other sensitive information unless specifically requested.

## Requirements

- iPhone with iOS 26.0 or later. iPad is not supported.
- The optional Apple Watch companion requires watchOS 26.5 or later and records GPS-only walks, not video or HealthKit workouts.
- The separate Mac tools require macOS 26.5 or later. Final Cut Pro or Motion is needed to use the overlay; neither is included in the installer.
- Location permission is needed to record routes. Video Walk also needs camera and microphone permission. Photos access is requested for the Photos actions you choose.
- Private iCloud sync requires the same Apple Account on the participating devices, with iCloud available. GPX import on Mac is an alternative when synced routes are unavailable.

## Recording on iPhone

Open **Walk** for a GPS-only recording or **Video Walk** for camera footage with a route. Tap the recording control and grant the requested permissions. Use the active recording banner to see progress and stop. Saved walks appear in **History**.

For background GPS, enable **Settings > Background GPS Recording** in ASMR Walk and grant **Always** location permission in iPhone Settings. This applies only to GPS Walk. Video Walk must stay in the foreground; leaving the foreground stops and saves the recording.

If location is unavailable, check Location Services and ASMR Walk’s permission in iPhone Settings. GPS accuracy can be reduced indoors or near tall buildings. If the camera or microphone is unavailable, check those permissions and return to Video Walk.

### Choosing a microphone

Once the Video Walk preview is ready, tap the microphone pill. Choose **Automatic**, **iPhone Microphone**, or a supported connected Bluetooth or USB microphone. The picker shows both your selection and the input actually in use. On the first launch, start a Video Walk to grant permissions; if recording begins, stop and save or discard the short sample before choosing an input.

Microphone selection is locked during recording. If an accessory disconnects, check the active input and fallback notice. Reconnect and select it again after stopping. If the requested input cannot become active, resolve the displayed error or select another input before recording.

A wireless receiver connected through USB-C appears as USB audio. Bluetooth quality depends on hardware and regional availability. Make a short recording and listen to it before a long walk. Preferences last for the current app session. The ready preview also uses the microphone; capture ends when the preview shuts down or the app leaves the foreground.

## Recording on Apple Watch

### Keep the Watch app visible

On Apple Watch, open **Settings > General > Return to Clock**, scroll to **ASMR Walk**, and choose **Custom > After 1 hour**. The recording screen will return when you raise your wrist during that interval. This does not keep the display continuously illuminated or require HealthKit.


Open ASMR Walk on the Watch, start a walk, and grant location access when prompted. Check elapsed time and distance, then stop and save the walk. Watch recordings contain GPS routes and metadata, not a local video.

### Transfer Watch walks to iPhone

Install the updated app on both your paired Watch and iPhone, then open ASMR Walk on both. Saved Watch walks transfer directly to the paired iPhone through Apple’s WatchConnectivity service; this first step does not require iCloud. Transfers are queued and may not arrive immediately. Open iPhone **History** and look for the Watch source label.

The Watch keeps the walk locally until delivery and reports **Saved walks received by iPhone** only after the iPhone confirms a successful save. If it is waiting, keep the devices connected and tap **Retry Transfer** on the Watch. On iPhone, **Settings > Apple Watch Transfers** shows import status and offers **Retry Watch Import**. Previously saved Watch walks are queued when you reopen the updated Watch app, including recoverable checkpoints from an interrupted recording. Do not uninstall the Watch app to troubleshoot: that can remove unsent local data.

Once a walk reaches iPhone, private iCloud sync makes it available to the Mac importer and other signed-in devices. If it appears on iPhone but not Mac, check the same Apple Account, internet connectivity, and iCloud status on those devices. Direct Watch transfer and iCloud sync are separate steps.

The Watch retains its local recording copy after delivery. Deleting the iPhone recording does not erase that Watch copy; confirmed transfers are not automatically resent.

For separately recorded camera footage, add external-camera timing notes to the Watch recording on iPhone. Those notes can accompany GPX exports; they do not import or sync the footage itself.

## Storage, Photos, and Exports

Walk metadata and routes can sync through your private iCloud database. Full video files do not sync through ASMR Walk: they remain on the device that recorded them. A synced route on another device does not mean the video is available there.

To save a movie copy, open **History**, select the Video Walk, and choose **Save Video to Photos**. The original stays in ASMR Walk. Older Photos-backed recordings may need Photos read permission for playback.

Deleting a recording removes its route, metadata, app-managed thumbnail, and app-managed video. It does not delete a copy saved to Photos. Export anything you want to preserve before deleting the app; do not treat sync as an independent backup of deleted records.

From a recording’s detail screen, export **GPX** to preserve recorded route points and metadata. Google Maps links are convenient for sharing but may not preserve every point. The destination you choose handles the shared information under its own privacy practices.

## Mac App and Final Cut Pro Overlay

### Download and install

[Download ASMR Walk Mac Tools 1.1.0 (.pkg)](https://github.com/heathdj/ASMRWalk/releases/download/release-1.1.0/ASMR-Walk-Mac-Tools-1.1.0.pkg)

1. Quit Final Cut Pro and Motion.
2. Open the downloaded installer and follow its prompts. It installs **ASMR Walk Mac Importer** and **ASMR Walk Route Overlay** in Applications, plus the ASMR Walk generator template for the signed-in user.
3. Open **ASMR Walk Mac Importer**. Choose **ASMR Walk Mac Importer > Final Cut Pro Plugin…**, then **Register or Repair Plugin**.
4. Close the overlay registration window when finished. The helper exits when its window closes; it does not need to stay open for FCP rendering.
5. Reopen Final Cut Pro. Look under **Generators > ASMR Walk** for **ASMR Walk Route Overlay**.

### Prepare a route package

1. In the importer, select a recording under **Synced Recordings**, or click **Import GPX** and choose a route exported from your iPhone or another supported GPX source.
2. Check the route preview. If needed, select an unwanted point and use **Delete Point**; **Reset Route** restores the imported route.
3. Optionally use **Choose Photos Video** or **Choose Video File** to pair footage. Route sync alone does not transfer your iPhone’s video; make the footage available separately on the Mac.
4. Click **Prepare Map** for a map background. For routes with more than 100 points, **Prepare Segmented Maps** creates overlapping map sections. Wait for preparation and inspect the previews. Both Light and Dark images are included. Map preparation may require internet access to Apple Maps.
5. Choose **Use Route Only** if you want a transparent route without a map background.
6. Click **Create Package**, choose a destination, and use **Reveal Package** to locate the resulting `.asmrroute` package. Keep the package intact.

### Use the package in Final Cut Pro

1. Add your footage to a project. Place **ASMR Walk Route Overlay** above it as a connected generator clip and set the generator’s duration for the intended walk interval.
2. Select the generator. In its published parameters, choose **Choose or Replace Route Package…** and drop your `.asmrroute` package into the chooser.
3. Choose **Route Timing**. **Clip Duration** fits route progress to the generator duration; GPX timestamp timing uses the route’s recorded timing. Adjust **Timing Offset (seconds)** to align it with your footage.
4. Adjust **Map Position**, **Map Size**, **Map Corners**, **Map Opacity**, and marker visibility. Choose **Map Appearance** for Light or Dark. The map and route scale together with Map Size.
5. Play the full interval and export a short sample to check alignment and timing. For segmented packages, also check the transitions between map sections.

Motion users can use the registered ASMR Walk Route Overlay plugin in the ASMR Walk group. Prepared package images and route data are used during playback and export; rendering does not fetch maps, Photos videos, or iCloud data.

### Mac troubleshooting

- **Generator missing:** quit FCP/Motion, rerun the installer, use **Final Cut Pro Plugin… > Register or Repair Plugin**, then reopen the host. Installation includes a generator template for the signed-in Mac user.
- **Missing or damaged plugin files:** reinstall the complete package. Do not replace files inside the installed apps individually.
- **Map does not match the route:** prepare maps again and export a new package, then replace the package in FCP. Old packages retain their original imagery and projection.
- **Dark map looks like Light:** prepare and export the route again with 1.1.0. Older packages or missing Dark images fall back to the available map for that segment.
- **Map preparation fails:** check connectivity, retry preparation, or use a route-only package.
- **Route timing is wrong:** verify the generator duration, timing mode, and offset against the footage. Separately recorded footage needs alignment; importing a route does not automatically synchronize an external camera.
- **Synced recording is missing:** check the Mac’s Apple Account and iCloud status. Use GPX import while investigating sync.

To uninstall the Mac tools, quit the apps and hosts, remove the two ASMR Walk apps from Applications, and remove only `~/Movies/Motion Templates.localized/Generators.localized/ASMR Walk/ASMR Walk Route Overlay`. Preserve other templates and your exported route packages.

## Appearance and Help

Use iPhone **Settings** to choose System, Light, or Dark appearance. **Show Onboarding Again** reopens the introduction. The FCP map appearance is a separate generator setting.

## Privacy

ASMR Walk has no developer-operated accounts, analytics, advertising, or backend storage. Apple services provide private iCloud route sync, map imagery, and optional Photos functionality. Read the [ASMR Walk Privacy Policy](https://bald-traveler.com/asmr-walk-privacy-policy/).
