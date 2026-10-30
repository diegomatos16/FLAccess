# Publicação no GitHub

Preferência permanente do responsável pelo projeto, registrada em 26/10/2026:
sempre que publicar uma versão, enviar também as DLLs necessárias do Sider.

Toda publicação deve incluir no repositório e no ZIP de instalação:

- `sider-core/sider.dll`: núcleo modificado compatível com Sider 7.3.3;
  no novo ZIP, fica em `sider/sider.dll` para copiar à raiz do SiderAddons.
- `modules/FlAccessReader/bin/prism.dll`, junto de todas as licenças em
  `modules/FlAccessReader/licenses`.
- Dois mods independentes: `modules/FlAccessReader/FlAccessReader.lua` e
  `modules/FlAccessGameplay/FlAccessGameplay.lua`, suas bibliotecas e licenças.
- Assets em `livecpk/FlAccessReader` e `livecpk/FlAccessGameplay`.

Estrutura solicitada em 27/10: FlAccess.zip contém somente as pastas livecpk,
modules e sider na raiz. Sons WAV ficam abertos/editáveis, sem criptografia.
O núcleo compatível continua obrigatório; a pasta sider leva instruções e snippet.

Não publicar somente o Lua. Não substituir a DLL testada por uma compilação
arbitrária ou por outra versão do Sider. Quando mudar a DLL, conferir fontes,
compatibilidade, documentação e hashes antes de publicar.

Gerar o pacote com `python tools/build_release.py`. O comando exige ambas as
DLLs e licenças, confere o ZIP e gera `sider/BUILD.json` com hashes dos arquivos e
commit de origem, além de `SHA256SUMS.txt` ao lado do pacote. Publicar os dois
artefatos na Release correspondente. A pasta `release/` é saída local ignorada.

O builder também gera o módulo Gameplay agregado para o sandbox do Sider; editar
os componentes em modules/FlAccessGameplay/engine e regenerar, não o arquivo final.
A versão0.1.9 publica Reader baseado na42 e Gameplay experimental16,
ambos autorizados pelo responsável em30/10/2026. Reader também é gerado por
build_reader_module.py; editar engine/, não o Lua agregado.

Criar commit e tag da nova versão; preservar versões anteriores. Publicação
acontece quando solicitada pelo responsável, sem envio automático a cada edição.
Registrar aprovações reais e limitações; testes internos não comprovam audição.
Não incluir executável/dados do jogo, saves, logs, capturas ou probes de pesquisa.
Gameplay experimental16 foi explicitamente autorizado nesta publicação; manter
as limitações e pendências nas notas. Não incluir outros experimentos automaticamente.

Para 0.1.8, o binário Sider publicado é o mesmo instalado e testado:
SHA256 `57005a0e5977e699c8053293163599508616fd78e044b0f4ccd8ca8e2ccab116`.
