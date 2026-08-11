using System.Globalization;

namespace PsyReaSFX.Desktop.Services;

public sealed record TransferVariant(double Pitch, double Rate, double Gain, bool Reverse, int Index)
{
    public int Count { get; init; } = 1;
    public string Direction => Reverse ? "reverse" : "forward";
    public string Token => $"p{Signed(Pitch)}_r{Rate:0.###}_g{Signed(Gain)}_{Direction}";
    private static string Signed(double value) => value >= 0 ? $"+{value:0.###}" : value.ToString("0.###", CultureInfo.InvariantCulture);
}

public sealed record TransferRequest(
    AudioAsset Asset,
    double SelectionStartRatio,
    double SelectionEndRatio,
    TransferVariant Variant,
    int AssetIndex);

public sealed class TransferOptions
{
    public string OutputDirectory { get; set; } = "";
    public string NamingTemplate { get; set; } = "{name}";
    public bool Lowercase { get; set; }
    public string Scope { get; set; } = "selection";
    public string Format { get; set; } = "wav24";
    public string SampleRate { get; set; } = "source";
    public string Channels { get; set; } = "source";
    public bool PreserveMetadata { get; set; } = true;
    public double FadeInMs { get; set; } = 5;
    public double FadeOutMs { get; set; } = 20;
    public string NormalizeMode { get; set; } = "off";
    public double NormalizeTarget { get; set; } = -1;
    public bool Dither { get; set; }
    public bool NoiseShaping { get; set; }
    public bool SmartTail { get; set; }
    public double TailThresholdDb { get; set; } = -60;
    public double TailMaximumMs { get; set; } = 5000;
    public double TailHoldMs { get; set; } = 180;
    public string CollisionPolicy { get; set; } = "increment";
    public bool OpenFolderAfter { get; set; }
    public double Pitch { get; set; }
    public double Rate { get; set; } = 1;
    public double Gain { get; set; }
    public bool Reverse { get; set; }
    public bool PreservePitch { get; set; } = true;
    public bool VariantsEnabled { get; set; }
    public string VariantPitches { get; set; } = "0";
    public string VariantRates { get; set; } = "1";
    public string VariantGains { get; set; } = "0";
    public bool VariantReverse { get; set; }
    public bool VariantAutoSuffix { get; set; } = true;
}

public sealed record TransferProgress(int Completed, int Total, string CurrentFile, string Message);

public sealed record TransferItemResult(
    string SourcePath,
    string OutputPath,
    bool Success,
    bool Skipped,
    string Message,
    TransferVariant Variant,
    double DurationSeconds);

public sealed class TransferRunResult
{
    public List<TransferItemResult> Items { get; } = [];
    public string ReportPath { get; set; } = "";
    public int SuccessCount => Items.Count(item => item.Success);
    public int SkippedCount => Items.Count(item => item.Skipped);
    public int FailedCount => Items.Count(item => !item.Success && !item.Skipped);
    public string? LastOutput => Items.LastOrDefault(item => item.Success)?.OutputPath;
}
