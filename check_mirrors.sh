#!/usr/bin/env bash
set -uo pipefail

MIRROR_FILE="./mirrors_list.yaml"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Global counters
TOTAL_MIRRORS=0
TOTAL_CHECKS=0

# Arrays for mirror scores (using associative arrays)
declare -A MIRROR_SCORES
declare -A MIRROR_LATENCIES
declare -A MIRROR_SUCCESS_COUNTS
declare -A MIRROR_TOTAL_COUNTS
declare -A MIRROR_URLS
declare -A MIRROR_DESCRIPTIONS

# Comprehensive package paths
declare -A PACKAGE_PATHS=(
  # Linux Distributions
  ["Ubuntu"]="ubuntu"
  ["Debian"]="debian"
  ["Arch Linux"]="archlinux"
  ["Archlinux"]="archlinux"
  ["CentOS"]="centos"
  ["Alpine"]="alpine"
  ["Rocky Linux"]="rocky"
  ["Mint"]="linuxmint"
  ["Raspbian"]="raspbian"
  ["Fedora"]="fedora"
  ["Fedora EPEL"]="epel"
  ["OpenSUSE"]="opensuse"
  ["OpenSuse"]="opensuse"
  ["OpenBSD"]="OpenBSD"
  ["Manjaro"]="manjaro"
  ["FreeBSD"]="FreeBSD"
  ["Almalinux"]="almalinux"
  
  # Package Managers
  ["PyPI"]="pypi"
  ["npm"]="npm"
  ["Composer"]="packages.json"
  ["Homebrew"]="brew"
  
  # Databases & Apps
  ["MariaDB"]="mariadb"
  ["MongoDB"]="mongodb"
  ["Zabbix"]="zabbix"
  
  # Documentation
  ["CTAN"]="CTAN"
  
  # Maven/Gradle
  ["Maven (google)"]=""
  ["Maven (jitpack)"]=""
  ["Maven (maven central)"]=""
  ["Others (Can be added)"]=""
  
  # Docker Registry
  ["Docker Registry"]="v2/"
)

# Check URL with latency measurement
function check_url_with_latency() {
  local url=$1
  local start_time=$(date +%s%N)
  
  # Try to fetch with timeout of 5s
  status=$(curl -s -o /dev/null -w "%{http_code}" --insecure --max-time 5 "$url" 2>/dev/null || echo "000")
  
  local end_time=$(date +%s%N)
  local latency=$(( (end_time - start_time) / 1000000 )) # Convert to ms
  
  echo "$status|$latency"
}

# Check single package for a mirror
function check_package() {
  local mirror_name=$1
  local base_url=$2
  local package=$3
  
  # Special handling for Docker Registry
  if [[ "$package" == "Docker Registry" ]]; then
    result=$(check_url_with_latency "$base_url/v2/")
    status=$(echo "$result" | cut -d'|' -f1)
    latency=$(echo "$result" | cut -d'|' -f2)
    
    if [[ "$status" == "200" || "$status" == "401" || "$status" == "403" ]]; then
      echo "SUCCESS|$latency"
    else
      echo "FAIL|$latency"
    fi
    return
  fi
  
  # Special handling for Maven
  if [[ "$package" =~ ^Maven || "$package" == "Others (Can be added)" ]]; then
    result=$(check_url_with_latency "$base_url")
    status=$(echo "$result" | cut -d'|' -f1)
    latency=$(echo "$result" | cut -d'|' -f2)
    
    if [[ "$status" == "200" || "$status" == "301" || "$status" == "302" ]]; then
      echo "SUCCESS|$latency"
    else
      echo "FAIL|$latency"
    fi
    return
  fi
  
  # Regular packages
  path=${PACKAGE_PATHS[$package]:-}
  
  if [[ -n "$path" ]]; then
    clean_url="${base_url%/}"
    full_url="$clean_url/$path"
    result=$(check_url_with_latency "$full_url")
    status=$(echo "$result" | cut -d'|' -f1)
    latency=$(echo "$result" | cut -d'|' -f2)
    
    if [[ "$status" == "200" || "$status" == "301" || "$status" == "302" ]]; then
      echo "SUCCESS|$latency"
    else
      echo "FAIL|$latency"
    fi
  else
    # Unknown package - try base URL
    result=$(check_url_with_latency "$base_url")
    status=$(echo "$result" | cut -d'|' -f1)
    latency=$(echo "$result" | cut -d'|' -f2)
    
    if [[ "$status" == "200" || "$status" == "301" || "$status" == "302" ]]; then
      echo "SUCCESS|$latency"
    else
      echo "FAIL|$latency"
    fi
  fi
}

# Calculate mirror score
function calculate_score() {
  local success_count=$1
  local total_count=$2
  local avg_latency=$3
  
  # Success rate (0-50 points)
  local success_rate=0
  if [[ $total_count -gt 0 ]]; then
    success_rate=$(echo "scale=2; ($success_count * 100) / $total_count" | bc)
  fi
  local success_points=$(echo "scale=2; ($success_rate * 50) / 100" | bc)
  
  # Latency score (0-30 points) - faster is better
  # Perfect score at 0ms, 0 points at 500ms+
  local latency_points=0
  if (( $(echo "$avg_latency < 500" | bc -l) )); then
    latency_points=$(echo "scale=2; 30 - ($avg_latency * 30 / 500)" | bc)
  fi
  
  # Coverage score (0-20 points)
  local coverage_points=$(echo "scale=2; ($total_count * 20) / 15" | bc) # Max 15 packages
  if (( $(echo "$coverage_points > 20" | bc -l) )); then
    coverage_points=20
  fi
  
  # Total score
  local total_score=$(echo "scale=0; ($success_points + $latency_points + $coverage_points) / 1" | bc)
  
  echo "$total_score"
}

# Display header
echo -e "${BLUE}${BOLD}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                                                           ║"
echo "║        🔍 Elite Mirror Scanner for Iran 🇮🇷               ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

# Check dependencies
if ! command -v yq &> /dev/null; then
    echo -e "${RED}❌ Error: yq is not installed.${NC}"
    echo -e "${YELLOW}Install: wget https://github.com/mikefarah/yq/releases/download/v4.44.1/yq_linux_amd64 -O /tmp/yq && chmod +x /tmp/yq && sudo mv /tmp/yq /usr/local/bin/yq${NC}"
    exit 1
fi

if ! command -v bc &> /dev/null; then
    echo -e "${RED}❌ Error: bc is not installed.${NC}"
    echo -e "${YELLOW}Install: sudo apt install bc -y${NC}"
    exit 1
fi

# Check YAML file
if [[ ! -f "$MIRROR_FILE" ]]; then
    echo -e "${RED}❌ Error: $MIRROR_FILE not found!${NC}"
    exit 1
fi

TOTAL_MIRRORS=$(yq e '.mirrors | length' "$MIRROR_FILE")

echo -e "${CYAN}📊 Found $TOTAL_MIRRORS mirrors to scan${NC}"
echo -e "${CYAN}⚡ Starting parallel scan (this may take 20-40 seconds)...${NC}\n"

# Main scanning loop
for idx in $(seq 0 $((TOTAL_MIRRORS - 1))); do
  mirror_name=$(yq e ".mirrors[$idx].name" "$MIRROR_FILE")
  base_url=$(yq e ".mirrors[$idx].url" "$MIRROR_FILE")
  description=$(yq e ".mirrors[$idx].description" "$MIRROR_FILE")
  
  # Store mirror info
  MIRROR_URLS["$mirror_name"]="$base_url"
  MIRROR_DESCRIPTIONS["$mirror_name"]="$description"
  
  echo -e "${BLUE}━━━ Scanning: ${BOLD}$mirror_name${NC}${BLUE} ($((idx + 1))/$TOTAL_MIRRORS)${NC}"
  
  package_count=$(yq e ".mirrors[$idx].packages | length" "$MIRROR_FILE")
  
  success_count=0
  total_latency=0
  checked_count=0
  
  # Check each package
  for j in $(seq 0 $((package_count - 1))); do
    package=$(yq e ".mirrors[$idx].packages[$j]" "$MIRROR_FILE")
    
    result=$(check_package "$mirror_name" "$base_url" "$package")
    status=$(echo "$result" | cut -d'|' -f1)
    latency=$(echo "$result" | cut -d'|' -f2)
    
    if [[ "$status" == "SUCCESS" ]]; then
      ((success_count++))
      echo -e "  ${GREEN}✅ $package${NC} (${latency}ms)"
    else
      echo -e "  ${RED}❌ $package${NC} (${latency}ms)"
    fi
    
    total_latency=$((total_latency + latency))
    ((checked_count++))
  done
  
  # Calculate average latency
  avg_latency=0
  if [[ $checked_count -gt 0 ]]; then
    avg_latency=$((total_latency / checked_count))
  fi
  
  # Store results
  MIRROR_SUCCESS_COUNTS["$mirror_name"]=$success_count
  MIRROR_TOTAL_COUNTS["$mirror_name"]=$checked_count
  MIRROR_LATENCIES["$mirror_name"]=$avg_latency
  
  # Calculate score
  score=$(calculate_score $success_count $checked_count $avg_latency)
  MIRROR_SCORES["$mirror_name"]=$score
  
  echo -e "  ${MAGENTA}📊 Score: $score/100 | Latency: ${avg_latency}ms | Success: $success_count/$checked_count${NC}\n"
done

# Sort mirrors by score and get top 3
echo -e "\n${BLUE}${BOLD}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              🏆 TOP 3 BEST MIRRORS IN IRAN               ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

# Sort and display top 3
sorted_mirrors=$(for mirror in "${!MIRROR_SCORES[@]}"; do
  echo "${MIRROR_SCORES[$mirror]}|$mirror"
done | sort -rn | head -3)

rank=1
best_mirror_name=""
best_mirror_url=""

while IFS='|' read -r score mirror_name; do
  if [[ $rank -eq 1 ]]; then
    best_mirror_name="$mirror_name"
    best_mirror_url="${MIRROR_URLS[$mirror_name]}"
  fi
  
  success=${MIRROR_SUCCESS_COUNTS[$mirror_name]}
  total=${MIRROR_TOTAL_COUNTS[$mirror_name]}
  latency=${MIRROR_LATENCIES[$mirror_name]}
  success_rate=$(echo "scale=1; ($success * 100) / $total" | bc)
  
  # Star rating based on score
  stars=""
  if (( $(echo "$score >= 90" | bc -l) )); then
    stars="⭐⭐⭐⭐⭐"
  elif (( $(echo "$score >= 75" | bc -l) )); then
    stars="⭐⭐⭐⭐"
  elif (( $(echo "$score >= 60" | bc -l) )); then
    stars="⭐⭐⭐"
  elif (( $(echo "$score >= 40" | bc -l) )); then
    stars="⭐⭐"
  else
    stars="⭐"
  fi
  
  echo -e " ${BOLD}${rank}️⃣  $mirror_name${NC}"
  echo -e "     ${CYAN}Score: ${BOLD}$score/100${NC} $stars"
  echo -e "     ${GREEN}Latency: ${latency}ms ⚡${NC}"
  echo -e "     ${GREEN}Success Rate: ${success_rate}% ✅${NC}"
  echo -e "     ${BLUE}Packages: $success/$total 📦${NC}"
  echo -e "     ${YELLOW}URL: ${MIRROR_URLS[$mirror_name]}${NC}"
  echo ""
  
  ((rank++))
done <<< "$sorted_mirrors"

# Auto-configuration function
function configure_system_mirrors() {
  local mirror_url=$1
  local mirror_name=$2
  
  echo -e "\n${CYAN}🔧 Starting auto-configuration...${NC}\n"
  
  # Create backup first
  echo -e "${BLUE}📦 Creating backup of current configuration...${NC}"
  BACKUP_DIR="/root/.mirava_backups"
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  mkdir -p "$BACKUP_DIR"
  
  # Backup APT sources
  if [[ -f "/etc/apt/sources.list" ]]; then
    cp /etc/apt/sources.list "$BACKUP_DIR/sources.list.$TIMESTAMP"
    echo -e "${GREEN}✅ Backed up: /etc/apt/sources.list${NC}"
  fi
  
  # Configure APT (Ubuntu/Debian) if supported
  success_count=${MIRROR_SUCCESS_COUNTS[$mirror_name]}
  total_count=${MIRROR_TOTAL_COUNTS[$mirror_name]}
  
  # Get packages list for this mirror
  for idx in $(seq 0 $((TOTAL_MIRRORS - 1))); do
    name=$(yq e ".mirrors[$idx].name" "$MIRROR_FILE")
    if [[ "$name" == "$mirror_name" ]]; then
      package_count=$(yq e ".mirrors[$idx].packages | length" "$MIRROR_FILE")
      
      has_ubuntu=false
      has_debian=false
      has_pypi=false
      has_npm=false
      
      for j in $(seq 0 $((package_count - 1))); do
        package=$(yq e ".mirrors[$idx].packages[$j]" "$MIRROR_FILE")
        [[ "$package" == "Ubuntu" ]] && has_ubuntu=true
        [[ "$package" == "Debian" ]] && has_debian=true
        [[ "$package" == "PyPI" ]] && has_pypi=true
        [[ "$package" == "npm" ]] && has_npm=true
      done
      
      # Configure APT if Ubuntu/Debian supported
      if [[ "$has_ubuntu" == true ]] && [[ -f "/etc/os-release" ]]; then
        . /etc/os-release
        if [[ "$ID" == "ubuntu" ]]; then
          echo -e "\n${YELLOW}⚙️  Configuring APT for Ubuntu...${NC}"
          clean_url="${mirror_url%/}"
          
          # Create new sources.list
          cat > /etc/apt/sources.list << EOF
# Mirava Auto-Generated - $(date)
# Mirror: $mirror_name
# Backup: $BACKUP_DIR/sources.list.$TIMESTAMP

deb $clean_url/ubuntu/ $VERSION_CODENAME main restricted universe multiverse
deb $clean_url/ubuntu/ $VERSION_CODENAME-updates main restricted universe multiverse
deb $clean_url/ubuntu/ $VERSION_CODENAME-security main restricted universe multiverse
deb $clean_url/ubuntu/ $VERSION_CODENAME-backports main restricted universe multiverse
EOF
          
          echo -e "${GREEN}✅ APT configured for Ubuntu ($VERSION_CODENAME)${NC}"
          echo -e "${CYAN}   Running: apt update...${NC}"
          apt update -qq && echo -e "${GREEN}✅ APT update successful${NC}" || echo -e "${RED}⚠️  APT update failed - check mirror compatibility${NC}"
        fi
      fi
      
      # Configure pip if PyPI supported
      if [[ "$has_pypi" == true ]]; then
        echo -e "\n${YELLOW}⚙️  Configuring pip for PyPI...${NC}"
        mkdir -p "$HOME/.pip"
        clean_url="${mirror_url%/}"
        
        cat > "$HOME/.pip/pip.conf" << EOF
[global]
index-url = $clean_url/pypi/simple
trusted-host = $(echo "$clean_url" | sed 's|https\?://||' | cut -d'/' -f1)

[install]
trusted-host = $(echo "$clean_url" | sed 's|https\?://||' | cut -d'/' -f1)
EOF
        
        echo -e "${GREEN}✅ pip configured (~/.pip/pip.conf)${NC}"
      fi
      
      # Configure npm if npm supported
      if [[ "$has_npm" == true ]]; then
        echo -e "\n${YELLOW}⚙️  Configuring npm...${NC}"
        clean_url="${mirror_url%/}"
        npm config set registry "$clean_url/npm/" 2>/dev/null
        echo -e "${GREEN}✅ npm configured${NC}"
      fi
      
      break
    fi
  done
  
  echo -e "\n${GREEN}${BOLD}✅ Configuration completed successfully!${NC}"
  echo -e "${BLUE}📁 Backups saved to: $BACKUP_DIR${NC}"
  echo -e "${YELLOW}💡 To restore: ./mirror_config_backup.sh --restore${NC}\n"
}

# Manual mirror selection function
function show_manual_selection() {
  echo -e "\n${BLUE}${BOLD}"
  echo "╔═══════════════════════════════════════════════════════════╗"
  echo "║           📋 ALL AVAILABLE MIRRORS IN IRAN               ║"
  echo "╚═══════════════════════════════════════════════════════════╝"
  echo -e "${NC}\n"
  
  # Create sorted list by score
  local sorted_all=$(for mirror in "${!MIRROR_SCORES[@]}"; do
    echo "${MIRROR_SCORES[$mirror]}|$mirror"
  done | sort -rn)
  
  local index=1
  declare -A INDEX_TO_MIRROR
  
  while IFS='|' read -r score mirror_name; do
    INDEX_TO_MIRROR[$index]="$mirror_name"
    
    success=${MIRROR_SUCCESS_COUNTS[$mirror_name]}
    total=${MIRROR_TOTAL_COUNTS[$mirror_name]}
    latency=${MIRROR_LATENCIES[$mirror_name]}
    success_rate=$(echo "scale=1; ($success * 100) / $total" | bc)
    
    # Format number with leading space for alignment
    printf " ${BOLD}%2d)${NC} %-30s ${CYAN}Score: %3d${NC} | ${GREEN}%4dms${NC} | ${GREEN}%5.1f%%${NC}\n" \
      "$index" "$mirror_name" "$score" "$latency" "$success_rate"
    
    ((index++))
  done <<< "$sorted_all"
  
  echo ""
  echo -e "${BOLD}${YELLOW} 0)${NC} Cancel and exit\n"
  
  # Get user selection
  while true; do
    read -p "$(echo -e ${BOLD}${GREEN}"Select mirror number (0-$((index-1))): "${NC})" selection
    
    # Validate input
    if [[ "$selection" =~ ^[0-9]+$ ]]; then
      if [[ "$selection" == "0" ]]; then
        echo -e "\n${BLUE}ℹ️  Configuration cancelled.${NC}\n"
        return 1
      elif [[ "$selection" -ge 1 ]] && [[ "$selection" -lt "$index" ]]; then
        local selected_mirror="${INDEX_TO_MIRROR[$selection]}"
        local selected_url="${MIRROR_URLS[$selected_mirror]}"
        
        echo -e "\n${CYAN}📌 Selected: ${BOLD}$selected_mirror${NC}"
        echo -e "${YELLOW}   URL: $selected_url${NC}\n"
        
        read -p "$(echo -e ${BOLD}"Confirm configuration? (y/n): "${NC})" confirm
        
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
          configure_system_mirrors "$selected_url" "$selected_mirror"
          return 0
        else
          echo -e "\n${BLUE}ℹ️  Configuration cancelled.${NC}\n"
          return 1
        fi
      else
        echo -e "${RED}Invalid selection. Please enter a number between 0 and $((index-1)).${NC}"
      fi
    else
      echo -e "${RED}Invalid input. Please enter a number.${NC}"
    fi
  done
}

# Ask user if they want to configure the best mirror
if [[ -n "$best_mirror_name" ]]; then
  echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}🏆 Best Mirror: ${CYAN}$best_mirror_name${NC}"
  echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  
  echo -e "${YELLOW}📝 Auto-configuration options:${NC}"
  echo -e "${YELLOW}   - APT (Ubuntu/Debian): /etc/apt/sources.list${NC}"
  echo -e "${YELLOW}   - pip (Python): ~/.pip/pip.conf${NC}"
  echo -e "${YELLOW}   - npm (Node.js): ~/.npmrc${NC}"
  echo -e "${YELLOW}   - Automatic backup before changes${NC}\n"
  
  echo -e "${BOLD}${CYAN}Choose an option:${NC}"
  echo -e " ${BOLD}1)${NC} Configure ${GREEN}$best_mirror_name${NC} (Recommended)"
  echo -e " ${BOLD}2)${NC} Choose manually from all mirrors"
  echo -e " ${BOLD}3)${NC} Skip configuration\n"
  
  read -p "$(echo -e ${BOLD}${GREEN}"Your choice (1-3): "${NC})" choice
  
  case "$choice" in
    1)
      echo -e "\n${CYAN}🔧 Configuring best mirror: $best_mirror_name${NC}"
      configure_system_mirrors "$best_mirror_url" "$best_mirror_name"
      ;;
    2)
      show_manual_selection
      ;;
    3)
      echo -e "\n${BLUE}ℹ️  No changes made to system configuration.${NC}\n"
      ;;
    *)
      echo -e "\n${RED}Invalid choice. No changes made.${NC}\n"
      ;;
  esac
fi

echo -e "${GREEN}✅ Scan completed!${NC}\n"
