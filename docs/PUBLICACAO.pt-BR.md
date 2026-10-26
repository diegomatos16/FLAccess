# Publicação no GitHub

Preferência permanente do responsável pelo projeto, registrada em 26/10/2026:
sempre que publicar uma versão, enviar também as DLLs necessárias do Sider.

Toda publicação deve incluir no repositório e no ZIP de instalação:

- `sider-core/sider.dll`: núcleo modificado compatível com Sider 7.3.3;
  no ZIP, fica na raiz como `sider.dll`.
- `modules/FLAccess-Prism/prism.dll`, junto de todas as licenças do Prism.
- Lua e índices PT/EN correspondentes à versão publicada.

Não publicar somente o Lua. Não substituir a DLL testada por uma compilação
arbitrária ou por outra versão do Sider. Quando mudar a DLL, conferir fontes,
compatibilidade, documentação e hashes antes de publicar.

Gerar o pacote com `python tools/build_release.py`. O comando exige ambas as
DLLs e licenças, confere o ZIP e gera `BUILD.json` com hashes dos arquivos e
commit de origem, além de `SHA256SUMS.txt` ao lado do pacote. Publicar os dois
artefatos na Release correspondente. A pasta `release/` é saída local ignorada.

Criar commit e tag da nova versão; preservar versões anteriores. Publicação
acontece quando solicitada pelo responsável, sem envio automático a cada edição.
Registrar aprovações reais e limitações; testes internos não comprovam audição.
Não incluir executável/dados do jogo, saves, logs, capturas ou experimentos.

Para 0.1.8, o binário Sider publicado é o mesmo instalado e testado:
SHA256 `57005a0e5977e699c8053293163599508616fd78e044b0f4ccd8ca8e2ccab116`.
