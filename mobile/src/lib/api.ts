export type PrayerTiming = { name: string; time: string };

export type PrayerTimesResponse = {
  readableDate: string;
  hijriDate: string;
  timezone: string;
  calculationMethod: string;
  timings: PrayerTiming[];
};

export type QiblaResponse = {
  direction: number;
  latitude: number;
  longitude: number;
};

export type SurahSummary = {
  number: number;
  name: string;
  englishName: string;
  englishNameTranslation: string;
  numberOfAyahs: number;
  revelationType: string;
};

export type AyahRow = {
  numberInSurah: number;
  arabicText: string;
  translationText: string;
  audioUrl: string;
  audioSecondaryUrl: string;
};

export type HadithItem = Record<string, unknown>;
export type AzkarEntry = Record<string, unknown>;
export type RadioStation = { id: number; name: string; url: string };

type QuranChapterPayload = {
  id: number;
  revelation_place: string;
  name_arabic: string;
  name_simple: string;
  translated_name?: { name?: string };
  verses_count: number;
};

const DEFAULT_HEADERS = {
  Accept: "application/json, text/plain, */*",
  "User-Agent": "MuslimAI-Mobile/0.1",
};

const QURAN_COM_API_BASE = "https://api.quran.com/api/v4";
const QURAN_VERSE_AUDIO_BASE = "https://verses.quran.com/";
const azkarSnapshot = require("../data/azkar.snapshot.json") as Record<string, unknown>;
const hisnMuslim27Snapshot = require("../data/hisn-muslim-27.snapshot.json") as Record<string, unknown>;

export const translationOptions = [
  { value: "85", label: "English · Abdel Haleem" },
  { value: "19", label: "English · Pickthall" },
  { value: "22", label: "English · Yusuf Ali" },
  { value: "31", label: "French · Hamidullah" },
  { value: "234", label: "Urdu · Jalandhry" },
] as const;

export const readerOptions = [
  { value: "7", label: "Sheikh Alafasy" },
  { value: "2", label: "Sheikh Abdul Samad" },
  { value: "3", label: "Sheikh Sudais" },
  { value: "4", label: "Sheikh Abu Bakr Al-Shatri" },
  { value: "6", label: "Sheikh Husary" },
] as const;

export const hadithCollections = [
  { value: "eng-bukhari", label: "Sahih al-Bukhari" },
  { value: "eng-muslim", label: "Sahih Muslim" },
  { value: "eng-abudawud", label: "Abu Dawud" },
  { value: "eng-tirmidhi", label: "Jami` at-Tirmidhi" },
  { value: "eng-nasai", label: "Sunan an-Nasa'i" },
  { value: "eng-ibnmajah", label: "Ibn Majah" },
] as const;

const AZKAR_SOURCE_URL =
  "https://raw.githubusercontent.com/nawafalqari/azkar-api/56df51279ab6eb86dc2f6202c7de26c8948331c1/azkar.json";

const fallbackHadithByCollection: Record<string, HadithItem[]> = {
  "eng-bukhari": [
    {
      number: 1,
      translation:
        "Narrated Umar ibn Al-Khattab: I heard Allah's Messenger saying that deeds are judged by intentions, and every person will have only what they intended.",
    },
    {
      number: 2,
      translation:
        "Narrated Abu Hurairah: Faith has many branches, the highest is the declaration that there is no deity but Allah, and the lowest is removing harm from the road.",
    },
  ],
  "eng-muslim": [
    {
      number: 1,
      translation:
        "Abu Hurairah reported: Whoever follows a path in pursuit of knowledge, Allah will make easy for him a path to Paradise.",
    },
    {
      number: 2,
      translation:
        "Abu Hurairah reported: Allah does not look at your bodies or your appearances, but He looks at your hearts and your deeds.",
    },
  ],
};

async function fetchJsonWithTimeout<T>(
  url: string,
  init?: RequestInit,
  timeoutMs = 10000,
): Promise<T> {
  let timeoutId: ReturnType<typeof setTimeout> | undefined;
  try {
    const response = (await Promise.race([
      fetch(url, init),
      new Promise<never>((_, reject) => {
        timeoutId = setTimeout(() => {
          reject(new Error(`Request timed out after ${timeoutMs}ms`));
        }, timeoutMs);
      }),
    ])) as Response;

    if (!response.ok) {
      throw new Error(`Request failed with status ${response.status}`);
    }

    const rawText = await response.text();
    return parseJsonPayload<T>(rawText, url);
  } finally {
    if (timeoutId) {
      clearTimeout(timeoutId);
    }
  }
}

function parseJsonPayload<T>(rawText: string, url: string): T {
  const cleanedText = rawText.replace(/^\uFEFF/, "").trim();

  if (!cleanedText) {
    throw new Error(`Empty JSON response from ${url}`);
  }

  try {
    return JSON.parse(cleanedText) as T;
  } catch {
    const preview = cleanedText.slice(0, 80).replace(/\s+/g, " ");
    throw new Error(`Invalid JSON response from ${url}: ${preview}`);
  }
}

async function fetchJson<T>(url: string): Promise<T> {
  const response = await fetch(url, { headers: DEFAULT_HEADERS });
  if (!response.ok) {
    throw new Error(`Request failed with status ${response.status}`);
  }
  const rawText = await response.text();
  return parseJsonPayload<T>(rawText, url);
}

function cleanTimingLabel(rawValue: string): string {
  return rawValue.split(" ", 1)[0].trim();
}

function sanitizeTranslationText(rawValue: unknown): string {
  return String(rawValue ?? "")
    .replace(/<[^>]+>/g, " ")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&amp;/g, "&")
    .replace(/\s+/g, " ")
    .trim();
}

function toAbsoluteVerseAudioUrl(rawValue: unknown): string {
  const url = String(rawValue ?? "").trim();
  if (!url) {
    return "";
  }
  if (/^https?:\/\//i.test(url)) {
    return url;
  }
  return `${QURAN_VERSE_AUDIO_BASE}${url.replace(/^\/+/, "")}`;
}

async function fetchAllQuranPages<T>(buildUrl: (page: number) => string, key: string): Promise<T[]> {
  const items: T[] = [];
  let page = 1;

  while (true) {
    const payload = await fetchJson<any>(buildUrl(page));
    const pageItems = Array.isArray(payload?.[key]) ? payload[key] : [];
    items.push(...pageItems);

    const nextPage = payload?.pagination?.next_page;
    if (!nextPage) {
      break;
    }
    page = Number(nextPage);
    if (!Number.isFinite(page) || page < 1) {
      break;
    }
  }

  return items;
}

function secondaryAudioUrl(payload: Record<string, unknown>): string {
  const candidates = payload.audioSecondary;
  if (Array.isArray(candidates) && typeof candidates[0] === "string") {
    return candidates[0];
  }
  return "";
}

export async function fetchPrayerTimes(
  prayerDate: string,
  latitude: number,
  longitude: number,
): Promise<PrayerTimesResponse> {
  const query = new URLSearchParams({
    latitude: String(latitude),
    longitude: String(longitude),
    method: "4",
  });
  const payload = await fetchJson<any>(
    `https://api.aladhan.com/v1/timings/${prayerDate}?${query.toString()}`,
  );
  if (payload.code !== 200) {
    throw new Error(payload.status || "Prayer times lookup failed.");
  }
  const data = payload.data;
  const order = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"];
  return {
    readableDate: data.date.readable,
    hijriDate: data.date.hijri.date,
    timezone: data.meta.timezone,
    calculationMethod: data.meta.method.name,
    timings: order.map((name) => ({
      name,
      time: cleanTimingLabel(data.timings[name]),
    })),
  };
}

export async function fetchQibla(
  latitude: number,
  longitude: number,
): Promise<QiblaResponse> {
  const payload = await fetchJson<any>(
    `https://api.aladhan.com/v1/qibla/${latitude}/${longitude}`,
  );
  if (payload.code !== 200) {
    throw new Error(payload.status || "Qibla lookup failed.");
  }
  return {
    direction: Number(payload.data.direction),
    latitude,
    longitude,
  };
}

export async function fetchSurahList(): Promise<SurahSummary[]> {
  const payload = await fetchJson<{ chapters?: QuranChapterPayload[] }>(
    `${QURAN_COM_API_BASE}/chapters?language=en`,
  );
  return Array.isArray(payload.chapters)
    ? payload.chapters.map((item) => ({
        number: item.id,
        name: item.name_arabic,
        englishName: item.name_simple,
        englishNameTranslation: item.translated_name?.name ?? "",
        numberOfAyahs: item.verses_count,
        revelationType: item.revelation_place,
      }))
    : [];
}

export async function fetchQuranSurah(
  surahNumber: number,
  translation: string,
  reader: string,
): Promise<{ surah: SurahSummary | null; ayahs: AyahRow[] }> {
  const [chapterPayload, arabicPayload, translationPayload, audioPayload] = await Promise.all([
    fetchJson<{ chapter?: QuranChapterPayload }>(`${QURAN_COM_API_BASE}/chapters/${surahNumber}?language=en`),
    fetchJson<{ verses?: Array<{ verse_key: string; text_uthmani: string }> }>(
      `${QURAN_COM_API_BASE}/quran/verses/uthmani?chapter_number=${surahNumber}`,
    ),
    fetchAllQuranPages<any>(
      (page) =>
        `${QURAN_COM_API_BASE}/verses/by_chapter/${surahNumber}?language=en&words=false&translations=${translation}&per_page=50&page=${page}&fields=chapter_id,verse_key,juz_number,hizb_number,page_number,manzil_number`,
      "verses",
    ),
    fetchAllQuranPages<any>(
      (page) => `${QURAN_COM_API_BASE}/recitations/${reader}/by_chapter/${surahNumber}?per_page=50&page=${page}`,
      "audio_files",
    ),
  ]);

  const chapter = chapterPayload.chapter;
  const arabicVerses = Array.isArray(arabicPayload.verses) ? arabicPayload.verses : [];
  const translationByVerseKey = new Map<string, any>();
  const audioByVerseKey = new Map<string, any>();

  for (const verse of translationPayload) {
    if (verse && typeof verse.verse_key === "string") {
      translationByVerseKey.set(verse.verse_key, verse);
    }
  }

  for (const verse of audioPayload) {
    if (verse && typeof verse.verse_key === "string") {
      audioByVerseKey.set(verse.verse_key, verse);
    }
  }

  const ayahs: AyahRow[] = arabicVerses.map((verse, index) => {
    const verseKey = verse.verse_key;
    const meta = translationByVerseKey.get(verseKey) ?? {};
    const audio = audioByVerseKey.get(verseKey) ?? {};
    const verseNumber = Number(String(verseKey).split(":")[1] ?? index + 1);

    return {
      numberInSurah: Number.isFinite(verseNumber) ? verseNumber : index + 1,
      arabicText: String(verse.text_uthmani ?? "").trim(),
      translationText: sanitizeTranslationText(meta?.translations?.[0]?.text ?? ""),
      audioUrl: toAbsoluteVerseAudioUrl(audio?.url),
      audioSecondaryUrl: "",
    };
  });

  return {
    surah: chapter
      ? {
          number: chapter.id,
          name: chapter.name_arabic,
          englishName: chapter.name_simple,
          englishNameTranslation: chapter.translated_name?.name ?? "",
          numberOfAyahs: chapter.verses_count,
          revelationType: chapter.revelation_place,
        }
      : null,
    ayahs,
  };
}

export async function fetchHadithPage(collection: string, page = 1, limit = 12) {
  const url = `https://raw.githubusercontent.com/fawazahmed0/hadith-api/1/editions/${collection}/sections/1.min.json`;
  try {
    const payload = await fetchJsonWithTimeout<Record<string, unknown>>(url, undefined, 10000);
    const rows = Array.isArray(payload?.hadiths) ? payload.hadiths : [];
    const start = Math.max(0, (page - 1) * limit);
    return rows.slice(start, start + limit).map((item: Record<string, unknown>) => ({
      number: item.hadithnumber ?? item.arabicnumber ?? "",
      translation: item.text ?? "",
      reference: item.reference ?? {},
    })) as HadithItem[];
  } catch {
    return (fallbackHadithByCollection[collection] ?? fallbackHadithByCollection["eng-bukhari"] ?? []).slice(
      0,
      limit,
    );
  }
}

function flattenAzkarEntries(node: unknown): AzkarEntry[] {
  if (node && typeof node === "object" && "content" in (node as Record<string, unknown>)) {
    return [node as AzkarEntry];
  }
  if (Array.isArray(node)) {
    return node.flatMap((item) => flattenAzkarEntries(item));
  }
  return [];
}

export async function fetchAzkarCategory(selectedCategory?: string) {
  const payload = azkarSnapshot;
  const categories = Object.keys(payload);
  const activeCategory = selectedCategory && payload[selectedCategory] ? selectedCategory : categories[0];
  return {
    categories,
    selectedCategory: activeCategory,
    entries: flattenAzkarEntries(payload[activeCategory] ?? []),
  };
}

export async function fetchHisnMuslim(collectionId: number) {
  const payload =
    collectionId === 27
      ? hisnMuslim27Snapshot
      : await fetchJson<Record<string, unknown>>(`https://www.hisnmuslim.com/api/ar/${collectionId}.json`);
  const [categoryName = "", rawEntries = []] = Object.entries(payload)[0] ?? ["", []];
  return {
    categoryName,
    entries: Array.isArray(rawEntries) ? rawEntries : [],
  };
}

export async function fetchRadioStations() {
  const payload = await fetchJson<any>("https://data-rosy.vercel.app/radio.json");
  const stations = Array.isArray(payload?.radios)
    ? payload.radios
        .filter((item: any) => item?.id != null && item?.name && item?.url)
        .map(
          (item: any): RadioStation => ({
            id: Number(item.id),
            name: String(item.name),
            url: String(item.url),
          }),
        )
    : [];
  return stations;
}
