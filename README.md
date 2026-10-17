# سيرفر Minecraft Paper

سيرفر **Paper** جاهز للتشغيل على ويندوز. Paper نسخة محسّنة من سيرفر ماينكرافت الرسمي:
أخف وأسرع، وبيقبل Plugins.

المجلد ده هو مجلد السيرفر نفسه - كل حاجة بتتحط هنا.

---

## فين السيرفر هيشتغل؟

| الطريقة | ملف الشرح |
|---|---|
| **VM مجاني في سحابة Oracle (شغال 24/7)** - Linux | [`deploy/ORACLE-SETUP.md`](deploy/ORACLE-SETUP.md) |
| **VM ويندوز على AWS / Azure** | [`deploy/windows/AWS-AZURE-WINDOWS.md`](deploy/windows/AWS-AZURE-WINDOWS.md) |
| على جهازك الويندوز (تجربة سريعة) | الأقسام 1-4 تحت |

`deploy/install.sh` هو النسخة اللي على Linux من نفس الخطوات - بينصّب Java، بيجيب Paper،
ويسيب السيرفر **خدمة** بتقوم لوحدها بعد كل restart أو كرش. ونفس الفكرة لسكربت الويندوز
`deploy/windows/Install-Paper.ps1`.

---

## 1) متطلبات قبل ما نبدأ

| الحاجة | المطلوب |
|---|---|
| Java | JDK 25 (أو أحدث). ورّينا في `setup.ps1` بنطلب نسخة Java المطلوبة تلقائياً حسب إصدار Paper |
| الرام | السيرفر بياخد 6 جيجا افتراضيًا (جهازك 16 جيجا - تقدر تغيّرها) |
| الإنترنت | للتحميل أول مرة بس |

### تنصيب Java (لو مش منصّب)
1. افتح <https://adoptium.net/temurin/releases/>
2. نزّل **JDK** لويندوز (نسخة x64، صيغة `.msi`).
3. شغّل الملف ووافق على خيار **Set JAVA_HOME** و **Add to PATH**.
4. تأكد من التنصيب في نافذة PowerShell جديدة:
   ```powershell
   java -version
   ```
   لو طلع رقم نسخة (زي `25`) يبقى تمام.

> ⚠️ لو PowerShell بيقولك "التنفيذ على هذا النظام مقيد"، شغّل السطر ده في نفس النافذة الأول:
> ```powershell
> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
> ```

---

## 2) تحميل السيرفر وتشغيله

من جوه المجلد ده، شغّل بالترتيب:

```powershell
cd C:\Users\Admin\Documents\Qoder\2026-10-17\e1055d00\minecraft-paper-server

# 1. تحميل آخر إصدار Paper مستقر + التأكد من سلامة الملف
.\setup.ps1

# 2. قبول اتفاقية الاستخدام (مرة واحدة)
notepad eula.txt   # غيّر eula=false لـ eula=true واحفظ

# 3. التشغيل
.\start.ps1
```

أول تشغيل بياخد دقيقة أو اتنين (بيحضّر ملفات العالم). بعد كده هتلاقي في نافذة
PowerShell سطر تحكم اكتب فيه أوامر السيرفر.

**عشان تقفل السيرفر صح** (من غير ما يفسد العالم): اكتب في النافذة

```
stop
```

لو قفلت النافذة والعالم لسه بيتحفظ، ممكن يحصل تلف في ملف العالم. دايمًا استخدم `stop`.

### أوامر مفيدة تكتبها في نافذة السيرفر
| الأمر | الوظيفة |
|---|---|
| `op اسمك` | يديك صلاحيات أدمن |
| `whitelist add اسمك` | يقفل السيرفر على قائمة ناس معينة |
| `gamemode creative اسمك` | تحويلك لكرييتيف |
| `weather clear` / `time set day` | الجو والوقت |
| `stop` | إيقاف نظيف |

---

## 3) تدخل السيرفر من اللعبة

افتح ماينكرافت ← **Multiplayer** ← **Add Server**:

| إنت بتلعب منين | الـ Address |
|---|---|
| نفس الجهاز | `localhost:25565` |
| جهاز تاني على نفس الواي فاي (LAN) | `192.168.x.x:25565` (الـ IP بتاع جهازك) |
| من بره الشبكة | محتاج Port Forwarding علىRouter للـ `25565`، أو حل أسهل تحت |

عرف الـ IP بتاعك بـ:
```powershell
ipconfig | findstr IPv4
```

### لو Windows Firewall مانع أصحابك
شغّل من PowerShell **كأدمن**:
```powershell
New-NetFirewallRule -DisplayName "Minecraft Server" -Direction Inbound -Protocol TCP -LocalPort 25565 -Action Allow
```

### أصحابك من بره البيت؟
أسهل طريقة من غير ما تلمس الـ Router: **Tailscale** أو **ZeroTier** - بتعمل شبكة
خاصة بينكم، وأصحابك يدخلوا على الـ IP الداخلي اللي بيقوهولك. طريقة تانية:
Port Forwarding للـ TCP 25565 على Router ثم تعطيهم الـ IP العام بتاعك
(`curl ifconfig.me`).

---

## 4) تعديل إعدادات السيرفر

كل الإعدادات في ملف **`server.properties`** (عدّله وأنت واقف السيرفر):

| السطر | معناه |
|---|---|
| `max-players=20` | أقصى عدد لاعبين |
| `view-distance=8` | مسافة الرؤية - الأقل = أخف على الجهاز |
| `simulation-distance=6` | مسافة محاكاة العالم |
| `gamemode=survival` | وضع اللعب الافتراضي |
| `difficulty=normal` | الصعوبة |
| `online-mode=true` | يتأكد إن حساب Microsoft أصلي - سيبه `true` إلا لو سبب معاك |
| `motd=...` | الرسالة اللي بتظهر في قائمة السيرفرات |
| `spawn-protection=16` | حماية منطقة البداية |
| `pvp=true` | القتال بين اللاعبين |

عايز تغيّر الرام اللي السيرفر بياخدها:
```powershell
.\start.ps1 -MemoryGB 8
```

عايز إصدار Minecraft معين مش أحدث نسخة:
```powershell
.\setup.ps1 -Version "1.21.4"   # اكتب أي إصدار متاح
```
وشوف كل الإصدارات المتاحة في أول نتيجة من `.\setup.ps1` أو على
<https://docs.papermc.io/paper/getting-started>.

---

## 5) الـ Plugins

حط ملف `.jar` بتاع الـ Plugin في مجلد **`plugins`** ثم اعمل `stop` وشغّل
`.\start.ps1` من جديد. اقتراحات للبداة: **EssentialsX**، **LuckPerms**،
**WorldEdit**، **WorldGuard**.

---

## 6) احتياطي (Backup) - مهم

قبل أي تعديل كبير، اعمل نسخة من مجلد العالم:
```powershell
Copy-Item .\world .\world_backup -Recurse
```
ولو حصل تلف في العالم، امسح `world` ورجّع نسخة الاحتياطي باسم `world`.

---

## 7) الملفات اللي في الريپو

| الملف | الوظيفة |
|---|---|
| `setup.ps1` | يحمّل آخر Paper مستقر من PaperMC، يتأكد من الـ checksum، ويتحقق من نسخة Java |
| `start.ps1` | يشغّل السيرفر بأعلام JVM محسّنة (G1GC) و`nogui` |
| `server.properties` | إعدادات السيرفر |
| `eula.txt` | موافقة اتفاقية الاستخدام (لازم تغيرها لإيدك) |
| `server.build.properties` | بيتكتب أوتوماتيك: الإصدار والـ build المحمّل |
| `.gitignore` | يمنع رفع ملف السيرفر (55MB)، العوالم، واللوجات |

**ليه ملف الـ jar مش مرفوع على GitHub؟** لأنه كبير (50+ ميجابايت) ودايمًا بيتحدّث -
`setup.ps1` بيجيبه من PaperMC في ثواني، وكده الريپو بيبقى خفيف ودائم.

---

## 8) مشاكل شائعة

| المشكلة | الحل |
|---|---|
| `Java not found` في `setup.ps1` | نزّل JDK من الخطوة 1 وافتح PowerShell **جديدة** |
| `Running servers must update eula.txt` | غيّر `eula=false` لـ `true` في `eula.txt` |
| `UnsupportedClassVersionError` | نسخة Java أقدم من المطلوب - نزّل الأحدث |
| أصحابك مش داخلين على LAN | راجع قاعدة الـ Firewall + تأكد إنكم على نفس الشبكة |
| السيرفر بطيء/بيهنّق | نزّل `view-distance` لـ 6 و`simulation-distance` لـ 4، وزوّد الرام `-MemoryGB 8` |
| PowerShell مانع السكربت | `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` |
