# --- WinKitty.ps1 ---
# WinKitty Project: auto-lock when the laptop lid is closed
# Agent-only version: no service, only a user-level agent
# - Windows Agent: WinKittyAgent (scheduled task ONLOGON, hidden process)

# Check for admin rights
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Please run this script as Administrator."
    return
}

$projectName      = "WinKitty"
$taskName         = "WinKittyAgent"
$installDir       = Join-Path $env:ProgramFiles $projectName
$agentExe         = Join-Path $installDir "WinKittyAgent.exe"

# Fancy ASCII logo (Hello Kitty style)
$logo = @'
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠿⣿⣿⣿⣿⣿⠟⠋⠉⠀⠈⠛⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠋⠀⢀⠀⡀⠉⠻⠋⠀⣠⣴⣾⣿⣷⡀⠘⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠿⠿⠟⠁⠀⡌⢂⠱⢠⠁⠄⠐⣿⣿⣿⣿⣿⣿⣷⠀⠸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⡟⠉⠀⢀⡀⠀⠉⠉⠙⠛⠟⠛⠉⠁⠀⣀⣀⣠⡄⢀⠘⡠⠌⠀⠁⠈⠀⠀⢀⠈⠉⠻⠛⠉⠀⡀⢀⠀⠙⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⠁⢠⣿⣿⣿⣿⣿⣷⣶⣤⣤⣴⣾⣿⣿⣿⣿⣿⠀⢀⠊⠔⡀⠀⡘⠀⠠⢌⠠⠘⠤⠀⠀⠀⠃⡰⠁⡌⠀⢹⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⡇⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡀⠠⠉⡔⠠⠄⠀⠀⠐⡌⠤⢉⠤⠁⠀⠠⠀⢀⠱⠐⠀⣸⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣧⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣇⠀⠃⢀⠃⠜⠀⠀⠀⠠⠀⠜⠀⠀⠀⠀⠀⡀⠇⠄⢀⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⡀⠘⠟⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣦⣤⣤⣴⣶⣿⣿⣦⣤⣤⣶⡀⠁⠌⡒⠐⠈⠀⠘⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣷⠀⢀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣤⣤⣤⣶⣿⡄⠘⣿⣿⣿⣿⣿
⣿⣿⣿⣿⡟⠀⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠟⠃⠀⢈⣉⣀⣤⣬
⣿⣿⣿⣿⠃⢠⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⣿⣿⣿⣿⣿⣦⣶⣶⠀⢸⣿⣿⣿⣿
⣿⣿⣿⣿⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡅⠀⠀⢹⣿⣿⣿⣿⡟⠛⠀⠈⠛⠙⠛⢻
⣿⣿⣿⣿⡀⠘⣿⡿⢿⣿⣿⣿⣿⡟⠋⠛⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⡀⢀⣾⣿⣿⣿⣿⣿⡾⠀⢸⣿⣿⣿⣿
⡟⠋⠉⢁⡀⠀⢠⣤⣤⣿⣿⣿⣿⠀⠀⠀⣹⣿⣿⣿⣿⣿⣿⡟⠋⠉⠉⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠛⠃⠀⠿⢿⣿⣿⣿
⣷⣾⣿⣿⣿⡄⠘⢿⡿⢿⣿⣿⣿⣷⣶⣶⣿⣿⣿⣿⣿⣿⣿⡄⠘⠑⠃⣀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠃⢀⣴⣦⣤⢀⣈⣿
⣿⣿⣿⡿⠛⠉⡀⠀⢴⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠉⡀⠀⠛⠿⢿⣿⣿⣿⣿
⣿⣿⣿⣦⣴⣿⣿⣦⡀⠙⠋⢁⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠟⠋⠁⢀⣾⣿⣷⣶⣦⡀⠙⣿⣿⣿
⣿⣿⣿⣿⣿⣿⡿⠋⢀⣤⣀⠀⠉⠛⠻⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠿⠿⠛⠛⠋⠁⢀⣀⣤⣶⡀⠘⣿⣿⣿⣿⣿⣷⠀⢸⣿⣿
⣿⣿⣿⣿⣿⣏⣠⣴⣿⣿⣿⡿⠓⠂⠀⠀⠀⠀⠀⠀⠁⢁⡀⣀⣀⣀⣠⣤⣤⠀⢀⡐⡀⠀⠻⣿⣿⣷⡄⠈⢻⣿⣿⣿⠇⠀⣾⣿⣿
⣿⣿⣿⣿⣿⣿⣿⠿⠛⠛⠁⠠⣴⣾⠟⠀⠀⢆⢂⠀⠸⣿⣿⣿⣿⣿⣿⣿⠇⠀⠄⡂⢅⠠⠀⠹⣿⣿⣿⣄⠀⠻⠟⠁⣠⣾⣿⣿⣿
⣿⣿⣿⣿⣿⡟⠁⣠⣶⣶⣧⡀⠈⠏⠀⠀⠃⠈⠠⠁⠄⠈⠛⠛⠿⠛⠛⠁⠀⡰⠈⠐⠈⠒⠀⠀⠘⠟⠛⠉⢀⣠⣴⣾⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⡷⠀⣸⣿⣿⣿⠟⠀⣀⣤⣶⣶⣶⣤⡀⠈⢂⠰⠀⠤⠐⡀⠆⠅⠀⣀⣤⣶⣶⣶⣦⣄⠀⠰⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⡇⠀⣿⣿⣿⠁⢠⣾⣿⣿⣿⣿⣿⣿⣿⣦⠀⠐⠉⡄⠃⡌⠀⠀⣼⣿⣿⣿⣿⣿⣿⣿⣷⡄⠈⢻⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⡄⠈⠻⠇⢀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⡆⠀⠡⠌⢂⠅⠀⣸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡄⠘⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣷⣤⠀⣸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⠀⠈⡄⠣⡀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⠀⢻⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⡐⠄⡃⠄⠀⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠀⣸⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⡀⠸⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠀⢀⠰⢁⠒⣈⠀⠘⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⢀⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⡀⠘⢿⣿⣿⣿⣿⣿⣿⠟⠀⠀⠈⠀⠀⠀⠀⠁⠀⠀⠻⢿⣿⣿⣿⣿⣿⠟⠁⢀⣾⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⡀⠉⠛⠛⠛⠉⢀⣠⣴⣶⣾⣿⣿⣿⣿⣶⣶⣦⣄⣀⠈⠉⠛⠉⢁⣠⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣶⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
'@

Write-Host $logo
Write-Host "=== WinKitty Project (Agent only) ==="
Write-Host "1 - Install / enable the agent"
Write-Host "2 - Uninstall / remove the agent"
$choice = Read-Host "Enter 1 or 2"

switch ($choice) {
    1 {
        # Create installation directory
        if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir | Out-Null }

        # Remove existing scheduled task if present
        if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
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
                        // On most laptops:
                        // Data = 1 -> lid closed
                        // Data = 0 -> lid open
                        if (ps.Data == 1)
                        {
                            LockWorkStation();
                        }
                    }
                }

                base.WndProc(ref m);
            }
        }
    }
}
"@

        # Save .cs
        $agentCsFile = Join-Path $env:TEMP "WinKittyAgent.cs"
        $agentCs | Out-File -FilePath $agentCsFile -Encoding UTF8

        # Locate csc.exe
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

        # Create scheduled task ONLOGON
        $escapedAgentExe = $agentExe.Replace('"','\"')
        schtasks.exe /Create `
            /TN "$taskName" `
            /TR "`"$escapedAgentExe`"" `
            /SC ONLOGON `
            /RL HIGHEST `
            /F | Out-Null

        # Start agent immediately
        Start-Process -FilePath $agentExe

        Write-Host "WinKitty installation completed (agent-only mode)."
        Write-Host "Agent: scheduled task $taskName + running in current session."
        Write-Host "Your session will lock automatically whenever the lid is closed."
    }

    2 {
        # Uninstall agent
        if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        }

        # Kill running agent process
        Get-Process WinKittyAgent -ErrorAction SilentlyContinue | ForEach-Object {
            try { $_.Kill() } catch {}
        }

        # Remove installation directory
        if (Test-Path $installDir) {
            Remove-Item $installDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        Write-Host "WinKitty has been uninstalled (agent + files removed)."
    }

    Default {
        Write-Host "Invalid option. Restart and choose 1 or 2."
    }
}
