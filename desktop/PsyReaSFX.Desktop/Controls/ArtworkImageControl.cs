using System.Collections.Concurrent;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media.Imaging;

namespace PsyReaSFX.Desktop.Controls;

public sealed class ArtworkImageControl : Image
{
    private static readonly ConcurrentDictionary<string, Task<BitmapSource?>> Cache = new(StringComparer.OrdinalIgnoreCase);
    private static readonly ConcurrentQueue<string> CacheOrder = new();
    private const int MaxCachedArtwork = 160;
    private int _version;

    public static readonly DependencyProperty FilePathProperty = DependencyProperty.Register(
        nameof(FilePath), typeof(string), typeof(ArtworkImageControl), new PropertyMetadata("", OnImageChanged));

    public static readonly DependencyProperty DecodePixelWidthProperty = DependencyProperty.Register(
        nameof(DecodePixelWidth), typeof(int), typeof(ArtworkImageControl), new PropertyMetadata(240, OnImageChanged));

    public string FilePath { get => (string)GetValue(FilePathProperty); set => SetValue(FilePathProperty, value); }
    public int DecodePixelWidth { get => (int)GetValue(DecodePixelWidthProperty); set => SetValue(DecodePixelWidthProperty, value); }

    private static void OnImageChanged(DependencyObject dependencyObject, DependencyPropertyChangedEventArgs args) =>
        ((ArtworkImageControl)dependencyObject).LoadAsync();

    private async void LoadAsync()
    {
        var version = ++_version;
        var path = FilePath;
        Source = null;
        if (string.IsNullOrWhiteSpace(path) || !File.Exists(path)) return;
        var width = Math.Clamp(DecodePixelWidth, 32, 1024);
        try
        {
            var key = path + "|" + width;
            await Task.Delay(width <= 96 ? 180 : 40);
            if (version != _version || !path.Equals(FilePath, StringComparison.OrdinalIgnoreCase)) return;
            var image = await Cache.GetOrAdd(key, _ =>
            {
                CacheOrder.Enqueue(key);
                TrimCache();
                return Task.Run(() => LoadBitmap(path, width));
            });
            if (version == _version && path.Equals(FilePath, StringComparison.OrdinalIgnoreCase)) Source = image;
        }
        catch { }
    }

    private static BitmapSource? LoadBitmap(string path, int width)
    {
        try
        {
            var image = new BitmapImage();
            image.BeginInit();
            image.CacheOption = BitmapCacheOption.OnLoad;
            image.CreateOptions = BitmapCreateOptions.IgnoreColorProfile;
            image.DecodePixelWidth = width;
            image.UriSource = new Uri(path, UriKind.Absolute);
            image.EndInit();
            image.Freeze();
            return image;
        }
        catch { return null; }
    }

    private static void TrimCache()
    {
        while (Cache.Count > MaxCachedArtwork && CacheOrder.TryDequeue(out var oldest))
            Cache.TryRemove(oldest, out _);
    }
}
