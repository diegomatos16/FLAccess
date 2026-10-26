# Publicação e preservação

- Publicar somente quando o responsável solicitar. Versão atual: 0.1.8,
  baseada no código local dev 25; preservar tags/releases anteriores.
- Sempre enviar também as DLLs necessárias em toda publicação no GitHub:
  `sider-core/sider.dll` e `modules/FLAccess-Prism/prism.dll`, com licenças.
  Incluir no repositório e no instalador. Ver docs/PUBLICACAO.pt-BR.md.
- Gerar ZIP e hashes com `python tools/build_release.py`; não publicar só Lua.
- Preservar comportamento aprovado; separar testes internos de audição real.
- Não publicar jogo, saves, logs, capturas brutas nem experimentos de gameplay.
