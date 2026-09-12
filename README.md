# FLAccess

Experimental, non-OCR menu accessibility for SP Football Life 2026 / PES 2021.

Current release: **0.1.5**.

- [Documentação em português](docs/README.pt-BR.md)
- [English documentation](docs/README.en.md)
- [Changelog](CHANGELOG.md)

The project reads strings and focus-related state inside the game through a Sider Lua module. The module calls [Prism](https://github.com/ethindp/prism) directly through its native C API to announce through NVDA or another screen reader, with Microsoft SAPI as fallback.

This is a research build tied to the studied `FL_2026.exe`. It does not patch
the executable and it is not complete gameplay accessibility. Game Plan,
including its main command screen and Edit Position, remains unreliable in
0.1.5 and is reserved for further investigation in 0.1.6. See the
language-specific documentation for installation, architecture, verified
behavior and known limitations.
