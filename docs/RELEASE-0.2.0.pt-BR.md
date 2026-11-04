# FLAccess 0.2.0 — experimental — 04/11/2026

Compatibilidade experimental com Football Life 27, aprimoramento no sistema de
navegação e exploração, alguns bugs corrigidos, mas mais pendências. Publicação
da base Reader 52 / Gameplay 19; a compatibilidade com FL27 é parcial.

## Mudanças

- Leitor e gameplay reunidos em um FLAccess, dividido em 31 módulos nativos do
  Sider. Listas e agrupamentos têm componentes separados. Recursos em
  content/FlAccess, código/configuração/DLLs em modules/FlAccess; leitor base
  sempre ativo. Não carregar os pacotes antigos simultaneamente com 0.2.0.
- Exploração com I/K e analógico direito vertical, um campo completo por passo.
  Título nativo do grupo junto do primeiro campo, quando a relação é comprovada.
  Motor comum de rótulos/valores, incluindo campos apresentados sem foco próprio.
  Atributos só na exploração; seleção automática mantém nome/situação e os
  registros reconhecidos da classificação. Comando de repetir removido.
- Ajustes de descoberta de componentes do FL27, seleção de times, entrega de
  falas/tooltips, slots e perguntas de salvamento. Classificação ordenada em time,
  posição, pontos, saldo e demais estatísticas; seleção pelo índice nativo.
  Data da carreira acrescentada à entrada e à exploração da Master Liga.
- Correções confirmadas pelo usuário: sufixo hexadecimal em Configurações do jogo
  e leitura dos itens Sim/Não do diálogo. Demais ajustes sem confirmação continuam
  explicitamente nas pendências abaixo.
- Tentativas de reduzir coleta nas listas, reutilizando estrutura com validação
  das ligações. Reader 52 evita invalidação global por foco de redesenho e troca
  de dono/guia. A51 continuava muito lenta; sem confirmação de desempenho 52.
- Prism 0.18.3 compilado do repositório oficial, com procedência no pacote. Áudio
  experimental adaptado às bases de câmera verificadas; câmera Jogador ID8 usa
  direção do corpo. Ajustes de recuperação da sessão após substituição.

## Pendências da publicação

- **Desempenho:** listas de times, ligas, jogadores/busca e classificação deixam
  o jogo muito pesado. Confirmado até 51; último ajuste 52 sem validação real.
- **Outros módulos do Sider no FL27:** suas opções deixaram de ser lidas, segundo
  o novo relato. Causa e abrangência ainda não investigadas; não declarar solução.
- **Menu principal:** Liga Master e Rumo ao Estrelato repetem o nome e deixam de
  ler o tooltip. Ajustes existentes ainda precisam de confirmação no FL27.
- **Submenu Football Life:** amistoso/liga/copa e outras opções têm relato de
  silêncio. Escolha de clubes também teve atributos sobrepondo o nome do time.
- **Dados dos jogadores e grupos:** há telas silenciosas ou com rótulos/números
  separados; agrupar corretamente altura, peso, força e outros campos em painéis
  como o da busca/Salah. Generalização não tem cobertura integral comprovada.
- **Master Liga:** cartões sob as guias, especialmente Diário; leitura das
  notícias, J/L e analógico direito horizontal para notícia anterior/próxima;
  confirmação da data automática ao entrar e na exploração. J ainda vai ao
  primeiro campo e L está sem ação; notícias horizontais não implementadas.
- **Classificação:** lentidão, atualização e alcance/rolagem além dos cinco times
  relatados. Dados de ligas/participantes devem ficar agrupados apenas na
  exploração. Calendário/finanças precisam de cobertura das variantes do FL27;
  a aprovação histórica 44 não certifica todas as telas atuais.
- **Salvamento e diálogos:** confirmar identificação dos slots ocupados/vazios e
  anúncio automático da pergunta de sobrescrita. Sim/Não foi confirmado corrigido;
  isso não confirma todos os diálogos nem opções de retorno ao principal.
- **Partida/áudio:** confirmar fim de “Editar posição” repetido após substituição
  e recuperação dos sons ao retomar. Orientação/antecedência do aviso de desarme
  continua aberta: o adversário está com a bola; o som atual indica proximidade
  da bola, sem prever intenção ou sucesso do desarme. Demais câmeras/efeitos e
  volume/mudo precisam de validação auditiva nos fluxos abertos.
- Permanecem relatos anteriores de países, mensagens parciais, tooltips e
  introdução da ML. Não reabrir aprovações históricas por inferência, nem encerrar
  pendências por testes automatizados. Estados e histórico na
  [lista detalhada](LISTA-PROBLEMAS-ATUAL.pt-BR.md).

## Instalação e controles

Baixe FlAccess.zip e SHA256SUMS.txt na Release v0.2.0. O ZIP contém content,
modules e sider; o Sider compatível, DLLs e respectivas licenças estão incluídos.
Siga a [instalação/migração](../packaging/INSTALL.pt-BR.md). São 31 linhas de
lua.module na ordem do snippet. Recursos próprios não usam cpk.root. Preserve
outros mods, preferências, WAVs e perfis personalizados. Python não é necessário
para jogar. Não substituir o sider.ini inteiro.

Navegação original pelos controles do jogo. Exploração: I/análogo direito para
cima, campo anterior; K/direito para baixo, próximo; J, primeiro campo;
L sem função por enquanto. Um campo por passo. Leitor base sem desligamento.

## Validação e limites

449 verificações Lua do leitor;65 testes Python passaram e 1 foi ignorado por
captura histórica ausente, incluindo 43 contratos do executável FL27. Integração
dos 31 módulos,16 eventos/23 registros/120 quadros e Prism nativo. O teste de
redesenho com 1200 eventos em 30 quadros manteve 5 descobertas periódicas.

Esses testes não comprovam FPS, audição ou funcionamento de todas as telas no
jogo. As pendências acompanham esta versão experimental; sem garantia de
acessibilidade completa da partida ou compatibilidade com qualquer mod.
