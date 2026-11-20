<div dir="rtl">

<img src="assets/icon/icon.png" width="120" align="left" alt="">

# כתבי הראי״ה

ספריית כתבי מרן הרב אברהם יצחק הכהן קוק זצ״ל – תוכנה חינמית למחשב ואתר, עם חיפוש מלא בכל הספרים.

**[⬇ הורדה ל-Windows](../../releases/latest)** · **[🌐 גרסה מקוונת](https://AshiVered.github.io/kitvei-harayah/app/)** · **[אתר התוכנה](https://AshiVered.github.io/kitvei-harayah/)**

## מה יש בתוכנה

- **ספרייה** – אורות, אורות הקודש, אורות התורה, אורות התשובה, אורות האמונה, שמונה קבצים, ערפלי טוהר, קבצים מכתב יד קדשו, עין איה, עולת ראיה, מוסר אביך, מידות הראיה, מאמרי הראיה, מדבר שור, אגרות ועוד.
- **חיפוש מלא** בכל הספרים, ללא תלות בניקוד ובגרשיים.
- **קריאה נוחה** – לשוניות, תוכן עניינים, ניקוד לבחירה, גופנים, גודל אות וערכת צבעים בהירה/כהה.
- **הערות אישיות** – מסמנים טקסט, קליק ימני ← „הוספת הערה”.
- **סימניות והמשך לימוד** מהמקום שבו הפסקתם.
- **גיבוי** – ייצוא וייבוא של ההגדרות, הסימניות, ההערות והיסטוריית הקריאה.
- **עובדת בלי אינטרנט** – כל הספרים כלולים בתוכנה.

גרסת האתר כוללת את הספרייה, החיפוש וההגדרות, אך אינה שומרת מידע אישי (הערות, סימניות והיסטוריה זמינות בתוכנה למחשב בלבד).

## התקנה

מורידים את קובץ ה-zip מ-[Releases](../../releases), פותחים אותו ומפעילים את `KitveiHaRaayah.exe`. אין צורך בהתקנה.

## מקורות ורישיונות

- **קוד התוכנה:** רישיון MIT (ראו [LICENSE](LICENSE)).
- **הטקסטים:** מוויקיטקסט העברי (CC BY-SA) ומספריא (נחלת הכלל / CC BY-SA, לפי המהדורה). נכללות רק מהדורות שהרישיון שלהן מוצהר במקור. פירוט לכל ספר בלשונית „אודות” ובקובץ [assets/text_licenses.json](assets/text_licenses.json).
- **גופנים:** Frank Ruhl Libre, David Libre, Heebo – SIL Open Font License.
- **דיוקן הרב באייקון:** צילום משנת 1924, אוסף ספריית הקונגרס האמריקנית (npcc.25595) – נחלת הכלל.

נשמח לקבל טקסטים נוספים מכתבי הרב, שאין בהם בעיה של זכויות יוצרים.

## בנייה מהקוד

נדרש [Flutter](https://flutter.dev) 3.50 ומעלה. ב-PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File build.ps1 windows
powershell -ExecutionPolicy Bypass -File build.ps1 web -BaseHref /kitvei-harayah/app/
```

עדכון הטקסטים מהמקורות:

```powershell
python tools/download_sefaria.py
python tools/download_wikisource.py
python tools/fetch_licenses.py
python tools/build_assets.py
```

</div>
