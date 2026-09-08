using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace PsyReaSFX.Data;

public sealed record SourcePathIdentity(
    string DisplayPath,
    string CanonicalPath,
    string VolumeLabel,
    string VolumeSerial,
    long LastSeenUtc);

public static class PathIdentity
{
    private const uint FileShareRead = 0x00000001;
    private const uint FileShareWrite = 0x00000002;
    private const uint FileShareDelete = 0x00000004;
    private const uint OpenExisting = 3;
    private const uint FileFlagBackupSemantics = 0x02000000;

    public static SourcePathIdentity CaptureSource(string path)
    {
        var display = Normalize(path);
        var canonical = ResolveCanonical(display);
        var label = "";
        var serial = "";
        var lastSeen = Directory.Exists(display) ? DateTimeOffset.UtcNow.ToUnixTimeSeconds() : 0;

        try
        {
            var root = Path.GetPathRoot(canonical);
            if (!string.IsNullOrWhiteSpace(root))
            {
                var volumeName = new StringBuilder(261);
                if (OperatingSystem.IsWindows() && GetVolumeInformation(
                        root, volumeName, volumeName.Capacity, out var volumeSerial,
                        out _, out _, null, 0))
                {
                    label = volumeName.ToString();
                    serial = volumeSerial.ToString("X8");
                }
                else
                {
                    var drive = new DriveInfo(root);
                    if (drive.IsReady) label = drive.VolumeLabel;
                }
            }
        }
        catch { }

        return new SourcePathIdentity(display, canonical, label, serial, lastSeen);
    }

    public static string Normalize(string path)
    {
        if (string.IsNullOrWhiteSpace(path)) return "";
        path = StripExtendedPrefix(path.Trim());
        var full = Path.GetFullPath(path).Replace(Path.AltDirectorySeparatorChar, Path.DirectorySeparatorChar);
        var root = Path.GetPathRoot(full) ?? "";
        return full.Length > root.Length ? full.TrimEnd(Path.DirectorySeparatorChar) : full;
    }

    public static string NormalizeRelative(string path)
    {
        var segments = new List<string>();
        foreach (var segment in (path ?? "")
                     .Replace(Path.AltDirectorySeparatorChar, Path.DirectorySeparatorChar)
                     .Split(Path.DirectorySeparatorChar, StringSplitOptions.RemoveEmptyEntries))
        {
            if (segment == ".") continue;
            if (segment == ".." && segments.Count > 0 && segments[^1] != "..") segments.RemoveAt(segments.Count - 1);
            else segments.Add(segment);
        }
        return string.Join(Path.DirectorySeparatorChar, segments);
    }

    public static string RelativeTo(string sourcePath, string assetPath)
    {
        try { return NormalizeRelative(Path.GetRelativePath(Normalize(sourcePath), Normalize(assetPath))); }
        catch { return NormalizeRelative(Path.GetFileName(assetPath)); }
    }

    public static string CreateAssetId(string sourceId, string relativePath)
    {
        var identity = (sourceId ?? "").Trim().ToUpperInvariant() + "\n"
                       + NormalizeRelative(relativePath).ToUpperInvariant();
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(identity)))[..32].ToLowerInvariant();
    }

    public static string AssetKey(string sourceId, string relativePath) =>
        (sourceId ?? "").Trim().ToUpperInvariant() + "|" + NormalizeRelative(relativePath).ToUpperInvariant();

    public static bool SamePhysicalSource(SourcePathIdentity first, SourcePathIdentity second)
    {
        var firstCanonical = Normalize(first.CanonicalPath);
        var secondCanonical = Normalize(second.CanonicalPath);
        if (!string.IsNullOrWhiteSpace(firstCanonical)
            && firstCanonical.Equals(secondCanonical, StringComparison.OrdinalIgnoreCase))
            return true;

        return !string.IsNullOrWhiteSpace(first.VolumeSerial)
               && first.VolumeSerial.Equals(second.VolumeSerial, StringComparison.OrdinalIgnoreCase)
               && !string.IsNullOrWhiteSpace(firstCanonical)
               && !string.IsNullOrWhiteSpace(secondCanonical)
               && PathWithinVolume(firstCanonical).Equals(
                   PathWithinVolume(secondCanonical), StringComparison.OrdinalIgnoreCase);
    }

    private static string PathWithinVolume(string path)
    {
        var normalized = Normalize(path);
        var root = Path.GetPathRoot(normalized) ?? "";
        return NormalizeRelative(normalized[root.Length..]);
    }

    private static string StripExtendedPrefix(string path)
    {
        if (path.StartsWith("\\\\?\\UNC\\", StringComparison.OrdinalIgnoreCase)) return "\\\\" + path[8..];
        return path.Length >= 7
               && path.StartsWith("\\\\?\\", StringComparison.OrdinalIgnoreCase)
               && char.IsAsciiLetter(path[4])
               && path[5] == ':'
            ? path[4..]
            : path;
    }

    private static string ResolveCanonical(string path)
    {
        if (!OperatingSystem.IsWindows() || (!File.Exists(path) && !Directory.Exists(path))) return path;
        try
        {
            using var handle = CreateFile(path, 0, FileShareRead | FileShareWrite | FileShareDelete,
                IntPtr.Zero, OpenExisting, FileFlagBackupSemantics, IntPtr.Zero);
            if (handle.IsInvalid) return path;
            var buffer = new StringBuilder(32768);
            var length = GetFinalPathNameByHandle(handle, buffer, (uint)buffer.Capacity, 0);
            if (length == 0 || length >= buffer.Capacity) return path;
            var resolved = buffer.ToString();
            return Normalize(StripExtendedPrefix(resolved));
        }
        catch { return path; }
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern SafeFileHandle CreateFile(string fileName, uint desiredAccess, uint shareMode,
        IntPtr securityAttributes, uint creationDisposition, uint flagsAndAttributes, IntPtr templateFile);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern uint GetFinalPathNameByHandle(SafeFileHandle file, StringBuilder path, uint length, uint flags);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetVolumeInformation(string rootPathName, StringBuilder volumeNameBuffer,
        int volumeNameSize, out uint volumeSerialNumber, out uint maximumComponentLength,
        out uint fileSystemFlags, StringBuilder? fileSystemNameBuffer, int fileSystemNameSize);
}
