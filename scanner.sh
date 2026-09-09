#!/bin/bash

# ==============================================================================
# WP-SECURITY AGENT ENTERPRISE v5.0 (AUDITORIA E DEFESA DE ALTA PRECISÃO)
# ==============================================================================

DATA_HORA=$(date +"%Y-%m-%d_%H-%M-%S")
RELATORIO="relatorio_seguranca_${DATA_HORA}.txt"
WP_ROOT=$(pwd)

CRITICAL_COUNT=0
HIGH_COUNT=0
MEDIUM_COUNT=0
LOW_COUNT=0

# Interface visual do Terminal
C_RESET='\033[0m'
C_RED='\033[1;31m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[1;34m'
C_CYAN='\033[1;36m'
C_BOLD='\033[1m'

clear
echo -e "${C_CYAN}"
echo "  ██╗███╗   ██╗███████╗██████╗ ███████╗██████╗ ███████╗████████╗"
echo "  ██║████╗  ██║██╔════╝██╔══██╗██╔════╝██╔══██╗██╔════╝╚══██╔══╝"
echo "  ██║██╔██╗ ██║███████╗██████╔╝█████╗  ██████╔╝███████╗   ██║   "
echo "  ██║██║╚██╗██║╚════██║██╔═══╝ ██╔══╝  ██╔══██╗╚════██║   ██║   "
echo "  ██║██║ ╚████║███████║██║     ███████╗██║  ██║███████║   ██║   "
echo "  ╚═╝╚═╝  ╚═══╝╚══════╝╚═╝     ╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝   "
echo -e "       AGENTE DE SEGURANÇA ENTERPRISE v5.0 - WORDPRESS ${C_RESET}"
echo -e "${C_BLUE}=================================================================${C_RESET}"
echo -e " Diretório: ${C_BOLD}${WP_ROOT}${C_RESET}"
echo -e " Data      : ${C_BOLD}${DATA_HORA}${C_RESET}"
echo -e "${C_BLUE}=================================================================${C_RESET}\n"

# Função auxiliar para salvar no relatório sem poluir stdout
log_txt() {
    echo -e "$1" >> "$RELATORIO"
}

# Inicializa arquivo de texto
echo "=================================================================" > "$RELATORIO"
echo "       RELATÓRIO DE AUDITORIA DE SEGURANÇA ENTERPRISE v5.0       " >> "$RELATORIO"
echo "=================================================================" >> "$RELATORIO"
echo "Data/Hora: $DATA_HORA" >> "$RELATORIO"
echo "Diretório: $WP_ROOT" >> "$RELATORIO"
echo "=================================================================" >> "$RELATORIO"
echo "" >> "$RELATORIO"

# ------------------------------------------------------------------------------
# 1. INTEGRIDADE DO CORE (CHECKSUM COM WORDPRESS.ORG)
# ------------------------------------------------------------------------------
echo -e "${C_YELLOW}[1/13] Analisando Integridade do Core (API oficial WordPress.org)...${C_RESET}"
log_txt "[1] INTEGRIDADE DO CORE WORDPRESS"
log_txt "-----------------------------------------------------------------"

WP_VER=$(grep '$wp_version =' wp-includes/version.php 2>/dev/null | cut -d"'" -f2)

if [ -n "$WP_VER" ] && command -v curl &> /dev/null; then
    LOCALE=$(grep '$wp_local_package =' wp-includes/version.php 2>/dev/null | cut -d"'" -f2)
    LOCALE=${LOCALE:-"en_US"}
    
    CHECKSUM_JSON=$(curl -s "https://api.wordpress.org/core/checksums/1.0/?version=${WP_VER}&locale=${LOCALE}")
    
    if echo "$CHECKSUM_JSON" | grep -q '"status":"failed"'; then
        log_txt "[ALERTA] Versão do WordPress ($WP_VER) não localizada para checagem de checksum."
    else
        ALTERADOS=0
        while IFS= read -r line; do
            FILE=$(echo "$line" | cut -d':' -f1 | tr -d '"')
            EXPECTED_HASH=$(echo "$line" | cut -d':' -f2 | tr -d '",}')
            
            if [ -f "$FILE" ]; then
                REAL_HASH=$(md5sum "$FILE" | awk '{print $1}')
                if [ "$REAL_HASH" != "$EXPECTED_HASH" ]; then
                    log_txt "[CRÍTICO] Arquivo do Core alterado/adulterado: $FILE"
                    ((CRITICAL_COUNT++))
                    ((ALTERADOS++))
                fi
            fi
        done < <(echo "$CHECKSUM_JSON" | grep -o '"[^"]*":"[a-f0-9]\{32\}"')
        
        if [ $ALTERADOS -eq 0 ]; then
            log_txt "[OK] Todos os arquivos do Core estão 100% autênticos e inalterados (Versão $WP_VER)."
            echo -e "  ${C_GREEN}✓ Core íntegro e autêntico (v$WP_VER)${C_RESET}"
        else
            echo -e "  ${C_RED}✗ $ALTERADOS arquivos originais do WordPress foram modificados!${C_RESET}"
        fi
    fi
else
    log_txt "[AVISO] Não foi possível obter o checksum do Core (curl ausente ou versão indisponível)."
    echo -e "  ${C_YELLOW}! Checagem de Checksum ignorada.${C_RESET}"
fi
echo "" >> "$RELATORIO"

# ------------------------------------------------------------------------------
# 2. VARREDURA AVANÇADA DE CÓDIGO MALICIOSO E WEBSHELLS
# ------------------------------------------------------------------------------
echo -e "${C_YELLOW}[2/13] Escaneando Malware, Webshells e Injeções em código...${C_RESET}"
log_txt "[2] VARREDURA DE AMEAÇAS E CÓDIGO MALICIOSO"
log_txt "-----------------------------------------------------------------"

MALWARE_PATTERNS="eval\s*\(\s*base64_decode|gzinflate\s*\(\s*base64_decode|str_rot13\s*\(\s*base64_decode|\$_POST\[.*\]\s*\(\s*\$_POST|\$GLOBALS\[.*\]\s*\(|class_exists\s*\(\s*['\"]\\\$"

INFECTED=$(find wp-content/ -type f -name "*.php" -exec grep -HnEi "$MALWARE_PATTERNS" {} + 2>/dev/null)

if [ -n "$INFECTED" ]; then
    log_txt "[CRÍTICO] Padrões de malware ativamente detectados:"
    log_txt "$INFECTED"
    COUNT=$(echo "$INFECTED" | wc -l)
    ((CRITICAL_COUNT+=COUNT))
    echo -e "  ${C_RED}✗ $COUNT ameaças críticas encontradas em wp-content!${C_RESET}"
else
    log_txt "[OK] Nenhum padrão ativo de Webshell/Backdoor identificado em plugins e temas."
    echo -e "  ${C_GREEN}✓ Nenhum malware identificado em código PHP${C_RESET}"
fi
echo "" >> "$RELATORIO"

# ------------------------------------------------------------------------------
# 3. VERIFICAÇÃO DE ARQUIVOS OCULTOS E EXECUTÁVEIS EM UPLOADS
# ------------------------------------------------------------------------------
echo -e "${C_YELLOW}[3/13] Inspecionando Mídia, Uploads e Arquivos Ocultos...${C_RESET}"
log_txt "[3] INSPEÇÃO DE UPLOADS E ESTRUTURA"
log_txt "-----------------------------------------------------------------"

PHP_UPLOADS=$(find wp-content/uploads/ -type f -name "*.php" 2>/dev/null)
if [ -n "$PHP_UPLOADS" ]; then
    log_txt "[CRÍTICO] Arquivos PHP executáveis na pasta UPLOADS:"
    log_txt "$PHP_UPLOADS"
    COUNT=$(echo "$PHP_UPLOADS" | wc -l)
    ((CRITICAL_COUNT+=COUNT))
    echo -e "  ${C_RED}✗ Executáveis PHP na pasta de mídia detectados!${C_RESET}"
else
    log_txt "[OK] Nenhum script PHP localizado no diretório de mídia."
    echo -e "  ${C_GREEN}✓ Diretório de Uploads limpo de scripts PHP${C_RESET}"
fi

OCULTOS=$(find . -maxdepth 2 -name ".*" ! -name "." ! -name ".." ! -name ".htaccess" ! -name ".user.ini" ! -name ".git*")
if [ -n "$OCULTOS" ]; then
    log_txt "[MÉDIO] Arquivos ocultos encontrados na raiz:"
    log_txt "$OCULTOS"
    ((MEDIUM_COUNT+=$(echo "$OCULTOS" | wc -l)))
fi
echo "" >> "$RELATORIO"

# ------------------------------------------------------------------------------
# 4. AUDITORIA DE PERMISSÕES E HARDENING DO LINUX
# ------------------------------------------------------------------------------
echo -e "${C_YELLOW}[4/13] Auditando Permissões de Arquivos (CHMOD)...${C_RESET}"
log_txt "[4] HARDENING DE PERMISSÕES"
log_txt "-----------------------------------------------------------------"

PERM_PASTAS=$(find . -type d -perm 0777 2>/dev/null)
if [ -n "$PERM_PASTAS" ]; then
    log_txt "[CRÍTICO] Diretórios com permissão 777 (Acesso público total):"
    log_txt "$PERM_PASTAS"
    ((CRITICAL_COUNT+=$(echo "$PERM_PASTAS" | wc -l)))
    echo -e "  ${C_RED}✗ Pastas inseguras com permissão 777 encontradas${C_RESET}"
else
    log_txt "[OK] Nenhuma pasta do sistema possui permissão 777."
    echo -e "  ${C_GREEN}✓ Permissões de diretório seguras${C_RESET}"
fi

WP_CONF_PERM=$(stat -c "%a" wp-config.php 2>/dev/null)
if [ -n "$WP_CONF_PERM" ] && [ "$WP_CONF_PERM" -gt 644 ]; then
    log_txt "[ALTO] Permissão insegura no wp-config.php ($WP_CONF_PERM)."
    ((HIGH_COUNT++))
else
    log_txt "[OK] wp-config.php ajustado para permissões restritas ($WP_CONF_PERM)."
fi
echo "" >> "$RELATORIO"

# ------------------------------------------------------------------------------
# 5. AUDITORIA DE SEGURANÇA DAS CONFIGURAÇÕES (WP-CONFIG)
# ------------------------------------------------------------------------------
echo -e "${C_YELLOW}[5/13] Checando Diretivas de Segurança do WordPress...${C_RESET}"
log_txt "[5] AUDITORIA DE CONFIGURAÇÃO (WP-CONFIG.PHP)"
log_txt "-----------------------------------------------------------------"

if [ -f wp-config.php ]; then
    if grep -q "DISALLOW_FILE_EDIT.*true" wp-config.php; then
        log_txt "[OK] DISALLOW_FILE_EDIT está ATIVADO (Edição no painel bloqueada)."
        echo -e "  ${C_GREEN}✓ Edição de arquivos via painel desativada${C_RESET}"
    else
        log_txt "[MÉDIO] DISALLOW_FILE_EDIT não ativado no wp-config.php."
        ((MEDIUM_COUNT++))
        echo -e "  ${C_YELLOW}! Edição pelo painel ativa (Adicione DISALLOW_FILE_EDIT)${C_RESET}"
    fi

    if grep -q "put your unique phrase here" wp-config.php; then
        log_txt "[CRÍTICO] Chaves SALT usando string padrão!"
        ((CRITICAL_COUNT++))
    fi
fi
echo "" >> "$RELATORIO"

# ------------------------------------------------------------------------------
# 6. BANCO DE DADOS: INJEÇÕES DE SCRIPT NAS OPÇÕES
# ------------------------------------------------------------------------------
echo -e "${C_YELLOW}[6/13] Verificando Injeções nas Opções do Banco de Dados...${C_RESET}"
log_txt "[6] BANCO DE DADOS (OPÇÕES)"
log_txt "-----------------------------------------------------------------"

if command -v wp &> /dev/null && wp core is-installed --allow-root &>/dev/null; then
    DB_INJECTIONS=$(wp db query "SELECT option_name FROM \$(wp db prefix --allow-root)options WHERE option_value LIKE '%<script%' OR option_value LIKE '%eval(function%';" --allow-root 2>/dev/null)
    if [ -n "$DB_INJECTIONS" ]; then
        log_txt "[CRÍTICO] Injeções de script encontradas na tabela wp_options:"
        log_txt "$DB_INJECTIONS"
        ((CRITICAL_COUNT++))
        echo -e "  ${C_RED}✗ Injeção maliciosa no banco de dados detectada!${C_RESET}"
    else
        log_txt "[OK] Nenhuma injeção evidente de script na tabela wp_options."
        echo -e "  ${C_GREEN}✓ Tabela de opções limpa de scripts maliciosos${C_RESET}"
    fi
else
    log_txt "[INFO] WP-CLI não disponível para varredura do banco de dados (ignorado)."
    echo -e "  ${C_BLUE}ℹ WP-CLI não detectado. Pulando varredura SQL das opções.${C_RESET}"
fi
echo "" >> "$RELATORIO"

# ------------------------------------------------------------------------------
# 7. DETECÇÃO DE ADMINISTRADORES OCULTOS (HIDDEN ADMINS)
# ------------------------------------------------------------------------------
echo -e "${C_YELLOW}[7/13] Auditando Administradores do WordPress (WP-CLI)...${C_RESET}"
log_txt "[7] AUDITORIA DE ADMINISTRADORES (WP_USERS)"
log_txt "-----------------------------------------------------------------"

if command -v wp &> /dev/null && wp core is-installed --allow-root &>/dev/null; then
    ADMINS=$(wp user list --role=administrator --fields=ID,user_login,user_email,user_registered --format=table --allow-root 2>/dev/null)
    log_txt "[INFO] Administradores cadastrados:"
    log_txt "$ADMINS"
    
    ADMIN_COUNT=$(wp user list --role=administrator --format=count --allow-root 2>/dev/null)
    echo -e "  ${C_GREEN}✓ $ADMIN_COUNT usuário(s) com perfil de Administrador listado(s)${C_RESET}"
else
    log_txt "[AVISO] WP-CLI indisponível. Não foi possível auditar usuários administradores."
    echo -e "  ${C_YELLOW}! Auditoria de administradores ignorada (WP-CLI ausente)${C_RESET}"
fi
echo "" >> "$RELATORIO"

# ------------------------------------------------------------------------------
# 8. MONITORAMENTO DE UPLOADS E ALTERAÇÕES RECENTES (24H / 48H)
# ------------------------------------------------------------------------------
echo -e "${C_YELLOW}[8/13] Escaneando Arquivos Modificados/Criados nas últimas 48h em wp-content...${C_RESET}"
log_txt "[8] ARQUIVOS RECENTES EM WP-CONTENT (ÚLTIMAS 48H)"
log_txt "-----------------------------------------------------------------"

RECENT_FILES=$(find wp-content/ -type f -mtime -2 2>/dev/null)

if [ -n "$RECENT_FILES" ]; then
    RECENT_COUNT=$(echo "$RECENT_FILES" | wc -l)
    log_txt "[ALERTA] $RECENT_COUNT arquivo(s) modificado(s) ou criado(s) nas últimas 48h:"
    log_txt "$RECENT_FILES"
    ((MEDIUM_COUNT++))
    echo -e "  ${C_YELLOW}! $RECENT_COUNT arquivos alterados nas últimas 48h em wp-content${C_RESET}"
else
    log_txt "[OK] Nenhum arquivo alterado/criado no diretório wp-content nas últimas 48h."
    echo -e "  ${C_GREEN}✓ Sem alterações recentes em wp-content${C_RESET}"
fi
echo "" >> "$RELATORIO"

# ------------------------------------------------------------------------------
# 9. AUDITORIA DE ARQUIVOS CRÍTICOS DA RAIZ (.HTACCESS, INDEX.PHP, ROBOTS.TXT)
# ------------------------------------------------------------------------------
echo -e "${C_YELLOW}[9/13] Auditando Integridade de Arquivos Críticos (.htaccess, index.php)...${C_RESET}"
log_txt "[9] AUDITORIA DE ARQUIVOS CRÍTICOS E ESTRUTURAIS"
log_txt "-----------------------------------------------------------------"

CRITICAL_FILES=(".htaccess" "index.php" "robots.txt")

for c_file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$c_file" ]; then
        if grep -qE "(eval|base64_decode|gzinflate|auto_prepend_file|RewriteCond.*http)" "$c_file"; then
            log_txt "[CRÍTICO] Injeção de código ou redirecionamento suspeito detectado em: $c_file"
            ((CRITICAL_COUNT++))
            echo -e "  ${C_RED}✗ Suspeita de adulteração no arquivo crítico: $c_file${C_RESET}"
        else
            log_txt "[OK] Arquivo $c_file verificado e sem alterações suspeitas evidentes."
        fi
    fi
done
echo -e "  ${C_GREEN}✓ Validação de arquivos estruturais concluída${C_RESET}"
echo "" >> "$RELATORIO"

# ------------------------------------------------------------------------------
# 10. DETECÇÃO DE REDIRECIONAMENTOS MALICIOSOS (SPAM REDIRECTS)
# ------------------------------------------------------------------------------
echo -e "${C_YELLOW}[10/13] Testando Redirecionamentos Ocultos (Googlebot / Mobile)...${C_RESET}"
log_txt "[10] TESTE DE REDIRECIONAMENTO MALICIOSO (UA SPOOFING)"
log_txt "-----------------------------------------------------------------"

if command -v curl &> /dev/null; then
    SITE_URL=$(grep "WP_HOME\|WP_SITEURL" wp-config.php 2>/dev/null | cut -d"'" -f4 | head -n 1)
    
    if [ -z "$SITE_URL" ] && command -v wp &> /dev/null && wp core is-installed --allow-root &>/dev/null; then
        SITE_URL=$(wp option get siteurl --allow-root 2>/dev/null)
    fi

    if [ -n "$SITE_URL" ]; then
        # Simula visualização de Smartphone Android
        HTTP_MOBILE=$(curl -s -I -A "Mozilla/5.0 (Linux; Android 10; SM-G960F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.181 Mobile Safari/537.36" "$SITE_URL" | grep -i "^location:")
        
        # Simula Crawler do Googlebot
        HTTP_GOOGLE=$(curl -s -I -A "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)" "$SITE_URL" | grep -i "^location:")
        
        if [ -n "$HTTP_MOBILE" ] || [ -n "$HTTP_GOOGLE" ]; then
            log_txt "[CRÍTICO] Redirecionamento condicional ativo detectado!"
            [ -n "$HTTP_MOBILE" ] && log_txt "  Location (Mobile): $HTTP_MOBILE"
            [ -n "$HTTP_GOOGLE" ] && log_txt "  Location (Googlebot): $HTTP_GOOGLE"
            ((CRITICAL_COUNT++))
            echo -e "  ${C_RED}✗ Redirecionamento suspeito detectado para bots/mobile!${C_RESET}"
        else
            log_txt "[OK] Nenhum redirecionamento suspeito para User-Agents de bots ou dispostivos móveis."
            echo -e "  ${C_GREEN}✓ Respostas HTTP limpas para Googlebot e Mobile${C_RESET}"
        fi
    else
        log_txt "[INFO] URL do site não identificada para o teste de redirecionamento HTTP."
        echo -e "  ${C_BLUE}ℹ URL não identificada. Teste ignorado.${C_RESET}"
    fi
else
    log_txt "[AVISO] curl não disponível para simular User-Agents."
fi
echo "" >> "$RELATORIO"

# ------------------------------------------------------------------------------
# 11. DETECÇÃO DE ARQUIVOS TEMPORÁRIOS E BACKUPS ESQUECIDOS
# ------------------------------------------------------------------------------
echo -e "${C_YELLOW}[11/13] Escaneando Backups Esquecidos e Arquivos Temporários...${C_RESET}"
log_txt "[11] ARQUIVOS TEMPORÁRIOS E BACKUPS EXPOSTOS"
log_txt "-----------------------------------------------------------------"

DANGEROUS_EXT=$(find . -maxdepth 3 -type f \( -name "*.zip" -o -name "*.tar.gz" -o -name "*.sql" -o -name "*.bak" -o -name "*.old" -o -name "wp-config.php*" \) ! -name "wp-config.php" 2>/dev/null)

if [ -n "$DANGEROUS_EXT" ]; then
    log_txt "[ALTO] Arquivos de backup/temporários sensíveis encontrados no servidor:"
    log_txt "$DANGEROUS_EXT"
    COUNT=$(echo "$DANGEROUS_EXT" | wc -l)
    ((HIGH_COUNT+=COUNT))
    echo -e "  ${C_RED}✗ $COUNT arquivo(s) de backup ou arquivos .sql/.zip expostos!${C_RESET}"
else
    log_txt "[OK] Nenhum arquivo de backup solto ou dump SQL identificado na raiz."
    echo -e "  ${C_GREEN}✓ Nenhum backup residual (.zip, .sql, .bak) detectado${C_RESET}"
fi
echo "" >> "$RELATORIO"

# ------------------------------------------------------------------------------
# 12. ANÁLISE DE CRON JOBS (TAREFAS AGENDADAS)
# ------------------------------------------------------------------------------
echo -e "${C_YELLOW}[12/13] Analisando Tarefas Agendadas (WordPress Cron)...${C_RESET}"
log_txt "[12] ANÁLISE DO WORDPRESS CRON"
log_txt "-----------------------------------------------------------------"

if command -v wp &> /dev/null && wp core is-installed --allow-root &>/dev/null; then
    CRON_EVENTS=$(wp cron event list --allow-root 2>/dev/null)
    log_txt "[INFO] Lista de eventos agendados no WP-Cron:"
    log_txt "$CRON_EVENTS"
    
    # Busca por padrões suspeitos nas rotinas cron
    SUSPICIOUS_CRON=$(echo "$CRON_EVENTS" | grep -Ei "eval|base64|temp_|shell|exec")
    if [ -n "$SUSPICIOUS_CRON" ]; then
        log_txt "[CRÍTICO] Hook suspeito identificado no WP-Cron:"
        log_txt "$SUSPICIOUS_CRON"
        ((CRITICAL_COUNT++))
        echo -e "  ${C_RED}✗ Hook de Cron altamente suspeito detectado!${C_RESET}"
    else
        log_txt "[OK] Eventos no WP-Cron sem padrões evidentes de malware."
        echo -e "  ${C_GREEN}✓ Cron Jobs auditados e validados${C_RESET}"
    fi
else
    log_txt "[INFO] WP-CLI não disponível para listar tarefas do WP-Cron."
    echo -e "  ${C_BLUE}ℹ WP-CLI não detectado. Pulando análise do Cron.${C_RESET}"
fi
echo "" >> "$RELATORIO"

# ------------------------------------------------------------------------------
# 13. DETECÇÃO DE MALWARE NAS TABELAS DE CONTEÚDO (WP_POSTS)
# ------------------------------------------------------------------------------
echo -e "${C_YELLOW}[13/13] Escaneando Tabela de Posts por iFrames e Links Spam...${C_RESET}"
log_txt "[13] AUDITORIA DE CONTEÚDO MALICIOSO (WP_POSTS)"
log_txt "-----------------------------------------------------------------"

if command -v wp &> /dev/null && wp core is-installed --allow-root &>/dev/null; then
    MALICIOUS_POSTS=$(wp db query "SELECT ID, post_title FROM \$(wp db prefix --allow-root)posts WHERE post_content LIKE '%<iframe%' OR post_content LIKE '%display:none%' OR post_content LIKE '%visibility:hidden%' OR post_content LIKE '%eval(%' AND post_status = 'publish';" --allow-root 2>/dev/null)
    
    if [ -n "$MALICIOUS_POSTS" ]; then
        log_txt "[ALTO] iFrames invisíveis ou trechos maliciosos em wp_posts:"
        log_txt "$MALICIOUS_POSTS"
        ((HIGH_COUNT++))
        echo -e "  ${C_RED}✗ Injeção de iFrame/conteúdo oculto encontrado nos posts!${C_RESET}"
    else
        log_txt "[OK] Nenhum iFrame invisível ou injeção de spam detectada em wp_posts."
        echo -e "  ${C_GREEN}✓ Tabela de posts limpa de scripts/iFrames nocivos${C_RESET}"
    fi
else
    log_txt "[INFO] WP-CLI não disponível para varredura na tabela wp_posts."
    echo -e "  ${C_BLUE}ℹ WP-CLI não detectado. Pulando varredura da wp_posts.${C_RESET}"
fi
echo "" >> "$RELATORIO"

# ------------------------------------------------------------------------------
# CÁLCULO DO SCORE E DASHBOARD FINAL
# ------------------------------------------------------------------------------
TOTAL_PENALIDADE=$(( (CRITICAL_COUNT * 30) + (HIGH_COUNT * 15) + (MEDIUM_COUNT * 5) + (LOW_COUNT * 2) ))
SCORE=$((100 - TOTAL_PENALIDADE))
if [ $SCORE -lt 0 ]; then SCORE=0; fi

STARS="5/5 ★★★★★"
RISCO_TEXTO="MUITO BAIXO (Ambiente Protegido)"
COR_RISCO=$C_GREEN

if [ $SCORE -lt 40 ]; then
    STARS="1/5 ★☆☆☆☆"
    RISCO_TEXTO="CRÍTICO (Ação Imediata Necessária)"
    COR_RISCO=$C_RED
elif [ $SCORE -lt 70 ]; then
    STARS="2/5 ★★☆☆☆"
    RISCO_TEXTO="ALTO (Vulnerável)"
    COR_RISCO=$C_RED
elif [ $SCORE -lt 85 ]; then
    STARS="3/5 ★★★☆☆"
    RISCO_TEXTO="MÉDIO (Requer Ajustes)"
    COR_RISCO=$C_YELLOW
elif [ $SCORE -lt 99 ]; then
    STARS="4/5 ★★★★☆"
    RISCO_TEXTO="BAIXO (Hardening Parcial)"
    COR_RISCO=$C_YELLOW
fi

# Grava conclusão no TXT
log_txt "================================================================="
log_txt "                    AVALIAÇÃO DE SEGURANÇA                       "
log_txt "================================================================="
log_txt "Ameaças Críticas Found : $CRITICAL_COUNT"
log_txt "Ameaças Altas Found    : $HIGH_COUNT"
log_txt "Ameaças Médias Found   : $MEDIUM_COUNT"
log_txt "-----------------------------------------------------------------"
log_txt "NOTA DE SEGURANÇA      : $STARS ($SCORE/100)"
log_txt "NÍVEL DE RISCO         : $RISCO_TEXTO"
log_txt "================================================================="

# Renderiza Dashboard no Terminal
echo -e "${C_BLUE}=================================================================${C_RESET}"
echo -e "                   ${C_BOLD}DASHBOARD DE AUDITORIA v5.0${C_RESET}                   "
echo -e "${C_BLUE}=================================================================${C_RESET}"
printf "  %-28s : %s\n" "Ameaças Críticas" "${CRITICAL_COUNT}"
printf "  %-28s : %s\n" "Ameaças Altas" "${HIGH_COUNT}"
printf "  %-28s : %s\n" "Ameaças Médias" "${MEDIUM_COUNT}"
echo -e "${C_BLUE}-----------------------------------------------------------------${C_RESET}"
printf "  %-28s : ${COR_RISCO}%s${C_RESET}\n" "Pontuação" "${SCORE}/100"
printf "  %-28s : ${COR_RISCO}%s${C_RESET}\n" "Nota de Segurança" "${STARS}"
printf "  %-28s : ${COR_RISCO}%s${C_RESET}\n" "Nível de Risco" "${RISCO_TEXTO}"
echo -e "${C_BLUE}=================================================================${C_RESET}\n"

echo -e "${C_GREEN}[+] Relatório detalhado salvo em: ${C_BOLD}${RELATORIO}${C_RESET}\n"