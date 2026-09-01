using Microsoft.Data.Sqlite;

namespace PsyReaSFX.Data;

public sealed class PsyReaSFXDatabase
{
    public SnapshotWriteStats LastSnapshotWriteStats { get; private set; } = new(0, 0, 0);
    public SnapshotWriteTimings LastSnapshotWriteTimings { get; private set; } = new(0, 0, 0, 0, 0, 0);
    public const int SupportedSchemaVersion = 3;
    private readonly string _connectionString;
    public string DataDirectory { get; }
    public string DatabasePath { get; }

    public PsyReaSFXDatabase(string? dataDirectory = null)
    {
        DataDirectory = dataDirectory ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PsyReaSFX");
        DatabasePath = Path.Combine(DataDirectory, "catalog-v1.sqlite3");
        _connectionString = new SqliteConnectionStringBuilder
        {
            DataSource = DatabasePath,
            Mode = SqliteOpenMode.ReadWriteCreate,
            Cache = SqliteCacheMode.Shared,
            Pooling = true
        }.ToString();
    }

    public async Task InitializeAsync(CancellationToken cancellationToken = default)
    {
        Directory.CreateDirectory(DataDirectory);

        // Check an existing catalog through a genuinely read-only connection
        // before executing even idempotent DDL. This is the fail-closed gate
        // that prevents an older executable from touching a future schema.
        if (File.Exists(DatabasePath) && new FileInfo(DatabasePath).Length > 0)
        {
            var existingVersion = await ReadExistingSchemaVersionAsync(cancellationToken);
            if (existingVersion > SupportedSchemaVersion)
                throw new InvalidDataException(
                    $"Catalog schema {existingVersion} is newer than this application supports ({SupportedSchemaVersion}).");
        }

        await using var connection = await OpenAsync(cancellationToken);
        var command = connection.CreateCommand();
        command.CommandText = BaseSchema;
        await command.ExecuteNonQueryAsync(cancellationToken);
        await ApplyMigrationsAsync(connection, cancellationToken);
        await ValidateSchemaVersionAsync(connection, cancellationToken);
    }

    public async Task<int> GetSchemaVersionAsync(CancellationToken cancellationToken = default)
    {
        if (!File.Exists(DatabasePath) || new FileInfo(DatabasePath).Length == 0)
            return 0;
        return await ReadExistingSchemaVersionAsync(cancellationToken);
    }

    public async Task BackupAsync(string destinationPath, CancellationToken cancellationToken = default)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(destinationPath)!);
        await using var source = await OpenAsync(cancellationToken);
        await using var destination = new SqliteConnection(new SqliteConnectionStringBuilder
        {
            DataSource = destinationPath,
            Mode = SqliteOpenMode.ReadWriteCreate,
            Pooling = false
        }.ToString());
        await destination.OpenAsync(cancellationToken);
        source.BackupDatabase(destination);
    }

    public static async Task<string> CheckIntegrityAsync(string databasePath, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqliteConnection(new SqliteConnectionStringBuilder
        {
            DataSource = databasePath,
            Mode = SqliteOpenMode.ReadOnly,
            Pooling = false
        }.ToString());
        await connection.OpenAsync(cancellationToken);
        var command = connection.CreateCommand();
        command.CommandText = "PRAGMA integrity_check";
        return Convert.ToString(await command.ExecuteScalarAsync(cancellationToken)) ?? "unknown";
    }

    public async Task<MigrationSummary> ImportLuaIfNeededAsync(string? sourceDirectory = null, CancellationToken cancellationToken = default)
    {
        sourceDirectory ??= LuaDataLocator.Find();
        if (string.IsNullOrWhiteSpace(sourceDirectory) || !Directory.Exists(sourceDirectory))
            return new MigrationSummary(null, 0, 0, 0, 0, 0, 0, 0, 0, false);

        await using var connection = await OpenAsync(cancellationToken);
        var check = connection.CreateCommand();
        check.CommandText = "SELECT COUNT(*) FROM migrations WHERE migration_key = $key";
        check.Parameters.AddWithValue("$key", "lua-0.7.23:" + Path.GetFullPath(sourceDirectory).ToUpperInvariant());
        if (Convert.ToInt64(await check.ExecuteScalarAsync(cancellationToken)) > 0)
            return new MigrationSummary(sourceDirectory, 0, 0, 0, 0, 0, 0, 0, 0, false);

        var bundle = await LuaDataImporter.ReadAsync(sourceDirectory, cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await ImportBundleAsync(connection, bundle, cancellationToken);
        var mark = connection.CreateCommand();
        mark.Transaction = (SqliteTransaction)transaction;
        mark.CommandText = "INSERT INTO migrations(migration_key, source_path, imported_utc) VALUES($key,$path,$utc)";
        mark.Parameters.AddWithValue("$key", "lua-0.7.23:" + Path.GetFullPath(sourceDirectory).ToUpperInvariant());
        mark.Parameters.AddWithValue("$path", Path.GetFullPath(sourceDirectory));
        mark.Parameters.AddWithValue("$utc", DateTimeOffset.UtcNow.ToUnixTimeSeconds());
        await mark.ExecuteNonQueryAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        return new MigrationSummary(sourceDirectory, bundle.Libraries.Count, bundle.Sources.Count, bundle.Assets.Count,
            bundle.Collections.Count, bundle.SavedSearches.Count, bundle.History.Count, bundle.Regions.Count,
            bundle.Loudness.Count, true);
    }

    public async Task<CatalogSnapshot> LoadSnapshotAsync(CancellationToken cancellationToken = default)
    {
        var snapshot = new CatalogSnapshot();
        await using var connection = await OpenAsync(cancellationToken);

        await using (var command = connection.CreateCommand())
        {
            command.CommandText = "SELECT id,name,artwork_path,expanded FROM libraries ORDER BY sort_order,name COLLATE NOCASE";
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
                snapshot.Libraries.Add(new LibraryRecord(reader.GetString(0), reader.GetString(1), reader.GetString(2), reader.GetBoolean(3)));
        }
        await using (var command = connection.CreateCommand())
        {
            command.CommandText = "SELECT id,library_id,path,alias,enabled,artwork_path,artwork_checked,artwork_scan_version,canonical_path,volume_label,volume_serial,last_seen_utc FROM sources ORDER BY sort_order,path COLLATE NOCASE";
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
                snapshot.Sources.Add(new SourceRecord(reader.GetString(0), reader.GetString(1), reader.GetString(2), reader.GetString(3), reader.GetBoolean(4), reader.GetString(5), reader.GetBoolean(6), reader.GetInt32(7), reader.GetString(8), reader.GetString(9), reader.GetString(10), reader.GetInt64(11)));
        }
        await using (var command = connection.CreateCommand())
        {
            command.CommandText = """
                SELECT asset_id,path,relative_path,name,folder,root,library,duration,channels,sample_rate,bit_depth,source_type,size,
                       description,keywords,catid,category,subcategory,artwork_path,workflow_status,marked,
                       preview_count,last_previewed,indexed,ready,used_count,last_used,root_id,library_id,last_seen_utc
                FROM assets ORDER BY name COLLATE NOCASE
                """;
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken)) snapshot.Assets.Add(ReadAsset(reader));
        }
        await using (var command = connection.CreateCommand())
        {
            command.CommandText = "SELECT path FROM favorites";
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken)) snapshot.Favorites.Add(reader.GetString(0));
        }
        await using (var command = connection.CreateCommand())
        {
            command.CommandText = "SELECT path FROM session_played";
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken)) snapshot.SessionPlayed.Add(reader.GetString(0));
        }
        await using (var command = connection.CreateCommand())
        {
            command.CommandText = "SELECT id,name,kind FROM collections ORDER BY name COLLATE NOCASE";
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
                snapshot.Collections.Add(new CollectionRecord(reader.GetString(0), reader.GetString(1), reader.GetString(2)));
        }
        await using (var command = connection.CreateCommand())
        {
            command.CommandText = "SELECT collection_id,path,sort_order FROM collection_items ORDER BY collection_id,sort_order";
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
                snapshot.CollectionItems.Add(new CollectionItemRecord(reader.GetString(0), reader.GetString(1), reader.GetInt32(2)));
        }
        await using (var command = connection.CreateCommand())
        {
            command.CommandText = "SELECT id,name,query,view,root,sort_mode,sort_desc,status_filter,collection_id,library_id FROM saved_searches ORDER BY name COLLATE NOCASE";
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
                snapshot.SavedSearches.Add(new SavedSearchRecord(reader.GetString(0), reader.GetString(1), reader.GetString(2), reader.GetString(3), reader.GetString(4), reader.GetString(5), reader.GetBoolean(6), reader.IsDBNull(7) ? null : reader.GetString(7), reader.IsDBNull(8) ? null : reader.GetString(8), reader.IsDBNull(9) ? null : reader.GetString(9)));
        }
        return snapshot;
    }

    public async Task SaveDesktopSnapshotAsync(CatalogSnapshot snapshot, CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        var phase = System.Diagnostics.Stopwatch.StartNew();
        var existingAssets = await LoadExistingAssetsAsync(connection, cancellationToken);
        var existingLoadMs = phase.Elapsed.TotalMilliseconds;
        phase.Restart();
        await RelocateSnapshotReferencesAsync(connection, snapshot.Assets, existingAssets, cancellationToken);
        var relocationMs = phase.Elapsed.TotalMilliseconds;
        phase.Restart();
        await ExecuteAsync(connection, "DELETE FROM libraries", cancellationToken);
        await ExecuteAsync(connection, "DELETE FROM sources", cancellationToken);

        for (var i = 0; i < snapshot.Libraries.Count; i++)
            await UpsertLibraryAsync(connection, snapshot.Libraries[i], i, cancellationToken);
        for (var i = 0; i < snapshot.Sources.Count; i++)
            await UpsertSourceAsync(connection, snapshot.Sources[i], i, cancellationToken);
        var workspaceMs = phase.Elapsed.TotalMilliseconds;
        phase.Restart();
        var incomingAssetIds = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var changedAssets = 0;
        var unchangedAssets = 0;
        foreach (var asset in snapshot.Assets)
        {
            var relativePath = EffectiveRelativePath(asset);
            var assetId = EffectiveAssetId(asset, relativePath);
            incomingAssetIds.Add(assetId);
            if (!existingAssets.TryGetValue(assetId, out var existing)
                || !AssetRecordsEquivalent(existing, asset, assetId, relativePath))
            {
                await UpsertAssetAsync(connection, asset, cancellationToken, assetId, relativePath);
                changedAssets++;
            }
            else unchangedAssets++;
        }
        var removedAssets = 0;
        foreach (var removedAssetId in existingAssets.Keys.Where(id => !incomingAssetIds.Contains(id)))
        {
            await using var delete = connection.CreateCommand();
            delete.CommandText = "DELETE FROM assets WHERE asset_id=$id";
            delete.Parameters.AddWithValue("$id", removedAssetId);
            await delete.ExecuteNonQueryAsync(cancellationToken);
            removedAssets++;
        }
        if (removedAssets > 0)
            await ExecuteAsync(connection,
                "DELETE FROM loudness WHERE NOT EXISTS(SELECT 1 FROM assets WHERE assets.path=loudness.asset_path)",
                cancellationToken);
        var assetsMs = phase.Elapsed.TotalMilliseconds;
        phase.Restart();

        await ExecuteAsync(connection, "DELETE FROM favorites", cancellationToken);
        foreach (var path in snapshot.Favorites)
        {
            var command = connection.CreateCommand();
            command.CommandText = "INSERT OR IGNORE INTO favorites(path) VALUES($path)";
            command.Parameters.AddWithValue("$path", path);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }
        await ExecuteAsync(connection, "DELETE FROM session_played", cancellationToken);
        foreach (var path in snapshot.SessionPlayed)
        {
            var command = connection.CreateCommand();
            command.CommandText = "INSERT OR IGNORE INTO session_played(path) VALUES($path)";
            command.Parameters.AddWithValue("$path", path);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }
        await ReplaceOrganizationAsync(connection, snapshot, cancellationToken);
        var organizationMs = phase.Elapsed.TotalMilliseconds;
        phase.Restart();
        await transaction.CommitAsync(cancellationToken);
        var commitMs = phase.Elapsed.TotalMilliseconds;
        LastSnapshotWriteStats = new SnapshotWriteStats(changedAssets, unchangedAssets, removedAssets);
        LastSnapshotWriteTimings = new SnapshotWriteTimings(
            existingLoadMs, relocationMs, workspaceMs, assetsMs, organizationMs, commitMs);
    }

    private static async Task RelocateSnapshotReferencesAsync(
        SqliteConnection connection,
        IEnumerable<AssetRecord> assets,
        IReadOnlyDictionary<string, AssetRecord> existingAssets,
        CancellationToken token)
    {
        var unambiguousAssets = assets
            .Where(asset => !string.IsNullOrWhiteSpace(asset.AssetId))
            .GroupBy(asset => asset.AssetId, StringComparer.OrdinalIgnoreCase)
            .Where(group => group.Count() == 1)
            .Select(group => group.Single());
        foreach (var asset in unambiguousAssets)
        {
            if (!existingAssets.TryGetValue(asset.AssetId, out var existing)
                || existing.Path.Equals(asset.Path, StringComparison.OrdinalIgnoreCase)) continue;
            await RelocatePathReferencesAsync(connection, existing.Path, asset.Path, token);
            await using var moveAsset = connection.CreateCommand();
            moveAsset.CommandText = "UPDATE assets SET path=$new WHERE asset_id=$id";
            moveAsset.Parameters.AddWithValue("$new", asset.Path);
            moveAsset.Parameters.AddWithValue("$id", asset.AssetId);
            await moveAsset.ExecuteNonQueryAsync(token);
        }
    }

    private static async Task<Dictionary<string, AssetRecord>> LoadExistingAssetsAsync(
        SqliteConnection connection,
        CancellationToken token)
    {
        var rows = new Dictionary<string, AssetRecord>(StringComparer.OrdinalIgnoreCase);
        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT asset_id,path,relative_path,name,folder,root,library,duration,channels,sample_rate,bit_depth,source_type,size,
                   description,keywords,catid,category,subcategory,artwork_path,workflow_status,marked,preview_count,last_previewed,
                   indexed,ready,used_count,last_used,root_id,library_id,last_seen_utc
            FROM assets WHERE asset_id<>''
            """;
        await using var reader = await command.ExecuteReaderAsync(token);
        while (await reader.ReadAsync(token))
        {
            var row = ReadAsset(reader);
            rows[row.AssetId] = row;
        }
        return rows;
    }

    private static string EffectiveAssetId(AssetRecord row, string? relativePath = null)
    {
        if (!string.IsNullOrWhiteSpace(row.AssetId)) return row.AssetId;
        return PathIdentity.CreateAssetId(row.RootId, relativePath ?? EffectiveRelativePath(row));
    }

    private static string EffectiveRelativePath(AssetRecord row) =>
        string.IsNullOrWhiteSpace(row.RelativePath)
            ? PathIdentity.RelativeTo(row.Root, row.Path)
            : PathIdentity.NormalizeRelative(row.RelativePath);

    private static bool AssetRecordsEquivalent(
        AssetRecord left,
        AssetRecord right,
        string effectiveAssetId,
        string effectiveRelativePath) =>
        left.AssetId.Equals(effectiveAssetId, StringComparison.OrdinalIgnoreCase)
        && left.Path.Equals(right.Path, StringComparison.OrdinalIgnoreCase)
        && left.RelativePath.Equals(effectiveRelativePath, StringComparison.OrdinalIgnoreCase)
        && left.Name == right.Name && left.Folder == right.Folder && left.Root == right.Root && left.Library == right.Library
        && left.Duration.Equals(right.Duration) && left.Channels == right.Channels && left.SampleRate == right.SampleRate
        && left.BitDepth == right.BitDepth && left.SourceType == right.SourceType && left.Size == right.Size
        && left.Description == right.Description && left.Keywords == right.Keywords && left.CatId == right.CatId
        && left.Category == right.Category && left.Subcategory == right.Subcategory && left.ArtworkPath == right.ArtworkPath
        && left.WorkflowStatus == right.WorkflowStatus && left.Marked == right.Marked && left.PreviewCount == right.PreviewCount
        && left.LastPreviewed.Equals(right.LastPreviewed) && left.Indexed == right.Indexed && left.Ready == right.Ready
        && left.UsedCount == right.UsedCount && left.LastUsed.Equals(right.LastUsed) && left.RootId == right.RootId
        && left.LibraryId == right.LibraryId && left.LastSeenUtc == right.LastSeenUtc;

    private static async Task RelocatePathReferencesAsync(
        SqliteConnection connection,
        string oldPath,
        string newPath,
        CancellationToken token)
    {
        foreach (var table in new[] { "favorites", "session_played" })
        {
            var insert = connection.CreateCommand();
            insert.CommandText = $"INSERT OR IGNORE INTO {table}(path) SELECT $new WHERE EXISTS(SELECT 1 FROM {table} WHERE path=$old)";
            insert.Parameters.AddWithValue("$new", newPath);
            insert.Parameters.AddWithValue("$old", oldPath);
            await insert.ExecuteNonQueryAsync(token);
            var delete = connection.CreateCommand();
            delete.CommandText = $"DELETE FROM {table} WHERE path=$old";
            delete.Parameters.AddWithValue("$old", oldPath);
            await delete.ExecuteNonQueryAsync(token);
        }

        var collection = connection.CreateCommand();
        collection.CommandText = """
            INSERT OR IGNORE INTO collection_items(collection_id,path,sort_order)
            SELECT collection_id,$new,sort_order FROM collection_items WHERE path=$old;
            DELETE FROM collection_items WHERE path=$old;
            """;
        collection.Parameters.AddWithValue("$new", newPath);
        collection.Parameters.AddWithValue("$old", oldPath);
        await collection.ExecuteNonQueryAsync(token);

        var regions = connection.CreateCommand();
        regions.CommandText = """
            INSERT OR IGNORE INTO regions(asset_path,start,finish,name,source,batch_id)
            SELECT $new,start,finish,name,source,batch_id FROM regions WHERE asset_path=$old;
            DELETE FROM regions WHERE asset_path=$old;
            """;
        regions.Parameters.AddWithValue("$new", newPath);
        regions.Parameters.AddWithValue("$old", oldPath);
        await regions.ExecuteNonQueryAsync(token);

        var loudness = connection.CreateCommand();
        loudness.CommandText = """
            INSERT INTO loudness(asset_path,size,lufs_i,lufs_m,lufs_s,true_peak)
            SELECT $new,size,lufs_i,lufs_m,lufs_s,true_peak FROM loudness WHERE asset_path=$old
            ON CONFLICT(asset_path) DO UPDATE SET
              size=MAX(loudness.size,excluded.size),
              lufs_i=COALESCE(loudness.lufs_i,excluded.lufs_i),
              lufs_m=COALESCE(loudness.lufs_m,excluded.lufs_m),
              lufs_s=COALESCE(loudness.lufs_s,excluded.lufs_s),
              true_peak=COALESCE(loudness.true_peak,excluded.true_peak);
            DELETE FROM loudness WHERE asset_path=$old;
            UPDATE project_usage SET asset_path=$new WHERE asset_path=$old;
            """;
        loudness.Parameters.AddWithValue("$new", newPath);
        loudness.Parameters.AddWithValue("$old", oldPath);
        await loudness.ExecuteNonQueryAsync(token);
    }

    public async Task SaveWorkspaceAsync(CatalogSnapshot snapshot, CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await ExecuteAsync(connection, "DELETE FROM libraries", cancellationToken);
        await ExecuteAsync(connection, "DELETE FROM sources", cancellationToken);
        for (var i = 0; i < snapshot.Libraries.Count; i++)
            await UpsertLibraryAsync(connection, snapshot.Libraries[i], i, cancellationToken);
        for (var i = 0; i < snapshot.Sources.Count; i++)
            await UpsertSourceAsync(connection, snapshot.Sources[i], i, cancellationToken);
        await ExecuteAsync(connection, "DELETE FROM favorites", cancellationToken);
        foreach (var path in snapshot.Favorites)
        {
            var command = connection.CreateCommand();
            command.Transaction = (SqliteTransaction)transaction;
            command.CommandText = "INSERT OR IGNORE INTO favorites(path) VALUES($path)";
            command.Parameters.AddWithValue("$path", path);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }
        await ReplaceOrganizationAsync(connection, snapshot, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
    }

    public async Task ReplaceSessionPlayedAsync(IEnumerable<string> paths, CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await ExecuteAsync(connection, "DELETE FROM session_played", cancellationToken);
        foreach (var path in paths.Where(path => !string.IsNullOrWhiteSpace(path)).Distinct(StringComparer.OrdinalIgnoreCase))
        {
            var command = connection.CreateCommand();
            command.Transaction = (SqliteTransaction)transaction;
            command.CommandText = "INSERT OR IGNORE INTO session_played(path) VALUES($path)";
            command.Parameters.AddWithValue("$path", path);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }
        await transaction.CommitAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<RegionRecord>> LoadRegionsAsync(string assetPath, CancellationToken cancellationToken = default)
    {
        var rows = new List<RegionRecord>();
        await using var connection = await OpenAsync(cancellationToken);
        var command = connection.CreateCommand();
        command.CommandText = "SELECT asset_path,start,finish,name,source,batch_id FROM regions WHERE asset_path=$path ORDER BY start,finish,name COLLATE NOCASE";
        command.Parameters.AddWithValue("$path", assetPath);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
            rows.Add(new RegionRecord(reader.GetString(0), reader.GetDouble(1), reader.GetDouble(2), reader.GetString(3), reader.GetString(4), reader.GetString(5)));
        return rows;
    }

    public async Task UpsertRegionAsync(RegionRecord region, CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenAsync(cancellationToken);
        var command = connection.CreateCommand();
        command.CommandText = "INSERT OR REPLACE INTO regions(asset_path,start,finish,name,source,batch_id) VALUES($path,$start,$finish,$name,$source,$batch)";
        command.Parameters.AddWithValue("$path", region.AssetPath);
        command.Parameters.AddWithValue("$start", region.Start);
        command.Parameters.AddWithValue("$finish", region.Finish);
        command.Parameters.AddWithValue("$name", region.Name);
        command.Parameters.AddWithValue("$source", region.Source);
        command.Parameters.AddWithValue("$batch", region.BatchId);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task DeleteRegionAsync(RegionRecord region, CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenAsync(cancellationToken);
        var command = connection.CreateCommand();
        command.CommandText = "DELETE FROM regions WHERE asset_path=$path AND start=$start AND finish=$finish AND name=$name";
        command.Parameters.AddWithValue("$path", region.AssetPath);
        command.Parameters.AddWithValue("$start", region.Start);
        command.Parameters.AddWithValue("$finish", region.Finish);
        command.Parameters.AddWithValue("$name", region.Name);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task<LoudnessRecord?> LoadLoudnessAsync(string assetPath, CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenAsync(cancellationToken);
        var command = connection.CreateCommand();
        command.CommandText = "SELECT asset_path,size,lufs_i,lufs_m,lufs_s,true_peak FROM loudness WHERE asset_path=$path";
        command.Parameters.AddWithValue("$path", assetPath);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return null;
        return new LoudnessRecord(reader.GetString(0), reader.GetInt64(1),
            reader.IsDBNull(2) ? null : reader.GetDouble(2), reader.IsDBNull(3) ? null : reader.GetDouble(3),
            reader.IsDBNull(4) ? null : reader.GetDouble(4), reader.IsDBNull(5) ? null : reader.GetDouble(5));
    }

    public async Task UpsertLoudnessAsync(LoudnessRecord row, CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenAsync(cancellationToken);
        var command = connection.CreateCommand();
        command.CommandText = "INSERT OR REPLACE INTO loudness(asset_path,size,lufs_i,lufs_m,lufs_s,true_peak) VALUES($path,$size,$i,$m,$s,$tp)";
        command.Parameters.AddWithValue("$path", row.AssetPath);
        command.Parameters.AddWithValue("$size", row.Size);
        command.Parameters.AddWithValue("$i", (object?)row.LufsI ?? DBNull.Value);
        command.Parameters.AddWithValue("$m", (object?)row.LufsM ?? DBNull.Value);
        command.Parameters.AddWithValue("$s", (object?)row.LufsS ?? DBNull.Value);
        command.Parameters.AddWithValue("$tp", (object?)row.TruePeak ?? DBNull.Value);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task AddProjectUsageAsync(ProjectUsageRecord row, CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenAsync(cancellationToken);
        var command = connection.CreateCommand();
        command.CommandText = """
            INSERT OR REPLACE INTO project_usage
            (id,asset_path,project_path,project_name,action,inserted_path,track_name,track_index,position,created_utc)
            VALUES($id,$asset,$project,$projectName,$action,$inserted,$track,$trackIndex,$position,$created)
            """;
        command.Parameters.AddWithValue("$id", row.Id);
        command.Parameters.AddWithValue("$asset", row.AssetPath);
        command.Parameters.AddWithValue("$project", row.ProjectPath);
        command.Parameters.AddWithValue("$projectName", row.ProjectName);
        command.Parameters.AddWithValue("$action", row.Action);
        command.Parameters.AddWithValue("$inserted", row.InsertedPath);
        command.Parameters.AddWithValue("$track", row.TrackName);
        command.Parameters.AddWithValue("$trackIndex", row.TrackIndex);
        command.Parameters.AddWithValue("$position", row.Position);
        command.Parameters.AddWithValue("$created", row.CreatedUtc);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<ProjectUsageRecord>> LoadProjectUsageAsync(int limit = 500, CancellationToken cancellationToken = default)
    {
        var rows = new List<ProjectUsageRecord>();
        await using var connection = await OpenAsync(cancellationToken);
        var command = connection.CreateCommand();
        command.CommandText = """
            SELECT id,asset_path,project_path,project_name,action,inserted_path,track_name,track_index,position,created_utc
            FROM project_usage ORDER BY created_utc DESC LIMIT $limit
            """;
        command.Parameters.AddWithValue("$limit", Math.Clamp(limit, 1, 10000));
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
            rows.Add(new ProjectUsageRecord(reader.GetString(0), reader.GetString(1), reader.GetString(2), reader.GetString(3),
                reader.GetString(4), reader.GetString(5), reader.GetString(6), reader.GetInt32(7), reader.GetDouble(8), reader.GetInt64(9)));
        return rows;
    }

    private static async Task ReplaceOrganizationAsync(SqliteConnection connection, CatalogSnapshot snapshot, CancellationToken token)
    {
        await ExecuteAsync(connection, "DELETE FROM collection_items", token);
        await ExecuteAsync(connection, "DELETE FROM collections", token);
        await ExecuteAsync(connection, "DELETE FROM saved_searches", token);
        foreach (var collection in snapshot.Collections)
        {
            var command = connection.CreateCommand();
            command.CommandText = "INSERT INTO collections(id,name,kind) VALUES($id,$name,$kind)";
            command.Parameters.AddWithValue("$id", collection.Id); command.Parameters.AddWithValue("$name", collection.Name); command.Parameters.AddWithValue("$kind", collection.Kind);
            await command.ExecuteNonQueryAsync(token);
        }
        foreach (var item in snapshot.CollectionItems)
        {
            var command = connection.CreateCommand();
            command.CommandText = "INSERT INTO collection_items(collection_id,path,sort_order) VALUES($id,$path,$order)";
            command.Parameters.AddWithValue("$id", item.CollectionId); command.Parameters.AddWithValue("$path", item.Path); command.Parameters.AddWithValue("$order", item.SortOrder);
            await command.ExecuteNonQueryAsync(token);
        }
        foreach (var saved in snapshot.SavedSearches)
        {
            var command = connection.CreateCommand();
            command.CommandText = "INSERT INTO saved_searches(id,name,query,view,root,sort_mode,sort_desc,status_filter,collection_id,library_id) VALUES($id,$name,$query,$view,$root,$sort,$desc,$status,$collection,$library)";
            command.Parameters.AddWithValue("$id", saved.Id); command.Parameters.AddWithValue("$name", saved.Name); command.Parameters.AddWithValue("$query", saved.Query); command.Parameters.AddWithValue("$view", saved.View); command.Parameters.AddWithValue("$root", saved.Root); command.Parameters.AddWithValue("$sort", saved.SortMode); command.Parameters.AddWithValue("$desc", saved.SortDescending); command.Parameters.AddWithValue("$status", (object?)saved.StatusFilter ?? DBNull.Value); command.Parameters.AddWithValue("$collection", (object?)saved.CollectionId ?? DBNull.Value); command.Parameters.AddWithValue("$library", (object?)saved.LibraryId ?? DBNull.Value);
            await command.ExecuteNonQueryAsync(token);
        }
    }

    public async Task SaveAssetActivityAsync(IEnumerable<AssetRecord> assets, CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        foreach (var asset in assets)
        {
            var command = connection.CreateCommand();
            command.Transaction = (SqliteTransaction)transaction;
            command.CommandText = "UPDATE assets SET preview_count=$count,last_previewed=$last,used_count=$used,last_used=$lastUsed WHERE path=$path";
            command.Parameters.AddWithValue("$count", asset.PreviewCount);
            command.Parameters.AddWithValue("$last", asset.LastPreviewed);
            command.Parameters.AddWithValue("$used", asset.UsedCount);
            command.Parameters.AddWithValue("$lastUsed", asset.LastUsed);
            command.Parameters.AddWithValue("$path", asset.Path);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }
        await transaction.CommitAsync(cancellationToken);
    }

    public async Task SaveAssetDetailsAsync(IEnumerable<AssetRecord> assets, CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        foreach (var asset in assets)
        {
            var command = connection.CreateCommand();
            command.Transaction = (SqliteTransaction)transaction;
            command.CommandText = """
                UPDATE assets SET description=$description,keywords=$keywords,catid=$catid,
                    category=$category,subcategory=$subcategory,artwork_path=$artwork,
                    workflow_status=$status,marked=$marked
                WHERE path=$path
                """;
            command.Parameters.AddWithValue("$description", asset.Description);
            command.Parameters.AddWithValue("$keywords", asset.Keywords);
            command.Parameters.AddWithValue("$catid", asset.CatId);
            command.Parameters.AddWithValue("$category", asset.Category);
            command.Parameters.AddWithValue("$subcategory", asset.Subcategory);
            command.Parameters.AddWithValue("$artwork", asset.ArtworkPath);
            command.Parameters.AddWithValue("$status", asset.WorkflowStatus);
            command.Parameters.AddWithValue("$marked", asset.Marked);
            command.Parameters.AddWithValue("$path", asset.Path);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }
        await transaction.CommitAsync(cancellationToken);
    }

    private async Task<SqliteConnection> OpenAsync(CancellationToken cancellationToken)
    {
        var connection = new SqliteConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        var pragma = connection.CreateCommand();
        pragma.CommandText = "PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL; PRAGMA busy_timeout=5000;";
        await pragma.ExecuteNonQueryAsync(cancellationToken);
        return connection;
    }

    private async Task<int> ReadExistingSchemaVersionAsync(CancellationToken token)
    {
        await using var connection = new SqliteConnection(new SqliteConnectionStringBuilder
        {
            DataSource = DatabasePath,
            Mode = SqliteOpenMode.ReadOnly,
            Pooling = false
        }.ToString());
        await connection.OpenAsync(token);

        var tableCheck = connection.CreateCommand();
        tableCheck.CommandText = "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='schema_info'";
        if (Convert.ToInt64(await tableCheck.ExecuteScalarAsync(token)) == 0)
            throw new InvalidDataException("The catalog has no schema_info table and will not be modified.");

        return await ReadSchemaVersionAsync(connection, token);
    }

    private static async Task<int> ReadSchemaVersionAsync(SqliteConnection connection, CancellationToken token)
    {
        var command = connection.CreateCommand();
        command.CommandText = "SELECT MAX(version) FROM schema_info";
        var value = await command.ExecuteScalarAsync(token);
        var version = value is null or DBNull ? 0 : Convert.ToInt32(value);
        if (version < 1)
            throw new InvalidDataException("The catalog schema has no valid version marker.");
        return version;
    }

    private static async Task ValidateSchemaVersionAsync(SqliteConnection connection, CancellationToken token)
    {
        var version = await ReadSchemaVersionAsync(connection, token);
        if (version > SupportedSchemaVersion)
            throw new InvalidDataException(
                $"Catalog schema {version} is newer than this application supports ({SupportedSchemaVersion}).");
        if (version != SupportedSchemaVersion)
            throw new InvalidDataException(
                $"Catalog schema migration stopped at {version}; expected {SupportedSchemaVersion}.");
    }

    private static async Task ApplyMigrationsAsync(SqliteConnection connection, CancellationToken token)
    {
        var version = await ReadSchemaVersionAsync(connection, token);
        if (version > SupportedSchemaVersion)
            throw new InvalidDataException(
                $"Catalog schema {version} is newer than this application supports ({SupportedSchemaVersion}).");

        await using var transaction = (SqliteTransaction)await connection.BeginTransactionAsync(token);
        try
        {
            while (version < SupportedSchemaVersion)
            {
                var targetVersion = version + 1;
                if (!SchemaMigrations.TryGetValue(targetVersion, out var sql))
                    throw new InvalidDataException(
                        $"No catalog migration is registered for schema {version} -> {targetVersion}.");

                var command = connection.CreateCommand();
                command.Transaction = transaction;
                command.CommandText = sql;
                await command.ExecuteNonQueryAsync(token);

                var record = connection.CreateCommand();
                record.Transaction = transaction;
                record.CommandText = "INSERT OR REPLACE INTO schema_history(version,applied_utc) VALUES($version,$utc)";
                record.Parameters.AddWithValue("$version", targetVersion);
                record.Parameters.AddWithValue("$utc", DateTimeOffset.UtcNow.ToUnixTimeSeconds());
                await record.ExecuteNonQueryAsync(token);

                var marker = connection.CreateCommand();
                marker.Transaction = transaction;
                marker.CommandText = "DELETE FROM schema_info; INSERT INTO schema_info(version) VALUES($version)";
                marker.Parameters.AddWithValue("$version", targetVersion);
                await marker.ExecuteNonQueryAsync(token);
                version = targetVersion;
            }

            await transaction.CommitAsync(token);
        }
        catch
        {
            await transaction.RollbackAsync(CancellationToken.None);
            throw;
        }
    }

    private static async Task ImportBundleAsync(SqliteConnection connection, LuaImportBundle bundle, CancellationToken token)
    {
        for (var i = 0; i < bundle.Libraries.Count; i++) await UpsertLibraryAsync(connection, bundle.Libraries[i], i, token);
        for (var i = 0; i < bundle.Sources.Count; i++) await UpsertSourceAsync(connection, bundle.Sources[i], i, token);
        foreach (var asset in bundle.Assets) await UpsertAssetAsync(connection, asset, token);
        foreach (var collection in bundle.Collections)
        {
            var command = connection.CreateCommand();
            command.CommandText = "INSERT OR REPLACE INTO collections(id,name,kind) VALUES($id,$name,$kind)";
            command.Parameters.AddWithValue("$id", collection.Id);
            command.Parameters.AddWithValue("$name", collection.Name);
            command.Parameters.AddWithValue("$kind", collection.Kind);
            await command.ExecuteNonQueryAsync(token);
        }
        foreach (var item in bundle.CollectionItems)
        {
            var command = connection.CreateCommand();
            command.CommandText = "INSERT OR IGNORE INTO collection_items(collection_id,path,sort_order) VALUES($id,$path,$order)";
            command.Parameters.AddWithValue("$id", item.CollectionId);
            command.Parameters.AddWithValue("$path", item.Path);
            command.Parameters.AddWithValue("$order", item.SortOrder);
            await command.ExecuteNonQueryAsync(token);
        }
        foreach (var saved in bundle.SavedSearches)
        {
            var command = connection.CreateCommand();
            command.CommandText = """
                INSERT OR REPLACE INTO saved_searches(id,name,query,view,root,sort_mode,sort_desc,status_filter,collection_id,library_id)
                VALUES($id,$name,$query,$view,$root,$sort,$desc,$status,$collection,$library)
                """;
            command.Parameters.AddWithValue("$id", saved.Id); command.Parameters.AddWithValue("$name", saved.Name);
            command.Parameters.AddWithValue("$query", saved.Query); command.Parameters.AddWithValue("$view", saved.View);
            command.Parameters.AddWithValue("$root", saved.Root); command.Parameters.AddWithValue("$sort", saved.SortMode);
            command.Parameters.AddWithValue("$desc", saved.SortDescending); command.Parameters.AddWithValue("$status", (object?)saved.StatusFilter ?? DBNull.Value);
            command.Parameters.AddWithValue("$collection", (object?)saved.CollectionId ?? DBNull.Value); command.Parameters.AddWithValue("$library", (object?)saved.LibraryId ?? DBNull.Value);
            await command.ExecuteNonQueryAsync(token);
        }
        foreach (var row in bundle.History)
        {
            var command = connection.CreateCommand();
            command.CommandText = "UPDATE assets SET preview_count=$count,last_previewed=$last WHERE path=$path";
            command.Parameters.AddWithValue("$count", row.Count); command.Parameters.AddWithValue("$last", row.Last); command.Parameters.AddWithValue("$path", row.Path);
            await command.ExecuteNonQueryAsync(token);
        }
        foreach (var path in bundle.SessionPlayed)
        {
            var command = connection.CreateCommand(); command.CommandText = "INSERT OR IGNORE INTO session_played(path) VALUES($path)";
            command.Parameters.AddWithValue("$path", path); await command.ExecuteNonQueryAsync(token);
        }
        foreach (var row in bundle.Regions)
        {
            var command = connection.CreateCommand(); command.CommandText = "INSERT OR REPLACE INTO regions(asset_path,start,finish,name,source,batch_id) VALUES($path,$start,$finish,$name,$source,$batch)";
            command.Parameters.AddWithValue("$path", row.AssetPath); command.Parameters.AddWithValue("$start", row.Start); command.Parameters.AddWithValue("$finish", row.Finish);
            command.Parameters.AddWithValue("$name", row.Name); command.Parameters.AddWithValue("$source", row.Source); command.Parameters.AddWithValue("$batch", row.BatchId);
            await command.ExecuteNonQueryAsync(token);
        }
        foreach (var row in bundle.Loudness)
        {
            var command = connection.CreateCommand(); command.CommandText = "INSERT OR REPLACE INTO loudness(asset_path,size,lufs_i,lufs_m,lufs_s,true_peak) VALUES($path,$size,$i,$m,$s,$tp)";
            command.Parameters.AddWithValue("$path", row.AssetPath); command.Parameters.AddWithValue("$size", row.Size);
            command.Parameters.AddWithValue("$i", (object?)row.LufsI ?? DBNull.Value); command.Parameters.AddWithValue("$m", (object?)row.LufsM ?? DBNull.Value);
            command.Parameters.AddWithValue("$s", (object?)row.LufsS ?? DBNull.Value); command.Parameters.AddWithValue("$tp", (object?)row.TruePeak ?? DBNull.Value);
            await command.ExecuteNonQueryAsync(token);
        }
        foreach (var pair in bundle.Settings)
        {
            var command = connection.CreateCommand(); command.CommandText = "INSERT OR REPLACE INTO settings(key,value) VALUES($key,$value)";
            command.Parameters.AddWithValue("$key", pair.Key); command.Parameters.AddWithValue("$value", pair.Value); await command.ExecuteNonQueryAsync(token);
        }
        await ExecuteAsync(connection, "INSERT INTO assets_fts(assets_fts) VALUES('rebuild')", token);
    }

    private static async Task UpsertLibraryAsync(SqliteConnection connection, LibraryRecord row, int order, CancellationToken token)
    {
        var command = connection.CreateCommand(); command.CommandText = "INSERT OR REPLACE INTO libraries(id,name,artwork_path,expanded,sort_order) VALUES($id,$name,$art,$expanded,$order)";
        command.Parameters.AddWithValue("$id", row.Id); command.Parameters.AddWithValue("$name", row.Name); command.Parameters.AddWithValue("$art", row.ArtworkPath);
        command.Parameters.AddWithValue("$expanded", row.Expanded); command.Parameters.AddWithValue("$order", order); await command.ExecuteNonQueryAsync(token);
    }

    private static async Task UpsertSourceAsync(SqliteConnection connection, SourceRecord row, int order, CancellationToken token)
    {
        var identity = PathIdentity.CaptureSource(row.Path);
        var command = connection.CreateCommand(); command.CommandText = """
            INSERT OR REPLACE INTO sources(id,library_id,path,alias,enabled,artwork_path,artwork_checked,artwork_scan_version,sort_order,canonical_path,volume_label,volume_serial,last_seen_utc)
            VALUES($id,$library,$path,$alias,$enabled,$art,$checked,$version,$order,$canonical,$label,$serial,$last_seen)
            """;
        command.Parameters.AddWithValue("$id", row.Id); command.Parameters.AddWithValue("$library", row.LibraryId); command.Parameters.AddWithValue("$path", row.Path);
        command.Parameters.AddWithValue("$alias", row.Alias); command.Parameters.AddWithValue("$enabled", row.Enabled); command.Parameters.AddWithValue("$art", row.ArtworkPath);
        command.Parameters.AddWithValue("$checked", row.ArtworkChecked); command.Parameters.AddWithValue("$version", row.ArtworkScanVersion); command.Parameters.AddWithValue("$order", order);
        command.Parameters.AddWithValue("$canonical", string.IsNullOrWhiteSpace(row.CanonicalPath) ? identity.CanonicalPath : row.CanonicalPath);
        command.Parameters.AddWithValue("$label", string.IsNullOrWhiteSpace(row.VolumeLabel) ? identity.VolumeLabel : row.VolumeLabel);
        command.Parameters.AddWithValue("$serial", string.IsNullOrWhiteSpace(row.VolumeSerial) ? identity.VolumeSerial : row.VolumeSerial);
        command.Parameters.AddWithValue("$last_seen", row.LastSeenUtc > 0 ? row.LastSeenUtc : identity.LastSeenUtc);
        await command.ExecuteNonQueryAsync(token);
    }

    private static async Task UpsertAssetAsync(
        SqliteConnection connection,
        AssetRecord row,
        CancellationToken token,
        string? effectiveAssetId = null,
        string? effectiveRelativePath = null)
    {
        var relativePath = effectiveRelativePath ?? EffectiveRelativePath(row);
        var assetId = effectiveAssetId ?? EffectiveAssetId(row, relativePath);
        var command = connection.CreateCommand(); command.CommandText = """
            INSERT INTO assets(asset_id,path,relative_path,name,folder,root,library,duration,channels,sample_rate,bit_depth,source_type,size,description,keywords,catid,category,subcategory,artwork_path,workflow_status,marked,preview_count,last_previewed,indexed,ready,used_count,last_used,root_id,library_id,last_seen_utc)
            VALUES($asset_id,$path,$relative_path,$name,$folder,$root,$library,$duration,$channels,$rate,$depth,$type,$size,$description,$keywords,$catid,$category,$subcategory,$artwork,$status,$marked,$preview_count,$last_previewed,$indexed,$ready,$used_count,$last_used,$root_id,$library_id,$last_seen)
            ON CONFLICT(path) DO UPDATE SET asset_id=excluded.asset_id,relative_path=excluded.relative_path,name=excluded.name,folder=excluded.folder,root=excluded.root,library=excluded.library,duration=excluded.duration,channels=excluded.channels,sample_rate=excluded.sample_rate,bit_depth=excluded.bit_depth,source_type=excluded.source_type,size=excluded.size,description=CASE WHEN excluded.description='' THEN assets.description ELSE excluded.description END,keywords=CASE WHEN excluded.keywords='' THEN assets.keywords ELSE excluded.keywords END,catid=CASE WHEN excluded.catid='' THEN assets.catid ELSE excluded.catid END,category=CASE WHEN excluded.category='' THEN assets.category ELSE excluded.category END,subcategory=CASE WHEN excluded.subcategory='' THEN assets.subcategory ELSE excluded.subcategory END,artwork_path=CASE WHEN excluded.artwork_path='' THEN assets.artwork_path ELSE excluded.artwork_path END,workflow_status=excluded.workflow_status,marked=excluded.marked,preview_count=MAX(assets.preview_count,excluded.preview_count),last_previewed=MAX(assets.last_previewed,excluded.last_previewed),indexed=excluded.indexed,ready=excluded.ready,used_count=MAX(assets.used_count,excluded.used_count),last_used=MAX(assets.last_used,excluded.last_used),root_id=excluded.root_id,library_id=excluded.library_id,last_seen_utc=MAX(assets.last_seen_utc,excluded.last_seen_utc)
            """;
        void Add(string name, object? value) => command.Parameters.AddWithValue(name, value ?? DBNull.Value);
        Add("$asset_id", assetId); Add("$path", row.Path); Add("$relative_path", relativePath); Add("$name", row.Name); Add("$folder", row.Folder); Add("$root", row.Root); Add("$library", row.Library);
        Add("$duration", row.Duration); Add("$channels", row.Channels); Add("$rate", row.SampleRate); Add("$depth", row.BitDepth); Add("$type", row.SourceType); Add("$size", row.Size);
        Add("$description", row.Description); Add("$keywords", row.Keywords); Add("$catid", row.CatId); Add("$category", row.Category); Add("$subcategory", row.Subcategory); Add("$artwork", row.ArtworkPath);
        Add("$status", row.WorkflowStatus); Add("$marked", row.Marked); Add("$preview_count", row.PreviewCount); Add("$last_previewed", row.LastPreviewed); Add("$indexed", row.Indexed); Add("$ready", row.Ready);
        Add("$used_count", row.UsedCount); Add("$last_used", row.LastUsed); Add("$root_id", row.RootId); Add("$library_id", row.LibraryId); Add("$last_seen", row.LastSeenUtc);
        await command.ExecuteNonQueryAsync(token);
    }

    private static AssetRecord ReadAsset(SqliteDataReader r) => new()
    {
        AssetId = r.GetString(0), Path = r.GetString(1), RelativePath = r.GetString(2), Name = r.GetString(3), Folder = r.GetString(4), Root = r.GetString(5), Library = r.GetString(6), Duration = r.GetDouble(7),
        Channels = r.GetInt32(8), SampleRate = r.GetInt32(9), BitDepth = r.GetInt32(10), SourceType = r.GetString(11), Size = r.GetInt64(12),
        Description = r.GetString(13), Keywords = r.GetString(14), CatId = r.GetString(15), Category = r.GetString(16), Subcategory = r.GetString(17), ArtworkPath = r.GetString(18),
        WorkflowStatus = r.GetString(19), Marked = r.GetBoolean(20), PreviewCount = r.GetInt32(21), LastPreviewed = r.GetDouble(22), Indexed = r.GetBoolean(23), Ready = r.GetBoolean(24),
        UsedCount = r.GetInt32(25), LastUsed = r.GetDouble(26), RootId = r.GetString(27), LibraryId = r.GetString(28), LastSeenUtc = r.GetInt64(29)
    };

    private static async Task ExecuteAsync(SqliteConnection connection, string sql, CancellationToken token)
    {
        var command = connection.CreateCommand(); command.CommandText = sql; await command.ExecuteNonQueryAsync(token);
    }

    private static readonly IReadOnlyDictionary<int, string> SchemaMigrations =
        new Dictionary<int, string>
        {
            [2] = """
                CREATE TABLE IF NOT EXISTS catalog_meta(key TEXT PRIMARY KEY,value TEXT NOT NULL);
                INSERT OR REPLACE INTO catalog_meta(key,value) VALUES('format','PsyReaSFX Desktop Catalog');
                INSERT OR REPLACE INTO catalog_meta(key,value) VALUES('minimum_reader_schema','1');
                CREATE TABLE IF NOT EXISTS schema_history(version INTEGER PRIMARY KEY,applied_utc INTEGER NOT NULL);
                """,
            [3] = """
                ALTER TABLE sources ADD COLUMN canonical_path TEXT NOT NULL DEFAULT '';
                ALTER TABLE sources ADD COLUMN volume_label TEXT NOT NULL DEFAULT '';
                ALTER TABLE sources ADD COLUMN volume_serial TEXT NOT NULL DEFAULT '';
                ALTER TABLE sources ADD COLUMN last_seen_utc INTEGER NOT NULL DEFAULT 0;
                UPDATE sources SET canonical_path=path WHERE canonical_path='';
                ALTER TABLE assets ADD COLUMN asset_id TEXT NOT NULL DEFAULT '';
                ALTER TABLE assets ADD COLUMN relative_path TEXT NOT NULL DEFAULT '';
                ALTER TABLE assets ADD COLUMN last_seen_utc INTEGER NOT NULL DEFAULT 0;
                UPDATE assets SET asset_id=lower(hex(randomblob(16))) WHERE asset_id='';
                CREATE UNIQUE INDEX IF NOT EXISTS assets_asset_id ON assets(asset_id);
                CREATE INDEX IF NOT EXISTS assets_source_relative ON assets(root_id,relative_path COLLATE NOCASE);
                INSERT OR REPLACE INTO catalog_meta(key,value) VALUES('minimum_reader_schema','3');
                """
        };

    private const string BaseSchema = """
        CREATE TABLE IF NOT EXISTS schema_info(version INTEGER NOT NULL);
        INSERT INTO schema_info(version) SELECT 1 WHERE NOT EXISTS(SELECT 1 FROM schema_info);
        CREATE TABLE IF NOT EXISTS migrations(migration_key TEXT PRIMARY KEY,source_path TEXT NOT NULL,imported_utc INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY,value TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS libraries(id TEXT PRIMARY KEY,name TEXT NOT NULL,artwork_path TEXT NOT NULL DEFAULT '',expanded INTEGER NOT NULL DEFAULT 1,sort_order INTEGER NOT NULL DEFAULT 0);
        CREATE TABLE IF NOT EXISTS sources(id TEXT PRIMARY KEY,library_id TEXT NOT NULL,path TEXT NOT NULL COLLATE NOCASE UNIQUE,alias TEXT NOT NULL DEFAULT '',enabled INTEGER NOT NULL DEFAULT 1,artwork_path TEXT NOT NULL DEFAULT '',artwork_checked INTEGER NOT NULL DEFAULT 0,artwork_scan_version INTEGER NOT NULL DEFAULT 0,sort_order INTEGER NOT NULL DEFAULT 0);
        CREATE TABLE IF NOT EXISTS assets(path TEXT PRIMARY KEY COLLATE NOCASE,name TEXT NOT NULL,folder TEXT NOT NULL DEFAULT '',root TEXT NOT NULL DEFAULT '',library TEXT NOT NULL DEFAULT '',duration REAL NOT NULL DEFAULT 0,channels INTEGER NOT NULL DEFAULT 0,sample_rate INTEGER NOT NULL DEFAULT 0,bit_depth INTEGER NOT NULL DEFAULT 0,source_type TEXT NOT NULL DEFAULT '',size INTEGER NOT NULL DEFAULT 0,description TEXT NOT NULL DEFAULT '',keywords TEXT NOT NULL DEFAULT '',catid TEXT NOT NULL DEFAULT '',category TEXT NOT NULL DEFAULT '',subcategory TEXT NOT NULL DEFAULT '',artwork_path TEXT NOT NULL DEFAULT '',workflow_status TEXT NOT NULL DEFAULT 'none',marked INTEGER NOT NULL DEFAULT 0,preview_count INTEGER NOT NULL DEFAULT 0,last_previewed REAL NOT NULL DEFAULT 0,indexed INTEGER NOT NULL DEFAULT 0,ready INTEGER NOT NULL DEFAULT 0,used_count INTEGER NOT NULL DEFAULT 0,last_used REAL NOT NULL DEFAULT 0,root_id TEXT NOT NULL DEFAULT '',library_id TEXT NOT NULL DEFAULT '');
        CREATE INDEX IF NOT EXISTS assets_library_id ON assets(library_id);
        CREATE INDEX IF NOT EXISTS assets_root_id ON assets(root_id);
        CREATE INDEX IF NOT EXISTS assets_name ON assets(name COLLATE NOCASE);
        CREATE INDEX IF NOT EXISTS assets_workflow ON assets(workflow_status);
        CREATE VIRTUAL TABLE IF NOT EXISTS assets_fts USING fts5(path,name,description,keywords,category,subcategory,library,content='assets',content_rowid='rowid');
        CREATE TRIGGER IF NOT EXISTS assets_ai AFTER INSERT ON assets BEGIN INSERT INTO assets_fts(rowid,path,name,description,keywords,category,subcategory,library) VALUES(new.rowid,new.path,new.name,new.description,new.keywords,new.category,new.subcategory,new.library); END;
        CREATE TRIGGER IF NOT EXISTS assets_ad AFTER DELETE ON assets BEGIN INSERT INTO assets_fts(assets_fts,rowid,path,name,description,keywords,category,subcategory,library) VALUES('delete',old.rowid,old.path,old.name,old.description,old.keywords,old.category,old.subcategory,old.library); END;
        CREATE TRIGGER IF NOT EXISTS assets_au AFTER UPDATE ON assets BEGIN INSERT INTO assets_fts(assets_fts,rowid,path,name,description,keywords,category,subcategory,library) VALUES('delete',old.rowid,old.path,old.name,old.description,old.keywords,old.category,old.subcategory,old.library); INSERT INTO assets_fts(rowid,path,name,description,keywords,category,subcategory,library) VALUES(new.rowid,new.path,new.name,new.description,new.keywords,new.category,new.subcategory,new.library); END;
        CREATE TABLE IF NOT EXISTS favorites(path TEXT PRIMARY KEY COLLATE NOCASE);
        CREATE TABLE IF NOT EXISTS collections(id TEXT PRIMARY KEY,name TEXT NOT NULL,kind TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS collection_items(collection_id TEXT NOT NULL,path TEXT NOT NULL COLLATE NOCASE,sort_order INTEGER NOT NULL DEFAULT 0,PRIMARY KEY(collection_id,path));
        CREATE TABLE IF NOT EXISTS saved_searches(id TEXT PRIMARY KEY,name TEXT NOT NULL,query TEXT NOT NULL,view TEXT NOT NULL,root TEXT NOT NULL,sort_mode TEXT NOT NULL,sort_desc INTEGER NOT NULL,status_filter TEXT,collection_id TEXT,library_id TEXT);
        CREATE TABLE IF NOT EXISTS session_played(path TEXT PRIMARY KEY COLLATE NOCASE);
        CREATE TABLE IF NOT EXISTS regions(asset_path TEXT NOT NULL COLLATE NOCASE,start REAL NOT NULL,finish REAL NOT NULL,name TEXT NOT NULL,source TEXT NOT NULL,batch_id TEXT NOT NULL,PRIMARY KEY(asset_path,start,finish,name));
        CREATE TABLE IF NOT EXISTS loudness(asset_path TEXT PRIMARY KEY COLLATE NOCASE,size INTEGER NOT NULL,lufs_i REAL,lufs_m REAL,lufs_s REAL,true_peak REAL);
        CREATE TABLE IF NOT EXISTS project_usage(id TEXT PRIMARY KEY,asset_path TEXT NOT NULL COLLATE NOCASE,project_path TEXT NOT NULL DEFAULT '',project_name TEXT NOT NULL DEFAULT '',action TEXT NOT NULL,inserted_path TEXT NOT NULL DEFAULT '',track_name TEXT NOT NULL DEFAULT '',track_index INTEGER NOT NULL DEFAULT -1,position REAL NOT NULL DEFAULT 0,created_utc INTEGER NOT NULL);
        CREATE INDEX IF NOT EXISTS project_usage_asset ON project_usage(asset_path);
        CREATE INDEX IF NOT EXISTS project_usage_created ON project_usage(created_utc DESC);
        """;
}
