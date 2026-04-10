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

const DEFAULT_HEADERS = {
  Accept: "application/json, text/plain, */*",
  "User-Agent": "MuslimAI-Mobile/0.1",
};

export const translationOptions = [
  { value: "en.asad", label: "English · Muhammad Asad" },
  { value: "en.pickthall", label: "English · Pickthall" },
  { value: "en.yusufali", label: "English · Yusuf Ali" },
  { value: "fr.hamidullah", label: "French · Hamidullah" },
  { value: "ur.jalandhry", label: "Urdu · Jalandhry" },
] as const;

export const readerOptions = [
  { value: "ar.alafasy", label: "Sheikh Alafasy" },
  { value: "ar.abdulsamad", label: "Sheikh Abdul Samad" },
  { value: "ar.abdurrahmaansudais", label: "Sheikh Sudais" },
  { value: "ar.shaatree", label: "Sheikh Shatri" },
  { value: "ar.mahermuaiqly", label: "Sheikh Maher Al Muaiqly" },
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

    return (await response.json()) as T;
  } finally {
    if (timeoutId) {
      clearTimeout(timeoutId);
    }
  }
}

async function fetchJson<T>(url: string): Promise<T> {
  const response = await fetch(url, { headers: DEFAULT_HEADERS });
  if (!response.ok) {
    throw new Error(`Request failed with status ${response.status}`);
  }
  return (await response.json()) as T;
}

function cleanTimingLabel(rawValue: string): string {
  return rawValue.split(" ", 1)[0].trim();
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
  const payload = await fetchJson<any>("https://api.alquran.cloud/v1/surah");
  return Array.isArray(payload.data) ? payload.data : [];
}

export async function fetchQuranSurah(
  surahNumber: number,
  translation: string,
  reader: string,
): Promise<{ surah: SurahSummary | null; ayahs: AyahRow[] }> {
  const [translationPayload, audioPayload] = await Promise.all([
    fetchJson<any>(
      `https://api.alquran.cloud/v1/surah/${surahNumber}/editions/quran-uthmani,${translation}`,
    ),
    fetchJson<any>(`https://api.alquran.cloud/v1/surah/${surahNumber}/${reader}`),
  ]);

  const translationEditions = Array.isArray(translationPayload.data)
    ? translationPayload.data
    : [];
  const arabicEdition = translationEditions[0] ?? null;
  const translatedEdition = translationEditions[1] ?? null;
  const audioSurah = audioPayload.data ?? null;
  const audioByAyah = new Map<number, Record<string, unknown>>();

  for (const ayah of audioSurah?.ayahs ?? []) {
    if (ayah && typeof ayah.numberInSurah === "number") {
      audioByAyah.set(ayah.numberInSurah, ayah);
    }
  }

  const ayahs: AyahRow[] = [];
  for (const [index, arabicAyah] of (arabicEdition?.ayahs ?? []).entries()) {
    const translationAyah = translatedEdition?.ayahs?.[index] ?? {};
    const audioAyah = audioByAyah.get(arabicAyah.numberInSurah) ?? {};
    ayahs.push({
      numberInSurah: arabicAyah.numberInSurah ?? index + 1,
      arabicText: arabicAyah.text ?? "",
      translationText: translationAyah.text ?? "",
      audioUrl: typeof audioAyah.audio === "string" ? audioAyah.audio : "",
      audioSecondaryUrl: secondaryAudioUrl(audioAyah),
    });
  }

  return {
    surah: translatedEdition ?? audioSurah ?? null,
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
  const payload = await fetchJson<Record<string, unknown>>(AZKAR_SOURCE_URL);
  const categories = Object.keys(payload);
  const activeCategory = selectedCategory && payload[selectedCategory] ? selectedCategory : categories[0];
  return {
    categories,
    selectedCategory: activeCategory,
    entries: flattenAzkarEntries(payload[activeCategory] ?? []),
  };
}

export async function fetchHisnMuslim(collectionId: number) {
  const payload = await fetchJson<Record<string, unknown>>(
    `https://www.hisnmuslim.com/api/ar/${collectionId}.json`,
  );
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
