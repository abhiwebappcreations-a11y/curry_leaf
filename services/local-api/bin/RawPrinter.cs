using System;
using System.IO;
using System.Runtime.InteropServices;

public class RawPrinter {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public class DOCINFOA {
        [MarshalAs(UnmanagedType.LPStr)] public string pDocName;
        [MarshalAs(UnmanagedType.LPStr)] public string pOutputFile;
        [MarshalAs(UnmanagedType.LPStr)] public string pDataType;
    }

    [DllImport("winspool.drv", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern bool OpenPrinter(string pPrinterName, out IntPtr phPrinter, IntPtr pDefault);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool ClosePrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool StartDocPrinter(IntPtr hPrinter, int level, [In, MarshalAs(UnmanagedType.LPStruct)] DOCINFOA di);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool EndDocPrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool StartPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool EndPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool WritePrinter(IntPtr hPrinter, IntPtr pBytes, int dwCount, out int dwWritten);

    public static int Main(string[] args) {
        if (args.Length < 2) {
            Console.WriteLine("Usage: RawPrinter.exe <printer_name> <binary_file_path>");
            return 1;
        }

        string printerName = args[0];
        string filePath = args[1];

        if (!File.Exists(filePath)) {
            Console.WriteLine("File not found: " + filePath);
            return 2;
        }

        byte[] bytes = File.ReadAllBytes(filePath);

        IntPtr hPrinter = IntPtr.Zero;
        if (!OpenPrinter(printerName, out hPrinter, IntPtr.Zero)) {
            int err = Marshal.GetLastWin32Error();
            Console.WriteLine("OpenPrinter failed for '" + printerName + "' with error code: " + err);
            return 3;
        }

        try {
            DOCINFOA di = new DOCINFOA();
            di.pDocName = "Hinopt POS Print Job";
            di.pDataType = "RAW";

            if (!StartDocPrinter(hPrinter, 1, di)) {
                int err = Marshal.GetLastWin32Error();
                Console.WriteLine("StartDocPrinter failed with error: " + err);
                return 4;
            }

            try {
                if (!StartPagePrinter(hPrinter)) {
                    int err = Marshal.GetLastWin32Error();
                    Console.WriteLine("StartPagePrinter failed with error: " + err);
                    return 5;
                }

                try {
                    IntPtr pBytes = Marshal.AllocHGlobal(bytes.Length);
                    try {
                        Marshal.Copy(bytes, 0, pBytes, bytes.Length);
                        int written = 0;
                        if (!WritePrinter(hPrinter, pBytes, bytes.Length, out written)) {
                            int err = Marshal.GetLastWin32Error();
                            Console.WriteLine("WritePrinter failed with error: " + err);
                            return 6;
                        }
                        Console.WriteLine("Successfully sent " + written + " bytes to " + printerName);
                    } finally {
                        Marshal.FreeHGlobal(pBytes);
                    }
                } finally {
                    EndPagePrinter(hPrinter);
                }
            } finally {
                EndDocPrinter(hPrinter);
            }
        } finally {
            ClosePrinter(hPrinter);
        }

        return 0;
    }
}
