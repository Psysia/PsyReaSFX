using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using PsyReaSFX.Desktop.Services;

namespace PsyReaSFX.Desktop;

public partial class SettingsWindow : Window
{
    public DesktopPreferences Preferences { get; }

    public SettingsWindow(DesktopPreferences preferences, string dataDirectory)
    {
        Preferences = preferences.Copy();
        InitializeComponent();
        AutoPreviewCheck.IsChecked = Preferences.AutoPreview;
        NavigationCheck.IsChecked = Preferences.NavigationVisible;
        InspectorCheck.IsChecked = Preferences.InspectorVisible;
        Inline256.IsChecked = Preferences.InlineWaveformResolution <= 256;
        Inline512.IsChecked = Preferences.InlineWaveformResolution > 256;
        Detail2048.IsChecked = Preferences.DetailWaveformResolution <= 2048;
        Detail4096.IsChecked = Preferences.DetailWaveformResolution > 2048;
        DataPathText.Text = dataDirectory;
        LogPathText.Text = AppDiagnostics.LogDirectory;
    }

    private void Page_Checked(object sender, RoutedEventArgs e)
    {
        if (!IsInitialized) return;
        GeneralPage.Visibility = GeneralNav.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        WaveformPage.Visibility = WaveformNav.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        MaintenancePage.Visibility = MaintenanceNav.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        AboutPage.Visibility = AboutNav.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
    }

    private static void OpenDirectory(string path)
    {
        Directory.CreateDirectory(path);
        Process.Start(new ProcessStartInfo("explorer.exe", path) { UseShellExecute = true });
    }

    private void OpenData_Click(object sender, RoutedEventArgs e) => OpenDirectory(DataPathText.Text);
    private void OpenLogs_Click(object sender, RoutedEventArgs e) => OpenDirectory(AppDiagnostics.LogDirectory);

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        Preferences.AutoPreview = AutoPreviewCheck.IsChecked == true;
        Preferences.NavigationVisible = NavigationCheck.IsChecked == true;
        Preferences.InspectorVisible = InspectorCheck.IsChecked == true;
        Preferences.InlineWaveformResolution = Inline512.IsChecked == true ? 512 : 256;
        Preferences.DetailWaveformResolution = Detail4096.IsChecked == true ? 4096 : 2048;
        DialogResult = true;
    }

    private void Cancel_Click(object sender, RoutedEventArgs e) => DialogResult = false;
}
