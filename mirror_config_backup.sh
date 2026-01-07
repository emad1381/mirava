#!/usr/bin/env bash
# Mirror Configuration Backup & Restore Tool

BACKUP_DIR="/root/.mirava_backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

function create_backup() {
    echo -e "${BLUE}📦 Creating backup...${NC}"
    mkdir -p "$BACKUP_DIR"
    
    # Backup APT sources
    if [[ -f "/etc/apt/sources.list" ]]; then
        cp /etc/apt/sources.list "$BACKUP_DIR/sources.list.$TIMESTAMP"
        echo -e "${GREEN}✅ Backed up: /etc/apt/sources.list${NC}"
    fi
    
    # Backup pip config
    if [[ -f "/etc/pip.conf" ]]; then
        cp /etc/pip.conf "$BACKUP_DIR/pip.conf.$TIMESTAMP"
        echo -e "${GREEN}✅ Backed up: /etc/pip.conf${NC}"
    fi
    
    if [[ -f "$HOME/.pip/pip.conf" ]]; then
        mkdir -p "$BACKUP_DIR/.pip"
        cp "$HOME/.pip/pip.conf" "$BACKUP_DIR/.pip/pip.conf.$TIMESTAMP"
        echo -e "${GREEN}✅ Backed up: ~/.pip/pip.conf${NC}"
    fi
    
    # Backup npm config
    if [[ -f "$HOME/.npmrc" ]]; then
        cp "$HOME/.npmrc" "$BACKUP_DIR/npmrc.$TIMESTAMP"
        echo -e "${GREEN}✅ Backed up: ~/.npmrc${NC}"
    fi
    
    echo -e "${GREEN}✅ All backups saved to: $BACKUP_DIR${NC}\n"
}

function list_backups() {
    echo -e "${BLUE}📋 Available backups:${NC}\n"
    
    if [[ -d "$BACKUP_DIR" ]]; then
        ls -lh "$BACKUP_DIR" | tail -n +2
    else
        echo -e "${YELLOW}No backups found.${NC}"
    fi
}

function restore_latest() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo -e "${RED}❌ No backups directory found!${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}⚠️  This will restore your latest backup. Continue? (y/n)${NC}"
    read -r choice
    
    if [[ "$choice" != "y" ]]; then
        echo -e "${BLUE}Restore cancelled.${NC}"
        exit 0
    fi
    
    echo -e "${BLUE}🔄 Restoring latest backup...${NC}\n"
    
    # Restore APT sources
    latest_sources=$(ls -t "$BACKUP_DIR"/sources.list.* 2>/dev/null | head -1)
    if [[ -n "$latest_sources" ]]; then
        cp "$latest_sources" /etc/apt/sources.list
        echo -e "${GREEN}✅ Restored: /etc/apt/sources.list${NC}"
    fi
    
    # Restore pip
    latest_pip=$(ls -t "$BACKUP_DIR"/pip.conf.* 2>/dev/null | head -1)
    if [[ -n "$latest_pip" ]]; then
        cp "$latest_pip" /etc/pip.conf 2>/dev/null || true
        echo -e "${GREEN}✅ Restored: /etc/pip.conf${NC}"
    fi
    
    latest_pip_user=$(ls -t "$BACKUP_DIR/.pip"/pip.conf.* 2>/dev/null | head -1)
    if [[ -n "$latest_pip_user" ]]; then
        mkdir -p "$HOME/.pip"
        cp "$latest_pip_user" "$HOME/.pip/pip.conf"
        echo -e "${GREEN}✅ Restored: ~/.pip/pip.conf${NC}"
    fi
    
    # Restore npm
    latest_npm=$(ls -t "$BACKUP_DIR"/npmrc.* 2>/dev/null | head -1)
    if [[ -n "$latest_npm" ]]; then
        cp "$latest_npm" "$HOME/.npmrc"
        echo -e "${GREEN}✅ Restored: ~/.npmrc${NC}"
    fi
    
    echo -e "\n${GREEN}✅ Restore completed!${NC}"
}

# Main
case "${1:-}" in
    --backup|-b)
        create_backup
        ;;
    --list|-l)
        list_backups
        ;;
    --restore|-r)
        restore_latest
        ;;
    *)
        echo "Mirror Configuration Backup Tool"
        echo ""
        echo "Usage: $0 [OPTION]"
        echo ""
        echo "Options:"
        echo "  -b, --backup    Create backup of current configuration"
        echo "  -l, --list      List all backups"
        echo "  -r, --restore   Restore latest backup"
        echo ""
        ;;
esac
