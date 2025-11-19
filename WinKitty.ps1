# --- WinKitty.ps1 (V2 user-space) ---
# WinKitty Project: auto-lock when the laptop lid is closed
# - User-space only (no admin required, no service, no registry machine-wide)
# - Installs a small C# agent into %LOCALAPPDATA%\WinKitty
# - Adds a shortcut to the user's Startup folder for persistence

$projectName = "WinKitty"
$agentName   = "WinKittyAgent.exe"

# Installation directory in user profile (no admin rights needed)
$installDir  = Join-Path $env:LOCALAPPDATA $projectName
$agentExe    = Join-Path $installDir $agentName

# Startup folder for the current user
$startupDir      = [Environment]::GetFolderPath("Startup")
$shortcutPath    = Join-Path $startupDir "WinKittyAgent.lnk"
$oldTaskName     = "WinKittyAgent"  # for cleanup of the old version if needed

Write-Host "=== WinKitty (Agent only, user-space) ==="
Write-Host "1 - Install / enable the agent"
Write-Host "2 - Uninstall / remove the agent"
$choice = Read-Host "Enter 1 or 2"

switch ($choice) {
    1 {
        # Optional cleanup: try to remove old scheduled task from previous version
        try {
            if (Get-ScheduledTask -TaskName $oldTaskName -ErrorAction SilentlyContinue) {
                Unregister-ScheduledTask -TaskName $oldTaskName -Confirm:$false -ErrorAction SilentlyContinue
            }
        } catch {
            # Ignorer les erreurs (si pas de droits ou tâche inexistante)
        }

        # Create installation directory (user-space)
        if (-not (Test-Path $installDir)) {
            New-Item -ItemType Directory -Path $installDir | Out-Null
        }

# =========================
#  C# AGENT (user session)
# =========================
       $agentCs = @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace WinKitty
{
    static class Program
    {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool LockWorkStation();

        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr RegisterPowerSettingNotification(IntPtr hRecipient, ref Guid PowerSettingGuid, int Flags);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool UnregisterPowerSettingNotification(IntPtr Handle);

        private static Guid GUID_LIDSWITCH_STATE_CHANGE = new Guid("BA3E0F4D-B817-4094-A2D1-D56379E6A0F3");

        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new HiddenApplicationContext());
        }

        private class HiddenApplicationContext : ApplicationContext
        {
            private MessageWindow _window;
            private IntPtr _hNotify = IntPtr.Zero;

            public HiddenApplicationContext()
            {
                _window = new MessageWindow(this);
                _hNotify = RegisterPowerSettingNotification(_window.Handle, ref GUID_LIDSWITCH_STATE_CHANGE, 0);
            }

            protected override void Dispose(bool disposing)
            {
                if (disposing)
                {
                    if (_hNotify != IntPtr.Zero)
                    {
                        UnregisterPowerSettingNotification(_hNotify);
                        _hNotify = IntPtr.Zero;
                    }

                    if (_window != null)
                    {
                        _window.DestroyHandle();
                        _window = null;
                    }
                }
                base.Dispose(disposing);
            }
        }

        private class MessageWindow : NativeWindow
        {
            private const int WM_POWERBROADCAST      = 0x0218;
            private const int PBT_POWERSETTINGCHANGE = 0x8013;

            private HiddenApplicationContext _ctx;

            // Nouveaux champs pour gérer l'état
            private bool _initialized = false;
            private bool _lidClosed   = false;

            public MessageWindow(HiddenApplicationContext ctx)
            {
                _ctx = ctx;
                CreateHandle(new CreateParams());
            }

            [StructLayout(LayoutKind.Sequential, Pack = 4)]
            public struct POWERBROADCAST_SETTING
            {
                public Guid PowerSetting;
                public int DataLength;
                public byte Data;
            }

            protected override void WndProc(ref Message m)
            {
                if (m.Msg == WM_POWERBROADCAST && m.WParam.ToInt32() == PBT_POWERSETTINGCHANGE)
                {
                    POWERBROADCAST_SETTING ps =
                        (POWERBROADCAST_SETTING)Marshal.PtrToStructure(
                            m.LParam, typeof(POWERBROADCAST_SETTING));

                    if (ps.PowerSetting == GUID_LIDSWITCH_STATE_CHANGE)
                    {
                        // Data = 1 -> lid fermé
                        // Data = 0 -> lid ouvert
                        bool nowClosed = (ps.Data == 1);

                        if (!_initialized)
                        {
                            // Premier event : on initialise juste l'état, sans locker
                            _lidClosed   = nowClosed;
                            _initialized = true;
                        }
                        else
                        {
                            // On lock uniquement si on passe de ouvert -> fermé
                            if (nowClosed && !_lidClosed)
                            {
                                LockWorkStation();
                            }

                            _lidClosed = nowClosed;
                        }
                    }
                }

                base.WndProc(ref m);
            }
        }
    }
}
"@

        # Save .cs in TEMP
        $agentCsFile = Join-Path $env:TEMP "WinKittyAgent.cs"
        $agentCs | Out-File -FilePath $agentCsFile -Encoding UTF8

        # Locate csc.exe (user needs .NET Framework 4.x dev tools, usually present)
        $cscPath = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
        if (-not (Test-Path $cscPath)) {
            $cscPath = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe"
        }
        if (-not (Test-Path $cscPath)) {
            Write-Error "csc.exe not found. Install the .NET Framework 4.x Developer Pack."
            return
        }

        # Compile AGENT as WinExe (no console window)
        & $cscPath `
            /t:winexe `
            /out:$agentExe `
            /r:System.Windows.Forms.dll `
            $agentCsFile

        if (-not (Test-Path $agentExe)) {
            Write-Error "Agent compilation failed (no EXE generated)."
            return
        }

        # Create a shortcut in the user's Startup folder for persistence
        try {
            $shell    = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut($shortcutPath)
            $shortcut.TargetPath       = $agentExe
            $shortcut.WorkingDirectory = $installDir
            $shortcut.WindowStyle      = 7  # Minimized / hidden
            $shortcut.Description      = "WinKitty Agent - auto-lock on lid close"
            $shortcut.Save()
        } catch {
            Write-Warning "Failed to create Startup shortcut: $($_.Exception.Message)"
        }

        # Start agent immediately in current session
        Start-Process -FilePath $agentExe | Out-Null

        Write-Host "WinKitty installation completed (user-space agent)."
        Write-Host "Agent path : $agentExe"
        Write-Host "Startup    : $shortcutPath"
        Write-Host "Your session will lock automatically whenever the lid is closed (for this user)."
    }

    2 {
        # Try to kill running agent process
        Get-Process WinKittyAgent -ErrorAction SilentlyContinue | ForEach-Object {
            try { $_.Kill() } catch {}
        }

        # Remove Startup shortcut
        if (Test-Path $shortcutPath) {
            Remove-Item $shortcutPath -Force -ErrorAction SilentlyContinue
        }

        # Remove installation directory
        if (Test-Path $installDir) {
            Remove-Item $installDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        # Optional cleanup of legacy scheduled task
        try {
            if (Get-ScheduledTask -TaskName $oldTaskName -ErrorAction SilentlyContinue) {
                Unregister-ScheduledTask -TaskName $oldTaskName -Confirm:$false -ErrorAction SilentlyContinue
            }
        } catch {
            # Ignorer si pas de droits
        }

        Write-Host "WinKitty has been uninstalled (agent + shortcut + files removed)."
    }

    Default {
        Write-Host "Invalid option. Restart and choose 1 or 2."
    }
}
