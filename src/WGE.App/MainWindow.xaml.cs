using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;

namespace WGE.App;

public partial class MainWindow : Window
{
    private readonly ObservableCollection<ManifestSummary> _manifests = new();
    private readonly ObservableCollection<TweakSummary> _tweaks = new();
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

                var summary = new ManifestSummary(
                    manifest.Metadata.Id ?? Path.GetFileNameWithoutExtension(manifestFile),
                    manifest.Metadata.Name ?? Path.GetFileNameWithoutExtension(manifestFile),
                    manifest.Metadata.Description ?? string.Empty,
                    manifest.Metadata.DefaultState ?? string.Empty,
                    manifest.Metadata.Category ?? string.Empty,
                    manifest.Tweaks?.Count ?? 0,
                    manifestFile,
                    manifest.Tweaks?.Select(t => new TweakSummary(
                        t.Id ?? string.Empty,
                        t.Name ?? string.Empty,
                        t.Category ?? string.Empty,
                        t.DefaultBehavior ?? string.Empty,
                        t.WhenDisabled ?? string.Empty,
                        t.RiskLevel ?? string.Empty
                    )).ToList() ?? new())
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
        await RunPresetAsync(dryRun: false);
    }

    private async void DryRunButton_OnClick(object sender, RoutedEventArgs e)
    {
        await RunPresetAsync(dryRun: true);
    }

    private async Task RunPresetAsync(bool dryRun)
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
        AppendLog($"Launching preset '{_selectedManifest.Name}' ({presetId}) with dryRun={(dryRun ? "true" : "false")}.");

        ToggleUiBusy(true);
        _results.Clear();

        try
        {
            var runResult = await Task.Run(() => ExecuteAutomation(powershellPath, scriptPath, presetId, dryRun));
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
        }
    }

    private static AutomationRunResult ExecuteAutomation(string powershellPath, string scriptPath, string presetId, bool dryRun)
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
            _tweaks.Add(tweak);
        }
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
        public ObservableCollection<ManifestTweak>? Tweaks { get; init; }
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
        List<TweakSummary> Tweaks)
    {
        public string DisplayName => $"{Name} ({Id})";
        public string[] Tags { get; set; } = Array.Empty<string>();
    }

    private record TweakSummary(
        string Id,
        string Name,
        string Category,
        string DefaultBehavior,
        string WhenDisabled,
        string RiskLevel);

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

    private sealed record ActionResultRow(string Status, string TweakName, string Target, string Message, string Details);
}
