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

# Ask user if they want to configure the best mirror
if [[ -n "$best_mirror_name" ]]; then
  echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}🏆 Best Mirror: ${CYAN}$best_mirror_name${NC}"
  echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  
  echo -e "${YELLOW}📝 Note: Auto-configuration will modify system files (backups will be created)${NC}"
  echo -e "${YELLOW}   - /etc/apt/sources.list (for Ubuntu/Debian packages)${NC}"
  echo -e "${YELLOW}   - ~/.pip/pip.conf (for Python packages)${NC}"
  echo -e "${YELLOW}   - ~/.npmrc (for Node.js packages)${NC}\n"
  
  read -p "$(echo -e ${BOLD}${GREEN}"Do you want to configure this mirror as your default? (y/n): "${NC})" choice
  
  if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
    echo -e "\n${CYAN}🔧 Auto-configuration feature coming soon!${NC}"
    echo -e "${CYAN}   For now, please manually configure: $best_mirror_url${NC}\n"
    
    # TODO: Implement auto-configuration
    # configure_system_mirrors "$best_mirror_url" "$best_mirror_name"
  else
    echo -e "\n${BLUE}ℹ️  No changes made to system configuration.${NC}\n"
  fi
fi

echo -e "${GREEN}✅ Scan completed!${NC}\n"
