# Instalação — FLAccess 0.2.2 — experimental

Use uma instalação do Football Life 27 no Windows com a pasta SiderAddons.
Extraia FlAccess.zip em uma pasta temporária. O pacote traz os módulos, sons,
perfis de câmera, DLLs do mod e a configuração de exemplo.

1. Feche o jogo e o Sider. Faça backup de sider.ini, sider.dll, INIs, WAVs
   e perfis de câmera personalizados.
2. Mescle content e modules no SiderAddons, preservando demais mods.
3. Em instalações compatíveis com Sider 7.3.3, copie sider/sider.dll do ZIP
   para SiderAddons/sider.dll. Essa atualização habilita F1 nos outros módulos.
4. Abra SiderAddons/sider.ini. Na seção [sider], confira que lua.enabled,
   luajit.ext.enabled e match-stats.enabled estão com valor 1. Adicione as 31
   linhas lua.module de sider/sider.ini.snippet na ordem fornecida. Em uma
   atualização, substitua as linhas do FLAccess anterior por esse bloco.
5. Remova somente cpk.root antigos de FlAccessReader e FlAccessGameplay.
   Recursos próprios são lidos diretamente de content/FlAccess.
6. Preserve valores read_tooltips, use_text_assets e tackle_* anteriores em
   modules/FlAccess/FlAccess.ini. Não sobrescreva preferências com padrões do ZIP.
7. Copie WAVs personalizados para content/FlAccess/sounds; perfis camera_00.ini
   até 09 para content/FlAccess/cameras. Catálogos ficam em content/FlAccess/text.
8. Inicie o Football Life pelo atalho normal com Sider. No painel FLAccess,
   F1 lê a ajuda e F4 toca a prévia do efeito selecionado.

No checkout: python tools/install_flaccess.py --sider <caminho-SiderAddons>.
Script registra backup e migra configurações/recursos; Python não é necessário
para jogar. Diretórios antigos ficam como backup, com entradas desativadas.
Para atualizar o núcleo, siga o passo 3 usando sider-core/sider.dll do checkout.

DLLs em modules/FlAccess/bin; licenças em licenses e COPYING.OpenAL.
Prism compilado do repositório oficial; commit/hash em PRISM-SOURCE.json.
Compatibilidade experimental com Football Life 27. Consulte as notas em RELEASE.pt-BR.md.
