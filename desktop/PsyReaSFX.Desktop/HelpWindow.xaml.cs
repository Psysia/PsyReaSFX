using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using PsyReaSFX.Desktop.Services;

namespace PsyReaSFX.Desktop;

public partial class HelpWindow : Window
{
    public HelpWindow(string? language)
    {
        InitializeComponent();
        UiLocalization.Apply(this, language);
    }

    private void TitleBar_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ChangedButton == MouseButton.Left) DragMove();
    }

    private void Close_Click(object sender, RoutedEventArgs e) => Close();

    private void Window_PreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key != Key.Escape) return;
        Close();
        e.Handled = true;
    }

    private void Page_Checked(object sender, RoutedEventArgs e)
    {
        if (StartPage == null) return;
        StartPage.Visibility = StartNav.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        SearchPage.Visibility = SearchNav.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        PreviewPage.Visibility = PreviewNav.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        OrganizePage.Visibility = OrganizeNav.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        ShortcutPage.Visibility = ShortcutNav.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        HelpScroller.ScrollToTop();
    }
}
