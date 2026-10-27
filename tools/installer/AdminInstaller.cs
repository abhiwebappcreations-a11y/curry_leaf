using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Threading;
using System.Windows.Forms;

namespace HinoptAdminInstaller
{
    public class AdminInstallerForm : Form
    {
        private ProgressBar progressBar;
        private Label lblStatus;
        private Label lblTitle;
        private Label lblSubtitle;
        private Button btnInstall;
        private BackgroundWorker worker;
        private string installDir;
        private bool isUpdateMode;

        public AdminInstallerForm()
        {
            this.Text = "Hinopt Admin Console - Setup & Update Wizard";
            this.Size = new Size(540, 340);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;
            this.BackColor = Color.FromArgb(248, 250, 252);
            this.Font = new Font("Segoe UI", 9.5f, FontStyle.Regular);

            string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            installDir = Path.Combine(localAppData, "Programs", "HinoptAdmin");

            isUpdateMode = Directory.Exists(installDir) && File.Exists(Path.Combine(installDir, "Hinopt_Admin.exe"));

            // Header Banner Panel
            Panel headerPanel = new Panel();
            headerPanel.Dock = DockStyle.Top;
            headerPanel.Height = 85;
            headerPanel.BackColor = Color.FromArgb(30, 41, 59); // Slate 800

            lblTitle = new Label();
            lblTitle.Text = isUpdateMode ? "Hinopt Cloud Admin Console - Update" : "Hinopt Cloud Admin Console";
            lblTitle.Font = new Font("Segoe UI", 14f, FontStyle.Bold);
            lblTitle.ForeColor = Color.White;
            lblTitle.Location = new Point(24, 18);
            lblTitle.AutoSize = true;

            lblSubtitle = new Label();
            lblSubtitle.Text = isUpdateMode
                ? "Seamless Software Update • Existing Cloud Configurations Preserved"
                : "Restaurant Management, Cryptographic Licensing & Cloud Ledger Setup";
            lblSubtitle.Font = new Font("Segoe UI", 9.5f, FontStyle.Regular);
            lblSubtitle.ForeColor = Color.FromArgb(148, 163, 184); // Slate 400
            lblSubtitle.Location = new Point(25, 48);
            lblSubtitle.AutoSize = true;

            headerPanel.Controls.Add(lblTitle);
            headerPanel.Controls.Add(lblSubtitle);

            // Body Controls
            Label lblInfo = new Label();
            lblInfo.Text = isUpdateMode
                ? "An existing Hinopt Admin installation was detected.\nClick 'Update Now' to update the admin console to the latest build."
                : "Click 'Install Now' to install the standalone Hinopt Admin Console.\nStandalone desktop app window • Live Supabase Cloud Sync • One-click launch.";
            lblInfo.Location = new Point(24, 105);
            lblInfo.Size = new Size(480, 42);
            lblInfo.ForeColor = Color.FromArgb(51, 65, 85);

            Label lblPath = new Label();
            lblPath.Text = "Installation Path: " + installDir;
            lblPath.Location = new Point(24, 155);
            lblPath.Size = new Size(480, 20);
            lblPath.Font = new Font("Segoe UI", 8.5f, FontStyle.Italic);
            lblPath.ForeColor = Color.FromArgb(100, 116, 139);

            progressBar = new ProgressBar();
            progressBar.Location = new Point(24, 185);
            progressBar.Size = new Size(475, 24);
            progressBar.Style = ProgressBarStyle.Continuous;
            progressBar.Value = 0;

            lblStatus = new Label();
            lblStatus.Text = isUpdateMode ? "Ready to update existing Hinopt Admin." : "Ready to install.";
            lblStatus.Location = new Point(24, 218);
            lblStatus.Size = new Size(350, 24);
            lblStatus.ForeColor = Color.FromArgb(71, 85, 105);

            btnInstall = new Button();
            btnInstall.Text = isUpdateMode ? "Update Now" : "Install Now";
            btnInstall.Location = new Point(379, 245);
            btnInstall.Size = new Size(120, 36);
            btnInstall.BackColor = Color.FromArgb(37, 99, 235); // Blue 600
            btnInstall.ForeColor = Color.White;
            btnInstall.FlatStyle = FlatStyle.Flat;
            btnInstall.FlatAppearance.BorderSize = 0;
            btnInstall.Font = new Font("Segoe UI", 10f, FontStyle.Bold);
            btnInstall.Cursor = Cursors.Hand;
            btnInstall.Click += BtnInstall_Click;

            this.Controls.Add(headerPanel);
            this.Controls.Add(lblInfo);
            this.Controls.Add(lblPath);
            this.Controls.Add(progressBar);
            this.Controls.Add(lblStatus);
            this.Controls.Add(btnInstall);

            worker = new BackgroundWorker();
            worker.WorkerReportsProgress = true;
            worker.DoWork += Worker_DoWork;
            worker.ProgressChanged += Worker_ProgressChanged;
            worker.RunWorkerCompleted += Worker_RunWorkerCompleted;
        }

        private void BtnInstall_Click(object sender, EventArgs e)
        {
            btnInstall.Enabled = false;
            btnInstall.Text = isUpdateMode ? "Updating..." : "Installing...";
            worker.RunWorkerAsync();
        }

        private void Worker_DoWork(object sender, DoWorkEventArgs e)
        {
            worker.ReportProgress(5, "Checking for running Admin instances...");

            // Terminate running Admin processes from target folder
            foreach (string pName in new string[] { "Hinopt_Admin", "node" })
            {
                try
                {
                    foreach (Process p in Process.GetProcessesByName(pName))
                    {
                        try
                        {
                            string pPath = p.MainModule != null ? p.MainModule.FileName : "";
                            if (!string.IsNullOrEmpty(pPath) && pPath.StartsWith(installDir, StringComparison.OrdinalIgnoreCase))
                            {
                                p.Kill();
                                p.WaitForExit(1500);
                            }
                        }
                        catch { }
                    }
                }
                catch { }
            }

            worker.ReportProgress(15, "Extracting Hinopt Admin files...");

            if (!Directory.Exists(installDir))
            {
                Directory.CreateDirectory(installDir);
            }

            Assembly asm = Assembly.GetExecutingAssembly();
            string tempZipPath = Path.Combine(Path.GetTempPath(), "hinopt_admin_pkg_" + Guid.NewGuid().ToString("N") + ".zip");

            using (Stream resourceStream = asm.GetManifestResourceStream("admin_payload.zip"))
            {
                if (resourceStream == null)
                {
                    throw new Exception("Embedded package 'admin_payload.zip' not found in installer binary.");
                }

                using (FileStream fs = new FileStream(tempZipPath, FileMode.Create, FileAccess.Write))
                {
                    byte[] buffer = new byte[65536];
                    int read;
                    long totalRead = 0;
                    long totalLength = resourceStream.Length;

                    while ((read = resourceStream.Read(buffer, 0, buffer.Length)) > 0)
                    {
                        fs.Write(buffer, 0, read);
                        totalRead += read;
                        int pct = 15 + (int)((totalRead * 55) / totalLength);
                        worker.ReportProgress(pct, "Extracting: " + (totalRead / (1024 * 1024)) + " MB...");
                    }
                }
            }

            worker.ReportProgress(75, "Deploying Hinopt Admin runtime and Supabase client...");
            using (ZipArchive archive = ZipFile.OpenRead(tempZipPath))
            {
                foreach (ZipArchiveEntry entry in archive.Entries)
                {
                    string destinationPath = Path.Combine(installDir, entry.FullName);
                    if (string.IsNullOrEmpty(entry.Name))
                    {
                        Directory.CreateDirectory(destinationPath);
                    }
                    else
                    {
                        Directory.CreateDirectory(Path.GetDirectoryName(destinationPath));
                        bool isData = entry.Name.Equals("google_drive_credentials.json", StringComparison.OrdinalIgnoreCase) ||
                                      entry.Name.Equals("upgrade_requests.json", StringComparison.OrdinalIgnoreCase) ||
                                      entry.Name.EndsWith(".env", StringComparison.OrdinalIgnoreCase) ||
                                      destinationPath.IndexOf("cloud_backups" + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase) >= 0;

                        if (isData && File.Exists(destinationPath))
                        {
                            continue;
                        }

                        entry.ExtractToFile(destinationPath, true);
                    }
                }
            }

            try { File.Delete(tempZipPath); } catch { }

            worker.ReportProgress(90, "Creating Windows desktop shortcut...");
            string launcherExe = Path.Combine(installDir, "Hinopt_Admin.exe");
            CreateDesktopShortcut(launcherExe, "Hinopt Admin Console");

            worker.ReportProgress(100, isUpdateMode ? "Update Complete! Opening Hinopt Admin..." : "Installation Complete! Opening Hinopt Admin...");
            Thread.Sleep(800);

            // Launch app
            if (File.Exists(launcherExe))
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = launcherExe,
                    WorkingDirectory = Path.GetDirectoryName(launcherExe)
                });
            }
        }

        private void Worker_ProgressChanged(object sender, ProgressChangedEventArgs e)
        {
            progressBar.Value = Math.Min(100, Math.Max(0, e.ProgressPercentage));
            lblStatus.Text = (string)e.UserState;
        }

        private void Worker_RunWorkerCompleted(object sender, RunWorkerCompletedEventArgs e)
        {
            if (e.Error != null)
            {
                MessageBox.Show("Operation failed:\n" + e.Error.Message, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                btnInstall.Enabled = true;
                btnInstall.Text = isUpdateMode ? "Retry Update" : "Retry Install";
            }
            else
            {
                this.Close();
            }
        }

        private void CreateDesktopShortcut(string targetExe, string shortcutName)
        {
            try
            {
                string desktopFolder = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
                string shortcutPath = Path.Combine(desktopFolder, shortcutName + ".lnk");

                Type shellType = Type.GetTypeFromProgID("WScript.Shell");
                if (shellType != null)
                {
                    dynamic shell = Activator.CreateInstance(shellType);
                    dynamic shortcut = shell.CreateShortcut(shortcutPath);
                    shortcut.TargetPath = targetExe;
                    shortcut.WorkingDirectory = Path.GetDirectoryName(targetExe);
                    shortcut.Description = "Hinopt Cloud Admin Console";
                    shortcut.Save();
                }
            }
            catch { }
        }

        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new AdminInstallerForm());
        }
    }
}
