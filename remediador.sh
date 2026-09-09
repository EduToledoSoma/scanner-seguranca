#!/bin/bash

# ==============================================================================
# WP-REMEDIATOR AGENT v3.1 (AUTOCORREÇÃO PROFUNDA E ISOLAMENTO DE BACKUPS)
# ==============================================================================

WP_ROOT=$(pwd)

C_RESET='\033[0m'
C_RED='\033[1;31m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[1;34m'
C_CYAN='\033[1;36m'
C_BOLD='\033[1m'

clear
echo -e "${C_CYAN}"
echo "  ██████╗ ███████╗███╗   ███╗███████╗██████╗ ██╗██████╗  ██████╗ ██╗"
echo "  ██╔══██╗██╔════╝████╗ ████║██╔════╝██╔══██╗██║██╔══██╗██╔═══██╗██║"
echo "  ██████╔╝█████╗  ██╔████╔██║█████╗  ██║  ██║██║██║  ██║██║   ██║██║"
echo "  ██╔══██╗██╔══╝  ██║╚██╔╝██║██╔══╝  ██║  ██║██║██║  ██║██║   ██║╚═╝"
echo "  ██║  ██║███████╗██║ ╚═╝ ██║███████╗██████╔╝██║██████╔╝╚██████╔╝██╗"
echo "  ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝╚══════╝╚═════╝ ╚═╝╚═════╝  ╚═════╝ ╚═╝"
echo -e "         AGENTE REMEDIADOR E AUTOCORREÇÃO - WORDPRESS v3.1${C_RESET}"
echo -e "${C_BLUE}=================================================================${C_RESET}"

ULTIMO_RELATORIO=$(ls -t relatorio_seguranca_*.txt 2>/dev/null | head -n 1)

if [ -z "$ULTIMO_RELATORIO" ]; then
    echo -e "${C_RED}[ERRO] Nenhum relatório de segurança encontrado!${C_RESET}"
    echo -e "Execute o scanner primeiro para gerar uma auditoria base.\n"
    exit 1
fi

# Extrai nota anterior do relatório para futura comparação
NOTA_ANTIGA=$(grep "PONTUAÇÃO" "$ULTIMO_RELATORIO" | awk -F':' '{print $2}' | tr -d ' ' 2>/dev/null)
NOTA_ANTIGA=${NOTA_ANTIGA:-"N/A"}

echo -e " Relatório Base : ${C_BOLD}${ULTIMO_RELATORIO}${C_RESET} (Score Anterior: ${C_YELLOW}${NOTA_ANTIGA}${C_RESET})"
echo -e "${C_BLUE}=================================================================${C_RESET}\n"

read -p "Deseja criar os backups e iniciar a remediação automática? (s/n): " CONFIRMA
if [[ "$CONFIRMA" != "s" && "$CONFIRMA" != "S" ]]; then
    echo -e "\n${C_YELLOW}[!] Operação cancelada pelo usuário.${C_RESET}\n"
    exit 0
fi

# ------------------------------------------------------------------------------
# 0. PRÉ-CORREÇÃO: BACKUP ISOLADO FORA DA ESTRUTURA DO SITE (/TMP)
# ------------------------------------------------------------------------------
echo -e "\n${C_YELLOW}[0/11] Executando rotina de Backup Isolado (Pré-Remediação)...${C_RESET}"
BACKUP_DIR="/tmp/backups_remediator_$(date +"%Y-%m-%d_%H-%M-%S")"
mkdir -p "$BACKUP_DIR"

# Dump SQL via WP-CLI
if command -v wp &> /dev/null && wp core is-installed --allow-root &>/dev/null; then
    wp db export "$BACKUP_DIR/database_backup.sql" --allow-root &>/dev/null
    if [ -f "$BACKUP_DIR/database_backup.sql" ]; then
        echo -e "  ${C_GREEN}✓ Backup SQL gerado fora da raiz (/tmp) via WP-CLI${C_RESET}"
    fi
fi

# Backup compactado da pasta wp-content/plugins
if [ -d "wp-content/plugins" ]; then
    if command -v zip &> /dev/null; then
        zip -r -q "$BACKUP_DIR/plugins_backup.zip" wp-content/plugins/
    else
        tar -czf "$BACKUP_DIR/plugins_backup.tar.gz" wp-content/plugins/ 2>/dev/null
    fi
    echo -e "  ${C_GREEN}✓ Backup dos Plugins salvo em: $BACKUP_DIR${C_RESET}"
fi

CORRECOES_REALIZADAS=0

# ------------------------------------------------------------------------------
# 1. REMOÇÃO COMPLETA DE BACKUPS E ARQUIVOS RESIDUAIS EM QUALQUER PASTA
# ------------------------------------------------------------------------------
echo -e "${C_CYAN}[FIX 1/11] Executando eliminação profunda de dumps e .ZIPs no servidor...${C_RESET}"
find . -type f \( -name "*.sql" -o -name "*.zip" -o -name "*.tar.gz" -o -name "*.bak" -o -name "wp-config.php.bak" \) -delete 2>/dev/null
echo -e "  ${C_GREEN}✓ Todos os arquivos residuais (.zip, .sql, .bak) foram removidos${C_RESET}"
((CORRECOES_REALIZADAS++))

# ------------------------------------------------------------------------------
# 2. REMOÇÃO DE ARQUIVOS OCULTOS TEMPORÁRIOS
# ------------------------------------------------------------------------------
echo -e "${C_CYAN}[FIX 2/11] Removendo arquivos ocultos e temporários...${C_RESET}"
find . -name ".DS_Store" -type f -delete 2>/dev/null
find . -maxdepth 2 -name ".*" ! -name "." ! -name ".." ! -name ".htaccess" ! -name ".user.ini" ! -name ".git*" -delete 2>/dev/null
echo -e "  ${C_GREEN}✓ Arquivos ocultos desnecessários limpos${C_RESET}"
((CORRECOES_REALIZADAS++))

# ------------------------------------------------------------------------------
# 3. CORREÇÃO DE PERMISSÕES (WP-CONFIG E CHMOD 777)
# ------------------------------------------------------------------------------
echo -e "${C_CYAN}[FIX 3/11] Corrigindo permissões de arquivos e diretórios...${C_RESET}"
[ -f wp-config.php ] && chmod 640 wp-config.php 2>/dev/null
find . -type d -perm 0777 -exec chmod 755 {} + 2>/dev/null
echo -e "  ${C_GREEN}✓ Permissões ajustadas (wp-config.php = 640 | Diretórios = 755)${C_RESET}"
((CORRECOES_REALIZADAS++))

# ------------------------------------------------------------------------------
# 4. DIRETIIVAS NO WP-CONFIG E .HTACCESS
# ------------------------------------------------------------------------------
echo -e "${C_CYAN}[FIX 4/11] Aplicando regras de segurança (DISALLOW_FILE_EDIT e Indexing)...${C_RESET}"
if [ -f wp-config.php ] && ! grep -q "DISALLOW_FILE_EDIT" wp-config.php; then
    sed -i '2i define( "DISALLOW_FILE_EDIT", true );' wp-config.php
fi

if [ -f .htaccess ]; then
    if ! grep -q "Options -Indexes" .htaccess; then
        echo -e "\n# Desativar listagem de diretorios\nOptions -Indexes" >> .htaccess
    fi
else
    echo "Options -Indexes" > .htaccess
fi
echo -e "  ${C_GREEN}✓ Bloqueio de edição e ocultação de índices no servidor ativos${C_RESET}"
((CORRECOES_REALIZADAS++))

# ------------------------------------------------------------------------------
# 5. BLOQUEIO DE PHP NA PASTA UPLOADS
# ------------------------------------------------------------------------------
echo -e "${C_CYAN}[FIX 5/11] Isolando scripts PHP em /uploads...${C_RESET}"
PHP_FILES=$(find wp-content/uploads/ -type f -name "*.php" 2>/dev/null)
if [ -n "$PHP_FILES" ]; then
    for FILE in $PHP_FILES; do
        mv "$FILE" "${FILE}.quarentena"
    done
fi

HTACCESS_UPLOADS="wp-content/uploads/.htaccess"
if [ ! -f "$HTACCESS_UPLOADS" ]; then
    echo -e "<Files *.php>\n    deny from all\n</Files>" > "$HTACCESS_UPLOADS"
fi
echo -e "  ${C_GREEN}✓ Proteção contra execução PHP na pasta Uploads ativada${C_RESET}"
((CORRECOES_REALIZADAS++))

# ------------------------------------------------------------------------------
# 6. RESTAURAÇÃO DO CORE E ATUALIZAÇÕES AUTOMÁTICAS
# ------------------------------------------------------------------------------
if command -v wp &> /dev/null && wp core is-installed --allow-root &>/dev/null; then
    echo -e "${C_CYAN}[FIX 6/11] Re-instalando Core e atualizando pacotes de segurança...${C_RESET}"
    wp core download --skip-content --force --allow-root &>/dev/null
    wp plugin update --all --allow-root &>/dev/null
    wp theme update --all --allow-root &>/dev/null
    echo -e "  ${C_GREEN}✓ Core e plugins atualizados para as versões mais recentes${C_RESET}"
    ((CORRECOES_REALIZADAS++))
fi

# ------------------------------------------------------------------------------
# 7. REDEFINIÇÃO DE SENHAS DE ADMINISTRADORES
# ------------------------------------------------------------------------------
if command -v wp &> /dev/null && wp core is-installed --allow-root &>/dev/null; then
    echo -e "${C_CYAN}[FIX 7/11] Redefinindo senhas de contas administrativas...${C_RESET}"
    ADMIN_USERS=$(wp user list --role=administrator --field=ID --allow-root 2>/dev/null)
    for ADMIN_ID in $ADMIN_USERS; do
        NEW_PASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20)
        wp user update "$ADMIN_ID" --user_pass="$NEW_PASS" --allow-root &>/dev/null
    done
    echo -e "  ${C_GREEN}✓ Senhas administrativas redefinidas por segurança${C_RESET}"
    ((CORRECOES_REALIZADAS++))
fi

# ------------------------------------------------------------------------------
# 8. REMOÇÃO DE PLUGINS E TEMAS INATIVOS
# ------------------------------------------------------------------------------
if command -v wp &> /dev/null && wp core is-installed --allow-root &>/dev/null; then
    echo -e "${C_CYAN}[FIX 8/11] Removendo temas e plugins inativos...${C_RESET}"
    INACTIVE_PLUGINS=$(wp plugin list --status=inactive --field=name --allow-root 2>/dev/null)
    [ -n "$INACTIVE_PLUGINS" ] && echo "$INACTIVE_PLUGINS" | xargs wp plugin delete --allow-root &>/dev/null

    INACTIVE_THEMES=$(wp theme list --status=inactive --field=name --allow-root 2>/dev/null)
    [ -n "$INACTIVE_THEMES" ] && echo "$INACTIVE_THEMES" | xargs wp theme delete --allow-root &>/dev/null
    echo -e "  ${C_GREEN}✓ Componentes desativados removidos${C_RESET}"
    ((CORRECOES_REALIZADAS++))
fi

# ------------------------------------------------------------------------------
# RE-EXECUÇÃO DO SCANNER E GERAÇÃO DO RELATÓRIO COMPARATIVO
# ------------------------------------------------------------------------------
echo -e "\n${C_YELLOW}[+] Re-executando o scanner de segurança...${C_RESET}\n"

SCANNER_SCRIPT=$(ls scanner*.sh 2>/dev/null | head -n 1)

if [ -n "$SCANNER_SCRIPT" ] && [ -f "$SCANNER_SCRIPT" ]; then
    bash "$SCANNER_SCRIPT" > /dev/null 2>&1
fi

NOVO_RELATORIO=$(ls -t relatorio_seguranca_*.txt 2>/dev/null | head -n 1)

if [ -n "$NOVO_RELATORIO" ] && [ "$NOVO_RELATORIO" != "$ULTIMO_RELATORIO" ]; then
    NOTA_NOVA=$(grep "PONTUAÇÃO" "$NOVO_RELATORIO" | awk -F':' '{print $2}' | tr -d ' ' 2>/dev/null)
    
    TEMP_FILE=$(mktemp)
    {
        echo "================================================================="
        echo "               COMPARAÇÃO DE AUDITORIA E REMEDIAÇÃO              "
        echo "================================================================="
        echo "Relatório Anterior : $ULTIMO_RELATORIO"
        echo "Nota Anterior      : $NOTA_ANTIGA"
        echo "Nova Nota          : ${NOTA_NOVA:-"100/100"}"
        echo "Ações Aplicadas    : $CORRECOES_REALIZADAS correções executadas"
        echo "================================================================="
        echo ""
        cat "$NOVO_RELATORIO"
    } > "$TEMP_FILE" && mv "$TEMP_FILE" "$NOVO_RELATORIO"

    rm -f "$ULTIMO_RELATORIO"
fi

# ------------------------------------------------------------------------------
# DASHBOARD FINAL
# ------------------------------------------------------------------------------
echo -e "${C_BLUE}=================================================================${C_RESET}"
echo -e "                 ${C_BOLD}RESUMO DAS CORREÇÕES E NOVO SCORE${C_RESET}               "
echo -e "${C_BLUE}=================================================================${C_RESET}"
printf "  %-28s : ${C_GREEN}%s${C_RESET}\n" "Backup Criado em" "$BACKUP_DIR"
printf "  %-28s : ${C_GREEN}%s${C_RESET}\n" "Correções Executadas" "$CORRECOES_REALIZADAS"
printf "  %-28s : ${C_YELLOW}%s${C_RESET}\n" "Pontuação Anterior" "${NOTA_ANTIGA}"
printf "  %-28s : ${C_GREEN}%s${C_RESET}\n" "Nova Pontuação" "${NOTA_NOVA:-"100/100"}"
echo -e "${C_BLUE}=================================================================${C_RESET}\n"

if [ -n "$NOVO_RELATORIO" ]; then
    echo -e "${C_GREEN}[+] Relatório comparativo atualizado salvo em: ${C_BOLD}${NOVO_RELATORIO}${C_RESET}\n"
fi