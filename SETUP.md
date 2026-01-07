# 🔍 Elite Mirror Scanner - Setup Guide

## Features

✨ **New Elite Scanner Features:**
- ⚡ **Fast Scanning**: 15-30 seconds for all mirrors
- 📊 **Intelligent Scoring**: 0-100 score based on speed, reliability & coverage
- 🏆 **TOP 3 Ranking**: Automatically identifies best mirrors
- 🎯 **Latency Measurement**: Precise response time for each package
- 💎 **Beautiful UI**: Professional output with colors and emojis
- 🔧 **Auto-Config Ready**: Coming soon - automatic system configuration

---

## Requirements

### 1. yq (YAML Parser Binary)

> **مهم:** نسخه Binary از yq نیاز است، نه Python version!

```bash
# نصب yq binary
VERSION=v4.44.1
cd /tmp
wget https://github.com/mikefarah/yq/releases/download/${VERSION}/yq_linux_amd64 -O yq
chmod +x yq
sudo mv yq /usr/local/bin/yq

# تست
yq --version
```

**یا با snap:**
```bash
sudo snap install yq
```

### 2. bc (Calculator)
```bash
sudo apt install bc -y
```

### 3. curl
```bash
# معمولاً از قبل نصب است
sudo apt install curl -y
```

---

## نحوه اجرا

### اجرای ساده
```bash
cd /path/to/mirava
chmod +x check_mirrors.sh
./check_mirrors.sh
```

### استفاده از Backup Tool
```bash
# گرفتن backup از تنظیمات فعلی
chmod +x mirror_config_backup.sh
./mirror_config_backup.sh --backup

# لیست کردن backup ها
./mirror_config_backup.sh --list

# بازگردانی آخرین backup
./mirror_config_backup.sh --restore
```

---

## مثال خروجی

```
╔═══════════════════════════════════════════════════════════╗
║        🔍 Elite Mirror Scanner for Iran 🇮🇷               ║
╚═══════════════════════════════════════════════════════════╝

📊 Found 15 mirrors to scan
⚡ Starting parallel scan (this may take 20-40 seconds)...

━━━ Scanning: MobinHost (14/15)
  ✅ FreeBSD (89ms)
  ✅ Alpine (67ms)
  ✅ Debian (72ms)
  📊 Score: 94/100 | Latency: 73ms | Success: 12/13

╔═══════════════════════════════════════════════════════════╗
║              🏆 TOP 3 BEST MIRRORS IN IRAN               ║
╚═══════════════════════════════════════════════════════════╝

 1️⃣  MobinHost Mirror
     Score: 94/100 ⭐⭐⭐⭐⭐
     Latency: 73ms ⚡
     Success Rate: 92.3% ✅
     Packages: 12/13 📦
     URL: https://mirror.mobinhost.com/

 2️⃣  Arvancloud
     Score: 91/100 ⭐⭐⭐⭐⭐
     Latency: 89ms ⚡
     Success Rate: 100.0% ✅
     Packages: 7/7 📦
     URL: https://www.arvancloud.ir/en/dev/linux-repository

 3️⃣  KubarCloud
     Score: 88/100 ⭐⭐⭐⭐
     Latency: 112ms ⚡
     Success Rate: 100.0% ✅
     Packages: 7/7 📦
     URL: https://mirrors.kubarcloud.com/

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏆 Best Mirror: MobinHost Mirror
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Do you want to configure this mirror as your default? (y/n):
```

---

## چگونه امتیاز محاسبه می‌شود؟

### فرمول امتیازدهی (0-100)

```
Score = Success_Points + Latency_Points + Coverage_Points

Success_Points  = (Success_Rate × 50) / 100     [0-50 points]
Latency_Points  = 30 - (Avg_Latency × 30 / 500) [0-30 points]
Coverage_Points = (Total_Packages × 20) / 15    [0-20 points]
```

**مثال:**
- Success Rate: 92% → 46 points
- Avg Latency: 73ms → 25.6 points  
- Coverage: 12 packages → 16 points
- **Total: 94/100** ⭐⭐⭐⭐⭐
