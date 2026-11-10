$ErrorActionPreference = 'Stop'
# Only creates hidden, disposable windows in this test process. No REAPER or
# existing desktop window is enumerated, activated, or modified.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class PsyReaSFXWindowContract {
  [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  static extern IntPtr CreateWindowExW(uint ex, string cls, string title, uint style,
    int x, int y, int width, int height, IntPtr parent, IntPtr menu, IntPtr instance, IntPtr param);
  [DllImport("user32.dll")] static extern IntPtr GetParent(IntPtr window);
  [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr window, uint relation);
  [DllImport("user32.dll")] static extern IntPtr GetWindowLongPtrW(IntPtr window, int index);
  [DllImport("user32.dll")] static extern IntPtr SetWindowLongPtrW(IntPtr window, int index, IntPtr value);
  [DllImport("user32.dll")] static extern bool DestroyWindow(IntPtr window);
  public static void Run() {
    const uint overlapped = 0x00CF0000;
    IntPtr owner = IntPtr.Zero, window = IntPtr.Zero;
    try {
      owner = CreateWindowExW(0, "STATIC", "PRS test owner", overlapped, 0, 0, 100, 100, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero);
      window = CreateWindowExW(0, "STATIC", "PRS test owned window", overlapped, 0, 0, 100, 100, owner, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero);
      if (owner == IntPtr.Zero || window == IntPtr.Zero) throw new Exception("Hidden window creation failed");
      if (GetParent(window) != IntPtr.Zero) throw new Exception("Unexpected GetParent contract");
      if (GetWindow(window, 4) != owner) throw new Exception("GW_OWNER must find an owned overlapped window");
      long extended = GetWindowLongPtrW(window, -20).ToInt64();
      SetWindowLongPtrW(window, -20, new IntPtr((extended | 0x40000L) & ~0x80L));
      if ((GetWindowLongPtrW(window, -20).ToInt64() & 0x40000L) == 0) throw new Exception("APPWINDOW did not persist");
      if (GetWindow(window, 4) != owner) throw new Exception("Taskbar policy must preserve ownership");
    } finally {
      if (window != IntPtr.Zero) DestroyWindow(window);
      if (owner != IntPtr.Zero) DestroyWindow(owner);
    }
  }
}
'@
[PsyReaSFXWindowContract]::Run()
Write-Output 'Windows owned-overlapped contract verified: GetParent=NULL, GW_OWNER=owner, APPWINDOW retained without changing ownership.'
