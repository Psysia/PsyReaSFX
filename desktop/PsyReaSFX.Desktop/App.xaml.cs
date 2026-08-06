using System.Windows;
using PsyReaSFX.Desktop.Services;

namespace PsyReaSFX.Desktop;

public partial class App : System.Windows.Application
{
    protected override async void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        AppDiagnostics.Write("Desktop startup entered.");
        AppDomain.CurrentDomain.UnhandledException += (_, args) =>
            AppDiagnostics.Write("Unhandled AppDomain exception.", args.ExceptionObject as Exception);
        TaskScheduler.UnobservedTaskException += (_, args) =>
        {
            AppDiagnostics.Write("Unobserved task exception.", args.Exception);
            args.SetObserved();
        };
        if (e.Args.Length >= 1 && e.Args[0].Equals("--self-test", StringComparison.OrdinalIgnoreCase))
        {
            var reportPath = e.Args.Length >= 2 && !string.IsNullOrWhiteSpace(e.Args[1])
                ? e.Args[1]
                : Path.Combine(Path.GetTempPath(), "PsyReaSFX-Desktop-self-test.json");
            if (Directory.Exists(reportPath)) reportPath = Path.Combine(reportPath, "PsyReaSFX-Desktop-self-test.json");
            try { Shutdown(await DesktopSelfTest.RunAsync(reportPath)); }
            catch (Exception exception)
            {
                AppDiagnostics.Write("Desktop self-test failed outside its safety boundary.", exception);
                Shutdown(1);
            }
            return;
        }

        DispatcherUnhandledException += (_, args) =>
        {
            AppDiagnostics.Write("Unhandled dispatcher exception.", args.Exception);
            MessageBox.Show(args.Exception.Message, "PsyReaSFX Desktop", MessageBoxButton.OK, MessageBoxImage.Error);
            args.Handled = true;
        };

        try
        {
            MainWindow = new MainWindow();
            MainWindow.Show();
            AppDiagnostics.Write("Main window shown.");
        }
        catch (Exception exception)
        {
            AppDiagnostics.Write("Main window creation failed.", exception);
            MessageBox.Show($"PsyReaSFX 无法启动。\n\n{exception.Message}\n\n日志：{AppDiagnostics.CurrentLogPath}",
                "PsyReaSFX Desktop", MessageBoxButton.OK, MessageBoxImage.Error);
            Shutdown(1);
        }
    }
}
