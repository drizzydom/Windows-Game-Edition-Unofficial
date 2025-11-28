# Tweak Manifest Schema

Manifest files describe every optimization the project can perform. They must be easy for humans to read, simple for PowerShell to parse, and rich enough to drive tooltips in the UI. This document outlines the structure each manifest should follow so future scripts and the desktop shell behave consistently.

## Directory Layout

Manifests live under a dedicated `manifests/` folder. Each preset or category gets its own JSON file so players can mix and match bundles later. Example layout once we start shipping tweaks:

```
manifests/
  performance.core.json
  privacy.full-lockdown.json
  xbox.optional.json
```

## File Structure Overview

Every manifest file is a JSON object with two sections: `metadata` and `tweaks`.

- `metadata` describes the preset itself (id, name, description, default selection state).
- `tweaks` is an array of tweak entries. Each entry defines what the service or feature does by default, what happens when we disable it, how to run the change, and how to undo it.

### Required Fields

| Field | Type | Description |
| ----- | ---- | ----------- |
| `schemaVersion` | string | Semver string that lets tooling detect breaking changes. Start at `0.1.0`. |
| `metadata.id` | string | Unique slug for the preset (e.g., `performance-core`). |
| `metadata.name` | string | Human friendly name shown in UI. |
| `metadata.category` | string | High level bucket such as `Performance`, `Privacy`, `Xbox`, `Bluetooth`, `Enterprise`, or `Optional`. |
| `metadata.description` | string | Short summary of what the preset targets. |
| `metadata.defaultState` | string | `enabled`, `disabled`, or `preview`. Determines whether the preset is selected when the app loads. |
| `tweaks[].id` | string | Unique slug for a tweak, typically `svc-sysmain` or `task-compattel`. |
| `tweaks[].name` | string | Friendly display label for the tweak. |
| `tweaks[].category` | string | Fine grained category shown in the UI. |
| `tweaks[].supportedSkus` | object | Describes which Windows SKUs can use the tweak. See below. |
| `tweaks[].defaultBehavior` | string | Tooltip text describing what Windows does out of the box. |
| `tweaks[].whenDisabled` | string | Tooltip text that explains the impact of turning the tweak on. |
| `tweaks[].riskLevel` | string | `low`, `medium`, or `high`. Helps highlight caution badges. |
| `tweaks[].requiresReboot` | boolean | Whether the user must reboot for the change to stick. |
| `tweaks[].requiresElevation` | boolean | Whether the commands must be run as administrator. |
| `tweaks[].commands.disable` | array | Ordered list of command objects that apply the tweak. |
| `tweaks[].commands.enable` | array | Ordered list of command objects that revert the tweak. |

### Optional Fields

| Field | Type | Description |
| ----- | ---- | ----------- |
| `metadata.tags` | array of strings | Additional labels such as `default`, `pro-only`, or `beta`. |
| `tweaks[].tags` | array of strings | Labels used for filtering in the UI (`networking`, `telemetry`, `storage`, etc.). |
| `tweaks[].dependencies` | array of strings | Other tweak ids that must run first. |
| `tweaks[].conflicts` | array of strings | Tweak ids that cannot run together. |
| `tweaks[].notes` | string | Long form tips, such as known issues with specific vendors. |
| `tweaks[].detection` | object | Checks to verify whether a tweak is already applied. |

### `supportedSkus` Object

```
"supportedSkus": {
  "include": ["win10-home", "win10-pro", "win11-home", "win11-pro"],
  "exclude": ["win11-enterprise"]
}
```

- `include` lists SKUs where the tweak is safe. Use `all` to cover every SKU.
- `exclude` lets us hide tweaks on certain editions even if they appear in `include`.
- In the PowerShell executor we will marry these values with runtime detection from `Get-ComputerInfo`.

### Command Objects

Each command object describes a single action. Types we expect to support:

- `service`: start, stop, set startup type.
- `scheduledTask`: enable, disable, run once.
- `registry`: set value, delete key, export backup.
- `powershell`: raw PowerShell snippet for anything more complex.

Example command definition:

```
{
  "type": "service",
  "name": "SysMain",
  "action": "SetStartup",
  "startupType": "Disabled",
  "undoAction": "SetStartup",
  "undoStartupType": "Manual"
}
```

Scripts should log each command before execution and honor `-WhatIf` by simulating the full array without making changes.

## Example Manifest

See `manifests/sample.performance.json` for a working example that targets the SysMain service. Future manifests should follow the same pattern and expand the `tweaks` array with additional entries.

## Contributing to the Schema

1. Propose schema changes in an issue so we can discuss compatibility and migration steps.
2. If the change risks breaking older manifests, bump `schemaVersion` and document the migration path inside this file.
3. Keep descriptions friendly and plain spoken. Tooltips are pulled directly from these entries, so clarity matters more than dense technical jargon.
