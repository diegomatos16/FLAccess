# Reader52 — invalidação das árvores nas listas

Usuário pediu uma última tentativa antes de levar a build ao GitHub. A condição
de publicação ainda depende do retorno do teste; não publicar automaticamente
com base no resultado de uma suíte offline.

O log real51 foi preservado em `.test-temp/fl27-audit/sider51-return.log`.
Confirma runtime0.2.0/build51 e os31 módulos carregados. A busca chega a
30–32 ms por quadro em intervalos de600 quadros, com24–28 ms nas janelas e
aproximadamente1200 cópias de memória por quadro. Portanto51 não resolveu o
problema. A exploração também ainda apresenta números e rótulos avulsos em um
painel do jogador; o agrupamento desse painel continua sem confirmação.

Inspeção encontrou duas invalidações globais excessivas: evento de foco em
widget ausente do grafo marcava toda a descoberta como suja; mudança de dono,
guia ou seleção suja apagava todas as árvores antes da reconstrução. Eventos de
redesenho podem vir de componentes fora da árvore de entrada. O log apresenta
sequências de entradas de foco nessas telas, mas não registrava a razão de cada
reconstrução: a contribuição exata de cada causa no jogo não foi medida.

52 remove a invalidação por foco desconhecido. O evento continua registrado;
cursor e cabeçalhos nativos continuam atualizados. Mudança de dono ou guia não
apaga árvores de outras raízes. Nova raiz é descoberta normalmente; seleção
alterada que não pode ser resolvida ainda exige reconstrução. Cada ligação usada
e o dono atual continuam validados antes de aceitar texto/fala.

As árvores habilitadas conservam expiração de6 quadros contados da descoberta
da própria árvore. Refazer apenas os cabeçalhos por troca de dono não prolonga
essa validade. Janela fechada, ligação removida e memória inacessível continuam
sendo rejeitadas. Nenhuma escrita de cursor ou envio de teclas ao jogo.

O log agora resume `window-refresh` a cada600 quadros, com contadores de caminho
leve, descoberta periódica e motivos de reconstrução. Isso permite distinguir
invalidação frequente de outras causas de custo sem rearmar a captura pesada.

449 verificações Lua passaram. Novo teste:1200 eventos de foco em30 quadros
mantêm a seleção nativa e só causam5 descobertas periódicas. Troca de dono não
reescaneia árvores alheias, mas janela fechada/ligação removida continuam
bloqueadas e a árvore volta a ser descoberta quando expira.

65 testes Python passaram;1 ignorado por captura histórica ausente. Incluem43
contratos do FL27. Integração31 módulos/16 eventos/23 registros/120 quadros,
Prism nativo. Isso não comprova FPS ou audição da52 no jogo.

Fonte canônica: `C:/Users/Diego/git/diegomatos16/FLAccess/modules/FlAccess`.
Instalação no SiderAddons do FL27 com backup. Gameplay19, atributos apenas na
exploração e demais escolhas de leitura preservados. Agrupamento do painel
observado51, data/Diário/notícias e rolagem da classificação continuam abertos
até evidência real; não são declarados corrigidos neste ajuste de desempenho.

Instalado e conferido:31 módulos idênticos à fonte e ao pacote local52;
30 recursos,3DLLs,2 arquivos de estado, FlAccess.ini e sider.ini preservados
em bytes. Backup `local-backups/flaccess020-install-20261104-015929-356497`.
Pacote local `release/0.2.0-local/FlAccess.zip`, build52,97 arquivos no manifesto.
