namespace PsyReaSFX.Desktop.Services;

public readonly record struct WindowPanelState(
    bool NavigationVisible,
    bool InspectorVisible,
    bool FocusMode,
    double NavigationWidth,
    double InspectorWidth);

/// <summary>
/// Owns panel visibility and remembered widths without touching WPF controls.
/// The window only renders the returned state.
/// </summary>
public sealed class WindowStateController
{
    public WindowPanelState State { get; private set; } = new(true, true, false, 240, 292);

    public WindowPanelState SetNavigation(bool visible, double currentWidth = 0)
    {
        var width = State.NavigationVisible && currentWidth > 0 ? currentWidth : State.NavigationWidth;
        State = State with { NavigationVisible = visible, NavigationWidth = width };
        return State;
    }

    public WindowPanelState SetInspector(bool visible, double currentWidth = 0)
    {
        var width = State.InspectorVisible && currentWidth > 0 ? currentWidth : State.InspectorWidth;
        State = State with { InspectorVisible = visible, InspectorWidth = width };
        return State;
    }

    public WindowPanelState SetFocusMode(bool enabled, double navigationWidth = 0, double inspectorWidth = 0)
    {
        var nav = State.NavigationVisible && navigationWidth > 0 ? navigationWidth : State.NavigationWidth;
        var inspector = State.InspectorVisible && inspectorWidth > 0 ? inspectorWidth : State.InspectorWidth;
        State = State with
        {
            FocusMode = enabled,
            NavigationVisible = !enabled,
            InspectorVisible = !enabled,
            NavigationWidth = nav,
            InspectorWidth = inspector
        };
        return State;
    }
}
