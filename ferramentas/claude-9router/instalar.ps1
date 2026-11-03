# Instalador: Claude oficial + 9router ao mesmo tempo (Windows / PowerShell)
#
# O que ele faz:
#   1. Cria o comando "claude9": abre o Claude Code passando pelo 9router,
#      com configuracao separada (~/.claude-9router), sem mexer no "claude" oficial.
#   2. Compartilha com o claude9 as suas skills, agentes, comandos, plugins e o CLAUDE.md global.
#   3. Instala a "ponte-9router" no Claude oficial: ele pode mandar tarefas para o 9router.
#   4. Avisa se o 9router esta configurado de forma global (o que tira os recursos da sua conta).
#
# Uso (no PowerShell, dentro desta pasta):
#   powershell -ExecutionPolicy Bypass -File .\instalar.ps1

param(
  [string]$UrlRouter = "",
  [string]$ChaveRouter = "",
  [string]$ModeloPadrao = ""
)

$ErrorActionPreference = "Stop"
$Aqui = Split-Path -Parent $MyInvocation.MyCommand.Path
$Oficial = Join-Path $HOME ".claude"
$Alt = Join-Path $HOME ".claude-9router"

Write-Host "`n=== Claude oficial + 9router ===`n" -ForegroundColor Cyan

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
  throw "O comando 'claude' nao foi encontrado. Instale o Claude Code primeiro."
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  throw "O Node.js nao foi encontrado (precisa da versao 18 ou mais nova)."
}

if (-not $UrlRouter) {
  $UrlRouter = Read-Host "Endereco do 9router (o mesmo que voce usou como ANTHROPIC_BASE_URL, ex.: http://localhost:20128)"
}
$UrlRouter = $UrlRouter.TrimEnd("/")
if ($UrlRouter.EndsWith("/v1")) { $UrlRouter = $UrlRouter.Substring(0, $UrlRouter.Length - 3) }
if (-not $ChaveRouter) {
  $ChaveRouter = Read-Host "Chave/token do 9router (Enter se nao tiver)"
}
if (-not $ModeloPadrao) {
  $ModeloPadrao = Read-Host "Modelo padrao para a ponte (Enter para escolher depois)"
}

# --- 1. Verifica configuracao global do 9router -------------------------------
$globalUrl = [Environment]::GetEnvironmentVariable("ANTHROPIC_BASE_URL", "User")
if ($globalUrl) {
  Write-Host "`nATENCAO: ANTHROPIC_BASE_URL esta definida para todo o Windows ($globalUrl)." -ForegroundColor Yellow
  Write-Host "Assim o 'claude' oficial tambem passa pelo 9router e perde os recursos da sua conta."
  $r = Read-Host "Remover essa variavel global? O 9router continua disponivel pelo 'claude9' (s/n)"
  if ($r -eq "s") {
    [Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", $null, "User")
    [Environment]::SetEnvironmentVariable("ANTHROPIC_AUTH_TOKEN", $null, "User")
    Remove-Item Env:ANTHROPIC_BASE_URL -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
    Write-Host "Removida. Abra um terminal novo depois da instalacao." -ForegroundColor Green
  }
}
$settingsOficial = Join-Path $Oficial "settings.json"
if ((Test-Path $settingsOficial) -and ((Get-Content $settingsOficial -Raw) -match "ANTHROPIC_BASE_URL")) {
  Write-Host "`nATENCAO: $settingsOficial tem ANTHROPIC_BASE_URL no bloco 'env'." -ForegroundColor Yellow
  Write-Host "Apague essa linha (e ANTHROPIC_AUTH_TOKEN, se houver) para o 'claude' oficial voltar a usar sua conta."
}

# --- 2. Configuracao separada para o claude9, compartilhando o que importa ---
New-Item -ItemType Directory -Force -Path $Oficial | Out-Null
New-Item -ItemType Directory -Force -Path $Alt | Out-Null

foreach ($pasta in @("skills", "agents", "commands", "plugins")) {
  $origem = Join-Path $Oficial $pasta
  $destino = Join-Path $Alt $pasta
  New-Item -ItemType Directory -Force -Path $origem | Out-Null
  if (Test-Path $destino) {
    $item = Get-Item $destino -Force
    if ($item.LinkType -eq "Junction") { continue }
    Write-Host "Ja existe $destino (pasta comum). Deixei como esta." -ForegroundColor Yellow
    continue
  }
  New-Item -ItemType Junction -Path $destino -Target $origem | Out-Null
  Write-Host "Compartilhado: $pasta"
}

$memOficial = Join-Path $Oficial "CLAUDE.md"
$memAlt = Join-Path $Alt "CLAUDE.md"
if (-not (Test-Path $memOficial)) {
  Set-Content -Path $memOficial -Encoding UTF8 -Value "# Minhas regras para o Claude`n`n- Responda em portugues.`n"
}
if (-not (Test-Path $memAlt)) {
  New-Item -ItemType HardLink -Path $memAlt -Target $memOficial | Out-Null
  Write-Host "Compartilhado: CLAUDE.md global"
}

$settingsAlt = Join-Path $Alt "settings.json"
if ((Test-Path $settingsOficial) -and -not (Test-Path $settingsAlt)) {
  Copy-Item $settingsOficial $settingsAlt
  Write-Host "Copiado: settings.json (plugins ativados e permissoes)"
}

# Copia a ponte para um lugar fixo
$ponte = Join-Path $Alt "ponte-9router.mjs"
Copy-Item (Join-Path $Aqui "ponte-9router.mjs") $ponte -Force

# Guarda a configuracao do router (so no seu usuario)
$cfg = @{ url = $UrlRouter; chave = $ChaveRouter; modelo = $ModeloPadrao } | ConvertTo-Json
Set-Content -Path (Join-Path $Alt "9router.json") -Value $cfg -Encoding UTF8

# --- 3. Comando claude9 no perfil do PowerShell -------------------------------
$marcaIni = "# >>> claude9 (9router) >>>"
$marcaFim = "# <<< claude9 (9router) <<<"
$bloco = @"
$marcaIni
function claude9 {
  `$cfg = Get-Content (Join-Path `$HOME ".claude-9router\9router.json") -Raw | ConvertFrom-Json
  `$nomes = "CLAUDE_CONFIG_DIR","ANTHROPIC_BASE_URL","ANTHROPIC_AUTH_TOKEN"
  `$antes = @{}; foreach (`$n in `$nomes) { `$antes[`$n] = [Environment]::GetEnvironmentVariable(`$n, "Process") }
  try {
    `$env:CLAUDE_CONFIG_DIR = Join-Path `$HOME ".claude-9router"
    `$env:ANTHROPIC_BASE_URL = `$cfg.url
    if (`$cfg.chave) { `$env:ANTHROPIC_AUTH_TOKEN = `$cfg.chave }
    claude @args
  } finally {
    foreach (`$n in `$nomes) { [Environment]::SetEnvironmentVariable(`$n, `$antes[`$n], "Process") }
  }
}
$marcaFim
"@

if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Force -Path $PROFILE | Out-Null }
$perfil = Get-Content $PROFILE -Raw
if ($null -eq $perfil) { $perfil = "" }
$padrao = "(?s)" + [regex]::Escape($marcaIni) + ".*?" + [regex]::Escape($marcaFim) + "\r?\n?"
$perfil = [regex]::Replace($perfil, $padrao, "")
Set-Content -Path $PROFILE -Value ($perfil.TrimEnd() + "`r`n`r`n" + $bloco + "`r`n") -Encoding UTF8
Write-Host "Comando 'claude9' adicionado em $PROFILE"

# --- 4. Ponte no Claude oficial ----------------------------------------------
$urlV1 = "$UrlRouter/v1"
$envs = @("-e", "NINE_ROUTER_URL=$urlV1")
if ($ChaveRouter) { $envs += @("-e", "NINE_ROUTER_KEY=$ChaveRouter") }
if ($ModeloPadrao) { $envs += @("-e", "NINE_ROUTER_MODEL=$ModeloPadrao") }

$salvo = $env:CLAUDE_CONFIG_DIR
Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue
& claude mcp remove ponte-9router --scope user 2>$null | Out-Null
& claude mcp add ponte-9router --scope user @envs -- node $ponte
if ($salvo) { $env:CLAUDE_CONFIG_DIR = $salvo }
Write-Host "Ponte 'ponte-9router' instalada no Claude oficial."

Write-Host "`n=== Pronto ===" -ForegroundColor Green
Write-Host "Feche e abra o terminal. Depois:"
Write-Host "  claude    -> Claude oficial, com sua conta (rode /login se pedir)"
Write-Host "  claude9   -> Claude passando pelo 9router, com as mesmas skills e plugins"
Write-Host "No Claude oficial, peca: 'use o 9router para fazer X' (ferramenta perguntar_9router)."
