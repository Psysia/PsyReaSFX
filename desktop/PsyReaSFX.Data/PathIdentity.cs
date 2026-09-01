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
        var full = Path.GetFullPath(path.Trim()).Replace(Path.AltDirectorySeparatorChar, Path.DirectorySeparatorChar);
        var root = Path.GetPathRoot(full) ?? "";
        return full.Length > root.Length ? full.TrimEnd(Path.DirectorySeparatorChar) : full;
    }

    public static string NormalizeRelative(string path) =>
        (path ?? "").Replace(Path.AltDirectorySeparatorChar, Path.DirectorySeparatorChar)
            .TrimStart(Path.DirectorySeparatorChar).TrimEnd(Path.DirectorySeparatorChar);

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
        if (!string.IsNullOrWhiteSpace(first.VolumeSerial)
            && first.VolumeSerial.Equals(second.VolumeSerial, StringComparison.OrdinalIgnoreCase))
            return first.CanonicalPath.Equals(second.CanonicalPath, StringComparison.OrdinalIgnoreCase);
        return first.CanonicalPath.Equals(second.CanonicalPath, StringComparison.OrdinalIgnoreCase);
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
            if (resolved.StartsWith("\\\\?\\UNC\\", StringComparison.OrdinalIgnoreCase))
                resolved = "\\\\" + resolved[8..];
            else if (resolved.StartsWith("\\\\?\\", StringComparison.OrdinalIgnoreCase))
                resolved = resolved[4..];
            return Normalize(resolved);
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
