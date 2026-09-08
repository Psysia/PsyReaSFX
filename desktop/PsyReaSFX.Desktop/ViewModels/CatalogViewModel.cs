using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Windows.Data;

namespace PsyReaSFX.Desktop.ViewModels;

/// <summary>
/// Owns the replaceable catalog collection and its stable WPF view. Filtering
/// and sorting remain caller-provided policies so migration does not change
/// visible behavior.
/// </summary>
public sealed class CatalogViewModel
{
    private Predicate<object>? _filter;

    public ObservableCollection<AudioAsset> Assets { get; private set; } = [];
    public ICollectionView View { get; private set; }

    public CatalogViewModel()
    {
        View = CollectionViewSource.GetDefaultView(Assets);
    }

    public void SetFilter(Predicate<object> filter)
    {
        _filter = filter;
        View.Filter = filter;
    }

    public void Replace(IEnumerable<AudioAsset> assets) =>
        Replace(new ObservableCollection<AudioAsset>(assets));

    public void Replace(ObservableCollection<AudioAsset> assets)
    {
        Assets = assets;
        View = CollectionViewSource.GetDefaultView(Assets);
        View.Filter = _filter;
    }

    public void ApplySort(string propertyName, ListSortDirection direction)
    {
        using var refresh = View.DeferRefresh();
        View.SortDescriptions.Clear();
        View.SortDescriptions.Add(new SortDescription(propertyName, direction));
    }

    public int RefreshAndCount()
    {
        View.Refresh();
        return View.Cast<object>().Count();
    }
}
