# Instalação — FLAccess 0.2.3 — experimental

Para Football Life 27 no Windows, com SiderAddons e Sider 7.3.3 compatível.
O FlAccess.zip contém apenas content, modules e sider.dll.

1. Feche jogo e Sider. Faça backup de sider.ini, sider.dll e dos INIs, WAVs e perfis de câmera personalizados.
2. Mescle content e modules em SiderAddons, preservando os demais mods. Em atualizações, preserve modules/FlAccess/FlAccess.ini e seus recursos personalizados.
3. Copie sider.dll da raiz do ZIP para SiderAddons/sider.dll.
4. Na seção [sider] de SiderAddons/sider.ini, confira lua.enabled = 1, luajit.ext.enabled = 1 e match-stats.enabled = 1. Substitua as entradas anteriores do FLAccess pelas 32 linhas lua.module de [sider.ini.snippet](sider.ini.snippet), na ordem fornecida. Remova também uma entrada antiga de FlAccessOpeningTrace.lua antes de adicionar o bloco, evitando duplicatas. Não remova entradas dos outros mods.
5. Remova somente cpk.root antigos de FlAccessReader e FlAccessGameplay. Os recursos atuais ficam em content/FlAccess.
6. Inicie pelo atalho normal com Sider e leitor de tela. F1 lê a ajuda do módulo ativo; I/K ou analógico direito exploram campos. No painel FLAccess, Audiodescrição controla cenas de abertura e escalações. Uniformes são lidos pela navegação; replays estão desativados.

A última linha, lua.module = "FlAccessOpeningTrace.lua", é necessária para a audiodescrição. O nome histórico do arquivo não significa que seja apenas diagnóstico.

Para instalar a partir do checkout: python tools/install_flaccess.py --sider <caminho-SiderAddons>. O script faz backup e preserva configurações e recursos. Para atualizar o núcleo, copie sider-core/sider.dll conforme o passo 3. Python não é necessário para jogar.

DLLs em modules/FlAccess/bin. Código-fonte e licenças no repositório, incluindo modules/FlAccess/licenses, COPYING.OpenAL e PRISM-SOURCE.json. Consulte as [notas da versão](../docs/RELEASE-0.2.3.pt-BR.md).
