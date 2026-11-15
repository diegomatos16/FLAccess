# FLAccess 0.2.3

Suporte inicial à audiodescrição de entrada de times e descrição de uniformes.
Compatibilidade experimental com Football Life 27 no Windows.

- Cenas verificadas da abertura: estádio, túnel, entrada dos times, cerimônia e fotos. Os detalhes dependem dos dados reconhecidos na cena.
- Escalações com os titulares por setor, do goleiro ao ataque. A leitura termina mesmo se o quadro mudar.
- Categoria Audiodescrição no painel FLAccess: chave geral, cenas de abertura e escalações.
- Uniformes descritos automaticamente ao navegar na seleção, independentemente da chave de audiodescrição.
- Replays ficam sem audiodescrição e sem opção no painel. Código de pesquisa preservado para uma versão futura.
- Classificação com leitura da seleção real e menos processamento redundante. O usuário confirmou a correção dos saltos e da lentidão.
- Exploração do Plano de Jogo: overall antes do estilo de jogo; energia depois da posição em campo, quando disponível. Lesões são anunciadas quando confirmadas.
- Leitura da configuração de comandos acompanha o foco nativo. Botões são falados quando seus símbolos são reconhecidos; controle PlayStation físico ainda não foi validado.

## Instalação

Baixe **FlAccess.zip** nos arquivos desta release. O ZIP contém somente as pastas **content**, **modules** e o arquivo **sider.dll**.

1. Feche jogo e Sider. Faça backup de sider.ini, sider.dll e das configurações e recursos personalizados do FLAccess.
2. Mescle content e modules na pasta SiderAddons. Preserve seu FlAccess.ini, WAVs e perfis de câmera personalizados ao atualizar.
3. Em instalação compatível com Sider 7.3.3, copie sider.dll para SiderAddons/sider.dll.
4. Confira as três opções e as 32 linhas de módulos na [configuração do Sider desta versão](https://github.com/diegomatos16/FLAccess/blob/v0.2.3/packaging/sider.ini.snippet). Na seção [sider] de sider.ini, substitua o bloco anterior do FLAccess pelo bloco fornecido, na mesma ordem, sem duplicatas. A última linha carrega FlAccessOpeningTrace.lua e é necessária para a audiodescrição.
5. Inicie o jogo pelo atalho habitual com Sider e leitor de tela ativos.

[Guia de instalação completo](https://github.com/diegomatos16/FLAccess/blob/v0.2.3/packaging/INSTALL.pt-BR.md).
Não é necessário Python para jogar. Código-fonte e licenças permanecem no repositório.

## Validação e limites

Testes automatizados verificam leitura, configurações, cenas sintéticas, assinaturas do executável local, migração e conteúdo do ZIP. Abertura, fotos e escalações receberam testes no jogo durante o desenvolvimento. Os testes não garantem reconhecimento de toda cena, estádio, uniforme ou controle. Replays continuam pendentes e estão desativados nesta versão.
