# FLAccess 0.1.7 — 21/10/2026

Versão pública baseada na dev 21, autorizada pelo usuário. Identificação pública
0.1.7; build interna 21 preservada. A instalação local de desenvolvimento e sua
captura armada foram preservadas.

- Decisão comum de foco, nome, valor e contexto, com validação na entrega.
- Descarte de fala de contexto anterior, inclusive ao adiar durante parágrafos.
- Revisão por I/K/J/L; edição, diálogos e componentes nativos de listas/comandos.
- Fontes de testes e relatórios de mecanismos, sem logs pessoais nem capturas brutas.

## Evidência e pendências

A base dev 21 passou em 295 verificações Lua por cópia, 33 testes Python,
sandbox do Sider e 15 assinaturas do executável. Não houve audição final da
dev 20/21; nenhum relato foi encerrado somente pelo resultado desses testes.
As confirmações anteriores e todos os relatos abertos constam em
[TESTES-LEITURA-PENDENCIAS.pt-BR.md](TESTES-LEITURA-PENDENCIAS.pt-BR.md).

Pendências incluem título inicial, guias, países, seleção inicial de liga/clube,
revisão do elenco do clube, confirmação após edição do treinador, botão real
de Pular, introdução/home da Master Liga, situação do elenco e lado do usuário.

## Pacote

O ZIP contém Lua, índices PT/EN, Prism e suas licenças, instruções e documentação.
Inclui também o `sider.dll` modificado 7.3.3, conforme solicitação posterior do
responsável pelo projeto. É o mesmo binário da instalação local e dos testes
anteriores, com `overlay_content` e a correção de alinhamento de pilha. Usar
somente no núcleo compatível 7.3.3. O código está em `sider-core`.
Não contém executável do jogo, saves, logs, backups nem experimentos de gameplay.
O pacote foi atualizado sem mudar a versão 0.1.7; confira o SHA256 atualizado.

Os testes publicados usam LuaJIT e, para verificações nativas, os arquivos da
instalação local pertencente ao testador. A suíte original espera o layout
`<jogo>/FLAccess` e `<jogo>/SiderAddons`, o LuaJIT e `memory.lua` do Sider em
`reference/sider7`, além da amostra local de fonte do controle. Esses arquivos
externos e a captura de proveniência não são redistribuídos. Python é ferramenta
de desenvolvimento, sem dependência para executar o mod.

## Conferência do artefato público

Na cópia pública, com identificação 0.1.7: 295 verificações Lua passaram;
26 testes Python de componentes/contratos passaram, com uma verificação de
proveniência pulada porque a captura bruta não é publicada; mais 6 testes de
extração passaram. Sandbox: 120 frames, Prism pronto, 175 locais; 15 assinaturas
do executável conferidas. Usados executável, fonte de controle e dependências
da instalação local para os testes que os exigem. Nenhuma audição adicional
foi realizada. A lógica Lua é idêntica à dev 21, exceto o sufixo público.
