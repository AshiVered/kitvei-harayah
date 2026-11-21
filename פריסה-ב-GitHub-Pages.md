# פריסת אתר כתבי הראי״ה

## איך זה בנוי

| מה | איפה |
|---|---|
| דף הבית של התוכנה (לחצן הורדה ולחצן לגרסה המקוונת) | https://aiv-dev.com/kitvei-harayah/ |
| הגרסה המקוונת של התוכנה | https://aiv-dev.com/kitvei-harayah/app/ |
| קוד המקור, ה-Releases וקובצי ההורדה | https://github.com/AshiVered/kitvei-harayah |
| הקבצים של האתר (ענף `gh-pages`) | https://github.com/AIV-DEV/kitvei-harayah |

**למה האתר בריפו נפרד:** לאתר האישי של החשבון AIV-DEV (`aiv-dev.github.io`) מוגדר הדומיין `aiv-dev.com`, דרך Cloudflare. במצב כזה GitHub מגיש **אוטומטית** כל ריפו עם Pages של אותו חשבון בכתובת `aiv-dev.com/<שם-הריפו>/`. לכן אין צורך לשנות שום דבר ב-Cloudflare או ב-DNS, ושאר האתר לא מושפע.

**דף הבית** נבנה מהתבנית `site/index.template.html` בעזרת `tools/build_site.py`. רשימת הספרים בו נלקחת מקטלוג התוכנה, כך שהיא תמיד תואמת לתוכנה.

---

## עדכון האתר

ב-PowerShell, בתיקיית הפרויקט:

```powershell
powershell -ExecutionPolicy Bypass -File deploy_github_pages.ps1 -User AshiVered -SiteOwner AIV-DEV -Repo kitvei-harayah -DirectDownload
```

הסקריפט עושה את הכול:
1. בונה את הגרסה המקוונת לנתיב `/kitvei-harayah/app/`.
2. בונה את דף הבית.
3. דוחף את שניהם לענף `gh-pages` בריפו `AIV-DEV/kitvei-harayah`.

אחרי דקה או שתיים האתר מתעדכן. כדי לראות את השינוי, ייתכן שתצטרכו לרענן עם Ctrl+F5.

**הפרמטרים:**
- `-User AshiVered`: הבעלים של ריפו הקוד. לשם מובילים הקישורים ל-Release ולקוד.
- `-SiteOwner AIV-DEV`: הבעלים של ריפו האתר.
- `-DirectDownload`: לחצן ההורדה מוביל ישירות לקובץ ה-zip שב-Release. בלי הפרמטר הזה הוא מוביל לדף ה-Release. משתמשים בו רק אחרי שה-zip של הגרסה כבר צורף ל-Release.
- `-SkipBuild`: לא לבנות מחדש את הגרסה המקוונת, אלא להשתמש ב-`build\web` הקיים (למשל אחרי שינוי בדף הבית בלבד).

> **חשוב:** הריצו מ-PowerShell ולא מ-Git Bash. Git Bash ממיר נתיבים כמו `/kitvei-harayah/app/` לנתיבים של Windows, והאתר יוצג כמסך לבן.

---

## גרסה חדשה של התוכנה

1. מעדכנים את מספר הגרסה ב-`pubspec.yaml` וב-`lib/version.dart`.
2. בונים: `powershell -ExecutionPolicy Bypass -File build.ps1 windows`.
3. יוצרים Release חדש בריפו `AshiVered/kitvei-harayah` ומצרפים אליו את ה-zip.
   - **שימו לב:** חיבור עם סינון נטו חוסם את `uploads.github.com`, ולכן צירוף קבצים ל-Release צריך להיעשות מרשת אחרת.
4. מריצים את פקודת הפריסה שלמעלה עם `-DirectDownload`. מספר הגרסה וקישור ההורדה בדף הבית מתעדכנים אוטומטית מ-`pubspec.yaml`.

---

## הערות

- **מידע אישי בגרסה המקוונת:** האתר לא שומר שום דבר אישי. אין בו הערות, סימניות, היסטוריית קריאה או ייצוא/ייבוא; אלה זמינים רק בתוכנה למחשב. הגדרות התצוגה (גופן, גודל, ניקוד, ערכת צבעים) חלות רק על המבקר, ומתאפסות כשהוא עוזב את האתר.
- **רישיונות:** הטקסטים מוויקיטקסט ברישיון CC BY-SA, ומחייבים ייחוס. לשונית „אודות” בתוכנה ובאתר כוללת את הייחוס המלא לכל ספר.
- **מגבלות GitHub Pages:** עד 1GB לאתר (האתר הזה כ-46MB), ותעבורה של כ-100GB בחודש. כך מופיע בתיעוד של GitHub; כדאי לוודא מול התיעוד העדכני.
