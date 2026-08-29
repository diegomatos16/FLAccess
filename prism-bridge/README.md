# PES A11y Prism Bridge 0.1.4

Small out-of-process bridge between the Sider accessibility module and
[Prism](https://github.com/ethindp/prism). Prism chooses a running screen
reader first and falls back to Microsoft SAPI when no reader is available.

The bridge watches `pes_a11y_speech.txt`. Each update is spoken with
interruption enabled so controller navigation stays responsive.

Build:

```powershell
dotnet publish -c Release -r win-x64 --self-contained false
```

The framework-dependent package requires the 64-bit .NET 8 runtime. The native
`prism.dll` and every notice under `vendor/prismatoid-0.17.3.dist-info/licenses`
must remain beside the published bridge distribution.

Test the native backend selection:

```powershell
pes-a11y-prism-bridge.exe --test
```
