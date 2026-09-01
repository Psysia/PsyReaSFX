using PsyReaSFX.Data;

namespace PsyReaSFX.Desktop.Services;

public sealed class PathIdentityService : IPathIdentityService
{
    public SourcePathIdentity CaptureSource(string path) => PathIdentity.CaptureSource(path);
    public string Normalize(string path) => PathIdentity.Normalize(path);
    public string RelativeTo(string rootPath, string filePath) => PathIdentity.RelativeTo(rootPath, filePath);
    public bool SamePhysicalSource(SourcePathIdentity left, SourcePathIdentity right) =>
        PathIdentity.SamePhysicalSource(left, right);
}
