# نصب و راه‌اندازی اسکریپت چک میرورها

## Requirements

برای اجرای این اسکریپت به ابزارهای زیر نیاز دارید:

### 1. yq (YAML Parser Binary - NOT Python version)

> **مهم:** نسخه Binary از yq نیاز است، نه Python version!

```bash
# نصب yq binary از GitHub releases
VERSION=v4.44.1  # آخرین نسخه پایدار
BINARY=yq_linux_amd64

cd /tmp
wget https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY} -O yq
chmod +x yq
sudo mv yq /usr/local/bin/yq

# تست نصب
yq --version
# باید خروجی: yq (https://github.com/mikefarah/yq/) version v4.x.x
```

**یا با snap:**
```bash
sudo snap install yq
```

### 2. bc (Calculator)
```bash
# برای محاسبه درصد موفقیت
sudo apt install bc -y
```

### 3. curl
```bash
# معمولاً از قبل نصب است
sudo apt install curl -y
```

## نحوه اجرا

```bash
cd /path/to/mirava
chmod +x check_mirrors.sh
./check_mirrors.sh
```

## ویژگی‌های جدید

✅ پشتیبانی کامل از 30+ نوع package  
✅ مدیریت SSL با flag `--insecure`  
✅ Timeout افزایش یافته به 10 ثانیه  
✅ Retry mechanism (2 تلاش مجدد)  
✅ خروجی رنگی و قابل خواندن  
✅ آمار کامل در انتها (Success Rate)  
✅ پشتیبانی از Docker Registry، Maven و...  

## مثال خروجی

```
========================================
🔍 Mirror Availability Checker for Iran
========================================

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 Mirror [1/13]: KubarCloud
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 URL: https://mirrors.kubarcloud.com/
📝 Description: Public software mirror

✅ Alpine → https://mirrors.kubarcloud.com/alpine (200)
✅ Arch Linux → https://mirrors.kubarcloud.com/archlinux (200)
...

========================================
📊 SUMMARY
========================================
Total Mirrors Checked: 13
Successful Checks: 45
Failed Checks: 3
Unknown Packages: 2
Success Rate: 90.00%
========================================
```
