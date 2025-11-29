# Windows Service and Feature Catalog

This catalog documents the Windows 10 and Windows 11 services, scheduled tasks, and experience features that impact the Windows Game Edition project. Use it to decide which tweaks belong in future manifests and to provide trustworthy tooltips for end users. Every entry includes the default role, the suggested optimization action, relative risk, and reminders about dependencies or anti cheat considerations.

## How to Read This Document

- **Essential Core** entries should remain active in every preset. Disabling them risks boot failures, sign in loops, or anti cheat bans.
- **Optional** entries can be exposed as toggles. Some are pre selected in the "Performance" preset while others live in the advanced view.
- **High Risk** entries require loud warnings and should default to off (user opt in only).
- Service names use the short service identifier (`SysMain`, `DiagTrack`, etc.). Scheduled tasks include their folder path. Features include inbox apps or Windows components.
- Many services share a svchost instance. Always check dependencies with `sc qdepend` before finalizing a tweak.

## Essential Core (Do Not Disable)

| Service / Feature | Default Role | Optimization Action | Risk | Notes |
| --- | --- | --- | --- | --- |
| Winlogon / LSASS | Handles logon sessions and authentication tokens | None | Critical | Required for sign in and anti cheat attestation. |
| RPCSS (DCOM Server Process Launcher) | Core COM/RPC broker | None | Critical | Disabling breaks most Windows components. |
| Service Control Manager | Dispatches all service lifecycle events | None | Critical | Cannot be disabled. |
| Windows Event Log (`EventLog`) | Collects system logs | Keep | Medium | Required for diagnosing crashes and anti cheat kernel events. |
| Windows Management Instrumentation (`Winmgmt`) | Provides system data for scripts | Keep | Medium | Needed by the executor to query services. |
| Windows Driver Foundation (`WdfSvc`) | Manages kernel drivers | Keep | High | Required for USB, controllers, GPUs. |
| Windows Audio (`Audiosrv`) and Audio Endpoint Builder | Provides audio playback | Keep | Medium | Needed for any gaming experience. |
| Network List Service / Network Location Awareness | Detects network changes | Keep | Medium | Steam and cloud saves expect it for routing. |
| DHCP Client / DNS Client | Handles IP and name resolution | Keep | Medium | Needed for updates, multiplayer, anti cheat. |
| Windows Defender Antivirus (`WinDefend`) | Baseline AV | Keep | Medium | Many anti cheat solutions expect it unless a vendor AV registers. |
| Windows Firewall (`MpsSvc`) | Outbound/inbound firewall | Keep | Medium | Important for anti cheat trust chains. |
| Windows Update (`wuauserv`) | Retrieves updates | Keep (Manual) | Medium | Leave manual unless user opts to disable temporarily. |
| Local Session Manager (`LSM`) | Manages user sessions | None | Critical | Required for sign in and session switching. |
| Plug and Play (`PlugPlay`) | Detects hardware changes | None | Critical | GPU, controllers, USB all depend on it. |
| Power (`Power`) | Power state management | None | Critical | Core OS function. |
| Security Accounts Manager (`SamSs`) | Account database | None | Critical | Authentication depends on it. |
| User Manager (`UserManager`) | User profile management | None | Critical | Required for user logon. |
| User Profile Service (`ProfSvc`) | Loads user profiles | None | Critical | Required for user logon. |
| Task Scheduler (`Schedule`) | Runs scheduled tasks | Keep | High | Many system functions rely on it. |
| System Event Notification Service (`SENS`) | System event broker | Keep | Medium | Many apps rely on it for network/power events. |
| System Events Broker (`SystemEventsBroker`) | UWP system triggers | Keep | Medium | Store apps depend on it. |
| State Repository Service (`StateRepository`) | App state storage | Keep | High | UWP apps need it for state. |
| Windows Installer (`msiserver`) | MSI installation | Keep | High | App installs need it. |
| Windows Modules Installer (`TrustedInstaller`) | Windows updates | Keep | Critical | Core update mechanism. |
| Windows License Manager Service (`LicenseManager`) | Store licensing | Keep | High | Store games need it. |
| Software Protection (`sppsvc`) | License validation | Keep | High | Windows activation. |
| Cryptographic Services (`CryptSvc`) | Certificate and crypto operations | Keep | High | Needed for updates, HTTPS, code signing. |
| Windows Time (`W32Time`) | Time synchronization | Keep | Medium | Auth and certs need accurate time. |
| Windows Connection Manager (`Wcmsvc`) | Network connection decisions | Keep | Medium | Core networking. |
| Windows Font Cache Service (`FontCache`) | Font caching | Keep | Medium | Performance benefit. |
| Themes (`Themes`) | Visual themes | Keep | Low | UI personalization. |
| Human Interface Device Service (`hidserv`) | HID device support | Keep | High | Controllers need this. |
| GraphicsPerfSvc | GPU preference settings | Keep | High | Required for per app GPU selection. |
| TokenBroker | Account token management | Keep | High | Sign in flows rely on it. |
| Capability Access Manager (`camsvc`) | Manages app capability access | Keep | Medium | UWP permission broker. |
| Time Broker (`TimeBrokerSvc`) | Background task timing | Keep | Medium | UWP background tasks. |
| Windows Security Service (`SecurityHealthService`) | Security dashboard | Keep | High | Anti cheat trusts it. |
| System Guard Runtime Monitor (`SgrmBroker`) | Virtualization based security monitor | Keep | High | Required when Credential Guard or Memory Integrity is enabled. |

## Performance Drains (Good Candidates for Presets)

| Service / Feature | Default Role | Optimization Action | Risk | Notes |
| --- | --- | --- | --- | --- |
| SysMain (Superfetch) | Prefetches frequently used apps | Disable service / set startup to Disabled | Low | Good to disable on SSD heavy rigs. |
| Connected User Experiences and Telemetry (`DiagTrack`) | Sends telemetry to Microsoft | Disable service and tasks | Low | Ensure privacy preset explains reduced diagnostics. |
| dmwappushsvc (WAP Push) | Legacy telemetry uploader | Disable | Low | Rarely used on desktops. |
| Windows Search (`WSearch`) | Indexes files | Disable or set Manual | Medium | Loses instant search. Keep optional toggle. |
| Offline Files (`CscService`) | Caches network files | Disable | Low | Mostly enterprise feature. |
| Superfetch tasks (`\Microsoft\Windows\MemoryDiagnostic`) | Background memory assessments | Disable tasks | Low | Rarely needed on gaming rigs. |
| Background Intelligent Transfer Service (`BITS`) | Transfers content in background | Set Manual | Medium | Needed for Store and updates. Prefer manual instead of disabled. |
| Delivery Optimization (`DoSvc`) | Peer to peer update transfers | Disable service/tasks | Low | Explain that Store downloads fall back to direct CDN. |
| Windows Error Reporting (`WerSvc`) | Uploads crash dumps | Disable service/tasks | Low | Some anti cheat vendors request crash data. Mention in tooltip. |
| Program Compatibility Assistant (`PcaSvc`) | Detects old app issues | Disable | Low | Rarely helps modern games. |
| Application Experience (`AeLookupSvc`) | Collects compatibility telemetry | Disable | Low | Works in tandem with PCA. |
| Remote Registry (`RemoteRegistry`) | Allows remote registry edits | Disable | Low | Security hardening benefit too. |
| Security Center (`wscsvc`) | Monitors AV/Firewall state | Keep | High | Do not disable; anti cheat queries this. |
| Server (`LanmanServer`) | File/print sharing | Optional: disable if no sharing | Medium | Needed for SMB/Steam local streaming. |
| Workstation (`LanmanWorkstation`) | SMB client | Keep | Medium | Steam remote play uses it. |
| Diagnostic Policy Service (`DPS`) | Detects and troubleshoots problems | Optional disable | Medium | May break some auto fixes. |
| Diagnostic Service Host (`WdiServiceHost`) | Hosts diagnostic modules | Optional disable | Medium | Related to DPS. |
| Diagnostic Execution Service (`diagsvc`) | Runs diagnostic scenarios | Disable | Low | Privacy benefit. |
| Distributed Link Tracking Client (`TrkWks`) | Maintains NTFS link tracking | Disable | Low | Legacy feature. |
| Print Spooler (`Spooler`) | Printing support | Optional disable | Low | Keep if printing. |
| Fax (`Fax`) | Fax service | Disable | Low | Ancient relic. |
| Secondary Logon (`seclogon`) | Run as different user | Optional disable | Low | Power users may want it. |
| Shell Hardware Detection (`ShellHWDetection`) | AutoPlay | Optional disable | Low | Disable for security. |
| TCP/IP NetBIOS Helper (`lmhosts`) | NetBIOS name resolution | Optional disable | Low | Legacy. |
| Telephony (`TapiSrv`) | Modem/telephony | Disable | Low | Ancient. |
| WebClient | WebDAV | Disable | Low | Rare use. |
| Windows Media Player Network Sharing Service (`WMPNetworkSvc`) | DLNA sharing | Disable | Low | Streaming only. |
| AllJoyn Router Service (`AJRouter`) | IoT device discovery | Disable | Low | Rarely used on gaming PCs. |
| Internet Connection Sharing (`SharedAccess`) | Hotspot/ICS | Disable | Low | Rare use. |
| Peer Name Resolution Protocol (`PNRPsvc`) | P2P name resolution | Disable | Low | Legacy. |
| Peer Networking Grouping (`p2psvc`) | P2P networking | Disable | Low | Legacy. |
| Peer Networking Identity Manager (`p2pimsvc`) | P2P identity | Disable | Low | Legacy. |
| PNRP Machine Name Publication Service (`PNRPAutoReg`) | P2P name publishing | Disable | Low | Legacy. |
| Remote Procedure Call Locator (`RpcLocator`) | Legacy RPC | Disable | Low | Ancient. |
| Routing and Remote Access (`RemoteAccess`) | Routing/VPN server | Disable | Low | Server feature. |
| SNMP Trap (`SNMPTRAP`) | Network monitoring | Disable | Low | Admin tool. |
| Windows Connect Now (`wcncsvc`) | WPS setup | Disable | Low | Router pairing. |
| Windows Remote Management (`WinRM`) | Remote management | Disable | Low | Admin tool. |

## Telemetry and Privacy Bundle

| Service / Feature | Default Role | Optimization Action | Risk | Notes |
| --- | --- | --- | --- | --- |
| Customer Experience Improvement tasks (`Consolidator`, `UsbCeip` etc.) | Upload usage data | Disable tasks | Low | Document effect on diagnostics. |
| Diagnostics Tracking (`DiagTrack`) | See performance section | See above | Low | Already listed. |
| Inventory Collector (`\Microsoft\Windows\AppID\SmartScreenSpecific` etc.) | Checks SmartScreen cloud reputation | Optional disable | Medium | Turning off reduces phishing protection; warn users. |
| Windows Spotlight / Content Delivery Manager | Rotates lock screen/ad assets | Disable scheduled tasks | Low | Cosmetic only. |
| Advertising ID (registry) | Personalized ads | Set `Enabled` to 0 | Low | Works via registry key under `HKCU`. |
| Activity History (`\System\Activity\Publisher`) | Syncs timeline data | Disable tasks and registry toggles | Low | Loss of timeline feature only. |
| Voice Activation (`\Speech\SpeechModelDownloadTask`) | Downloads speech models | Disable | Low | Mention Cortana impact. |
| Tailored Experiences (`HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy`) | Personalized tips | Disable via registry | Low | Document location. |
| Recommended Troubleshooting Service (`TroubleshootingSvc`) | Auto troubleshooters | Disable | Low | Privacy benefit. |
| Windows Insider Service (`wisvc`) | Insider builds | Disable if not insider | Low | Dev channel only. |
| Windows Defender Advanced Threat Protection (`Sense`) | Enterprise EDR | Disable on home PCs | Low | Enterprise only. |
| Windows Event Collector (`Wecsvc`) | Event forwarding | Disable | Low | Enterprise feature. |
| Device Census (`DeviceCensus`) | Collects device info for updates | Disable task | Low | Privacy focused. |
| KMS Client Activation (`\Microsoft\Windows\SoftwareProtectionPlatform\SvcRestartTask*`) | License checks | Keep | High | Needed for activation. |
| Flighting tasks (`\Microsoft\Windows\Flighting\*`) | Feature experimentation | Disable all | Low | Privacy and stability. |
| Device Information tasks (`\Microsoft\Windows\Device Information\*`) | Device telemetry | Disable | Low | Privacy focused. |
| Feedback tasks (`\Microsoft\Windows\Feedback\Siuf\*`) | Feedback upload | Disable | Low | Privacy focused. |

## Xbox and Gaming Services

| Service / Feature | Default Role | Optimization Action | Risk | Notes |
| --- | --- | --- | --- | --- |
| Xbox Accessory Management (`XboxGipSvc`) | Xbox peripherals | Optional toggle | Low | Keep enabled if user uses controllers via Xbox Accessories app. |
| Xbox Live Auth Manager (`XblAuthManager`) | Xbox Live authentication | Optional toggle | Medium | Required for Game Pass / Xbox app games. Provide warning. |
| Xbox Live Game Save (`XblGameSave`) | Sync saves for Microsoft Store titles | Optional toggle | Medium | Disable only if user does not play Xbox PC games. |
| Xbox Live Networking Service (`XboxNetApiSvc`) | NAT traversal for Xbox services | Optional toggle | Medium | Multiplayer in Xbox app needs it. |
| Game Bar services (`BcastDVRUserService*`) | Handles captures and Game Bar UI | Disable | Low | Provide quick note about losing Win+G overlay. |
| Gaming Services (Store app) | Underpins Game Pass installs | Keep by default | Medium | Removing it breaks Game Pass titles. |
| Xbox Game Monitoring (`xgamemode`) | Game Mode helper | Keep | Medium | Game Mode feature. |
| Xbox save tasks (`\Microsoft\XblGameSave\*`) | Xbox save sync | Optional toggle | Medium | Needed for Xbox cloud saves. |

## Cloud Sync and Consumer Apps

| Service / Feature | Default Role | Optimization Action | Risk | Notes |
| --- | --- | --- | --- | --- |
| OneDrive (`OneSyncSvc`) | File sync | Disable service/app | Low | Provide option to re enable per profile. |
| Phone Link (`Link to Windows`) | Phone notifications | Disable app tasks | Low | Not needed on gaming PCs. |
| Shared Experiences (`WpnService`, `OneSyncSvc`) | Cross device notifications | Disable | Low | Document impact on notifications. |
| Contact Data (`PimIndexMaintenanceSvc`) | Indexes contacts | Disable | Low | Rarely relevant. |
| User Data Access/Storage (`UserDataSvc`) | Syncs settings between devices | Disable | Medium | Some UWP apps rely on it; caution note. |
| Microsoft Teams Consumer | Chat client | Remove app via `Get-AppxPackage` | Low | Optional uninstall entry. |
| Widgets / Web Experience Pack | Windows 11 widgets | Optional removal | Low | UI only. |
| Clipboard User Service (`cbdhsvc`) | Cloud clipboard sync | Optional disable | Low | Lose cross device paste. |
| Data Sharing Service (`DsSvc`) | Data brokering between apps | Optional disable | Low | Minimal impact. |
| Data Usage (`DusmSvc`) | Tracks network data usage | Optional disable | Low | UI stat only. |
| MessagingService | SMS/MMS relay | Disable | Low | Phone Link related. |
| Windows Push Notifications System Service (`WpnService`) | Push notifications | Optional disable | Medium | Lose app notifications. |
| Windows Push Notifications User Service (`WpnUserService`) | Per user push | Optional disable | Medium | Same as above. |
| SettingSync tasks (`\Microsoft\Windows\SettingSync\*`) | Settings upload | Disable | Low | Privacy focused. |

## Enterprise and Management

| Service / Feature | Default Role | Optimization Action | Risk | Notes |
| --- | --- | --- | --- | --- |
| Device Management Enrollment (`DmEnrollmentSvc`) | MDM enrollment | Disable on home PCs | Low | Enterprises need it. |
| Microsoft Account Sign in Assistant (`wlidsvc`) | Handles MSA auth | Keep | Medium | Needed for Store, Xbox app, even Steam overlay sign ins. |
| Work Folders (`WorkFolders`) | Enterprise sync | Disable | Low | For domain environments only. |
| Offline Files (`CscService`) | Cached network files | Disable | Low | Already noted. |
| Remote Desktop Services (`TermService`) | Provides RDP | Optional disable | Medium | Keep if user streams from other PCs. |
| Smart Card (`SCardSvr`) | Smart card auth | Disable | Low | Rare on gaming rigs. |
| IP Helper (`iphlpsvc`) | IPv6 transition, tunnel broker | Optional disable | Medium | Some VPNs rely on it. |
| Enterprise App Management (`EntAppSvc`) | MDM app deployment | Disable on home PCs | Low | Enterprise only. |
| Microsoft App V Client (`AppVClient`) | App virtualization | Disable | Low | Enterprise feature. |
| Netlogon | Domain authentication | Keep on domain PCs | Medium | Home users can disable. |
| Network Connectivity Assistant (`NcaSvc`) | DirectAccess connectivity | Disable | Low | Enterprise VPN. |
| User Experience Virtualization Service (`UevAgentService`) | UE V roaming | Disable | Low | Enterprise only. |
| Windows Management Service (`WManSvc`) | MDM management | Disable on home PCs | Low | Enterprise only. |
| Wired AutoConfig (`dot3svc`) | 802.1X wired auth | Disable | Low | Enterprise only. |
| User Access Logging Service (`UALSVC`) | Usage logging | Disable | Low | Server feature. |
| Remote Desktop Configuration (`SessionEnv`) | RDP config | Disable if not using RDP | Low | Same as RDP. |
| Remote Desktop Services UserMode Port Redirector (`UmRdpService`) | RDP device redirection | Disable if not using RDP | Low | Same as RDP. |
| KtmRm for Distributed Transaction Coordinator (`KtmRm`) | Transaction recovery | Disable | Low | Server feature. |
| AssignedAccessManager | Kiosk mode lockdown | Disable | Low | Enterprise/kiosk only. |
| Embedded Mode (`embeddedmode`) | IoT/kiosk embedded features | Disable | Low | Not relevant. |
| Workplace Join tasks (`\Microsoft\Windows\Workplace Join\*`) | Workplace join | Disable | Low | Enterprise only. |
| Work Folders tasks (`\Microsoft\Windows\Work Folders\*`) | Work Folders sync | Disable | Low | Enterprise only. |
| BitLocker Drive Encryption Service (`BDESVC`) | Full disk encryption | Keep if BitLocker is enabled | Medium | Present on Pro/Enterprise/Education; disable only when encryption is not in use. |
| BranchCache (`PeerDistSvc`) | LAN content caching | Disable | Low | Exists on Pro/Enterprise/Education; pointless on standalone rigs. |
| AppLocker (`AppIDSvc`) | Application whitelisting | Disable | Low | Enterprise/Education only; harshly restricts unsigned games if left configured. |
| Device Guard Management Service (`dgssvc`) | Virtualization based code integrity | Disable | Medium | Enterprise/Education; depends on Hyper V and VBS features. |
| Windows Defender Application Guard (`wdagservice`) | Isolated Edge sessions | Disable | Low | Pro/Enterprise only; not required for gaming workflows. |

## Media, Peripheral, and Sensor Services

| Service / Feature | Default Role | Optimization Action | Risk | Notes |
| --- | --- | --- | --- | --- |
| Bluetooth Support Service (`bthserv`) | Bluetooth stack | Optional toggle | Low | Provide UI toggle (remains user controllable). |
| Geolocation Service (`lfsvc`) | Provides location to apps | Optional disable | Low | Some Store apps may need it. |
| Sensor Service (`SensorService`) | Sensors, screen rotation | Disable | Low | Convertible laptops may want it. |
| Windows Camera Frame Server (`FrameServer`) | Shares camera feed | Optional disable | Medium | Impacts streaming apps that use camera. |
| Windows Biometric Service (`WbioSrvc`) | Fingerprint/face auth | Optional disable | Medium | Disable only if user does not use Windows Hello. |
| Payment and NFC/SE Manager (`SEMgrSvc`) | Wallet payments | Disable | Low | Rare on desktops. |
| Tablet PC Input Service (`TabletInputService`) | Touch keyboard / pen | Disable | Low | Keep on tablets. |
| Touch Keyboard and Handwriting Panel (`TabTip`) | On screen keyboard | Disable | Low | UI only. |
| Radio Management Service (`RmSvc`) | Airplane mode | Keep | Medium | Laptops need it. |
| Portable Device Enumerator Service (`WPDBusEnum`) | MTP device support | Keep | Medium | Phone/camera transfers. |
| Windows Image Acquisition (`stisvc`) | Scanner/camera | Optional disable | Low | Keep for scanners. |
| Still Image Acquisition Events (`WiaRpc`) | Scanner/camera events | Optional disable | Low | Keep for scanners. |
| Windows Color System (`WcsPlugInService`) | Color profiles | Keep | Low | Display calibration. |
| Device Picker (`DevicePickerUserSvc`) | Bluetooth/cast device picker | Optional disable | Low | Impacts quick pair. |
| Auto Time Zone Updater (`tzautoupdate`) | Changes time zone by location | Disable | Low | Gaming rigs stay put. |
| Cellular Time (`CellularTime`) | Syncs time via cellular | Disable | Low | Desktops lack modems. |
| Natural Authentication (`NaturalAuthentication`) | Proximity unlock | Disable | Low | Rare feature. |
| Certificate Propagation (`CertPropSvc`) | Smartcard cert handling | Disable | Low | Rare use case. |
| Smart Card Device Enumeration Service (`ScDeviceEnum`) | Smart card readers | Disable | Low | Rare. |
| Smart Card Removal Policy (`SCPolicySvc`) | Lock on card removal | Disable | Low | Enterprise. |
| WalletService | Payment wallet | Disable | Low | Rarely used. |
| Microsoft Passport (`NgcSvc`, `NgcCtnrSvc`) | Windows Hello credential | Keep if using Hello | Medium | Biometric auth. |
| Function Discovery Provider Host (`fdPHost`) | Network device discovery | Optional disable | Medium | Affects network browsing. |
| Function Discovery Resource Publication (`FDResPub`) | Publishes this PC on network | Optional disable | Medium | Same as above. |
| Network Connected Devices Auto Setup (`NcdAutoSetup`) | Auto device setup | Optional disable | Low | Impacts printers. |
| SSDP Discovery (`SSDPSRV`) | UPnP discovery | Optional disable | Medium | Some games use UPnP. |
| UPnP Device Host (`upnphost`) | UPnP hosting | Optional disable | Medium | Related to SSDP. |
| Wi Fi Direct Services Connection Manager (`WFDSConMgrSvc`) | Wi Fi Direct | Optional disable | Low | Miracast uses it. |

## Mixed Reality, VR, and 3D

| Service / Feature | Default Role | Optimization Action | Risk | Notes |
| --- | --- | --- | --- | --- |
| Mixed Reality OpenXR Service (`MixedRealityOpenXRSvc`) | Manages WMR headsets | Optional disable | Low | Keep if user owns WMR headset. |
| Spatial Data Service (`SpatialDataService`) | Stores holographic mapping data | Disable | Low | WMR only. |
| Holographic Shell (`HologramWorld`) | Mixed reality shell | Disable | Low | Remove if not using MR. |
| 3D Viewer / Print 3D apps | 3D modeling tools | Optional removal | Low | Document via Appx removal commands. |
| Windows Perception Service (`spectrum`) | Spatial perception | Disable | Low | MR only. |
| Windows Perception Simulation Service (`perceptionsimulation`) | MR simulation | Disable | Low | Dev tool. |

## Virtualization and Hyper V

| Service / Feature | Default Role | Optimization Action | Risk | Notes |
| --- | --- | --- | --- | --- |
| Hyper V Virtual Machine Management (`vmms`) | Manages Hyper V VMs | Optional disable | Medium | Disable only if user does not run Hyper V or WSL2. |
| HV Host Service (`hvservice`) | Hypervisor support | Optional disable | High | Needed for WSL2, Memory Integrity, some anti cheat uses VBS. |
| Windows Sandbox dependencies | Provides sandbox environment | Optional disable | Low | Rare use case. |
| Hyper V Data Exchange Service (`vmickvpexchange`) | VM integration | Disable if not using VMs | Low | Hyper V guest only. |
| Hyper V Guest Service Interface (`vmicguestinterface`) | VM integration | Disable if not using VMs | Low | Same. |
| Hyper V Guest Shutdown Service (`vmicshutdown`) | VM integration | Disable if not using VMs | Low | Same. |
| Hyper V Heartbeat Service (`vmicheartbeat`) | VM integration | Disable if not using VMs | Low | Same. |
| Hyper V PowerShell Direct Service (`vmicvmsession`) | VM integration | Disable if not using VMs | Low | Same. |
| Hyper V Remote Desktop Virtualization Service (`vmicrdv`) | VM integration | Disable if not using VMs | Low | Same. |
| Hyper V Time Synchronization Service (`vmictimesync`) | VM integration | Disable if not using VMs | Low | Same. |
| Hyper V Volume Shadow Copy Requestor (`vmicvss`) | VM integration | Disable if not using VMs | Low | Same. |

## Networking and VPN Services

| Service / Feature | Default Role | Optimization Action | Risk | Notes |
| --- | --- | --- | --- | --- |
| WLAN AutoConfig (`WlanSvc`) | Wi Fi management | Keep if using Wi Fi | High | Core for wireless. |
| WWAN AutoConfig (`WwanSvc`) | Cellular data | Disable | Low | No modem on desktops. |
| Remote Access Auto Connection Manager (`RasAuto`) | Auto dial VPN | Disable | Low | Legacy. |
| Remote Access Connection Manager (`RasMan`) | VPN connections | Keep if using VPN | Medium | VPN gamers need it. |
| IKE and AuthIP IPsec Keying Modules (`IKEEXT`) | VPN/IPsec | Keep if using VPN | Medium | Some games use VPNs. |
| Secure Socket Tunneling Protocol Service (`SstpSvc`) | SSTP VPN | Keep if using VPN | Medium | VPN support. |
| Microsoft iSCSI Initiator Service (`MSiSCSI`) | iSCSI connections | Disable | Low | NAS/SAN only. |
| Net.Tcp Port Sharing Service (`NetTcpPortSharing`) | WCF port sharing | Disable | Low | Dev feature. |
| WinHTTP Web Proxy Auto Discovery (`WinHttpAutoProxySvc`) | Proxy detection | Keep | Medium | Some networks need it. |
| Quality Windows Audio Video Experience (`QWAVE`) | QoS for AV streaming | Keep | Medium | May help streaming. |

## Search, Indexing, and Explorer Extras

| Service / Feature | Default Role | Optimization Action | Risk | Notes |
| --- | --- | --- | --- | --- |
| Windows Search | See above | See above | Medium | Provided for completeness. |
| Indexing Service tasks (`\Microsoft\Windows\Search`) | Rebuilds indexes | Disable tasks | Medium | Same warnings as service. |
| Connected Devices Platform (`CDPSvc`) | Device discovery | Optional disable | Low | Impacts "Share Across Devices" features. |
| Windows Explorer add ons (Quick Assist, Steps Recorder) | Support apps | Optional removal | Low | Document Appx removal commands. |

## Update Helpers and Maintenance

| Service / Feature | Default Role | Optimization Action | Risk | Notes |
| --- | --- | --- | --- | --- |
| Update Orchestrator Service (`UsoSvc`) | Coordinates Windows Update | Set Manual | Medium | Keep ability to update when needed. |
| Windows Update Medic Service (`WaaSMedicSvc`) | Repairs update components | Disable only in privacy preset | Medium | Document risk of corrupted update stack. |
| MapsBroker | Offline maps | Disable | Low | Rarely used. |
| Disk Defragmenter (`\Microsoft\Windows\Defrag\ScheduledDefrag`) | Scheduled defrag | Disable for SSD systems | Low | Leave manual button for HDD. |
| Storage Sense (`Sense`) | Auto cleanup | Optional disable | Low | Some players like it active. |
| Optimize Drives (`defragsvc`) | SSD TRIM and HDD defrag | Set Manual | Low | Let user trigger. |
| App Readiness (`AppReadiness`) | Prepares apps on first sign in | Set Manual | Medium | Needed after major updates. |
| AppX Deployment Service (`AppXSvc`) | Installs/uninstalls Store apps | Keep | Medium | Required for Store games. |
| Microsoft Software Shadow Copy Provider (`swprv`) | VSS provider | Keep | Medium | Restore points need it. |
| Volume Shadow Copy (`VSS`) | Backup snapshots | Keep | Medium | Restore points. |
| Windows Backup (`SDRSVC`) | Windows Backup | Optional disable | Low | Keep if using backup. |
| File History Service (`fhsvc`) | Backs up user files | Optional disable | Low | Keep if user relies on it. |
| Microsoft Storage Spaces SMP (`smphost`) | Storage Spaces | Disable if not using | Low | Advanced storage. |
| Storage Tiers Management (`TieringEngineService`) | SSD/HDD tiering | Disable if not using | Low | Advanced storage. |
| Virtual Disk (`vds`) | Disk management | Set Manual | Low | Admin tool. |
| Spot Verifier (`svsvc`) | File integrity checking | Set Manual | Low | Rare use. |
| Language Experience Service (`LxpSvc`) | Language pack deployment | Set Manual | Low | Keep if switching languages. |
| Problem Reports Control Panel Support (`wercplsupport`) | Error report viewer | Disable | Low | Privacy. |
| Performance Logs and Alerts (`pla`) | Data collection sets | Set Manual | Low | Admin tools. |
| Performance Counter DLL Host (`perfhost`) | Performance counters | Keep | Medium | Monitoring tools use it. |
| WMI Performance Adapter (`wmiApSrv`) | WMI perf data | Set Manual | Low | Monitoring. |
| Windows Encryption Provider Host Service (`WEPHOSTSVC`) | Encryption operations | Keep | Medium | Security. |
| Encrypting File System (`EFS`) | File encryption support | Keep | Medium | Some games store encrypted saves. |

## Optional UI Components and Apps

| Service / Feature | Default Role | Optimization Action | Risk | Notes |
| --- | --- | --- | --- | --- |
| Cortana / SearchUI | Voice assistant | Disable process / uninstall app | Low | Document registry/policy method. |
| News and Interests, Widgets | Feeds | Disable via policy | Low | Quality of life only. |
| Clipchamp, Solitaire Collection, etc. | Inbox games/apps | Optional removal | Low | Provide Appx removal script. |
| Microsoft Store Install Service (`InstallService`) | Handles Store installs | Keep | Medium | Needed for Store purchases even if user prefers Steam. |
| Microsoft Edge Elevation Service (`MicrosoftEdgeElevationService`) | Edge updates | Optional disable | Low | Keep if using Edge. |
| Microsoft Edge Update Service (`edgeupdate`, `edgeupdatem`) | Edge updates | Optional disable | Low | Same. |
| WarpJITSvc | Just in time compilation | Keep | Medium | Edge/apps use it. |
| Retail Demo Service (`RetailDemo`) | Store demo mode | Disable | Low | Consumer PCs. |
| Family Safety (`WpcMonSvc`) | Parental controls | Optional disable | Low | Keep for families. |
| Remote Assistance tasks | Remote assistance | Disable | Low | Rarely needed. |

## Scheduled Task Reference (Comprehensive)

| Task Path | Function | Action |
| --- | --- | --- |
| `\Microsoft\Windows\Application Experience\ProgramDataUpdater` | Uploads compatibility data | Disable in privacy preset |
| `\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser` | Compatibility telemetry | Disable |
| `\Microsoft\Windows\Application Experience\AitAgent` | App telemetry | Disable |
| `\Microsoft\Windows\Application Experience\StartupAppTask` | Startup app telemetry | Disable |
| `\Microsoft\Windows\Customer Experience Improvement Program\Consolidator` | Telemetry upload | Disable |
| `\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip` | USB telemetry | Disable |
| `\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask` | Kernel telemetry | Disable |
| `\Microsoft\Windows\Autochk\Proxy` | Disk check telemetry | Disable |
| `\Microsoft\Windows\MemoryDiagnostic\RunFullMemoryDiagnostic` | Full memory check at boot | Disable |
| `\Microsoft\Windows\MemoryDiagnostic\ProcessMemoryDiagnosticEvents` | Memory diagnostics | Optional |
| `\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem` | Power efficiency check | Disable |
| `\Microsoft\Windows\Shell\FamilySafetyMonitor` | Parental controls | Disable if not used |
| `\Microsoft\Windows\Shell\FamilySafetyRefresh` | Family safety refresh | Disable if not used |
| `\Microsoft\Windows\Shell\FamilySafetyUpload` | Family safety upload | Disable if not used |
| `\Microsoft\Windows\Shell\IndexerAutomaticMaintenance` | Search indexer | Optional disable |
| `\Microsoft\Windows\Shell\CreateObjectTask` | Shell objects | Keep |
| `\Microsoft\Windows\Defrag\ScheduledDefrag` | Disk defrag | Disable for SSD |
| `\Microsoft\Windows\Defender\CacheMaintenance` | Defender maintenance | Keep |
| `\Microsoft\Windows\Defender\Cleanup` | Defender cleanup | Keep |
| `\Microsoft\Windows\Defender\Scheduled Scan` | Defender scan | Keep |
| `\Microsoft\Windows\Defender\Verification` | Defender verify | Keep |
| `\Microsoft\Windows\Windows Error Reporting\QueueReporting` | Crash upload | Optional |
| `\Microsoft\Windows\Maps\MapsUpdateTask` | Map updates | Disable |
| `\Microsoft\Windows\Maps\MapsToastTask` | Maps toast | Disable |
| `\Microsoft\Windows\UpdateOrchestrator\Reboot` | Schedule forced reboots | Optional disable |
| `\Microsoft\Windows\UpdateOrchestrator\Schedule Scan` | Update scan | Keep |
| `\Microsoft\Windows\UpdateOrchestrator\Schedule Scan Static Task` | Static scan | Keep |
| `\Microsoft\Windows\UpdateOrchestrator\Schedule Maintenance Work` | Update maintenance | Optional |
| `\Microsoft\Windows\UpdateOrchestrator\Schedule Wake To Work` | Wake to update | Disable |
| `\Microsoft\Windows\UpdateOrchestrator\Schedule Work` | Update work | Keep |
| `\Microsoft\Windows\UpdateOrchestrator\UpdateModelTask` | Update model | Keep |
| `\Microsoft\Windows\UpdateOrchestrator\USO_UxBroker` | Update UX | Keep |
| `\Microsoft\Windows\ApplicationData\CleanupTemporaryState` | Cleans temp app state | Optional disable |
| `\Microsoft\Windows\ApplicationData\DsSvcCleanup` | Data sharing cleanup | Optional disable |
| `\Microsoft\Windows\AppxDeploymentClient\Pre-staged app cleanup` | Removes staged apps | Optional disable |
| `\Microsoft\Windows\Bluetooth\UninstallDeviceTask` | Removes old BT devices | Optional disable |
| `\Microsoft\Windows\BrokerInfrastructure\BgTaskRegistrationMaintenanceTask` | Background task maintenance | Keep |
| `\Microsoft\Windows\Chkdsk\ProactiveScan` | Proactive disk check | Optional disable |
| `\Microsoft\Windows\Clip\License Validation` | Clipboard license | Keep |
| `\Microsoft\Windows\CloudExperienceHost\CreateObjectTask` | OOBE tasks | Disable after setup |
| `\Microsoft\Windows\Device Information\Device` | Device telemetry | Disable |
| `\Microsoft\Windows\Device Information\Device User` | User telemetry | Disable |
| `\Microsoft\Windows\DeviceDirectoryClient\HandleCommand` | Device directory | Disable |
| `\Microsoft\Windows\DeviceDirectoryClient\HandleWnsCommand` | WNS commands | Disable |
| `\Microsoft\Windows\DeviceDirectoryClient\IntegrityCheck` | Integrity check | Disable |
| `\Microsoft\Windows\DeviceDirectoryClient\LocateCommandUserSession` | Location commands | Disable |
| `\Microsoft\Windows\DeviceDirectoryClient\RegisterDeviceAccountChange` | Account changes | Disable |
| `\Microsoft\Windows\DeviceDirectoryClient\RegisterDeviceLocationRightsChange` | Location rights | Disable |
| `\Microsoft\Windows\DeviceDirectoryClient\RegisterDevicePeriodic24` | Daily check | Disable |
| `\Microsoft\Windows\DeviceDirectoryClient\RegisterDevicePolicyChange` | Policy changes | Disable |
| `\Microsoft\Windows\DeviceDirectoryClient\RegisterDeviceProtectionStateChanged` | Protection state | Disable |
| `\Microsoft\Windows\DeviceDirectoryClient\RegisterDeviceSettingChange` | Settings changes | Disable |
| `\Microsoft\Windows\DeviceDirectoryClient\RegisterUserDevice` | User device | Disable |
| `\Microsoft\Windows\Diagnosis\RecommendedTroubleshootingScanner` | Auto troubleshoot | Disable |
| `\Microsoft\Windows\Diagnosis\Scheduled` | Scheduled diagnosis | Disable |
| `\Microsoft\Windows\DiskCleanup\SilentCleanup` | Silent disk cleanup | Optional (keep for storage) |
| `\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector` | Disk telemetry | Disable |
| `\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticResolver` | Disk troubleshooter | Optional disable |
| `\Microsoft\Windows\DiskFootprint\Diagnostics` | Disk footprint | Disable |
| `\Microsoft\Windows\DiskFootprint\StorageSense` | Storage Sense | Optional (user pref) |
| `\Microsoft\Windows\ErrorDetails\EnableErrorDetailsUpdate` | Error details | Disable |
| `\Microsoft\Windows\ErrorDetails\ErrorDetailsUpdate` | Error updates | Disable |
| `\Microsoft\Windows\Feedback\Siuf\DmClient` | Feedback upload | Disable |
| `\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload` | Feedback download | Disable |
| `\Microsoft\Windows\File Classification Infrastructure\Property Definition Sync` | File classification | Disable |
| `\Microsoft\Windows\FileHistory\File History (maintenance mode)` | File History | Optional |
| `\Microsoft\Windows\Flighting\FeatureConfig\ReconcileFeatures` | Feature flighting | Disable |
| `\Microsoft\Windows\Flighting\FeatureConfig\UsageDataFlushing` | Usage data | Disable |
| `\Microsoft\Windows\Flighting\FeatureConfig\UsageDataReporting` | Usage reporting | Disable |
| `\Microsoft\Windows\Flighting\OneSettings\RefreshCache` | Settings refresh | Disable |
| `\Microsoft\Windows\HelloFace\FODCleanupTask` | Hello cleanup | Optional |
| `\Microsoft\Windows\Input\LocalUserSyncDataAvailable` | Input sync | Optional disable |
| `\Microsoft\Windows\Input\MouseSyncDataAvailable` | Mouse sync | Optional disable |
| `\Microsoft\Windows\Input\PenSyncDataAvailable` | Pen sync | Optional disable |
| `\Microsoft\Windows\Input\TouchpadSyncDataAvailable` | Touchpad sync | Optional disable |
| `\Microsoft\Windows\International\Synchronize Language Settings` | Language sync | Optional |
| `\Microsoft\Windows\LanguageComponentsInstaller\Installation` | Language install | Set Manual |
| `\Microsoft\Windows\LanguageComponentsInstaller\ReconcileLanguageResources` | Language reconcile | Set Manual |
| `\Microsoft\Windows\LanguageComponentsInstaller\Uninstallation` | Language uninstall | Set Manual |
| `\Microsoft\Windows\License Manager\TempSignedLicenseExchange` | License exchange | Keep |
| `\Microsoft\Windows\Location\Notifications` | Location notifications | Disable |
| `\Microsoft\Windows\Location\WindowsActionDialog` | Location dialog | Disable |
| `\Microsoft\Windows\Maintenance\WinSAT` | Windows Experience Index | Disable |
| `\Microsoft\Windows\Management\Provisioning\Cellular` | Cellular provisioning | Disable |
| `\Microsoft\Windows\Management\Provisioning\Logon` | Logon provisioning | Optional |
| `\Microsoft\Windows\MediaSharing\UpdateLibrary` | Media library update | Optional |
| `\Microsoft\Windows\Mobile Broadband Accounts\MNO Metadata Parser` | Cellular metadata | Disable |
| `\Microsoft\Windows\MUI\LPRemove` | Language pack removal | Optional |
| `\Microsoft\Windows\Multimedia\SystemSoundsService` | System sounds | Keep |
| `\Microsoft\Windows\NetCfg\BindingWorkItemQueueHandler` | Network binding | Keep |
| `\Microsoft\Windows\NetTrace\GatherNetworkInfo` | Network trace | Disable |
| `\Microsoft\Windows\NlaSvc\WiFiTask` | Wi Fi NLA | Keep |
| `\Microsoft\Windows\PI\Sqm-Tasks` | SQM telemetry | Disable |
| `\Microsoft\Windows\Plug and Play\Device Install Group Policy` | Device policy | Keep |
| `\Microsoft\Windows\Plug and Play\Device Install Reboot Required` | Reboot prompt | Keep |
| `\Microsoft\Windows\Plug and Play\Sysprep Generalize Drivers` | Sysprep | Disable |
| `\Microsoft\Windows\PushToInstall\LoginCheck` | Push to install check | Disable |
| `\Microsoft\Windows\PushToInstall\Registration` | Push registration | Disable |
| `\Microsoft\Windows\Ras\MobilityManager` | VPN mobility | Optional |
| `\Microsoft\Windows\RecoveryEnvironment\VerifyWinRE` | Verify recovery | Keep |
| `\Microsoft\Windows\Registry\RegIdleBackup` | Registry backup | Keep |
| `\Microsoft\Windows\RemoteAssistance\RemoteAssistanceTask` | Remote assistance | Disable |
| `\Microsoft\Windows\RetailDemo\CleanupOfflineContent` | Demo cleanup | Disable |
| `\Microsoft\Windows\SettingSync\BackgroundUploadTask` | Settings upload | Disable |
| `\Microsoft\Windows\SettingSync\BackupTask` | Settings backup | Optional |
| `\Microsoft\Windows\SettingSync\NetworkStateChangeTask` | Settings network | Optional |
| `\Microsoft\Windows\Setup\SetupCleanupTask` | Setup cleanup | Set Manual |
| `\Microsoft\Windows\Setup\SnapshotCleanupTask` | Snapshot cleanup | Set Manual |
| `\Microsoft\Windows\SharedPC\Account Cleanup` | Shared PC cleanup | Disable |
| `\Microsoft\Windows\SoftwareProtectionPlatform\SvcRestartTask` | License restart | Keep |
| `\Microsoft\Windows\SoftwareProtectionPlatform\SvcRestartTaskLogon` | License logon | Keep |
| `\Microsoft\Windows\SoftwareProtectionPlatform\SvcRestartTaskNetwork` | License network | Keep |
| `\Microsoft\Windows\SpacePort\SpaceAgentTask` | Storage Spaces | Optional |
| `\Microsoft\Windows\SpacePort\SpaceManagerTask` | Storage manager | Optional |
| `\Microsoft\Windows\Speech\SpeechModelDownloadTask` | Speech models | Disable |
| `\Microsoft\Windows\Sysmain\HybridDriveCachePrepopulate` | Hybrid drive cache | Optional |
| `\Microsoft\Windows\Sysmain\HybridDriveCacheRebalance` | Cache rebalance | Optional |
| `\Microsoft\Windows\Sysmain\ResPriStaticDbSync` | Resource priority | Optional |
| `\Microsoft\Windows\Sysmain\WsSwapAssessmentTask` | Swap assessment | Optional |
| `\Microsoft\Windows\SystemRestore\SR` | System Restore | Keep |
| `\Microsoft\Windows\Task Manager\Interactive` | Task Manager | Keep |
| `\Microsoft\Windows\TextServicesFramework\MsCtfMonitor` | Text services | Keep |
| `\Microsoft\Windows\Time Synchronization\ForceSynchronizeTime` | Force time sync | Keep |
| `\Microsoft\Windows\Time Synchronization\SynchronizeTime` | Time sync | Keep |
| `\Microsoft\Windows\Time Zone\SynchronizeTimeZone` | Timezone sync | Optional |
| `\Microsoft\Windows\TPM\Tpm-HASCertRetr` | TPM cert | Keep |
| `\Microsoft\Windows\TPM\Tpm-Maintenance` | TPM maintenance | Keep |
| `\Microsoft\Windows\UNP\RunUpdateNotificationMgr` | Update notification | Optional |
| `\Microsoft\Windows\UPnP\UPnPHostConfig` | UPnP config | Optional |
| `\Microsoft\Windows\USB\Usb-Notifications` | USB notifications | Keep |
| `\Microsoft\Windows\User Profile Service\HiveUploadTask` | Profile upload | Disable |
| `\Microsoft\Windows\WCM\WiFiTask` | Wi Fi connection | Keep |
| `\Microsoft\Windows\WDI\ResolutionHost` | Diagnostic resolution | Disable |
| `\Microsoft\Windows\Windows Filtering Platform\BfeOnServiceStartTypeChange` | Firewall service | Keep |
| `\Microsoft\Windows\WindowsColorSystem\Calibration Loader` | Color calibration | Keep |
| `\Microsoft\Windows\WindowsUpdate\Scheduled Start` | Update start | Keep |
| `\Microsoft\Windows\WlanSvc\CDSSync` | Wi Fi sync | Optional |
| `\Microsoft\Windows\WOF\WIM-Hash-Management` | WIM hashing | Optional |
| `\Microsoft\Windows\WOF\WIM-Hash-Validation` | WIM validation | Optional |
| `\Microsoft\Windows\Work Folders\Work Folders Logon Synchronization` | Work Folders | Disable |
| `\Microsoft\Windows\Work Folders\Work Folders Maintenance Work` | Work Folders | Disable |
| `\Microsoft\Windows\Workplace Join\Automatic-Device-Join` | Workplace join | Disable |
| `\Microsoft\Windows\Workplace Join\Device-Sync` | Device sync | Disable |
| `\Microsoft\Windows\Workplace Join\Recovery-Check` | Recovery check | Disable |
| `\Microsoft\Windows\WS\WSTask` | Windows Store task | Optional |
| `\Microsoft\Windows\WwanSvc\NotificationTask` | Cellular notification | Disable |
| `\Microsoft\Windows\WwanSvc\OobeDiscovery` | Cellular OOBE | Disable |
| `\Microsoft\XblGameSave\XblGameSaveTask` | Xbox save sync | Optional toggle |
| `\Microsoft\XblGameSave\XblGameSaveTaskLogon` | Xbox save logon | Optional toggle |
| `\Microsoft\Windows\StateRepository\MaintenanceTask` | App state DB tuning | Keep |
| `\Microsoft\Windows\StateRepository\CacheMaintenance` | App state cache cleanup | Optional |
| `\Microsoft\Windows\Store\AutomaticAppUpdate` | Store app updates | Optional disable |
| `\Microsoft\Windows\Store\WSRefreshBannedAppsListTask` | Store compliance refresh | Disable |
| `\Microsoft\Windows\Store\WSRefreshCache` | Store cache maintenance | Optional disable |
| `\Microsoft\Windows\WindowsCopilot\CopilotTask` | Copilot background refresh | Disable |
| `\Microsoft\Windows\WindowsBackup\BackupMonitor` | Windows Backup monitor | Optional |
| `\Microsoft\Windows\WindowsBackup\BackupTask` | Windows Backup task | Optional |
| `\MicrosoftEdgeUpdateTaskMachineCore` | Edge updater core | Optional disable |
| `\MicrosoftEdgeUpdateTaskMachineUA` | Edge updater UA | Optional disable |

## Inbox Apps for Removal

| App | Package Name Pattern | Action |
| --- | --- | --- |
| 3D Builder | `Microsoft.3DBuilder` | Remove |
| 3D Viewer | `Microsoft.Microsoft3DViewer` | Remove |
| Alarms and Clock | `Microsoft.WindowsAlarms` | Optional |
| Calculator | `Microsoft.WindowsCalculator` | Keep |
| Calendar/Mail | `microsoft.windowscommunicationsapps` | Optional |
| Camera | `Microsoft.WindowsCamera` | Optional |
| Clipchamp | `Clipchamp.Clipchamp` | Remove |
| Cortana | `Microsoft.549981C3F5F10` | Remove |
| Disney+ | `Disney.*` | Remove |
| Facebook | `Facebook.*` | Remove |
| Feedback Hub | `Microsoft.WindowsFeedbackHub` | Remove |
| Get Help | `Microsoft.GetHelp` | Remove |
| Groove Music | `Microsoft.ZuneMusic` | Optional |
| Maps | `Microsoft.WindowsMaps` | Remove |
| Messaging | `Microsoft.Messaging` | Remove |
| Microsoft News | `Microsoft.BingNews` | Remove |
| Microsoft Pay | `Microsoft.Wallet` | Remove |
| Microsoft Solitaire Collection | `Microsoft.MicrosoftSolitaireCollection` | Remove |
| Microsoft Teams | `MicrosoftTeams` | Remove |
| Microsoft Tips | `Microsoft.Getstarted` | Remove |
| Microsoft To Do | `Microsoft.Todos` | Optional |
| Microsoft Dev Home | `Microsoft.DevHome` | Remove |
| Microsoft Outlook (new) | `Microsoft.OutlookForWindows` | Optional |
| Mixed Reality Portal | `Microsoft.MixedReality.Portal` | Remove |
| Money | `Microsoft.BingFinance` | Remove |
| Movies and TV | `Microsoft.ZuneVideo` | Optional |
| News | `Microsoft.BingNews` | Remove |
| Office Hub | `Microsoft.MicrosoftOfficeHub` | Optional |
| OneNote | `Microsoft.Office.OneNote` | Optional |
| Paint 3D | `Microsoft.MSPaint` (3D version) | Remove |
| People | `Microsoft.People` | Remove |
| Phone Link | `Microsoft.YourPhone` | Remove |
| Photos | `Microsoft.Windows.Photos` | Keep |
| Power Automate | `Microsoft.PowerAutomateDesktop` | Remove |
| Print 3D | `Microsoft.Print3D` | Remove |
| Quick Assist | `MicrosoftCorporationII.QuickAssist` | Optional |
| Skype | `Microsoft.SkypeApp` | Remove |
| Snipping Tool | `Microsoft.ScreenSketch` | Keep |
| Spotify | `SpotifyAB.SpotifyMusic` | Remove |
| Sports | `Microsoft.BingSports` | Remove |
| Sticky Notes | `Microsoft.MicrosoftStickyNotes` | Optional |
| Voice Recorder | `Microsoft.WindowsSoundRecorder` | Optional |
| Weather | `Microsoft.BingWeather` | Optional |
| Web Experience Pack | `MicrosoftWindows.Client.WebExperience` | Remove |
| Whiteboard | `Microsoft.Whiteboard` | Remove |
| Windows Backup | `MicrosoftWindows.Backup` | Optional |
| Xbox App | `Microsoft.XboxApp` | Optional toggle |
| Xbox Console Companion | `Microsoft.XboxGamingOverlay` | Optional toggle |
| Xbox Game Bar | `Microsoft.XboxGameOverlay` | Optional toggle |
| Xbox Identity Provider | `Microsoft.XboxIdentityProvider` | Keep if using Xbox |
| Xbox Speech to Text Overlay | `Microsoft.XboxSpeechToTextOverlay` | Optional |
| Zune Music | `Microsoft.ZuneMusic` | Optional |
| Zune Video | `Microsoft.ZuneVideo` | Optional |

## Windows Optional Features (Features on Demand)

| Feature | Default State | Suggested Action | Availability | Notes |
| --- | --- | --- | --- | --- |
| Windows Sandbox | Off | Optional enable toggle | Win10/11 Pro, Enterprise, Education | Requires Hyper V and Virtualization Based Security. |
| Virtual Machine Platform | Off | Optional enable toggle | Win10/11 Home+ | Needed for WSL2; activates hypervisor. |
| Windows Subsystem for Linux | Off | Optional enable toggle | Win10 2004+ and Win11 all editions | Depends on Virtual Machine Platform on Home. |
| Windows Subsystem for Android | Off | Optional enable toggle | Win11 22H2+ Home (US), Pro, Enterprise | Exclusive to Windows 11; requires Amazon Appstore setup. |
| Hyper V | Off | Optional enable toggle | Win10/11 Pro, Enterprise, Education | Not available on Home; enabling impacts VirtualBox/VMware. |
| Containers | Off | Optional enable toggle | Win10/11 Pro, Enterprise | Required for Docker on Windows without WSL. |
| BitLocker Device Encryption | On for supported hardware | Keep unless incompatible | Win10/11 Pro, Enterprise, Education | Surfaces through `BDESVC`; ensure manifests respect hardware support. |
| Device Guard / Credential Guard | Off | Optional enable toggle | Win10/11 Enterprise, Education | Requires VBS; ties into `dgssvc` and `SgrmBroker`. |
| AppLocker | Off | Optional enable toggle | Win10/11 Enterprise, Education | Uses `AppIDSvc`; avoid enabling on unmanaged rigs. |
| BranchCache | Off | Optional enable toggle | Win10/11 Pro, Enterprise, Education | Service `PeerDistSvc`; rarely needed for gamers. |
| DirectAccess | Off | Optional enable toggle | Win10/11 Enterprise | Depends on `NcaSvc`; remote corporate networking feature. |
| Remote Server Administration Tools (RSAT) | Off | Optional install | Win10/11 Pro, Enterprise, Education | Adds admin consoles; not for gaming. |
| OpenSSH Client | On (Win11), Optional (Win10) | Optional disable | Win10/11 all editions | Background update tasks minimal; leave as user choice. |
| OpenSSH Server | Off | Optional enable toggle | Win10/11 all editions | Exposes SSH service; disable unless explicitly needed. |
| Legacy Components (DirectPlay) | Off | Optional enable toggle | Win10/11 all editions | Needed for some classics; document compatibility use case. |
| Media Features (Windows Media Player) | On | Optional disable | Win10 Home/Pro, Win11 Pro | N/A on N editions; removal affects DLNA. |
| XPS Viewer | Off (Win11), On (older Win10) | Optional removal | Win10/11 all editions | Legacy document viewer; deprecate unless required. |

## OS and SKU Availability Cheat Sheet

| Component or Bundle | Win10 Home | Win10 Pro | Win10 Enterprise/Education | Win11 Home | Win11 Pro | Win11 Enterprise/Education | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Widgets & Windows Web Experience Pack (`MicrosoftWindows.Client.WebExperience`) | Limited (Spotlight only) | Limited | Limited | Included by default | Included by default | Included by default | Provides Widgets, Copilot shell, Recommendations feed. |
| Windows Copilot UX | Not available | Not available | Not available | Included (23H2+, region gated) | Included (23H2+) | Included (23H2+) | Piggybacks on Web Experience Pack updates; disable via policy if needed. |
| Windows Subsystem for Android | N/A | N/A | N/A | Available in supported regions | Available | Available | Exclusive to Windows 11; manage via Optional Features section. |
| Windows Sandbox | N/A | Available | Available | N/A | Available | Available | Requires virtualization + Hyper V. |
| Hyper V role | N/A | Available | Available | N/A | Available | Available | Home editions can only use WSL2 lightweight hypervisor. |
| BitLocker Device Encryption | Hardware dependent auto enable | Included | Included | Hardware dependent auto enable | Included | Included | Requires TPM 2.0 and Modern Standby on Home. |
| AppLocker (`AppIDSvc`) | N/A | N/A | Included | N/A | N/A | Included | Managed by enterprise policy only. |
| Device Guard / Credential Guard (`dgssvc`, `SgrmBroker`) | N/A | Available (Pro for Business) | Included | N/A | Available (Pro for Business) | Included | Requires VBS; interplay with anti cheat. |
| BranchCache (`PeerDistSvc`) | N/A | Included | Included | N/A | Included | Included | Enterprise content caching; safe to disable on personal rigs. |
| DirectAccess (`NcaSvc`) | N/A | N/A | Included | N/A | N/A | Included | Corporate VPN replacement; disable outside enterprise. |
| Windows Defender Application Guard (`wdagservice`) | N/A | Available | Available | N/A | Available | Available | Integrates with Edge; heavy use of virtualization. |
| Windows Update for Business policy set (`UsoSvc`, `WaaSMedicSvc`) | Group policy limited | GP capable | GP capable | Settings based deferrals only | GP capable | GP capable | Defines how aggressively updates can be postponed. |
| Local Group Policy Editor (`gpedit.msc`) | N/A | Included | Included | N/A | Included | Included | Drives many privacy/preset toggles; Home requires registry edits instead. |
| Windows Hello Enhanced Biometric Suite (`WbioSrvc`, `NgcSvc`) | Included | Included | Included | Included | Included | Included | Biometrics optional but present everywhere. |
| Windows Defender Application Control (WDAC) | Controlled via policy only | Available | Included | Controlled via policy only | Available | Included | Another name for Device Guard; avoid toggling unless policy aware. |

### Windows 11 Exclusive Components Already Cataloged

- Windows Widgets / Web Experience Pack (see Optional UI Components section).
- Clipchamp, Outlook (new), Dev Home, and other Store shipped inbox apps (see Inbox Apps table).
- Voice Access, Live Captions, and other accessibility shells piggyback on `Accessibility Tools` optional features; ensure presets leave them enabled unless user opts out.

### Windows 10 Legacy Components to Keep in Mind

- Legacy Microsoft Edge (EdgeHTML) scheduled tasks (`\MicrosoftEdge\MicrosoftEdgeUpdateTaskMachine*`) still exist on LTSB/LTSC branches; treat like optional UI tasks for cleanup.
- OneSync legacy sync stack (`OneSyncSvc`) remains active on Win10 even when Widgets are absent; we already list it under Cloud Sync.
- Windows Media Player remains on by default for Win10 non N editions; Win11 hides it behind Media Features.
- Cortana is removed on Windows 11 23H2+, but persists as an AppX on earlier Win10/11 builds; treat it as optional removal where present.

## Using the Catalog

1. **Manifest Mapping:** Each row should eventually correspond to a `tweaks[].id` entry in a manifest. Copy the name, default role, optimization action, and risk level directly into the `defaultBehavior`, `whenDisabled`, and `riskLevel` fields.
2. **Preset Planning:** Use the category sections to build presets. For example, the "Performance Core" preset may include SysMain, Delivery Optimization, and Windows Search, while the "Privacy Shield" preset includes telemetry services and advertising IDs.
3. **Anti Cheat Review:** Before committing a tweak to a default preset, double check how common anti cheat systems (EAC, BattlEye, Vanguard) behave when that service is missing. Add caution notes when needed.
4. **User Education:** The Notes column is a reminder to write playful, clear tooltips. Players should always know what they are trading off.

This catalog will evolve as we test on actual Windows builds. When you discover a new service worth toggling, add it here first, include the rationale, and then mirror it in the manifests.
