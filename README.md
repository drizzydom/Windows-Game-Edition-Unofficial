# Windows Game Edition (Unofficial)

Windows can be a busy roommate when all you want to do is game. This project introduces a portable companion that pauses non essential services, background tasks, and telemetry so you get a focused SteamOS like experience without losing anti cheat support, cloud saves, or store access.

> **Disclaimer:** This effort is community driven and not affiliated with Microsoft. Make backups before trying anything adventurous.

## Why This Project Exists

Most tweak packs fall into one of three buckets. Some hide everything inside an opaque installer, some are copy and paste snippets from a forum, and others are paid dashboards packed with ads. Windows Game Edition takes a different path by staying portable, transparent, and reversible. Every optimization lives in a manifest that explains the default behavior, the change we apply, and the path back to stock Windows. Security services like Defender and Secure Boot helpers stay active unless you intentionally disable them. A privacy mode can mute telemetry and scheduled diagnostics with the same level of clarity. Casual users get presets while power users can dive into Xbox services, Bluetooth stacks, enterprise features, and beyond, with clear descriptions wrapped around every toggle.

## Supported Windows Releases

- Windows 10 in every public edition except S Mode
- Windows 11 in every public edition except S Mode

The app will detect your exact edition such as Home, Pro, Enterprise, or Education and quietly hide any tweak that would be unsafe on that build.

## Feature Pillars

**Performance Presets**
Curated bundles that target the path from boot to login to launching a game library and finally into a game session.

**Privacy Shield**
Optional switches that shut down telemetry, diagnostics, and Microsoft only connections for players who want near offline privacy.

**Undo Queue**
Every change writes to a log with a matching restore action, so you can bounce in and out of Game Edition mode any time.

**Education First UI**
Tooltips and subtext explain what each service does out of the box, and what happens when it is disabled.

**Audit Friendly Logs**
Actions land in plain text or JSON logs so you can troubleshoot anti cheat complaints or compare before and after states.

## Project Status

- Memory and contributor guidance established
- Deep research underway on Windows 10 and 11 services, scheduled tasks, and telemetry
- Manifest schema captured, automation module + CLI scaffolded, and WPF desktop host bootstrapped

If you enjoy alpha stage experiments and PowerShell tinkering, you are in the right place.

## Roadmap Preview

1. Define the tweak manifest schema and seed it with high impact services such as SysMain, the Xbox stack, and telemetry.
2. Build the PowerShell executor with WhatIf previews, SKU filtering, logging, and an automatic undo queue.
3. Craft a WinUI or WPF desktop shell that reads the same manifests, offers one click presets, and exposes advanced categories for deeper control.
4. Package manifests, scripts, and UI into a single portable download with clear offline instructions.

## Development Quick Start

**Prerequisites**
- .NET 8 SDK for building the WPF host (required only for contributors)
- Windows 10 or newer test box for running the UI and PowerShell executor

**Run the PowerShell executor directly**
1. Open an elevated Windows PowerShell 5.1 console.
2. Navigate to the `automation` folder.
3. Enumerate available presets:
	```powershell
	.\wge.ps1 -List
	```
4. Preview a preset without making changes:
	```powershell
	.\wge.ps1 -Preset performance -DryRun -SkipUnsupported
	```
5. Apply the preset (writes logs and enforces undo metadata):
	```powershell
	.\wge.ps1 -Preset performance -SkipUnsupported
	```

**Build the single-file WPF host**
1. From the repo root on any development machine with the .NET 8 SDK installed:
	```powershell
	dotnet publish src/WGE.App/WGE.App.csproj -c Release -r win10-x64 \
		 -p:PublishSingleFile=true -p:SelfContained=true -p:IncludeNativeLibrariesForSelfExtract=true
	```
2. Find the portable `.exe` inside `src/WGE.App/bin/Release/net8.0-windows/win10-x64/publish/`.
3. Copy the published executable to a clean Windows PC (no extra dependencies required). The embedded automation scripts run entirely offline and revert changes through the bundled undo metadata.

## Contributing

1. Open an issue or drop a comment if you have insight into Windows tweaks, especially those that are hard to find in public docs. We use those threads to capture context that might otherwise disappear.
2. When proposing a change, describe what the service or feature does, why disabling it helps, and how to put everything back the way it was.
3. Keep contributions reversible. Every disable action needs an enable action, and both should be easy to read.
4. Write documentation in a friendly conversational tone so newer gamers can follow along.

## Safety Checklist

- Run every script with WhatIf flags first so you can see exactly what would change.
- Create a restore point or backup with tools like Macrium or Veeam before applying tweaks.
- Leave Windows Update and Defender running unless you fully understand the security trade offs.
- Share any anti cheat quirks you discover in issues so the community can learn from it.

## License

License coming soon. Treat the repository as open for review and contributions, but please avoid redistributing binaries until we post the final terms.

---

Questions, ideas, or even friendly banter? Open an issue and we will respond.
