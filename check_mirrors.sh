#!/usr/bin/env bash
set -euo pipefail

MIRROR_FILE="./mirrors_list.yaml"

# Colors for better output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters for summary
TOTAL_MIRRORS=0
SUCCESSFUL_CHECKS=0
FAILED_CHECKS=0
UNKNOWN_PACKAGES=0

# Comprehensive package paths dictionary
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
  
  # Maven/Gradle (these usually don't have simple paths, will be checked differently)
  ["Maven (google)"]=""
  ["Maven (jitpack)"]=""
  ["Maven (maven central)"]=""
  ["Others (Can be added)"]=""
  
  # Docker Registry - special handling
  ["Docker Registry"]="v2/"
)

function check_url() {
  local url=$1
  # Increased timeout to 10s and added insecure flag for SSL issues
  status=$(curl -s -o /dev/null -w "%{http_code}" --insecure --max-time 10 --retry 2 "$url" 2>/dev/null || echo "000")
  echo "$status"
}

function check_docker_registry() {
  local url=$1
  # Docker Registry requires a GET to /v2/ and must respond with 200, 401, or 403
  status=$(curl -s -o /dev/null -w "%{http_code}" --insecure --max-time 10 "$url/v2/" 2>/dev/null || echo "000")
  
  if [[ "$status" == "200" || "$status" == "401" || "$status" == "403" ]]; then
    echo -e "${GREEN}✅ Docker Registry OK ($status)${NC}"
    ((SUCCESSFUL_CHECKS++))
    return 0
  else
    echo -e "${RED}❌ Docker Registry Failed ($status)${NC}"
    ((FAILED_CHECKS++))
    return 1
  fi
}

function check_maven_repository() {
  local url=$1
  local package=$2
  # Maven repositories usually respond to their base URL
  status=$(check_url "$url")
  
  if [[ "$status" == "200" || "$status" == "301" || "$status" == "302" ]]; then
    echo -e "${GREEN}✅ $package ($status)${NC}"
    ((SUCCESSFUL_CHECKS++))
    return 0
  else
    echo -e "${RED}❌ $package ($status)${NC}"
    ((FAILED_CHECKS++))
    return 1
  fi
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🔍 Mirror Availability Checker for Iran${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo -e "${RED}❌ Error: yq is not installed.${NC}"
    echo -e "${YELLOW}Please install it using: pip install yq${NC}"
    exit 1
fi

# Check if YAML file exists
if [[ ! -f "$MIRROR_FILE" ]]; then
    echo -e "${RED}❌ Error: $MIRROR_FILE not found!${NC}"
    exit 1
fi

TOTAL_MIRRORS=$(yq e '.mirrors | length' "$MIRROR_FILE")

for idx in $(seq 0 $((TOTAL_MIRRORS - 1))); do
  name=$(yq e ".mirrors[$idx].name" "$MIRROR_FILE")
  base_url=$(yq e ".mirrors[$idx].url" "$MIRROR_FILE")
  description=$(yq e ".mirrors[$idx].description" "$MIRROR_FILE")
  
  echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}🔍 Mirror [$((idx + 1))/$TOTAL_MIRRORS]: $name${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "📍 URL: $base_url"
  echo -e "📝 Description: $description\n"

  package_count=$(yq e ".mirrors[$idx].packages | length" "$MIRROR_FILE")

  for j in $(seq 0 $((package_count - 1))); do
    package=$(yq e ".mirrors[$idx].packages[$j]" "$MIRROR_FILE")
    
    # Special handling for Docker Registry
    if [[ "$package" == "Docker Registry" ]]; then
      check_docker_registry "$base_url"
      continue
    fi
    
    # Special handling for Maven repositories
    if [[ "$package" =~ ^Maven || "$package" == "Others (Can be added)" ]]; then
      check_maven_repository "$base_url" "$package"
      continue
    fi
    
    # Get path for package
    path=${PACKAGE_PATHS[$package]:-}
    
    if [[ -n "$path" ]]; then
      # Remove trailing slash from base_url to prevent double slashes
      clean_url="${base_url%/}"
      full_url="$clean_url/$path"
      status=$(check_url "$full_url")
      
      if [[ "$status" == "200" || "$status" == "301" || "$status" == "302" ]]; then
        echo -e "${GREEN}✅ $package → $full_url ($status)${NC}"
        ((SUCCESSFUL_CHECKS++))
      elif [[ "$status" == "000" ]]; then
        echo -e "${RED}❌ $package → $full_url (Connection Failed)${NC}"
        ((FAILED_CHECKS++))
      else
        echo -e "${RED}❌ $package → $full_url ($status)${NC}"
        ((FAILED_CHECKS++))
      fi
    else
      # Try base URL for unknown packages
      status=$(check_url "$base_url")
      if [[ "$status" == "200" || "$status" == "301" || "$status" == "302" ]]; then
        echo -e "${YELLOW}⚠️  $package (checked base URL: $status)${NC}"
        ((SUCCESSFUL_CHECKS++))
      else
        echo -e "${YELLOW}⚠️  Unknown package type: $package (base URL: $status)${NC}"
        ((UNKNOWN_PACKAGES++))
      fi
    fi
  done
done

# Final Summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}📊 SUMMARY${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Total Mirrors Checked: ${BLUE}$TOTAL_MIRRORS${NC}"
echo -e "${GREEN}Successful Checks: $SUCCESSFUL_CHECKS${NC}"
echo -e "${RED}Failed Checks: $FAILED_CHECKS${NC}"
echo -e "${YELLOW}Unknown Packages: $UNKNOWN_PACKAGES${NC}"

TOTAL_CHECKS=$((SUCCESSFUL_CHECKS + FAILED_CHECKS + UNKNOWN_PACKAGES))
if [[ $TOTAL_CHECKS -gt 0 ]]; then
  SUCCESS_RATE=$(echo "scale=2; $SUCCESSFUL_CHECKS * 100 / $TOTAL_CHECKS" | bc)
  echo -e "Success Rate: ${GREEN}${SUCCESS_RATE}%${NC}"
fi

echo -e "${BLUE}========================================${NC}\n"

# Exit with error if there were failures
if [[ $FAILED_CHECKS -gt 0 ]]; then
  exit 1
fi
