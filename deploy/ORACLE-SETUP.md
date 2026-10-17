# تشغيل السيرفر على Oracle Cloud مجاني (VM شغال 24/7)

الهدف: سيرفر Paper على جهاز في سحابة أوراكل، الخطة المجانية الدائمة (Always Free) -
**4 نوى ARM + 24 جيجا رام**، من غير اشتراك شهري، ومفتوح دايمًا (مش بينطفي لما محدش يلعب).

ده بديل الجهاز: الملفات في `deploy/` هي اللي بتعمل كل حاجة.

---

## المرحلة 1: حساب أوراكل (10 دقايق)

1. سجّل في `signup.cloud.oracle.com` بإيميلك، وادخل **بيانات بطاقة بنكية** (فيزا/ماستر).
   أوراكل بتعمل عملية تحقق بسيطة وبترجّع الفلوس؛ الخطة المجانية مش بخصم حاجة.
2. اختار الـ **Home Region** الأقرب لمصر: `eu-frankfurt-1` (ألمانيا) أو `uk-london`.
   ⚠️ الـ Home Region **ميتغيرش بعدين**، والخطة المجانية بتتحسب عليه، فاختار مرة واحدة.
3. اختار **Oracle Cloud Free Tier** (مش Pay As You Go) وكمّل التسجيل.

### مهم عشان الحساب ميوقفش
- **Budget**: من القائمة ← Billing & Management ← Budgets ← اعمل Alert عند `0.00` (تنبيه بس).
- **لو طلبوا Upgrade to Pay As You Go**: متنفعش. الحساب بيفضل Free طول ما إنت مش بتستخدم خدمات مدفوعة.
- **Idle reclamation**: أوراكل ممكن تسترجع أي جهاز مجاني راكد (أقل من 20% استهلاك CPU أسبوع ورا أسبوع).
  سيرفر ماينكرافت شغال مع لاعبين بيفضل فوق الحد ده، والأفضل تثبت **APM Agent** (بيختار أثناء إنشاء
  الـ VM: "Install the Cloud Watch agent" أو "APM") وبيخلي Instance بتاعك "مستكشف" في نظرهم.

---

## المرحلة 2: إنشاء الـ VM

1. Console ← **Compute** ← **Instances** ← **Create instance**.
2. Name: `minecraft`. Comartment: root.
3. **Image**: اختار **Ubuntu 24.04** (لو الـ Shape ARM، النسخة هتبقى `aarch64` أوتوماتيك).
4. **Shape**: **Ampere** ← `VM.Standard.A1.Flex` ← ارفع السلايدرز لـ **4 OCPU** و **24 GB RAM**.
   - لو طلع خطأ **"Out of host capacity"**: دي مشكلة مش عندك - جرب:
     - تختار **Availability Domain** تاني في نفس الـ Region (مثلا `:EU-FRANKFURT-1-AD-3`).
     - تعدّل المحاولة كل نص ساعة، أو جرب يوم تاني. أحيانًا بيحتاج ترفع طلب دعم بسيط.
     - مش دايمًا ARM متوفر - الخيارات التانية المجانية (`E2.1.Micro` = 1 جيجا رام) **ضعيفة جدًا**
       لسيرفر Paper، فالحل الأحسن تستنى ARM أو تدفع ~€4 في Hetzner.
5. **Network**: سيبل Default + **تأكد** إن "Assign public IPv4 address" متفعّل.
6. **Add SSH keys**: اختار **Generate a key for me** ونزّل المفتاح الخاص (`.key`) -
   محتاجه في الخطوة الجاية. أو لو عندك مفتاح عندك اختار "Paste public key".
7. دوس **Create instance** واستنى لحد الحالة تبقى **Running**.
8. انسخ الـ **Public IP** من صفحة الـ Instance.

### فتح بورت 25565 (خطوة أوراكل الإلزامية)
من صفحة الـ Instance ← دوس على اسم الـ **Subnet** ← **VCN** ← **Security Lists** ←
**Default Security List for your-vcn** ← **Add Ingress Rules**:

| Field | Value |
|---|---|
| Source Type | CIDR |
| Source CIDR | `0.0.0.0/0` |
| Destination Type | CIDR |
| IP Protocol | **TCP** |
| Destination Port Range | `25565` |
| Description | minecraft |

من غير القاعدة دي هتلاقي السيرفر شغال بسحدك مش داخلين أصحابك.

---

## المرحلة 3: تركيب السكربتات (5 دقايق)

من جهازك (Git Bash أو PowerShell)، ارفع المجلد كله على الـ VM:

```bash
scp -i /مسار/المفتاح.key -r ../minecraft-paper-server ubuntu@<PublicIP>:~/
```

لو Windows بيقولك إن صلاحيات المفتاح واسعة:
```powershell
icacls "C:\مسار\المفتاح.key" /inheritance:r /grant:r "${env:USERNAME}:R"
```

ادخل على الـ VM وشغّل التنصيب:

```bash
ssh -i /مسار/المفتاح.key ubuntu@<PublicIP>
cd ~/minecraft-paper-server/deploy
sudo bash install.sh
```

السكربت بيعمل كل حاجة لوحده:
- بينصّب **Temurin JDK 25** (أو أي نسخة مطلوبها الإصدار اللي اختاره)
- بيجيب **آخر Paper مستقر** من PaperMC ويتأكد من SHA-256
- بياخد نسخة من `server.properties` و`plugins/`
- بيسيب مستخدم `minecraft` وبيشغّل السيرفر كـ **خدمة systemd**:
  - `Restart=always` - لو كرَش بيقوم تاني بعد 5 ثواني
  - `systemctl enable` - بيشتغل لوحده بعد أي restart أو صيانة من أوراكل
- بيفتح البورت 25565 في فيروال الـ VM

### الموافقة على EULA (لازم بإيدك)
السكربت متعمّد إنه ما يوافقش عنك. بعد ما تقرا `https://www.minecraft.net/en-us/eula`:

```bash
sudo bash -c 'echo eula=true > /srv/minecraft/paper/eula.txt && chown minecraft: /srv/minecraft/paper/eula.txt && systemctl restart paper'
```

---

## المرحلة 4: أوامر يومية

```bash
journalctl -u paper -f            # اللوغات لايف
systemctl status paper            # حالة + آخر سطور
sudo systemctl restart paper      # إعادة تشغيل بعد أي تعديل
sudo systemctl stop paper         # إيقاف نظيف (أفضل من قتل العملية)
sudo apt update                   # تحديث النظام كل فترة
```

### أوامر الإدارة (op، whitelist، weather، ...)
السيرفر شغال كخدمة من غير console تفاعلية، فرمّم أول مرة بالطريقة دي:

```bash
# 1) ضيف نفسك كـ OP
sudo nano /srv/minecraft/paper/ops.json      # أو whitelist.json لقائمة المدعوين
sudo systemctl restart paper
```

بعد كده **كل الأوامر بتكتبها من جوه اللعبة** وأنت OP: `/gamemode creative`، `/weather clear`،
`/kick`، `/stop` (الـ systemd هيقوم السيرفر تاني لو وقفته بالـ stop وعايزه يرجع - استخدم
`sudo systemctl stop paper` لو عايزه يقفل فعلاً).

لو السيرفر رافع plugins، في إضافات بتدي console من جوه اللعبة (EssentialsX / AdvancedConsole).

### نسخ احتياطي للعالم
```bash
sudo bash ~/minecraft-paper-server/deploy/backup.sh
# كل يوم 5 الصبح أوتوماتيك:
( crontab -l 2>/dev/null; echo "0 5 * * * sudo bash /home/ubuntu/minecraft-paper-server/deploy/backup.sh" ) | crontab -
```

### تحديث Paper
أعد تشغيل نفس السكربت - هيكتشف إن الإصدار الجديد اتغيّر وينزّله:
```bash
cd ~/minecraft-paper-server/deploy && sudo bash install.sh
```
عايز إصدار Minecraft معين (مثلا 1.21.4):
```bash
sudo MINECRAFT_VERSION=1.21.4 bash install.sh
```
> ⚠️ تغيير الإصدار ممكن ياثر على العالم القديم - خد نسخة احتياطية الأول.

---

## المرحلة 5: أصحابك يدخلوا ازاي

Multiplayer ← Add Server ← Address: **`<PublicIP>:25565`**

- كل لاعب محتاج **حساب Microsoft أصلي** (`online-mode=true` - وسيبه كده للأمان).
- عايز اسم بدل IP؟ اشتري دومين رخيص (أو `freedns.afraid.org` مجانًا) واديه **A record**
  pointing على الـ IP، وبعدين `mc.yourname.com:25565`.

---

## لو حاجة ما شغلتش

| العَرَض | السبب غالبًا والحل |
|---|---|
| `Connection refused / timed out` | ناسي قاعدة الـ Security List في أوراكل، أو فيروال الـ VM - `sudo iptables -S INPUT` لازم فيه `--dport 25565 ACCEPT` |
| `Can't connect to server` و السيرفر Running | صاحبك داخل بـ account مش أصلي، أو إصدار اللعبة مختلف عن إصدار السيرفر |
| `Out of memory` في اللوغات | قلل الرام: `sudo MEMORY_MB=4096 bash install.sh` أو نزّل `view-distance` لـ 6 |
| `Killed` بعد دقيقة من التشغيل | قلة رام عند أول توليد للعالم - زوّد `MEMORY_MB` |
| `no supported Paper version found` | الـ API اتغير - جرب `python3 resolve_paper.py https://fill.papermc.io/v3 ""` وشوف الرسالة |
| الحساب اتوقف | مراجعة Billing + تأكد إنك مش بتستخدم موارد مدفوعة (block volume كبير / إيجاز NAT gateway) |
| الـ VM اتحذف لوحده | Idle reclamation - خلي السيرفر شغال، وثبّت APM/Cloud Watch agent |
