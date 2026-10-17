# Migração pra Windows — guia de retomada

Escrito em 2026-10-17, antes de formatar os 2 discos atuais (Linux). Tudo
que está registrado aqui é pra uma sessão nova (Claude Code ou você mesmo)
conseguir reconstruir o ambiente de trabalho do zero só com este repositório
clonado — sem depender de nada que ficou pra trás na máquina antiga.

## O que já está 100% seguro (viaja com `git clone`)

- Todo o código do cliente Godot (`client/scripts`, `client/scenes`) e do
  servidor FastAPI (`server/`).
- Os 733 arquivos de assets do jogo (sprites, UI, áudio) em `client/assets/`.
- Toda a documentação de projeto (`.project/ARCHITECTURE.md`,
  `.project/SPRITE_PIPELINE.md`, `.project/ART_PROMPTS.md`,
  `.project/STATE.md` — o checkpoint longo de cada rodada de trabalho) e as
  regras de arquitetura/UI em `.clauderules`.
- `.project/diario_de_design.docx` — suas anotações originais de design do
  jogo (estavam soltas em `~/Downloads`, copiadas pra cá nesta rodada).
- Os 4 branches (`main`, `dev`, `feature/town-hub-redesign`,
  `feature/issue-4-ship-movement`) já estão sincronizados com
  `origin` em `github.com/fagundessouza/Navizin` (repositório **público**).
  `feature/town-hub-redesign` é o branch com o trabalho ativo mais recente.

## O que NÃO está no repositório (de propósito) e precisa ser refeito

### 1. Godot 4.7.2

Baixe exatamente a versão `4.7.2.stable.official` em
`godotengine.org/download/windows` (build Standard, não a `.NET`, a menos
que algum script C# tenha entrado no projeto depois desta data — hoje não
há nenhum). Versões diferentes de 4.7.x costumam abrir o projeto sem
drama, mas evite usar uma major diferente (4.8+) sem testar antes.

### 2. Godot MCP Toolkit (addon do editor + ponte MCP)

Isto é ferramenta de desenvolvimento, não faz parte do jogo — por isso
`client/addons/godot_mcp_toolkit/`, `.mcp.json` e `client/.mcp.json` nunca
foram commitados (ver histórico em `.project/STATE.md` linha ~415).
Addon público, versão usada aqui: `1.0.3`.

1. Baixe o addon em `github.com/NPGameDev/godot-mcp-toolkit` e copie a
   pasta `addons/godot_mcp_toolkit/` pra dentro de `client/addons/`.
2. Abra o projeto no editor Godot. Vá em **Project Settings → Plugins** e
   ative **Godot MCP Toolkit**.
3. Use o próprio menu do addon — **Project → Tools → MCP Toolkit → Write
   .mcp.json** — pra gerar o `.mcp.json` já correto pra Windows (ele
   detecta a plataforma sozinho, não copie o `.mcp.json` antigo do Linux
   direto).
4. **Se o Claude Code não conectar** com o `.mcp.json` gerado automático: a
   sessão Linux teve um bug onde o campo `cwd` do `.mcp.json` não era
   respeitado, e a correção foi fazer o próprio comando mudar de diretório
   antes de rodar a ponte:
   ```json
   {
     "mcpServers": {
       "godot-mcp-toolkit": {
         "command": "cmd",
         "args": ["/c", "cd /d <CAMINHO_DO_PROJETO>\\client && npx -y @npgamedev/godot-mcp-server"],
         "env": { "GODOT_MCP_CONFIG_VERSION": "1" }
       }
     }
   }
   ```
   (No Linux o equivalente era `"command": "sh", "args": ["-c", "cd ... && exec npx ..."]` —
   troque pra essa forma `cmd /c` se estiver rodando Claude Code nativo no
   Windows; se estiver rodando dentro do WSL, a forma `sh -c` original
   funciona igual, só ajustando o caminho pra dentro do WSL.)
5. Precisa de **Node.js 22+** instalado (o `npx` busca o pacote
   `@npgamedev/godot-mcp-server` sozinho na primeira conexão).

### 3. Disciplina de higiene do `project.godot` (não é opcional)

`client/project.godot` tem uma linha de autoload (`MCPRuntimeServer=...`)
e um bloco `[editor_plugins]` que só devem existir **localmente**, nunca
num commit:

- Antes de QUALQUER `git commit` que toque `client/project.godot`: remova
  a linha `MCPRuntimeServer="*res://addons/godot_mcp_toolkit/..."` do
  `[autoload]` e o bloco `[editor_plugins]` inteiro.
- Depois do `git push`: restaure as duas coisas de volta (precisa delas
  ativas localmente pra MCP funcionar).
- Isso se repetiu em toda rodada de trabalho desta sessão — é o padrão
  esperado, não um bug.

### 4. Git / GitHub

Configure uma chave SSH nova no Windows (ou use HTTPS + `gh auth login`) e
associe à sua conta GitHub. O remote já aponta pra
`git@github.com:fagundessouza/Navizin.git` — só precisa de credencial nova
na máquina nova, não precisa copiar a chave antiga.

### 5. Claude Code CLI

Instale normalmente pro Windows. Se quiser preservar a memória entre
sessões (preferências registradas, checkpoints de rodadas passadas), copie
a pasta `~/.claude/projects/-home-lucas-navizin/memory/` da máquina antiga
ANTES de formatar — ela não é versionada neste repositório. Se não copiar,
tudo bem: o essencial pra continuar o trabalho já está consolidado em
`.project/STATE.md` e `.clauderules` (que viajam com o `git clone`), e a
seção 6 abaixo resume as regras de processo que só existiam na memória.

### 6. Regras de processo que só existiam na memória do Claude (resumo)

Pra não se perder caso a memória entre sessões não seja copiada:

- **Nunca afirmar "verificado" sem rodar o jogo de verdade** (MCP:
  `game_start`/`execute_code`/`input_simulate`/`runtime_screenshot`), não
  só ler o código ou rodar um script de teste isolado.
- **Nunca inventar nomes/contagens de assets.** Sempre escanear a pasta
  real (`client/assets/...`) ou o `item_database.gd` antes de escrever
  qualquer lista de itens.
- **Specs coladas pelo usuário podem estar erradas** (arquivo que não
  existe, diagnóstico equivocado) — sempre confirmar rodando o jogo antes
  de aceitar o diagnóstico como verdade.
- **Calibração de UI contra arte pintada:** nunca estimar posição de
  ícone por "olhômetro" em screenshot — ler a textura-fonte com detecção
  de cor por pixel (`PIL`) pra achar a posição exata.
- Mais detalhes e o histórico completo de cada rodada: `.project/STATE.md`.

### 7. (Opcional) Servidor FastAPI / infra

Só necessário se for continuar o lado servidor também — ver `README.md`
na raiz. No Windows, troque Podman nativo por **Podman Desktop** (ou
Docker Desktop, ajustando `docker-compose.yml`) e `make` por
**Make for Windows** ou rodando os comandos do `Makefile` manualmente.

## O que ficou pra trás de propósito (confirmado com o usuário em 2026-10-17)

- **ComfyUI** (`~/ai_tools/ComfyUI`, ~11GB) — pipeline local de geração de
  arte, não estava em uso no momento da migração. Não documentado aqui a
  pedido explícito do usuário; reinstalar do zero se for preciso gerar
  mais arte no mesmo estilo.
- **Addon "lit"** (shader de iluminação) — estava instalado em
  `client/addons/lit/` mas não é referenciado em nenhuma cena/script do
  projeto. Descartado a pedido explícito do usuário; é um addon público
  do Asset Library do Godot, reinstala rápido se algum dia for usado de
  verdade.

## Checklist rápido pra retomar

1. `git clone git@github.com:fagundessouza/Navizin.git` (ou HTTPS)
2. `git checkout feature/town-hub-redesign`
3. Instalar Godot 4.7.2.stable, abrir `client/project.godot`
4. Instalar Node.js 22+
5. Reinstalar o addon MCP Toolkit (seção 2) e gerar `.mcp.json` novo
6. Instalar Claude Code CLI, rodar `claude` dentro da pasta do projeto
7. Pedir pra continuar o trabalho a partir de `.project/STATE.md`
