# سيرفر Paper على VM ويندوز (AWS / Azure)

## ⚠️ اسم كويس قبل ما تفتح الحساب: المصيدة في الـ RAM

"سنة مجاني" على AWS وAzure بتكون على أجهزة بحجم **1 جيجا رام** فقط:

| العرض المجاني | الجهاز | الرام | يشتغل Windows + Paper؟ |
|---|---|---|---|
| Azure free account | B1s Windows (750 ساعة/شهر، 12 شهر) | **1 GB** | **لأ** - Windows Server نفسه بياكلها كلها |
| AWS حساب جديد (2026) | $100 رصيد + $100 تاني مع الاستخدام | - | الرصيد بيكفي شهر واحد لجهاز بحجم مناسب، مش سنة |
| AWS حسابات قديمة (legacy) | t2.micro/t3.micro 750 ساعة/شهر | **1 GB** | **لأ** لنفس السبب |

سيرفر Paper مع Windows محتاج **4 جيجا على الأقل** (و 6-8 جيجا لو plugins أو أكتر من 5 لاعبين).
يعني:
- **لو عايز Windows حرفيًا**: لازم جهاز 4-8 جيجا، وده **مدفوع** حتى مع العرض المجاني
  (تقريبًا $30-60 للشهر على Azure/AWS، أو ~$8-15 للشهر على استضافة VPS صغيرة بترخص Windows
  بالتجزئة - الأرقام دي تقديرية، السعر النهائي بيظهر في الـ console قبل الضغط).
- **لو مش فارق معاك الويندوز**: Oracle Linux المجاني (4 نوى / 24 جيجا، للأبد) بيديك نفس
  النتيجة بالظبط من جوه اللعبة - راجع `../ORACLE-SETUP.md`.

أنا جهّزت السكربتات دي عشان تشتغل على **أي** VM ويندوز، فمهما كان اختيارك الخطوة الأخيرة واحدة.

---

## 1) إنشاء الجهاز

### Azure
1. `azure.microsoft.com/free` ← سجّل بإيميل + بطاقة (توثيق بس بدون خصم) + **$200 رصيد 30 يوم**.
2. Portal ← **Create a resource** ← **Virtual machine**.
3. **Size** ← دوس "Change size" واختار **B2ms** (2 نوى / 8 GB) أو **B2s_v2** (4 GB) - متسيبش B1s.
4. **Image**: Windows Server 2022 Datacenter (أو 2025).
5. **Authentication**: **Set admin username** + **password** (مش مفتاح SSH - دي خطوات RDP).
6. **Inbound ports**: اختار HTTP/HTTPS بس - البورت 3389 (RDP) هيضاف لوحده؛ البورت 25565 هنفتحه يدوي بعد كده.
7. **Review + create** (تاخد 3-5 دقايق) ← انسخ **Public IP**.

### AWS
1. `aws.amazon.com` ← Create account (إيميل + بطاقة + مكالمة/رسالة توثيق).
2. EC2 ← **Launch instance**:
   - **AMI**: Windows Server 2022 (Quick Start).
   - **Instance type**: **t3.large** (2 نوى / 8 GB) أو **m6a.large**. ومتسيبش t3.micro.
   - **Key pair**: اختار "Create new" ونزّل الـ `.pem` (مش مطلوب للـ RDP بس AWS بيقفله).
3. **Security group**: أضف inbound rule **TCP / 25565 / Source 0.0.0.0/0** - ده **ضروري**،
   من غيره أصحابك مش هيدخلوا حتى لو السيرفر شغال.
4. **Storage**: 30-50 GB gp3 كفاية.
5. **Launch** ← استنى الحالة Running ← **Connect** ← **RDP client** ←
   **Get password** (استنى 10 دقايق بعد الإقلاع أول مرة) ← ارفع الملف `.pem` ← **Connect with RDP**.

---

## 2) بعد ما تفتح RDP

مش لازم تنصّب أي حاجة الأول: انسخ المجلد `minecraft-paper-server` كله على الجهاز
(في RDP النسخ واللصق شغال بين جهازك والجهاز البعيد)، أو نزّله من GitHub لما ترفعه.

في الـ VM، افتح **PowerShell as Administrator** واشغل:

```powershell
cd C:\minecraft-paper-server\deploy\windows
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
.\Install-Paper.ps1
```

السكربت بيعمل بالترتيب:
1. بيقرا آخر إصدار Paper مستقر من PaperMC ومطلوباته من Java.
2. بينصّب **Temurin JDK** (النسخة المطلوبة، بمعمارية الجهاز x64 أو ARM64) في
   `C:\Program Files\Java\current` وبيضيفه لـ PATH النظام.
3. بينزّل `server.jar` وبيتأكد من **SHA-256**.
4. بيفتح **TCP 25565** في Windows Firewall.
5. بيسجّل task اسمه `PaperMinecraftServer` بيشتغل **لوحده بعد كل reboot** وبيعاود التشغيل
   3 مرات لو السيرفر كرس (ده اللي بيخليه "مفتوح ولا ينطفي" - طلبته صراحة، ولو عايز تلغيه:
   `Unregister-ScheduledTask -TaskName PaperMinecraftServer -Confirm:$false`).

عايز RAM أو إصدار مختلف:
```powershell
.\Install-Paper.ps1 -MemoryGB 6
.\Install-Paper.ps1 -MinecraftVersion "1.21.4"
.\Install-Paper.ps1 -SkipAutoStart      # بدون تسجيل الـ task
```

---

## 3) الموافقة على EULA وتشغيل السيرفر

السكربت متعمّد ما يوافقش عنك. بعد قراءة `https://www.minecraft.net/en-us/eula`:

```powershell
cd C:\minecraft-server-path
notepad eula.txt          # غيّر eula=false لـ eula=true واحفظ
.\start.ps1 -MemoryGB 6
```

النافذة اللي هتفتح دي هي **console السيرفر** - اكتب `stop` فيها للإيقاف النظيف،
أو `op اسمك` وكمّل كل أوامرك من جوّه اللعبة.

للتشغيل التلقائي بعد كده مفيش console تفاعلية (الـ task بيشتغل في الخلفية)، فإدارتك هتكون:
- عدّل `ops.json` / `whitelist.json` بإيدك ثم شغل `.\start.ps1` من جديد
- أو استخدّم RDP وافتح `.\start.ps1` بنفسك وقت ما تعوز console كاملة

---

## 4) أصحابك يدخلوا + النافذة تقفل

| حاجة | تفاصيل |
|---|---|
| Address | `<Public IP>:25565` |
| النافذة/الاتصال | في AWS/Azure **ممنوع تقفل جلسة RDP بـ Log off** - استخدم **Disconnect** من القائمة دي، وإلا السيرفر بيقفل مع النافذة |
| الباور | في Azure فعّل "Boot diagnostics" عشان تشوف اللوغات لو حاجة مقفلتش؛ في AWS **Stop** = البورت الضائع، استنى **Restart** بدلها |
| الأمان | متفتحش البورت 3389 (RDP) للعالم إلا لو لازم - ثبّت IP معين أو استخدم Bastion |

---

## 5) حساب الفاتورة (اعمله دلوقتي مش بعدين)

- **Azure**: Cost Management ← Budgets ← Alert عند `5$` شهريًا.
- **AWS**: Billing ← Budgets ← Alert على EC2 عند `5$`، وفعّل **Free Tier usage alerts**.
- متسيبش الجهاز شغال شهر كامل وأنت مختار shape كبير - 8 جيجا Windows على Azure حوالي
  $0.18-0.25 في الساعة (أي ~$130-180 للشهر). لو عايز توفر: إطفي الجهاز لما محدش يلعب
  (`Stop (deallocate)`) - بس ساعتها مش 24/7.

## 6) مشاكل متوقعة

| العَرَض | الحل |
|---|---|
| `Java install failed` | تأكد إن PowerShell **Administrator**، وإن الجهاز عنده إنترنت صادر |
| أصحابك `Connection timed out` | Security Group / NSG: قاعدة inbound TCP 25565 ناقصة (دي أشهر مشكلة) |
| `Version 'x' not available` | شوف قائمة الإصدارات: `Invoke-RestMethod "https://fill.papermc.io/v3/projects/paper/versions?limit=25"` |
| السيرفر وقف لما قفلت RDP | استخدم **Disconnect** مش **Sign out**، أو اعتمد على task التشغيل التلقائي |
| `Out of memory` / lag تقيل | نزّل `view-distance` لـ 4-6، و`simulation-distance` لـ 4، وزوّد `-MemoryGB` لو الرام تسمح |
