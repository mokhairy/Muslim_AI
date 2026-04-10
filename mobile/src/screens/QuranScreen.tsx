import { Ionicons } from "@expo/vector-icons";
import { Picker } from "@react-native-picker/picker";
import { setAudioModeAsync, useAudioPlayer, useAudioPlayerStatus } from "expo-audio";
import { useEffect, useMemo, useRef, useState } from "react";
import {
  ActivityIndicator,
  FlatList,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from "react-native";

import {
  fetchQuranSurah,
  fetchSurahList,
  readerOptions,
  translationOptions,
  type AyahRow,
  type SurahSummary,
} from "../lib/api";
import { fonts, palette, radii, shadows, spacing } from "../theme";

const modeOptions = [
  { value: "read", label: "Read only" },
  { value: "listen", label: "Listen only" },
  { value: "read_listen", label: "Read while listening" },
] as const;

export function QuranScreen() {
  const [surahs, setSurahs] = useState<SurahSummary[]>([]);
  const [surahNumber, setSurahNumber] = useState(1);
  const [translation, setTranslation] = useState("en.asad");
  const [reader, setReader] = useState("ar.alafasy");
  const [mode, setMode] = useState<(typeof modeOptions)[number]["value"]>("read_listen");
  const [ayahs, setAyahs] = useState<AyahRow[]>([]);
  const [surah, setSurah] = useState<SurahSummary | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [currentAyahIndex, setCurrentAyahIndex] = useState(0);
  const [surahSearch, setSurahSearch] = useState("");
  const flatListRef = useRef<FlatList<AyahRow>>(null);
  const previousDidJustFinishRef = useRef(false);
  const playbackAyahIndexRef = useRef<number | null>(null);
  const player = useAudioPlayer(null, {
    updateInterval: 250,
    downloadFirst: true,
    keepAudioSessionActive: true,
  });
  const playerStatus = useAudioPlayerStatus(player);
  const isPlaying = Boolean(playerStatus?.playing);

  const currentAyah = ayahs[currentAyahIndex] ?? null;

  const filteredSurahs = useMemo(() => {
    const normalizedSearch = surahSearch.trim().toLowerCase();
    if (!normalizedSearch) {
      return surahs.slice(0, 8);
    }
    return surahs.filter((item) =>
      `${item.number} ${item.englishName} ${item.englishNameTranslation}`
        .toLowerCase()
        .includes(normalizedSearch),
    );
  }, [surahs, surahSearch]);

  async function loadSurahs() {
    try {
      setSurahs(await fetchSurahList());
    } catch {
      setSurahs([]);
    }
  }

  async function loadSurah() {
    setLoading(true);
    setError("");
    try {
      const result = await fetchQuranSurah(surahNumber, translation, reader);
      setSurah(result.surah);
      setAyahs(result.ayahs);
      setCurrentAyahIndex(0);
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : "Unable to load surah.");
      setAyahs([]);
      setSurah(null);
    } finally {
      setLoading(false);
    }
  }

  function playAyah(index: number) {
    const row = ayahs[index];
    if (!row) {
      return;
    }
    const source = row.audioSecondaryUrl || row.audioUrl;
    if (!source) {
      return;
    }

    playbackAyahIndexRef.current = index;
    setCurrentAyahIndex(index);
    player.replace(source);
    player.seekTo(0);
    player.play();
  }

  function togglePlayback() {
    if (playerStatus?.playing) {
      player.pause();
      return;
    }

    if (
      playbackAyahIndexRef.current === currentAyahIndex &&
      typeof playerStatus?.currentTime === "number" &&
      playerStatus.currentTime > 0 &&
      !playerStatus?.didJustFinish
    ) {
      player.play();
      return;
    }

    playAyah(currentAyahIndex);
  }

  useEffect(() => {
    setAudioModeAsync({
      playsInSilentMode: true,
      interruptionMode: "doNotMix",
      shouldPlayInBackground: false,
    }).catch(() => null);
    loadSurahs().catch(() => null);
  }, []);

  useEffect(() => {
    loadSurah().catch(() => null);
  }, [surahNumber, translation, reader]);

  useEffect(() => {
    previousDidJustFinishRef.current = false;
    playbackAyahIndexRef.current = null;
    player.pause();
  }, [ayahs, player]);

  useEffect(() => {
    if (mode === "read") {
      previousDidJustFinishRef.current = false;
      player.pause();
    }
  }, [mode, player]);

  useEffect(() => {
    if (mode === "read_listen" && ayahs[currentAyahIndex]) {
      flatListRef.current?.scrollToIndex({
        animated: true,
        index: currentAyahIndex,
        viewPosition: 0.2,
      });
    }
  }, [currentAyahIndex, mode, ayahs]);

  useEffect(() => {
    const didJustFinish = Boolean(playerStatus?.didJustFinish);
    if (!didJustFinish) {
      previousDidJustFinishRef.current = false;
      return;
    }

    if (previousDidJustFinishRef.current) {
      return;
    }

    previousDidJustFinishRef.current = true;
    const finishedIndex = playbackAyahIndexRef.current ?? currentAyahIndex;
    const nextIndex = finishedIndex + 1;
    if (ayahs[nextIndex] && mode !== "read") {
      playAyah(nextIndex);
      return;
    }

    playbackAyahIndexRef.current = null;
    player.pause();
  }, [ayahs, currentAyahIndex, mode, player, playerStatus?.didJustFinish]);

  return (
    <View style={styles.page}>
      <FlatList
        ref={flatListRef}
        data={mode === "listen" ? [] : ayahs}
        keyExtractor={(item) => String(item.numberInSurah)}
        contentContainerStyle={styles.content}
        onScrollToIndexFailed={({ index, averageItemLength }) => {
          flatListRef.current?.scrollToOffset({
            animated: true,
            offset: index * averageItemLength,
          });
        }}
        ListHeaderComponent={
          <>
            <View style={styles.topBar}>
              <Text style={styles.brand}>Muslim AI</Text>
              <View style={styles.profileDot} />
            </View>

            <View style={styles.heroBlock}>
              <Text style={styles.heroKicker}>Sacred text</Text>
              <Text style={styles.heroTitle}>Journey through the Divine Revelation.</Text>
            </View>

            <View style={styles.panel}>
              <View style={styles.panelHeader}>
                <Text style={styles.panelTitle}>Surahs</Text>
                <Text style={styles.panelLabel}>{surahs.length} available</Text>
              </View>
              <View style={styles.searchBox}>
                <Ionicons name="search-outline" size={16} color={palette.outline} />
                <TextInput
                  style={styles.searchInput}
                  value={surahSearch}
                  onChangeText={setSurahSearch}
                  placeholder="Search surah..."
                  placeholderTextColor={palette.outline}
                />
              </View>
              <View style={styles.surahList}>
                {filteredSurahs.map((item) => {
                  const active = item.number === surahNumber;
                  return (
                    <Pressable
                      key={item.number}
                      onPress={() => setSurahNumber(item.number)}
                      style={[styles.surahCard, active ? styles.surahCardActive : undefined]}
                    >
                      <View style={[styles.surahIndex, active ? styles.surahIndexActive : undefined]}>
                        <Text
                          style={[
                            styles.surahIndexText,
                            active ? styles.surahIndexTextActive : undefined,
                          ]}
                        >
                          {String(item.number).padStart(2, "0")}
                        </Text>
                      </View>
                      <View style={styles.surahMeta}>
                        <Text style={[styles.surahName, active ? styles.surahNameActive : undefined]}>
                          {item.englishName}
                        </Text>
                        <Text
                          style={[
                            styles.surahSubtitle,
                            active ? styles.surahSubtitleActive : undefined,
                          ]}
                        >
                          {item.englishNameTranslation} • {item.numberOfAyahs} verses
                        </Text>
                      </View>
                    </Pressable>
                  );
                })}
              </View>
            </View>

            <View style={styles.panel}>
              <Text style={styles.panelTitle}>Reader controls</Text>
              <View style={styles.pickerWrap}>
                <Picker
                  selectedValue={surahNumber}
                  style={styles.picker}
                  dropdownIconColor={palette.primary}
                  onValueChange={(value) => setSurahNumber(Number(value))}
                >
                  {surahs.map((item) => (
                    <Picker.Item
                      key={item.number}
                      label={`${item.number}. ${item.englishName}`}
                      value={item.number}
                    />
                  ))}
                </Picker>
              </View>
              <View style={styles.pickerWrap}>
                <Picker
                  selectedValue={translation}
                  style={styles.picker}
                  dropdownIconColor={palette.primary}
                  onValueChange={(value) => setTranslation(String(value))}
                >
                  {translationOptions.map((item) => (
                    <Picker.Item key={item.value} label={item.label} value={item.value} />
                  ))}
                </Picker>
              </View>
              <View style={styles.pickerWrap}>
                <Picker
                  selectedValue={reader}
                  style={styles.picker}
                  dropdownIconColor={palette.primary}
                  onValueChange={(value) => setReader(String(value))}
                >
                  {readerOptions.map((item) => (
                    <Picker.Item key={item.value} label={item.label} value={item.value} />
                  ))}
                </Picker>
              </View>
              <View style={styles.modeGroup}>
                {modeOptions.map((item) => (
                  <Pressable
                    key={item.value}
                    onPress={() => setMode(item.value)}
                    style={[styles.modeChip, mode === item.value ? styles.modeChipActive : undefined]}
                  >
                    <Text
                      style={[
                        styles.modeChipText,
                        mode === item.value ? styles.modeChipTextActive : undefined,
                      ]}
                    >
                      {item.label}
                    </Text>
                  </Pressable>
                ))}
              </View>
              {error ? <Text style={styles.errorText}>{error}</Text> : null}
            </View>

            <View style={styles.bookmarkCard}>
              <Text style={styles.bookmarkTitle}>Recent bookmark</Text>
              <Text style={styles.bookmarkMeta}>
                {surah ? `${surah.englishName} • Ayah ${currentAyah?.numberInSurah ?? 1}` : "Open a surah"}
              </Text>
              <TouchableOpacity style={styles.bookmarkButton} onPress={() => setMode("read_listen")}>
                <Text style={styles.bookmarkButtonText}>Continue reading</Text>
              </TouchableOpacity>
            </View>

            <View style={styles.banner}>
              <Text style={styles.bannerKicker}>
                {surah ? `Surah ${surah.englishName}` : "Surah"}
              </Text>
              <Text style={styles.bannerArabic}>{surah?.name ?? "..."}</Text>
              <Text style={styles.bannerCopy}>
                {surah
                  ? `${surah.englishNameTranslation} • ${surah.numberOfAyahs} verses • ${surah.revelationType}`
                  : "Choose a surah to begin reading or listening."}
              </Text>
            </View>

            {loading ? <ActivityIndicator color={palette.primary} style={styles.loader} /> : null}
          </>
        }
        renderItem={({ item, index }) => {
          const active = index === currentAyahIndex && mode !== "read";
          return (
            <Pressable
              onPress={() => {
                setCurrentAyahIndex(index);
                if (mode !== "read") {
                  playAyah(index);
                }
              }}
              style={[styles.ayahBlock, active ? styles.ayahBlockActive : undefined]}
            >
              <View style={styles.ayahHeader}>
                <Text style={styles.ayahReference}>
                  {surahNumber}:{item.numberInSurah}
                </Text>
                <View style={styles.ayahActions}>
                  <Ionicons name="bookmark-outline" size={18} color={palette.textMuted} />
                  <Ionicons name="play-circle-outline" size={20} color={palette.textMuted} />
                </View>
              </View>
              <Text style={styles.arabicText}>{item.arabicText}</Text>
              <Text style={styles.translationText}>{item.translationText}</Text>
            </Pressable>
          );
        }}
        ListEmptyComponent={
          loading ? null : (
            <View style={styles.emptyState}>
              <Text style={styles.emptyStateText}>
                {mode === "listen"
                  ? "Listen-only mode keeps the reading surface clear and uses the floating player below."
                  : "No ayahs loaded yet."}
              </Text>
            </View>
          )
        }
      />

      {currentAyah && mode !== "read" ? (
        <View style={styles.playerDock}>
          <View style={styles.playerTextBlock}>
            <Text style={styles.playerKicker}>
              {surah ? `${surah.englishName} • Ayah ${currentAyah.numberInSurah}` : "Now playing"}
            </Text>
            <Text style={styles.playerLine} numberOfLines={1}>
              {currentAyah.translationText}
            </Text>
          </View>
          <TouchableOpacity
            style={styles.playerIconButton}
            onPress={() => playAyah(Math.max(0, currentAyahIndex - 1))}
          >
            <Ionicons name="play-skip-back" size={18} color={palette.primary} />
          </TouchableOpacity>
          <TouchableOpacity style={styles.playerPrimary} onPress={togglePlayback}>
            <Ionicons name={isPlaying ? "pause" : "play"} size={18} color={palette.onPrimary} />
          </TouchableOpacity>
          <TouchableOpacity
            style={styles.playerIconButton}
            onPress={() => playAyah(Math.min(ayahs.length - 1, currentAyahIndex + 1))}
          >
            <Ionicons name="play-skip-forward" size={18} color={palette.primary} />
          </TouchableOpacity>
        </View>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  page: {
    flex: 1,
    backgroundColor: palette.background,
  },
  content: {
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.xl,
    paddingBottom: 188,
    gap: spacing.lg,
  },
  topBar: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: spacing.md,
  },
  brand: {
    fontFamily: fonts.serifBold,
    fontSize: 24,
    color: palette.primary,
  },
  profileDot: {
    width: 34,
    height: 34,
    borderRadius: radii.pill,
    backgroundColor: palette.surfaceHighest,
  },
  heroBlock: {
    marginBottom: spacing.md,
  },
  heroKicker: {
    fontFamily: fonts.bodyBold,
    fontSize: 11,
    letterSpacing: 1.8,
    textTransform: "uppercase",
    color: palette.secondary,
  },
  heroTitle: {
    marginTop: spacing.xs,
    fontFamily: fonts.serifBold,
    fontSize: 36,
    lineHeight: 44,
    color: palette.primary,
  },
  panel: {
    borderRadius: radii.lg,
    backgroundColor: palette.surfaceLow,
    padding: spacing.lg,
    gap: spacing.sm,
  },
  panelHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  panelTitle: {
    fontFamily: fonts.serifBold,
    fontSize: 23,
    color: palette.primary,
  },
  panelLabel: {
    fontFamily: fonts.bodyBold,
    fontSize: 10,
    letterSpacing: 1.6,
    textTransform: "uppercase",
    color: palette.textMuted,
  },
  searchBox: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.sm,
    borderRadius: radii.md,
    backgroundColor: palette.surfaceLowest,
    paddingHorizontal: spacing.md,
    paddingVertical: 2,
  },
  searchInput: {
    flex: 1,
    fontFamily: fonts.bodyMedium,
    fontSize: 15,
    color: palette.text,
    paddingVertical: 12,
  },
  surahList: {
    gap: spacing.sm,
  },
  surahCard: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.md,
    borderRadius: radii.md,
    backgroundColor: palette.surfaceLowest,
    padding: spacing.md,
  },
  surahCardActive: {
    backgroundColor: palette.primaryContainer,
  },
  surahIndex: {
    width: 42,
    height: 42,
    borderRadius: 14,
    backgroundColor: palette.surfaceLow,
    alignItems: "center",
    justifyContent: "center",
  },
  surahIndexActive: {
    backgroundColor: "rgba(176, 240, 214, 0.14)",
  },
  surahIndexText: {
    fontFamily: fonts.serifBold,
    fontSize: 16,
    color: palette.outline,
  },
  surahIndexTextActive: {
    color: palette.onPrimary,
  },
  surahMeta: {
    flex: 1,
    gap: 2,
  },
  surahName: {
    fontFamily: fonts.serifBold,
    fontSize: 18,
    color: palette.primary,
  },
  surahNameActive: {
    color: palette.onPrimary,
  },
  surahSubtitle: {
    fontFamily: fonts.bodyMedium,
    fontSize: 11,
    letterSpacing: 1,
    textTransform: "uppercase",
    color: palette.textMuted,
  },
  surahSubtitleActive: {
    color: "rgba(255,255,255,0.72)",
  },
  pickerWrap: {
    borderRadius: radii.md,
    overflow: "hidden",
    backgroundColor: palette.surfaceLowest,
  },
  picker: {
    color: palette.text,
    backgroundColor: palette.surfaceLowest,
  },
  modeGroup: {
    gap: spacing.sm,
  },
  modeChip: {
    borderRadius: radii.md,
    backgroundColor: palette.surfaceHighest,
    paddingHorizontal: spacing.md,
    paddingVertical: 14,
  },
  modeChipActive: {
    backgroundColor: palette.primary,
  },
  modeChipText: {
    fontFamily: fonts.bodySemiBold,
    fontSize: 14,
    color: palette.text,
  },
  modeChipTextActive: {
    color: palette.onPrimary,
  },
  errorText: {
    fontFamily: fonts.bodyMedium,
    color: palette.error,
  },
  bookmarkCard: {
    position: "relative",
    overflow: "hidden",
    borderRadius: radii.lg,
    backgroundColor: "rgba(254, 214, 91, 0.14)",
    padding: spacing.xl,
  },
  bookmarkTitle: {
    fontFamily: fonts.serifBold,
    fontSize: 22,
    color: palette.secondary,
  },
  bookmarkMeta: {
    marginTop: spacing.xs,
    fontFamily: fonts.bodyBold,
    fontSize: 11,
    letterSpacing: 1.6,
    textTransform: "uppercase",
    color: palette.textMuted,
  },
  bookmarkButton: {
    marginTop: spacing.md,
    alignSelf: "flex-start",
    borderRadius: radii.md,
    backgroundColor: palette.secondary,
    paddingHorizontal: spacing.lg,
    paddingVertical: 12,
  },
  bookmarkButtonText: {
    fontFamily: fonts.bodyBold,
    fontSize: 12,
    letterSpacing: 1.1,
    textTransform: "uppercase",
    color: palette.onPrimary,
  },
  banner: {
    borderRadius: radii.lg,
    backgroundColor: palette.primaryContainer,
    padding: spacing.xl,
    alignItems: "center",
    ...shadows.ambient,
  },
  bannerKicker: {
    fontFamily: fonts.bodyBold,
    fontSize: 11,
    letterSpacing: 2.2,
    textTransform: "uppercase",
    color: "rgba(255,255,255,0.68)",
  },
  bannerArabic: {
    marginTop: spacing.sm,
    fontFamily: fonts.serifBold,
    fontSize: 44,
    color: palette.onPrimary,
    textAlign: "center",
  },
  bannerCopy: {
    marginTop: spacing.xs,
    fontFamily: fonts.bodyMedium,
    fontSize: 13,
    textTransform: "uppercase",
    letterSpacing: 1.2,
    color: "rgba(255,255,255,0.72)",
    textAlign: "center",
  },
  loader: {
    marginVertical: spacing.md,
  },
  ayahBlock: {
    gap: spacing.md,
    paddingVertical: spacing.xl,
    paddingHorizontal: spacing.lg,
    backgroundColor: palette.surfaceLow,
  },
  ayahBlockActive: {
    backgroundColor: palette.surfaceHighest,
  },
  ayahHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  ayahReference: {
    borderRadius: radii.pill,
    overflow: "hidden",
    fontFamily: fonts.bodyBold,
    fontSize: 11,
    letterSpacing: 1.8,
    textTransform: "uppercase",
    color: palette.secondary,
  },
  ayahActions: {
    flexDirection: "row",
    gap: spacing.sm,
  },
  arabicText: {
    fontFamily: fonts.serifRegular,
    fontSize: 32,
    lineHeight: 54,
    textAlign: "right",
    color: palette.primary,
  },
  translationText: {
    fontFamily: fonts.bodyMedium,
    fontSize: 18,
    lineHeight: 30,
    color: palette.textMuted,
  },
  emptyState: {
    borderRadius: radii.md,
    backgroundColor: palette.surfaceLow,
    padding: spacing.xl,
    alignItems: "center",
  },
  emptyStateText: {
    fontFamily: fonts.bodyMedium,
    fontSize: 15,
    lineHeight: 24,
    textAlign: "center",
    color: palette.textMuted,
  },
  playerDock: {
    position: "absolute",
    left: 18,
    right: 18,
    bottom: 102,
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.sm,
    borderRadius: radii.lg,
    backgroundColor: palette.glassStrong,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    ...shadows.ambient,
  },
  playerTextBlock: {
    flex: 1,
  },
  playerKicker: {
    fontFamily: fonts.bodyBold,
    fontSize: 10,
    letterSpacing: 1.4,
    textTransform: "uppercase",
    color: palette.textMuted,
  },
  playerLine: {
    marginTop: 4,
    fontFamily: fonts.bodySemiBold,
    fontSize: 13,
    color: palette.primary,
  },
  playerIconButton: {
    width: 38,
    height: 38,
    borderRadius: radii.pill,
    backgroundColor: palette.surfaceLow,
    alignItems: "center",
    justifyContent: "center",
  },
  playerPrimary: {
    width: 42,
    height: 42,
    borderRadius: radii.pill,
    backgroundColor: palette.primary,
    alignItems: "center",
    justifyContent: "center",
  },
});
