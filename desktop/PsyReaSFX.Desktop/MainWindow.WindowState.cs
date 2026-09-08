using System.Windows;
using System.Windows.Media;
using PsyReaSFX.Desktop.Services;

namespace PsyReaSFX.Desktop;

public partial class MainWindow
{
    private void NavigationToggle_Click(object sender, RoutedEventArgs e) =>
        SetNavigationVisible(!_windowState.State.NavigationVisible);

    private void InspectorToggle_Click(object sender, RoutedEventArgs e) =>
        SetInspectorVisible(!_windowState.State.InspectorVisible);

    private void FocusToggle_Click(object sender, RoutedEventArgs e)
    {
        var state = _windowState.SetFocusMode(
            !_windowState.State.FocusMode,
            NavigationColumn.Width.Value,
            InspectorColumn.Width.Value);
        RenderWindowState(state);
    }

    private void SetNavigationVisible(bool visible) =>
        RenderWindowState(_windowState.SetNavigation(visible, NavigationColumn.Width.Value));

    private void SetInspectorVisible(bool visible) =>
        RenderWindowState(_windowState.SetInspector(visible, InspectorColumn.Width.Value));

    private void RenderWindowState(WindowPanelState state)
    {
        NavigationPanel.Visibility = NavigationSplitter.Visibility = state.NavigationVisible
            ? Visibility.Visible : Visibility.Collapsed;
        NavigationColumn.MinWidth = state.NavigationVisible ? 190 : 0;
        NavigationColumn.Width = state.NavigationVisible ? new GridLength(state.NavigationWidth) : new GridLength(0);
        NavigationSplitterColumn.Width = state.NavigationVisible ? new GridLength(5) : new GridLength(0);
        NavigationToggle.IsActive = state.NavigationVisible;

        InspectorPanel.Visibility = InspectorSplitter.Visibility = state.InspectorVisible
            ? Visibility.Visible : Visibility.Collapsed;
        InspectorColumn.MinWidth = state.InspectorVisible ? 230 : 0;
        InspectorColumn.Width = state.InspectorVisible ? new GridLength(state.InspectorWidth) : new GridLength(0);
        InspectorSplitterColumn.Width = state.InspectorVisible ? new GridLength(5) : new GridLength(0);
        InspectorToggle.IsActive = state.InspectorVisible;

        FocusToggle.Foreground = state.FocusMode
            ? (Brush)FindResource("AccentBrightBrush")
            : (Brush)FindResource("TextBrush");
        FocusToggle.IsActive = state.FocusMode;
    }
}
