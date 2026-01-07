# نصب و راه‌اندازی اسکریپت چک میرورها

## Requirements

برای اجرای این اسکریپت به ابزارهای زیر نیاز دارید:

### 1. yq (YAML Parser)
```bash
# نصب با pip
sudo apt update
sudo apt install python3-pip -y
pip3 install yq

# یا نصب با snap
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
