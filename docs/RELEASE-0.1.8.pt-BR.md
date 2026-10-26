# FLAccess 0.1.8 — 26/10/2026

Corrigidos bugs na leitura de alguns menus e implementado suporte inicial à
leitura de jogadores no plano de jogo. Publicação autorizada para preservar
o progresso da base dev 25. A versão 0.1.7 permanece disponível.

- Opções na entrada do plano de jogo e nomes em Editar posição: correções
  confirmadas pelo usuário ouvindo a dev 24.
- Revisão do jogador com K/I e analógico direito baixo/cima: número/nome,
  posição principal, secundárias existentes com adaptação completa/parcial
  e posição no campo ou “Não está no campo”.
- Titular/reserva/não relacionado somente ao navegar entre jogadores.
  Novo vínculo slot/lado/ID elimina dependência do cache de atributos.
- Revalidação da fala adiada e descarte de nome/valor de jogador anterior.

## Instalação e DLLs

Baixe `FLAccess-0.1.8-sider.zip` e siga as instruções incluídas. Contém o
`sider.dll` modificado compatível com Sider 7.3.3, Prism com suas licenças e
índices PT/EN. Ambas as DLLs também estão no repositório. Não requer Python
para jogar. As próximas publicações devem sempre incluir as DLLs; política
e geração verificável em [PUBLICACAO.pt-BR.md](PUBLICACAO.pt-BR.md).

## Validação e limites

Base local: 321 verificações Lua por cópia, 38 Python, sandbox Sider com
120 quadros/15 eventos, 15 assinaturas do executável e 175 locais. A promoção
para 0.1.8 altera a identificação, preservando a lógica dev 25. A suíte final
passou com 321 verificações Lua por cópia e 40 Python, incluindo dois testes
de empacotamento, além do sandbox e das assinaturas.

Revisão e situação adicionadas na dev 25 ainda precisam de confirmação audível.
Regras de competição não resolvidas dependem da captura válida do limite
nativo; sem essa prova não se inventa reserva/não relacionado. Outros relatos
continuam registrados na [matriz de pendências](TESTES-LEITURA-PENDENCIAS.pt-BR.md).
Acessibilidade das partidas não está implementada. Logs pessoais e capturas
brutas não são publicados; o ZIP inclui manifesto e hashes de verificação.
