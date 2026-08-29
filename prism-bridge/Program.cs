using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using System.Text;
using System.Diagnostics;

namespace PesA11yPrismBridge;

internal static class PrismNative
{
    private const string Library = "prism.dll";

    [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
    internal static extern nint prism_init(nint config);

    [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void prism_shutdown(nint context);

    [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
    internal static extern nint prism_registry_create_best(nint context);

    [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
    internal static extern nint prism_registry_create(nint context, ulong backendId);

    [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
    internal static extern int prism_backend_initialize(nint backend);

    [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void prism_backend_free(nint backend);

    [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
    internal static extern nint prism_backend_name(nint backend);

    [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
    internal static extern int prism_backend_speak(
        nint backend,
        [MarshalAs(UnmanagedType.LPUTF8Str)] string text,
        [MarshalAs(UnmanagedType.I1)] bool interrupt);

    [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
    internal static extern nint prism_error_string(int error);
}

internal static class Ole32
{
    internal const uint CoinitMultithreaded = 0x0;

    [DllImport("ole32.dll")]
    internal static extern int CoInitializeEx(nint reserved, uint coInit);

    [DllImport("ole32.dll")]
    internal static extern void CoUninitialize();
}

internal sealed class PrismSpeaker : IDisposable
{
    private const ulong SapiBackendId = 0x1D6DF72422CEEE66;
    private nint context;
    private nint backend;

    public string BackendName { get; private set; } = "nenhum";

    public PrismSpeaker()
    {
        context = PrismNative.prism_init(0);
        if (context == 0)
            throw new InvalidOperationException("Prism não pôde ser inicializado.");
        SelectBestBackend();
    }

    private void SelectBestBackend()
    {
        if (backend != 0)
            PrismNative.prism_backend_free(backend);
        backend = PrismNative.prism_registry_create_best(context);
        if (backend == 0)
        {
            backend = PrismNative.prism_registry_create(context, SapiBackendId);
            var sapiError = backend == 0
                ? -1
                : PrismNative.prism_backend_initialize(backend);
            if (sapiError != 0)
            {
                if (backend != 0)
                {
                    PrismNative.prism_backend_free(backend);
                    backend = 0;
                }
                var message = sapiError < 0
                    ? "backend SAPI ausente na build"
                    : Marshal.PtrToStringUTF8(
                        PrismNative.prism_error_string(sapiError)) ?? $"erro {sapiError}";
                throw new InvalidOperationException(
                    $"Prism não encontrou leitor de telas e o fallback SAPI falhou: {message}.");
            }
        }
        BackendName = Marshal.PtrToStringUTF8(
            PrismNative.prism_backend_name(backend)) ?? "desconhecido";
    }

    public void Speak(string text)
    {
        if (string.IsNullOrWhiteSpace(text))
            return;
        var error = PrismNative.prism_backend_speak(backend, text, true);
        if (error == 0)
            return;

        // NVDA and similar backends do not reconnect after the reader exits.
        // Ask Prism to select the best currently working backend, including SAPI.
        SelectBestBackend();
        error = PrismNative.prism_backend_speak(backend, text, true);
        if (error != 0)
        {
            var message = Marshal.PtrToStringUTF8(
                PrismNative.prism_error_string(error)) ?? $"erro {error}";
            throw new InvalidOperationException($"Falha de fala Prism: {message}");
        }
    }

    public void Dispose()
    {
        if (backend != 0)
        {
            PrismNative.prism_backend_free(backend);
            backend = 0;
        }
        if (context != 0)
        {
            PrismNative.prism_shutdown(context);
            context = 0;
        }
    }
}

[SupportedOSPlatform("windows")]
internal static class Program
{
    private static readonly UTF8Encoding Utf8 = new(false, true);
    private static volatile bool stopping;

    public static int Main(string[] args)
    {
        var exitCode = 1;
        var prismThread = new Thread(() => exitCode = Run(args));
        prismThread.SetApartmentState(ApartmentState.MTA);
        prismThread.Start();
        prismThread.Join();
        return exitCode;
    }

    private static int Run(string[] args)
    {
        using var singleton = new Mutex(true, "Local\\PesA11yPrismBridge", out var firstInstance);
        if (!firstInstance)
        {
            Console.Error.WriteLine("O bridge Prism já está em execução.");
            return 2;
        }

        try
        {
            var comResult = Ole32.CoInitializeEx(0, Ole32.CoinitMultithreaded);
            const int RpcChangedMode = unchecked((int)0x80010106);
            if (comResult < 0 && comResult != RpcChangedMode)
                Marshal.ThrowExceptionForHR(comResult);
            var shouldUninitializeCom = comResult >= 0;
            try
            {
            using var speaker = new PrismSpeaker();
            Console.WriteLine($"Prism pronto. Backend: {speaker.BackendName}");

            if (args.Length >= 1 && args[0] == "--test")
            {
                speaker.Speak(args.Length >= 2
                    ? string.Join(' ', args.Skip(1))
                    : $"Prism funcionando com {speaker.BackendName}");
                return 0;
            }

            string? speechPathArgument = null;
            int? parentProcessId = null;
            for (var index = 0; index < args.Length; index++)
            {
                if (args[index] == "--speech-file" && index + 1 < args.Length)
                    speechPathArgument = args[++index];
                else if (args[index] == "--parent" && index + 1 < args.Length
                    && int.TryParse(args[++index], out var parsedParent))
                    parentProcessId = parsedParent;
                else if (!args[index].StartsWith("--", StringComparison.Ordinal))
                    speechPathArgument ??= args[index];
            }
            var speechPath = speechPathArgument is not null
                ? Path.GetFullPath(speechPathArgument)
                : Path.GetFullPath(Path.Combine(
                    AppContext.BaseDirectory, "..", "pes_a11y_speech.txt"));
            Process? parentProcess = null;
            if (parentProcessId is not null)
            {
                try
                {
                    parentProcess = Process.GetProcessById(parentProcessId.Value);
                }
                catch (ArgumentException)
                {
                    return 0;
                }
            }
            Console.WriteLine($"Monitorando: {speechPath}");
            Console.WriteLine("Pressione Ctrl+C para encerrar.");

            Console.CancelKeyPress += (_, e) =>
            {
                e.Cancel = true;
                stopping = true;
            };

            long lastWrite = -1;
            if (File.Exists(speechPath))
            {
                var initialWrite = File.GetLastWriteTimeUtc(speechPath);
                if (parentProcess is null
                    || initialWrite < parentProcess.StartTime.ToUniversalTime())
                    lastWrite = initialWrite.Ticks;
            }
            while (!stopping)
            {
                if (parentProcess?.HasExited == true)
                    break;
                try
                {
                    if (File.Exists(speechPath))
                    {
                        var write = File.GetLastWriteTimeUtc(speechPath).Ticks;
                        if (write != lastWrite)
                        {
                            var line = File.ReadAllText(speechPath, Utf8);
                            var tab = line.IndexOf('\t');
                            var text = (tab >= 0 ? line[(tab + 1)..] : line).Trim();
                            if (text.Length != 0)
                            {
                                speaker.Speak(text);
                                Console.WriteLine(text);
                            }
                            lastWrite = write;
                        }
                    }
                }
                catch (IOException)
                {
                    // The Lua writer may briefly own the tiny handoff file.
                }
                // Menu focus can change every rendered frame. A 25 ms poll
                // could skip the short-lived handoff between two rapid moves;
                // 5 ms keeps the file bridge responsive while remaining tiny.
                Thread.Sleep(5);
            }
            parentProcess?.Dispose();
            return 0;
            }
            finally
            {
                if (shouldUninitializeCom)
                    Ole32.CoUninitialize();
            }
        }
        catch (Exception error)
        {
            Console.Error.WriteLine(error.Message);
            return 1;
        }
    }
}
