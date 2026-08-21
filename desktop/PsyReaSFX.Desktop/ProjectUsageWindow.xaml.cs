using System.Diagnostics;
using System.IO;
using System.Windows;
using PsyReaSFX.Data;

namespace PsyReaSFX.Desktop;

public partial class ProjectUsageWindow : Window
{
    private readonly bool _english;
    public ProjectUsageWindow(IReadOnlyList<ProjectUsageRecord> records, bool english)
    {
        InitializeComponent();
        _english = english;
        UsageGrid.ItemsSource = records.Select(row => new UsageView(row, english)).ToList();
        CountText.Text = english ? $"{records.Count:N0} recorded deliveries" : $"已记录 {records.Count:N0} 次交付";
        if (english) ApplyEnglish();
    }

    private void ApplyEnglish()
    {
        Title = "PsyReaSFX · Project usage";
        Heading.Text = "REAPER project usage";
        Subheading.Text = "Assets delivered successfully through the optional Bridge";
        TimeColumn.Header = "Time"; AssetColumn.Header = "Asset"; ProjectColumn.Header = "REAPER project";
        ActionColumn.Header = "Delivery"; TrackColumn.Header = "Track"; PositionColumn.Header = "Position";
        RevealButton.Content = "Reveal asset"; CloseButton.Content = "Close";
    }

    private void Reveal_Click(object sender, RoutedEventArgs e)
    {
        if (UsageGrid.SelectedItem is not UsageView view || !File.Exists(view.AssetPath)) return;
        Process.Start(new ProcessStartInfo("explorer.exe", $"/select,\"{view.AssetPath}\"") { UseShellExecute = true });
    }
    private void Close_Click(object sender, RoutedEventArgs e) => Close();

    private sealed class UsageView
    {
        public string AssetPath { get; }
        public string CreatedText { get; }
        public string AssetName { get; }
        public string ProjectName { get; }
        public string ActionText { get; }
        public string TrackText { get; }
        public string PositionText { get; }

        public UsageView(ProjectUsageRecord row, bool english)
        {
            AssetPath = row.AssetPath;
            CreatedText = DateTimeOffset.FromUnixTimeSeconds(row.CreatedUtc).ToLocalTime().ToString("yyyy-MM-dd HH:mm");
            AssetName = Path.GetFileName(row.AssetPath);
            ProjectName = string.IsNullOrWhiteSpace(row.ProjectName) ? (english ? "Untitled" : "未命名工程") : row.ProjectName;
            ActionText = row.Action switch
            {
                "insert_current" => english ? "Current track" : "当前轨",
                "insert_new_track" => english ? "New track" : "新轨",
                "insert_bwf" => "BWF Spot",
                _ => row.Action
            };
            TrackText = row.TrackIndex > 0 ? $"{row.TrackIndex}. {row.TrackName}" : row.TrackName;
            PositionText = TimeSpan.FromSeconds(Math.Max(0, row.Position)).ToString(@"hh\:mm\:ss\.fff");
        }
    }
}
