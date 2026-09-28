# Catálogo de assets de texto — Football Life 2026

Catálogo offline para desenvolvimento do **FLAccess** e leitores de tela. O jogo
não precisa ser aberto. A extração não altera executáveis, CPKs nem outros
arquivos da instalação.

## Conteúdo

- `catalog.sqlite.zip`: catálogo completo compactado para o Git LFS. Extraia
  `catalog.sqlite` antes de executar as consultas ou regenerar os índices.
  O banco guarda texto, papel semântico,
  confiança, arquivo físico, membro CPK, offset, codificação, idioma e método de
  extração.
- `localization/*.jsonl`: ocorrências extraídas das tabelas localizadas, uma
  linha JSON por texto. Códigos importantes: `bra` (português brasileiro),
  `por` (português europeu) e `eng` (inglês).
- `by-role/*.jsonl`: textos únicos organizados por papel estimado.
- `files.csv`: cobertura de cada arquivo físico da instalação.
- `cpk-members.csv`: inventário de cada arquivo interno dos CPKs e estado da
  análise.
- `manifest.json`: totais, idiomas, papéis e cobertura da execução.
- `tools/extract_text_assets.py`: extrator reproduzível.

## Papéis semânticos

Classificação é heurística; `confidence` informa certeza estimada.

- `dialog`: pergunta, confirmação ou aviso modal.
- `dialog-button`: botão curto de diálogo, como Sim, Não, OK ou Cancelar.
- `control`: opção configurável, seletor, controle, volume, câmera etc.
- `instruction`: instrução de uso ou comando de botão.
- `status`: carregamento, salvamento, erro ou outro estado transitório.
- `tooltip-or-description`: ajuda ou descrição longa.
- `menu-item-or-title`: item curto de menu ou título.
- `label-or-name`: rótulo, nome de entidade, competição, clube ou pessoa.
- `text`: texto sem papel seguro.
- `technical`: caminho, identificador, mensagem interna ou texto de engenharia.

O papel real depende do widget e contexto em tempo de execução. Para fala, use
esta classificação como pista; foco capturado pelo FLAccess continua sendo a
fonte autoritativa.

## Consulta

Depois de clonar o repositório com Git LFS, na raiz do projeto:

```powershell
tar -xf textAssets/catalog.sqlite.zip -C textAssets
```

O arquivo extraído `catalog.sqlite` é local e não deve ser adicionado ao Git.

Exemplo com Python:

```python
import sqlite3

db = sqlite3.connect("textAssets/catalog.sqlite")
for row in db.execute("""
    SELECT a.text, a.role, o.source_file, o.archive_member, o.byte_offset
    FROM assets a
    JOIN occurrences o ON o.asset_id = a.id
    WHERE o.locale = 'bra' AND a.role IN ('dialog', 'control')
    ORDER BY a.text
"""):
    print(row)
```

Busca direta:

```sql
SELECT a.text, a.role, o.*
FROM assets a JOIN occurrences o ON o.asset_id = a.id
WHERE a.normalized LIKE '%configurações de volume%';
```

## Atualização

Na raiz do jogo, defina `PYTHONPATH` para
`FLAccess/reference/pes-file-tools/lib` ou use o ambiente Python configurado no
projeto, então execute:

```powershell
python textAssets/tools/extract_text_assets.py --quick
```

Remova `--quick` para também varrer binários pequenos de extensões desconhecidas.
Use `--resume` para continuar após interrupção sem repetir arquivos concluídos.
Executáveis e DLLs sempre passam por varredura completa. CPKs sempre têm todos
os membros indexados; arquivos internos com formato textual conhecido, inclusive
`.str` e `.bin`, são extraídos até 64 MiB.

## Limites conhecidos

- Conteúdo visual rasterizado não vira texto: não há OCR neste processo.
- Áudio não é transcrito.
- Arquivos grandes de mídia são inventariados, não interpretados como texto.
- Strings de executáveis revelam literais e recursos, não todo texto criado
  dinamicamente em tempo de execução.
- Alguns textos curtos podem ter papel ambíguo. Confirme pelo contexto/widget
  antes de automatizar fala.
- Árvores de pesquisa e releases duplicados em `FLAccess/reference` e
  `FLAccess/release` ficam inventariadas, mas não alimentam o catálogo textual.
