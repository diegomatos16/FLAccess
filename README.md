# PES A11y Menu Scanner

Experimental, non-OCR menu accessibility for SP Football Life 2026 / PES 2021.

Current release: **0.1.4**.

- [Documentação em português](docs/README.pt-BR.md)
- [English documentation](docs/README.en.md)
- [Changelog](CHANGELOG.md)

The project reads strings and focus-related state inside the game through a Sider Lua module. A small out-of-process bridge sends announcements to NVDA or another screen reader through [Prism](https://github.com/ethindp/prism), with Microsoft SAPI as fallback.

This is a research build tied to the studied `FL_2026.exe`. It does not patch the executable and it is not complete gameplay accessibility. See the language-specific documentation for installation, architecture, verified behavior and known limitations.
