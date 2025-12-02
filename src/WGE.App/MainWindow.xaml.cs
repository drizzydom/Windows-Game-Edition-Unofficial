using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Runtime.CompilerServices;

namespace WGE.App;

public partial class MainWindow : Window
{
    private readonly ObservableCollection<ManifestSummary> _manifests = new();
    private readonly ObservableCollection<TweakRow> _tweaks = new();
    private readonly ObservableCollection<ActionResultRow> _results = new();
    private static readonly JsonSerializerOptions AutomationJsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };
    private ManifestSummary? _selectedManifest;

    public MainWindow()
    {
        InitializeComponent();
        ManifestList.ItemsSource = _manifests;
        TweaksGrid.ItemsSource = _tweaks;
        ResultGrid.ItemsSource = _results;
        Loaded += OnLoaded;
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        try
        {
            LoadManifests();
        }
        catch (Exception ex)
        {
            AppendLog($"Failed to load manifests: {ex.Message}");
        }
    }

    private void LoadManifests()
    {
        _manifests.Clear();
        var automationRoot = Path.Combine(AppContext.BaseDirectory, "Automation");
        var manifestRoot = Path.Combine(automationRoot, "manifests");

        if (!Directory.Exists(manifestRoot))
        {
            AppendLog($"Manifest directory not found: {manifestRoot}");
            return;
        }

        var options = new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        };

        foreach (var manifestFile in Directory.EnumerateFiles(manifestRoot, "*.json", SearchOption.TopDirectoryOnly))
        {
            try
            {
                using var stream = File.OpenRead(manifestFile);
                var manifest = JsonSerializer.Deserialize<ManifestDocument>(stream, options);
                if (manifest?.Metadata is null)
                {
                    AppendLog($"Skipping manifest with missing metadata: {manifestFile}");
                    continue;
                }

                var tweakItems = manifest.Tweaks?.ToList() ?? new();
                var summary = new ManifestSummary(
                    manifest.Metadata.Id ?? Path.GetFileNameWithoutExtension(manifestFile),
                    manifest.Metadata.Name ?? Path.GetFileNameWithoutExtension(manifestFile),
                    manifest.Metadata.Description ?? string.Empty,
                    manifest.Metadata.DefaultState ?? string.Empty,
                    manifest.Metadata.Category ?? string.Empty,
                    tweakItems.Count,
                    manifestFile,
                    tweakItems)
                {
                    Tags = manifest.Metadata.Tags?.ToArray() ?? Array.Empty<string>()
                };

                _manifests.Add(summary);
            }
            catch (Exception ex)
            {
                AppendLog($"Could not parse manifest '{manifestFile}': {ex.Message}");
            }
        }

        if (_manifests.Count == 0)
        {
            AppendLog("No manifests were found. Drop JSON manifest files into Automation/Manifests to continue.");
        }
        else
        {
            ManifestList.SelectedIndex = 0;
        }
    }

    private async void ApplyButton_OnClick(object sender, RoutedEventArgs e)
    {
        await RunPresetAsync(dryRun: false, revert: false);
    }

    private async void DryRunButton_OnClick(object sender, RoutedEventArgs e)
    {
        await RunPresetAsync(dryRun: true, revert: false);
    }

    private async Task RunPresetAsync(bool dryRun, bool revert)
    {
        if (_selectedManifest is null)
        {
            AppendLog("Pick a preset before applying anything.");
            return;
        }

        var powershellPath = ResolvePowershellPath();
        if (string.IsNullOrWhiteSpace(powershellPath) || !File.Exists(powershellPath))
        {
            AppendLog("Unable to locate Windows PowerShell 5.1. Make sure you run this on Windows 10 or newer.");
            return;
        }

        var scriptPath = Path.Combine(AppContext.BaseDirectory, "Automation", "wge.ps1");
        if (!File.Exists(scriptPath))
        {
            AppendLog($"Automation script missing: {scriptPath}");
            return;
        }

        var presetId = Path.GetFileNameWithoutExtension(_selectedManifest.FilePath);
        var action = revert ? "reverting" : "applying";
        var actionLabel = revert ? "Reverting" : (dryRun ? "Previewing" : "Applying");
        AppendLog($"{actionLabel} preset '{_selectedManifest.Name}' ({presetId})...");

        ToggleUiBusy(true);
        ShowLoading(true, $"{actionLabel} tweaks...");
        _results.Clear();

        try
        {
            var runResult = await Task.Run(() => ExecuteAutomation(powershellPath, scriptPath, presetId, dryRun, revert));
            if (runResult.Summary is not null)
            {
                ApplyAutomationSummary(runResult.Summary, runResult, dryRun);
            }
            else
            {
                if (!string.IsNullOrWhiteSpace(runResult.StandardOutput))
                {
                    AppendLog(runResult.StandardOutput.Trim());
                }

                if (!string.IsNullOrWhiteSpace(runResult.StandardError))
                {
                    AppendLog($"stderr: {runResult.StandardError.Trim()}");
                }

                AppendLog($"Exit code: {runResult.ExitCode}");
                _results.Add(new ActionResultRow("FAIL", _selectedManifest?.Name ?? presetId, "-", "Automation did not return structured output.", $"Exit code {runResult.ExitCode}"));
            }
        }
        catch (Exception ex)
        {
            AppendLog($"Automation failed: {ex.Message}");
        }
        finally
        {
            ToggleUiBusy(false);
            ShowLoading(false);
        }

        if (_selectedManifest is not null)
        {
            ShowLoading(true, "Refreshing status...");
            await RefreshTweakStatusesAsync(_selectedManifest);
            ShowLoading(false);
        }
    }

    private static AutomationRunResult ExecuteAutomation(string powershellPath, string scriptPath, string presetId, bool dryRun, bool revert)
    {
        var info = new ProcessStartInfo(powershellPath)
        {
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
            WorkingDirectory = Path.GetDirectoryName(scriptPath) ?? AppContext.BaseDirectory
        };

        info.ArgumentList.Add("-NoLogo");
        info.ArgumentList.Add("-NoProfile");
        info.ArgumentList.Add("-ExecutionPolicy");
        info.ArgumentList.Add("Bypass");
        info.ArgumentList.Add("-File");
        info.ArgumentList.Add(scriptPath);
        info.ArgumentList.Add("-Preset");
        info.ArgumentList.Add(presetId);
        info.ArgumentList.Add("-SkipUnsupported");
        info.ArgumentList.Add("-AsJson");
        if (dryRun)
        {
            info.ArgumentList.Add("-DryRun");
        }
        if (revert)
        {
            info.ArgumentList.Add("-Revert");
        }

        using var process = new Process { StartInfo = info };
        process.Start();
        var stdout = process.StandardOutput.ReadToEnd();
        var stderr = process.StandardError.ReadToEnd();
        process.WaitForExit();

        AutomationSummary? summary = null;
        var trimmedOut = stdout.Trim();
        if (!string.IsNullOrWhiteSpace(trimmedOut))
        {
            try
            {
                summary = JsonSerializer.Deserialize<AutomationSummary>(trimmedOut, AutomationJsonOptions);
            }
            catch (JsonException)
            {
                // If parsing fails, fall back to the textual output.
            }
        }

        return new AutomationRunResult(summary, stdout, stderr, process.ExitCode);
    }

    private void ManifestList_OnSelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (ManifestList.SelectedItem is ManifestSummary summary)
        {
            _selectedManifest = summary;
            UpdatePresetDetails(summary);
        }
    }

    private void UpdatePresetDetails(ManifestSummary summary)
    {
        PresetTitle.Text = summary.Name;
        PresetDescription.Text = summary.Description;
        var tagString = summary.Tags.Length > 0 ? string.Join(", ", summary.Tags) : "No tags";
        PresetMeta.Text = $"ID: {summary.Id}  •  Category: {summary.Category}  •  Tweaks: {summary.TweakCount}  •  Default state: {summary.DefaultState}  •  Tags: {tagString}";
        _tweaks.Clear();
        foreach (var tweak in summary.Tweaks)
        {
            _tweaks.Add(new TweakRow(
                tweak.Id ?? string.Empty,
                tweak.Name ?? string.Empty,
                tweak.Category ?? string.Empty,
                tweak.DefaultBehavior ?? string.Empty,
                tweak.WhenDisabled ?? string.Empty,
                tweak.RiskLevel ?? string.Empty));
        }
        _ = RefreshTweakStatusesWithLoadingAsync(summary);
    }

    private async Task RefreshTweakStatusesWithLoadingAsync(ManifestSummary summary)
    {
        ShowLoading(true, "Checking current system status...");
        await RefreshTweakStatusesAsync(summary);
        ShowLoading(false);
    }

    private void AppendLog(string message)
    {
        if (string.IsNullOrWhiteSpace(message))
        {
            return;
        }

        var timestamp = DateTime.Now.ToString("u");
        LogBox.AppendText($"[{timestamp}] {message}{Environment.NewLine}");
        LogBox.ScrollToEnd();
    }

    private void ToggleUiBusy(bool busy)
    {
        ApplyButton.IsEnabled = !busy;
        DryRunButton.IsEnabled = !busy;
        RevertButton.IsEnabled = !busy;
        RefreshButton.IsEnabled = !busy;
        ManifestList.IsEnabled = !busy;
    }

    private void ShowLoading(bool show, string message = "Checking system status...")
    {
        LoadingOverlay.Visibility = show ? Visibility.Visible : Visibility.Collapsed;
        LoadingText.Text = message;
    }

    private void AboutButton_OnClick(object sender, RoutedEventArgs e)
    {
        var aboutMessage = @"Windows Game Edition (Unofficial)
Version 0.1.0

A friendly tool to optimize your Windows PC for gaming by disabling 
unnecessary services and processes - all while keeping anti-cheat 
compatibility intact!

Inspired by SteamOS and the Steam Deck experience, this project aims 
to bring that same level of optimization to Windows gamers.

Key Features:
• One-click optimization presets
• Full reversibility - undo any changes instantly
• Safe defaults that won't break your games
• Privacy-focused options to reduce telemetry

This is an open-source community project. All changes are logged 
and can be reviewed before applying.

⚠️ Always run as Administrator for full functionality.

GitHub: github.com/drizzydom/Windows-Game-Edition-Unofficial";

        MessageBox.Show(aboutMessage, "About Windows Game Edition", MessageBoxButton.OK, MessageBoxImage.Information);
    }

    private async void RefreshButton_OnClick(object sender, RoutedEventArgs e)
    {
        try
        {
            ToggleUiBusy(true);
            LoadManifests();
            
            if (_selectedManifest is not null)
            {
                ShowLoading(true, "Refreshing tweak status...");
                await RefreshTweakStatusesAsync(_selectedManifest);
                ShowLoading(false);
            }
            
            AppendLog("Refreshed presets and status information.");
        }
        catch (Exception ex)
        {
            AppendLog($"Refresh failed: {ex.Message}");
        }
        finally
        {
            ToggleUiBusy(false);
            ShowLoading(false);
        }
    }

    private async void RevertButton_OnClick(object sender, RoutedEventArgs e)
    {
        if (_selectedManifest is null)
        {
            AppendLog("Select a preset first before reverting.");
            return;
        }

        var result = MessageBox.Show(
            $"This will restore the original Windows settings for the '{_selectedManifest.Name}' preset.\n\n" +
            "Are you sure you want to revert all changes?\n\n" +
            "Note: A system restart may be required for some changes to take effect.",
            "Confirm Revert",
            MessageBoxButton.YesNo,
            MessageBoxImage.Warning);

        if (result != MessageBoxResult.Yes)
        {
            return;
        }

        await RunPresetAsync(dryRun: false, revert: true);
    }

    private async Task RefreshTweakStatusesAsync(ManifestSummary summary)
    {
        if (summary is null)
        {
            return;
        }

        var powershellPath = ResolvePowershellPath();
        if (string.IsNullOrWhiteSpace(powershellPath) || !File.Exists(powershellPath))
        {
            AppendLog("Cannot refresh status because Windows PowerShell 5.1 was not found.");
            return;
        }

        var scriptPath = Path.Combine(AppContext.BaseDirectory, "Automation", "wge.ps1");
        if (!File.Exists(scriptPath))
        {
            AppendLog("Cannot refresh status because the automation script is missing.");
            return;
        }

        var presetId = Path.GetFileNameWithoutExtension(summary.FilePath);
        try
        {
            var result = await Task.Run(() => FetchPresetStatus(powershellPath, scriptPath, presetId));
            if (result.Summary is null)
            {
                if (!string.IsNullOrWhiteSpace(result.StandardOutput))
                {
                    AppendLog(result.StandardOutput.Trim());
                }

                if (!string.IsNullOrWhiteSpace(result.StandardError))
                {
                    AppendLog($"stderr: {result.StandardError.Trim()}");
                }

                AppendLog($"Status probe exited with {result.ExitCode}.");
                return;
            }

                var entries = result.Summary.Entries ?? new List<TweakStatusEntry>();
                var lookup = new Dictionary<string, TweakStatusEntry>(StringComparer.OrdinalIgnoreCase);
                foreach (var entry in entries)
                {
                    var key = entry?.TweakId ?? string.Empty;
                    if (string.IsNullOrWhiteSpace(key) || entry is null)
                    {
                        continue;
                    }

                    lookup[key] = entry;
                }
            foreach (var row in _tweaks)
            {
                if (lookup.TryGetValue(row.Id, out var entry))
                {
                    row.Status = MapStatus(entry.State);
                    row.StatusDetails = FormatStatusDetails(entry);
                }
                else
                {
                    row.Status = "Unknown";
                    row.StatusDetails = "No status information returned.";
                }
            }
        }
        catch (Exception ex)
        {
            AppendLog($"Status refresh failed: {ex.Message}");
        }
    }

    private static string MapStatus(string? state)
    {
        return state?.ToLowerInvariant() switch
        {
            "applied" => "Applied",
            "partial" => "Partial",
            "notapplied" => "Stock",
            "failed" => "Error",
            "error" => "Error",
            "unsupported" => "Skipped",
            "pending" => "Pending",
            "unknown" => "Unknown",
            _ => "Unknown"
        };
    }

    private static string FormatStatusDetails(TweakStatusEntry entry)
    {
        var lines = new List<string>();
        if (!string.IsNullOrWhiteSpace(entry.Message))
        {
            lines.Add(entry.Message!);
        }

        if (entry.Checks is not null && entry.Checks.Count > 0)
        {
            foreach (var check in entry.Checks)
            {
                if (check is null)
                {
                    continue;
                }

                var status = check.Compliant ? "[OK]" : "[WARN]";
                var desired = string.IsNullOrWhiteSpace(check.Desired) ? "(unspecified)" : check.Desired;
                var actual = string.IsNullOrWhiteSpace(check.Actual) ? "(none)" : check.Actual;
                var extra = string.IsNullOrWhiteSpace(check.Message) ? string.Empty : $" ({check.Message})";
                lines.Add($"{status} {check.Target} -> wanted {desired}, actual {actual}{extra}");
            }
        }

        return lines.Count == 0 ? "No checks defined." : string.Join(Environment.NewLine, lines);
    }

    private static StatusRunResult FetchPresetStatus(string powershellPath, string scriptPath, string presetId)
    {
        var info = new ProcessStartInfo(powershellPath)
        {
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
            WorkingDirectory = Path.GetDirectoryName(scriptPath) ?? AppContext.BaseDirectory
        };

        info.ArgumentList.Add("-NoLogo");
        info.ArgumentList.Add("-NoProfile");
        info.ArgumentList.Add("-ExecutionPolicy");
        info.ArgumentList.Add("Bypass");
        info.ArgumentList.Add("-File");
        info.ArgumentList.Add(scriptPath);
        info.ArgumentList.Add("-Preset");
        info.ArgumentList.Add(presetId);
        info.ArgumentList.Add("-Status");
        info.ArgumentList.Add("-AsJson");

        using var process = new Process { StartInfo = info };
        process.Start();
        var stdout = process.StandardOutput.ReadToEnd();
        var stderr = process.StandardError.ReadToEnd();
        process.WaitForExit();

        PresetStatusSummary? summary = null;
        var trimmedOut = stdout.Trim();
        if (!string.IsNullOrWhiteSpace(trimmedOut))
        {
            try
            {
                summary = JsonSerializer.Deserialize<PresetStatusSummary>(trimmedOut, AutomationJsonOptions);
            }
            catch (JsonException)
            {
                // Fall back to textual output.
            }
        }

        return new StatusRunResult(summary, stdout, stderr, process.ExitCode);
    }

    private void ApplyAutomationSummary(AutomationSummary summary, AutomationRunResult runResult, bool dryRun)
    {
        var message = summary.Message ?? "Preset completed.";
        AppendLog(message);

        if (summary.Counts is not null)
        {
            AppendLog($"Totals -> ok: {summary.Counts.Succeeded}, fail: {summary.Counts.Failed}, skipped: {summary.Counts.Skipped}, previewed: {summary.Counts.WhatIf}");
        }

        if (!dryRun && !string.IsNullOrWhiteSpace(summary.ActionLogPath))
        {
            AppendLog($"Action log saved to {summary.ActionLogPath}");
        }
        else if (dryRun)
        {
            AppendLog("Dry run only; no changes saved.");
        }

        if (!string.IsNullOrWhiteSpace(runResult.StandardError))
        {
            AppendLog($"stderr: {runResult.StandardError.Trim()}");
        }

        AppendLog($"Exit code: {runResult.ExitCode}");

        _results.Clear();
        if (summary.Entries is not null && summary.Entries.Count > 0)
        {
            foreach (var entry in summary.Entries)
            {
                var details = BuildDetails(entry);
                _results.Add(new ActionResultRow(
                    Status: entry.Status is not null ? entry.Status.ToUpperInvariant() : "UNK",
                    TweakName: !string.IsNullOrWhiteSpace(entry.TweakName) ? entry.TweakName! : entry.TweakId ?? "(unknown)",
                    Target: entry.Target ?? string.Empty,
                    Message: entry.Message ?? string.Empty,
                    Details: details));
            }
        }

        if (_results.Count == 0)
        {
            _results.Add(new ActionResultRow("INFO", "No commands", "-", "Preset did not execute any commands.", string.Empty));
        }
    }

    private static string BuildDetails(AutomationEntry entry)
    {
        var parts = new List<string>();
        if (!string.IsNullOrWhiteSpace(entry.SkipReason))
        {
            parts.Add($"skip: {entry.SkipReason}");
        }

        if (!string.IsNullOrWhiteSpace(entry.ErrorMessage))
        {
            parts.Add($"error: {entry.ErrorMessage}");
        }

        if (entry.RequiresReboot)
        {
            parts.Add("reboot required");
        }

        if (entry.RequiresElevation)
        {
            parts.Add("needs elevation");
        }

        return parts.Count == 0 ? string.Empty : string.Join(" | ", parts);
    }

    private static string ResolvePowershellPath()
    {
        var systemDirectory = Environment.GetFolderPath(Environment.SpecialFolder.System);
        if (string.IsNullOrWhiteSpace(systemDirectory))
        {
            return string.Empty;
        }

        return Path.Combine(systemDirectory, "WindowsPowerShell", "v1.0", "powershell.exe");
    }

    private record ManifestDocument
    {
        public ManifestMetadata? Metadata { get; init; }
        public List<ManifestTweak>? Tweaks { get; init; }
    }

    private record ManifestMetadata
    {
        public string? Id { get; init; }
        public string? Name { get; init; }
        public string? Description { get; init; }
        public string? DefaultState { get; init; }
        public string? Category { get; init; }
        public string[]? Tags { get; init; }
    }

    private record ManifestTweak
    {
        public string? Id { get; init; }
        public string? Name { get; init; }
        public string? Category { get; init; }
        public string? DefaultBehavior { get; init; }
        public string? WhenDisabled { get; init; }
        public string? RiskLevel { get; init; }
    }

    private record ManifestSummary(
        string Id,
        string Name,
        string Description,
        string DefaultState,
        string Category,
        int TweakCount,
        string FilePath,
        List<ManifestTweak> Tweaks)
    {
        public string DisplayName => $"{Name} ({Id})";
        public string[] Tags { get; set; } = Array.Empty<string>();
    }

    private sealed class TweakRow : INotifyPropertyChanged
    {
        private string _status = "Pending";
        private string _statusDetails = string.Empty;

        public TweakRow(string id, string name, string category, string defaultBehavior, string whenDisabled, string riskLevel)
        {
            Id = id;
            Name = name;
            Category = category;
            DefaultBehavior = defaultBehavior;
            WhenDisabled = whenDisabled;
            RiskLevel = riskLevel;
            _statusDetails = "Not evaluated yet.";
        }

        public string Id { get; }
        public string Name { get; }
        public string Category { get; }
        public string DefaultBehavior { get; }
        public string WhenDisabled { get; }
        public string RiskLevel { get; }

        public string Status
        {
            get => _status;
            set => SetField(ref _status, value ?? "Unknown");
        }

        public string StatusDetails
        {
            get => _statusDetails;
            set => SetField(ref _statusDetails, value ?? string.Empty);
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        private void SetField(ref string field, string value, [CallerMemberName] string? propertyName = null)
        {
            if (field == value)
            {
                return;
            }

            field = value;
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }

    private sealed record AutomationRunResult(AutomationSummary? Summary, string StandardOutput, string StandardError, int ExitCode);

    private sealed record AutomationSummary
    {
        public string? PresetId { get; init; }
        public string? PresetName { get; init; }
        public string? ManifestPath { get; init; }
        public bool DryRun { get; init; }
        public string? ActionLogPath { get; init; }
        public AutomationCounts? Counts { get; init; }
        public List<AutomationEntry> Entries { get; init; } = new();
        public string? Message { get; init; }
    }

    private sealed record AutomationCounts
    {
        public int Total { get; init; }
        public int Succeeded { get; init; }
        public int Failed { get; init; }
        public int Skipped { get; init; }
        public int WhatIf { get; init; }
    }

    private sealed record AutomationEntry
    {
        public string? Status { get; init; }
        public string? TweakId { get; init; }
        public string? TweakName { get; init; }
        public string? CommandType { get; init; }
        public string? Target { get; init; }
        public string? Message { get; init; }
        public bool RequiresReboot { get; init; }
        public bool RequiresElevation { get; init; }
        public bool Skipped { get; init; }
        public string? SkipReason { get; init; }
        public string? ErrorMessage { get; init; }
    }

    private sealed record PresetStatusSummary
    {
        public string? PresetId { get; init; }
        public string? PresetName { get; init; }
        public string? Message { get; init; }
        public List<TweakStatusEntry> Entries { get; init; } = new();
    }

    private sealed record TweakStatusEntry
    {
        public string? TweakId { get; init; }
        public string? TweakName { get; init; }
        public string? State { get; init; }
        public string? Message { get; init; }
        public List<TweakStatusCheck> Checks { get; init; } = new();
    }

    private sealed record TweakStatusCheck
    {
        public string? Target { get; init; }
        public bool Compliant { get; init; }
        public string? Desired { get; init; }
        public string? Actual { get; init; }
        public string? Message { get; init; }
    }

    private sealed record StatusRunResult(PresetStatusSummary? Summary, string StandardOutput, string StandardError, int ExitCode);

    private sealed record ActionResultRow(string Status, string TweakName, string Target, string Message, string Details);
}
