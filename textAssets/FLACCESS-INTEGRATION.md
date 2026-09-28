# Integração com o FLAccess

O catálogo completo está em `textAssets/catalog.sqlite.zip` no repositório.
Extraia `catalog.sqlite` conforme `textAssets/README.md` antes de regenerar os
índices. O jogo não carrega esse banco de aproximadamente 2,2 GB. O gerador
`tools/build_flaccess_runtime_assets.py` produz dois índices UTF-8 pequenos:

- `pt.tsv`, a partir de `Data/dt20_bra_x64.cpk`;
- `en.tsv`, a partir de `Data/dt20_eng_x64.cpk`.

Cada linha contém `papel<TAB>texto exato`. O FLAccess usa o papel como pista
semântica antes das heurísticas antigas. Foco real, sliders e contexto de tela
continuam tendo prioridade, pois um mesmo texto pode funcionar de modos diferentes
em telas diferentes.

Entram todos os textos da árvore `string` classificados como `control`, `dialog`,
`dialog-button`, `instruction`, `status`, `tooltip-or-description`,
`menu-item-or-title`, `label-or-name` ou `text`. Itens `technical` ficam fora para
não transformar identificadores internos e fragmentos binários em fala.

Para regenerar, execute na raiz do jogo:

```powershell
python textAssets/tools/build_flaccess_runtime_assets.py
```

Os destinos padrão são `SiderAddons/modules/FLAccess-text` (instalação ativa) e
`FLAccess/modules/FLAccess-text` (fonte do mod). A opção `use_text_assets` em
`FLAccess.ini` permite desligar somente essa camada sem remover os arquivos.
