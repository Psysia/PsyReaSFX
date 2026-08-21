using Microsoft.Data.Sqlite;

namespace PsyReaSFX.Data;

public sealed class PsyReaSFXDatabase
{
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
        await using var connection = await OpenAsync(cancellationToken);
        var command = connection.CreateCommand();
        command.CommandText = Schema;
        await command.ExecuteNonQueryAsync(cancellationToken);
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
            command.CommandText = "SELECT id,library_id,path,alias,enabled,artwork_path,artwork_checked,artwork_scan_version FROM sources ORDER BY sort_order,path COLLATE NOCASE";
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
                snapshot.Sources.Add(new SourceRecord(reader.GetString(0), reader.GetString(1), reader.GetString(2), reader.GetString(3), reader.GetBoolean(4), reader.GetString(5), reader.GetBoolean(6), reader.GetInt32(7)));
        }
        await using (var command = connection.CreateCommand())
        {
            command.CommandText = """
                SELECT path,name,folder,root,library,duration,channels,sample_rate,bit_depth,source_type,size,
                       description,keywords,catid,category,subcategory,artwork_path,workflow_status,marked,
                       preview_count,last_previewed,indexed,ready,used_count,last_used,root_id,library_id
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
        await ExecuteAsync(connection, "DELETE FROM libraries", cancellationToken);
        await ExecuteAsync(connection, "DELETE FROM sources", cancellationToken);
        await ExecuteAsync(connection, "DELETE FROM assets", cancellationToken);

        for (var i = 0; i < snapshot.Libraries.Count; i++)
            await UpsertLibraryAsync(connection, snapshot.Libraries[i], i, cancellationToken);
        for (var i = 0; i < snapshot.Sources.Count; i++)
            await UpsertSourceAsync(connection, snapshot.Sources[i], i, cancellationToken);
        foreach (var asset in snapshot.Assets) await UpsertAssetAsync(connection, asset, cancellationToken);

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
        await transaction.CommitAsync(cancellationToken);
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
        var command = connection.CreateCommand(); command.CommandText = """
            INSERT OR REPLACE INTO sources(id,library_id,path,alias,enabled,artwork_path,artwork_checked,artwork_scan_version,sort_order)
            VALUES($id,$library,$path,$alias,$enabled,$art,$checked,$version,$order)
            """;
        command.Parameters.AddWithValue("$id", row.Id); command.Parameters.AddWithValue("$library", row.LibraryId); command.Parameters.AddWithValue("$path", row.Path);
        command.Parameters.AddWithValue("$alias", row.Alias); command.Parameters.AddWithValue("$enabled", row.Enabled); command.Parameters.AddWithValue("$art", row.ArtworkPath);
        command.Parameters.AddWithValue("$checked", row.ArtworkChecked); command.Parameters.AddWithValue("$version", row.ArtworkScanVersion); command.Parameters.AddWithValue("$order", order);
        await command.ExecuteNonQueryAsync(token);
    }

    private static async Task UpsertAssetAsync(SqliteConnection connection, AssetRecord row, CancellationToken token)
    {
        var command = connection.CreateCommand(); command.CommandText = """
            INSERT INTO assets(path,name,folder,root,library,duration,channels,sample_rate,bit_depth,source_type,size,description,keywords,catid,category,subcategory,artwork_path,workflow_status,marked,preview_count,last_previewed,indexed,ready,used_count,last_used,root_id,library_id)
            VALUES($path,$name,$folder,$root,$library,$duration,$channels,$rate,$depth,$type,$size,$description,$keywords,$catid,$category,$subcategory,$artwork,$status,$marked,$preview_count,$last_previewed,$indexed,$ready,$used_count,$last_used,$root_id,$library_id)
            ON CONFLICT(path) DO UPDATE SET name=excluded.name,folder=excluded.folder,root=excluded.root,library=excluded.library,duration=excluded.duration,channels=excluded.channels,sample_rate=excluded.sample_rate,bit_depth=excluded.bit_depth,source_type=excluded.source_type,size=excluded.size,description=CASE WHEN excluded.description='' THEN assets.description ELSE excluded.description END,keywords=CASE WHEN excluded.keywords='' THEN assets.keywords ELSE excluded.keywords END,catid=CASE WHEN excluded.catid='' THEN assets.catid ELSE excluded.catid END,category=CASE WHEN excluded.category='' THEN assets.category ELSE excluded.category END,subcategory=CASE WHEN excluded.subcategory='' THEN assets.subcategory ELSE excluded.subcategory END,artwork_path=CASE WHEN excluded.artwork_path='' THEN assets.artwork_path ELSE excluded.artwork_path END,workflow_status=excluded.workflow_status,marked=excluded.marked,preview_count=MAX(assets.preview_count,excluded.preview_count),last_previewed=MAX(assets.last_previewed,excluded.last_previewed),indexed=excluded.indexed,ready=excluded.ready,used_count=MAX(assets.used_count,excluded.used_count),last_used=MAX(assets.last_used,excluded.last_used),root_id=excluded.root_id,library_id=excluded.library_id
            """;
        void Add(string name, object? value) => command.Parameters.AddWithValue(name, value ?? DBNull.Value);
        Add("$path", row.Path); Add("$name", row.Name); Add("$folder", row.Folder); Add("$root", row.Root); Add("$library", row.Library);
        Add("$duration", row.Duration); Add("$channels", row.Channels); Add("$rate", row.SampleRate); Add("$depth", row.BitDepth); Add("$type", row.SourceType); Add("$size", row.Size);
        Add("$description", row.Description); Add("$keywords", row.Keywords); Add("$catid", row.CatId); Add("$category", row.Category); Add("$subcategory", row.Subcategory); Add("$artwork", row.ArtworkPath);
        Add("$status", row.WorkflowStatus); Add("$marked", row.Marked); Add("$preview_count", row.PreviewCount); Add("$last_previewed", row.LastPreviewed); Add("$indexed", row.Indexed); Add("$ready", row.Ready);
        Add("$used_count", row.UsedCount); Add("$last_used", row.LastUsed); Add("$root_id", row.RootId); Add("$library_id", row.LibraryId);
        await command.ExecuteNonQueryAsync(token);
    }

    private static AssetRecord ReadAsset(SqliteDataReader r) => new()
    {
        Path = r.GetString(0), Name = r.GetString(1), Folder = r.GetString(2), Root = r.GetString(3), Library = r.GetString(4), Duration = r.GetDouble(5),
        Channels = r.GetInt32(6), SampleRate = r.GetInt32(7), BitDepth = r.GetInt32(8), SourceType = r.GetString(9), Size = r.GetInt64(10),
        Description = r.GetString(11), Keywords = r.GetString(12), CatId = r.GetString(13), Category = r.GetString(14), Subcategory = r.GetString(15), ArtworkPath = r.GetString(16),
        WorkflowStatus = r.GetString(17), Marked = r.GetBoolean(18), PreviewCount = r.GetInt32(19), LastPreviewed = r.GetDouble(20), Indexed = r.GetBoolean(21), Ready = r.GetBoolean(22),
        UsedCount = r.GetInt32(23), LastUsed = r.GetDouble(24), RootId = r.GetString(25), LibraryId = r.GetString(26)
    };

    private static async Task ExecuteAsync(SqliteConnection connection, string sql, CancellationToken token)
    {
        var command = connection.CreateCommand(); command.CommandText = sql; await command.ExecuteNonQueryAsync(token);
    }

    private const string Schema = """
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
