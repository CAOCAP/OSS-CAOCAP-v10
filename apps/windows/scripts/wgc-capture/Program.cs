// Adapted from glasscap (MIT), https://github.com/bandersong/glasscap
// One-frame window or monitor capture via Windows.Graphics.Capture so WinUI 3
// / DirectComposition content is not the blank white GDI BitBlt/PrintWindow see.
// arg0 = HWND (decimal) or 0 for the primary monitor
// arg1 = output PNG path

using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using Windows.Graphics;
using Windows.Graphics.Capture;
using Windows.Graphics.DirectX;
using Windows.Graphics.DirectX.Direct3D11;
using Windows.Graphics.Imaging;
using Windows.Storage.Streams;
using WinRT;

namespace WgcCapture;

internal static class Program
{
    [DllImport("d3d11.dll")]
    static extern int D3D11CreateDevice(IntPtr a, int driverType, IntPtr s, uint flags,
        IntPtr fl, uint flc, uint sdk, out IntPtr dev, out int flOut, out IntPtr ctx);

    [DllImport("d3d11.dll")]
    static extern int CreateDirect3D11DeviceFromDXGIDevice(IntPtr dxgi, out IntPtr graphics);

    [DllImport("user32.dll")]
    static extern IntPtr MonitorFromWindow(IntPtr h, uint f);

    [DllImport("combase.dll")]
    static extern int RoGetActivationFactory(IntPtr activatableClassId, ref Guid iid, out IntPtr factory);

    [DllImport("combase.dll")]
    static extern int RoInitialize(int initType);

    [DllImport("combase.dll", CharSet = CharSet.Unicode)]
    static extern int WindowsCreateString(string src, int length, out IntPtr hstring);

    [DllImport("combase.dll")]
    static extern int WindowsDeleteString(IntPtr hstring);

    [ComImport, Guid("3628E81B-3CAC-4C60-B7F4-23CE0E0C3356"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IGraphicsCaptureItemInterop
    {
        [PreserveSig] int CreateForWindow(IntPtr window, ref Guid iid, out IntPtr result);
        [PreserveSig] int CreateForMonitor(IntPtr monitor, ref Guid iid, out IntPtr result);
    }

    static readonly Guid IID_IDXGIDevice = new("54ec77fa-1377-44e6-8c32-88fd5f44c84c");
    static readonly Guid IID_GraphicsCaptureItem = new("79c3f95b-31f7-4ec2-a464-632ef5d30760");
    static readonly Guid IID_IGraphicsCaptureItemInterop = new("3628E81B-3CAC-4C60-B7F4-23CE0E0C3356");

    [MTAThread]
    static int Main(string[] args)
    {
        if (args.Length < 2)
        {
            Console.Error.WriteLine("usage: wgc-capture <hwnd|0> <out.png>");
            return 2;
        }

        if (!long.TryParse(args[0], out long hwndVal))
        {
            Console.Error.WriteLine($"error: '{args[0]}' is not a valid window handle (decimal) or 0");
            return 2;
        }

        string outPath = args[1];
        RoInitialize(1); // RO_INIT_MULTITHREADED

        try
        {
            const uint BGRA = 0x20; // D3D11_CREATE_DEVICE_BGRA_SUPPORT
            int hr = D3D11CreateDevice(IntPtr.Zero, 1, IntPtr.Zero, BGRA, IntPtr.Zero, 0, 7, out IntPtr dev, out _, out _);
            if (hr != 0)
            {
                // WARP software rasterizer — GitHub-hosted runners often have no GPU.
                hr = D3D11CreateDevice(IntPtr.Zero, 5, IntPtr.Zero, BGRA, IntPtr.Zero, 0, 7, out dev, out _, out _);
            }
            if (hr != 0)
            {
                Console.Error.WriteLine($"D3D11CreateDevice 0x{hr:X8}");
                return 3;
            }

            Guid dxgiId = IID_IDXGIDevice;
            Marshal.QueryInterface(dev, ref dxgiId, out IntPtr dxgi);
            hr = CreateDirect3D11DeviceFromDXGIDevice(dxgi, out IntPtr insp);
            if (hr != 0)
            {
                Console.Error.WriteLine($"FromDXGIDevice 0x{hr:X8}");
                return 4;
            }

            var device = MarshalInterface<IDirect3DDevice>.FromAbi(insp);

            Guid interopIid = IID_IGraphicsCaptureItemInterop;
            const string className = "Windows.Graphics.Capture.GraphicsCaptureItem";
            WindowsCreateString(className, className.Length, out IntPtr hClass);
            hr = RoGetActivationFactory(hClass, ref interopIid, out IntPtr factoryPtr);
            WindowsDeleteString(hClass);
            if (hr != 0)
            {
                Console.Error.WriteLine($"RoGetActivationFactory 0x{hr:X8}");
                return 5;
            }

            var interop = (IGraphicsCaptureItemInterop)Marshal.GetObjectForIUnknown(factoryPtr);

            Guid itemIid = IID_GraphicsCaptureItem;
            IntPtr itemPtr;
            if (hwndVal == 0)
            {
                IntPtr mon = MonitorFromWindow(IntPtr.Zero, 1); // MONITOR_DEFAULTTOPRIMARY
                hr = interop.CreateForMonitor(mon, ref itemIid, out itemPtr);
            }
            else
            {
                hr = interop.CreateForWindow((IntPtr)hwndVal, ref itemIid, out itemPtr);
            }

            if (hr != 0 || itemPtr == IntPtr.Zero)
            {
                Console.Error.WriteLine($"CreateForX 0x{hr:X8}");
                return 6;
            }

            var item = MarshalInterface<GraphicsCaptureItem>.FromAbi(itemPtr);
            SizeInt32 size = item.Size;
            var pool = Direct3D11CaptureFramePool.CreateFreeThreaded(
                device,
                DirectXPixelFormat.B8G8R8A8UIntNormalized,
                2,
                size);
            var session = pool.CreateCaptureSession(item);
            var evt = new ManualResetEventSlim(false);
            Direct3D11CaptureFrame got = null;
            pool.FrameArrived += (s, _) =>
            {
                var f = s.TryGetNextFrame();
                if (f != null && got == null)
                {
                    got = f;
                    evt.Set();
                }
            };
            session.StartCapture();
            if (!evt.Wait(8000))
            {
                Console.Error.WriteLine("timeout waiting for frame");
                return 7;
            }

            var sb = SoftwareBitmap.CreateCopyFromSurfaceAsync(got.Surface).AsTask().GetAwaiter().GetResult();
            var conv = SoftwareBitmap.Convert(sb, BitmapPixelFormat.Bgra8, BitmapAlphaMode.Premultiplied);

            using var ras = new InMemoryRandomAccessStream();
            var enc = BitmapEncoder.CreateAsync(BitmapEncoder.PngEncoderId, ras).AsTask().GetAwaiter().GetResult();
            enc.SetSoftwareBitmap(conv);
            enc.FlushAsync().AsTask().GetAwaiter().GetResult();

            ras.Seek(0);
            uint len = (uint)ras.Size;
            var reader = new DataReader(ras.GetInputStreamAt(0));
            reader.LoadAsync(len).AsTask().GetAwaiter().GetResult();
            byte[] buf = new byte[len];
            reader.ReadBytes(buf);
            string? directory = Path.GetDirectoryName(outPath);
            if (!string.IsNullOrEmpty(directory))
            {
                Directory.CreateDirectory(directory);
            }

            File.WriteAllBytes(outPath, buf);
            Console.WriteLine($"OK {size.Width}x{size.Height} -> {outPath}");
            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("EX: " + ex);
            return 9;
        }
    }
}
