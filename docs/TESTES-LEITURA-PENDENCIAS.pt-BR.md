# Validação e pendências 0.1.9

Ver [lista consolidada](LISTA-PROBLEMAS-ATUAL.pt-BR.md) e
[notas completas](RELEASE-0.1.9.pt-BR.md). Confirmações audíveis permanecem distintas
de verificações internas. Principal/países/mensagens/tabelas/tooltips e desempenho
continuam com relatos abertos; gameplay é experimental.

Base Reader42:410 verificações Lua por cópia,60Python,16eventos e16assinaturas.
Base Gameplay16:191contratos de câmera,104de gameplay e ciclo de áudio/pacote.
Os testes Windows usam memória do processo de teste, não comprovam audição/FPS.
Logs/capturas, executável e fontes de dados privados não acompanham o repositório.

Desenvolvimento: LuaJIT2.1 x64, Python3 e Sider SDK local em reference/sider7.
Fixtures privadas (por exemplo fonte de símbolos) e executável compatível são
necessários para o conjunto completo local; não são necessários para jogar.
Reconstruir artefatos usando somente arquivos publicados:

```powershell
python tools/build_reader_module.py --check
python tools/build_gameplay_module.py
python tools/build_release.py
python -m unittest discover -s tests -p "test_*.py"
```

Os contratos nativos são ignorados sem o executável local; relatórios de pesquisa
referenciam evidências locais não distribuídas. Para uso, migrar pelo guia e navegar
normalmente. Não usar pausa cronometrada para mascarar silêncio.
