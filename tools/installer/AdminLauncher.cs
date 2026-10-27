using System;
using System.Diagnostics;
using System.IO;
using System.Net.Sockets;
using System.Threading;
using System.Windows.Forms;

namespace HinoptAdminLauncher
{
    static class Program
    {
        private static bool IsPortOpen(string host, int port)
        {
            try
            {
                using (TcpClient client = new TcpClient())
                {
                    IAsyncResult result = client.BeginConnect(host, port, null, null);
                    bool success = result.AsyncWaitHandle.WaitOne(800);
                    if (!success) return false;
                    client.EndConnect(result);
                    return true;
                }
            }
            catch
            {
                return false;
            }
        }

        private static bool LaunchAppWindow(string url)
        {
            string[] candidateBrowsers = new string[]
            {
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Microsoft", "Edge", "Application", "msedge.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Microsoft", "Edge", "Application", "msedge.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Google", "Chrome", "Application", "chrome.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Google", "Chrome", "Application", "chrome.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Google", "Chrome", "Application", "chrome.exe")
            };

            foreach (string exe in candidateBrowsers)
            {
                if (File.Exists(exe))
                {
                    try
                    {
                        ProcessStartInfo psi = new ProcessStartInfo();
                        psi.FileName = exe;
                        psi.Arguments = string.Format("--app=\"{0}\" --window-size=1366,860", url);
                        psi.UseShellExecute = false;
                        Process.Start(psi);
                        return true;
                    }
                    catch
                    {
                        // Try next candidate
                    }
                }
            }

            return false;
        }

        [STAThread]
        static void Main()
        {
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            string nodeExe = Path.Combine(baseDir, "node.exe");
            string serverScript = Path.Combine(baseDir, "apps", "hinopt_admin", "server.js");

            if (!File.Exists(serverScript))
            {
                MessageBox.Show("Could not find Hinopt Admin server script:\n" + serverScript, "Hinopt Admin Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            // Check if server is already running on port 5000
            bool alreadyRunning = IsPortOpen("127.0.0.1", 5000);

            if (!alreadyRunning && File.Exists(nodeExe))
            {
                try
                {
                    ProcessStartInfo startInfo = new ProcessStartInfo();
                    startInfo.FileName = nodeExe;
                    startInfo.Arguments = "\"" + serverScript + "\"";
                    startInfo.WorkingDirectory = Path.GetDirectoryName(serverScript);
                    startInfo.CreateNoWindow = true;
                    startInfo.UseShellExecute = false;
                    Process.Start(startInfo);

                    // Wait up to 3 seconds for port 5000 to bind
                    for (int i = 0; i < 15; i++)
                    {
                        Thread.Sleep(200);
                        if (IsPortOpen("127.0.0.1", 5000)) break;
                    }
                }
                catch (Exception ex)
                {
                    MessageBox.Show("Failed to launch background server:\n" + ex.Message, "Hinopt Admin Notice", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                }
            }

            // Launch as dedicated standalone desktop app window
            if (!LaunchAppWindow("http://localhost:5000"))
            {
                try
                {
                    Process.Start(new ProcessStartInfo("http://localhost:5000") { UseShellExecute = true });
                }
                catch
                {
                    Process.Start("explorer.exe", "http://localhost:5000");
                }
            }
        }
    }
}
