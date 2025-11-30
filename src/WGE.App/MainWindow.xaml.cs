using System;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;

namespace WGE.App;

public partial class MainWindow : Window
{
    private readonly ObservableCollection<ManifestSummary> _manifests = new();
    private readonly ObservableCollection<TweakSummary> _tweaks = new();
    private ManifestSummary? _selectedManifest;

    public MainWindow()
    {
        InitializeComponent();
        ManifestList.ItemsSource = _manifests;
        TweaksGrid.ItemsSource = _tweaks;
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

        try
        {
            var output = await Task.Run(() => ExecuteAutomation(powershellPath, scriptPath, presetId, dryRun));
            AppendLog(output);
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

    private static string ExecuteAutomation(string powershellPath, string scriptPath, string presetId, bool dryRun)
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
        if (dryRun)
        {
            info.ArgumentList.Add("-DryRun");
        }

        using var process = new Process { StartInfo = info };
        var buffer = new StringBuilder();

        process.Start();
        buffer.AppendLine(process.StandardOutput.ReadToEnd());
        var error = process.StandardError.ReadToEnd();
        process.WaitForExit();

        if (!string.IsNullOrWhiteSpace(error))
        {
            buffer.AppendLine("[stderr]");
            buffer.AppendLine(error);
        }

        buffer.AppendLine($"Exit code: {process.ExitCode}");
        return buffer.ToString();
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
        System.Collections.Generic.List<TweakSummary> Tweaks)
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
}
