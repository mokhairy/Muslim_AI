import { Ionicons } from "@expo/vector-icons";
import { Picker } from "@react-native-picker/picker";
import * as Speech from "expo-speech";
import { useEffect, useMemo, useRef, useState } from "react";
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from "react-native";

import {
  fetchAzkarCategory,
  fetchHadithPage,
  fetchHisnMuslim,
  hadithCollections,
} from "../lib/api";
import { fonts, palette, radii, shadows, spacing } from "../theme";

const sections = [
  { value: "hadith", label: "Hadith" },
  { value: "azkar", label: "Adhkar" },
  { value: "hisn", label: "Hisn Muslim" },
] as const;

const readerModeOptions = [
  { value: "read", label: "Read only" },
  { value: "listen", label: "Listen only" },
  { value: "read_listen", label: "Read while listening" },
] as const;

type ReaderMode = (typeof readerModeOptions)[number]["value"];

function getAzkarText(entry: Record<string, unknown>): string {
  return String(entry.zekr ?? entry.content ?? "").trim();
}

function getAzkarTitle(entry: Record<string, unknown>, index: number): string {
  return String(entry.category ?? `Remembrance ${index + 1}`);
}

function getHadithReference(item: Record<string, unknown>): string {
  const reference = item.reference;
  if (!reference || typeof reference !== "object") {
    return "";
  }

  const book = "book" in reference ? String(reference.book ?? "").trim() : "";
  const hadith = "hadith" in reference ? String(reference.hadith ?? "").trim() : "";
  if (book && hadith) {
    return `Book ${book} • Hadith ${hadith}`;
  }
  return book || hadith;
}

export function LibraryScreen() {
  const [section, setSection] = useState<(typeof sections)[number]["value"]>("hadith");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const [collection, setCollection] = useState("eng-bukhari");
  const [hadithItems, setHadithItems] = useState<any[]>([]);

  const [azkarCategory, setAzkarCategory] = useState("");
  const [azkarCategories, setAzkarCategories] = useState<string[]>([]);
  const [azkarEntries, setAzkarEntries] = useState<any[]>([]);
  const [tasbihCounts, setTasbihCounts] = useState<Record<number, number>>({});
  const [azkarMode, setAzkarMode] = useState<ReaderMode>("read_listen");
  const [currentAzkarIndex, setCurrentAzkarIndex] = useState(0);
  const [isAzkarPlaying, setIsAzkarPlaying] = useState(false);
  const [azkarVoiceIdentifier, setAzkarVoiceIdentifier] = useState<string>();
  const azkarPlaybackTokenRef = useRef(0);

  const [hisnCollectionId, setHisnCollectionId] = useState("27");
  const [hisnTitle, setHisnTitle] = useState("");
  const [hisnEntries, setHisnEntries] = useState<any[]>([]);

  const currentAzkarEntry = azkarEntries[currentAzkarIndex] ?? null;

  function stopAzkarPlayback() {
    azkarPlaybackTokenRef.current += 1;
    setIsAzkarPlaying(false);
    Speech.stop();
  }

  function playAzkarEntry(index: number) {
    const entry = azkarEntries[index];
    const text = entry ? getAzkarText(entry) : "";
    if (!text) {
      return;
    }

    const nextToken = azkarPlaybackTokenRef.current + 1;
    azkarPlaybackTokenRef.current = nextToken;
    setCurrentAzkarIndex(index);
    setIsAzkarPlaying(true);
    Speech.stop();
    Speech.speak(text, {
      language: "ar",
      voice: azkarVoiceIdentifier,
      rate: 0.9,
      pitch: 1,
      onDone: () => {
        if (azkarPlaybackTokenRef.current !== nextToken) {
          return;
        }
        const nextIndex = index + 1;
        if (azkarMode !== "read" && azkarEntries[nextIndex]) {
          playAzkarEntry(nextIndex);
          return;
        }
        setIsAzkarPlaying(false);
      },
      onStopped: () => {
        if (azkarPlaybackTokenRef.current === nextToken) {
          setIsAzkarPlaying(false);
        }
      },
      onError: () => {
        if (azkarPlaybackTokenRef.current === nextToken) {
          setIsAzkarPlaying(false);
          setError("Unable to play this remembrance on the current device voice.");
        }
      },
    });
  }

  function toggleAzkarPlayback() {
    if (isAzkarPlaying) {
      stopAzkarPlayback();
      return;
    }
    playAzkarEntry(currentAzkarIndex);
  }

  function moveAzkarSelection(direction: -1 | 1) {
    if (!azkarEntries.length) {
      return;
    }

    const nextIndex = Math.min(
      Math.max(currentAzkarIndex + direction, 0),
      Math.max(azkarEntries.length - 1, 0),
    );
    setCurrentAzkarIndex(nextIndex);

    if (azkarMode === "listen" || isAzkarPlaying) {
      playAzkarEntry(nextIndex);
    }
  }

  async function loadActiveSection() {
    setLoading(true);
    setError("");
    try {
      if (section === "hadith") {
        const nextHadithItems = await fetchHadithPage(collection);
        setHadithItems(nextHadithItems);
      } else if (section === "azkar") {
        const result = await fetchAzkarCategory(azkarCategory || undefined);
        setAzkarCategories(result.categories);
        setAzkarCategory(result.selectedCategory);
        setAzkarEntries(result.entries);
      } else {
        const result = await fetchHisnMuslim(Number(hisnCollectionId || 27));
        setHisnTitle(result.categoryName);
        setHisnEntries(result.entries);
      }
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : "Unable to load this section.");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadActiveSection().catch(() => null);
  }, [section, collection]);

  useEffect(() => {
    if (section === "azkar" && azkarCategory) {
      loadActiveSection().catch(() => null);
    }
  }, [azkarCategory]);

  useEffect(() => {
    Speech.getAvailableVoicesAsync()
      .then((voices) => {
        const arabicVoice = voices.find((voice) => voice.language?.toLowerCase().startsWith("ar"));
        setAzkarVoiceIdentifier(arabicVoice?.identifier);
      })
      .catch(() => null);
  }, []);

  useEffect(() => {
    if (section !== "azkar" || azkarMode === "read") {
      stopAzkarPlayback();
    }
  }, [azkarMode, section]);

  useEffect(() => {
    setCurrentAzkarIndex(0);
    stopAzkarPlayback();
  }, [azkarCategory, section]);

  useEffect(() => {
    return () => {
      azkarPlaybackTokenRef.current += 1;
      Speech.stop();
    };
  }, []);

  const completedAzkar = useMemo(
    () => Object.values(tasbihCounts).filter((value) => value > 0).length,
    [tasbihCounts],
  );

  return (
    <ScrollView style={styles.page} contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
      <View style={styles.topBar}>
        <Text style={styles.brand}>Muslim AI</Text>
        <View style={styles.profileDot} />
      </View>

      <View style={styles.headerBlock}>
        <Text style={styles.kicker}>Knowledge library</Text>
        <Text style={styles.title}>Hadith, remembrance, and daily recitation in one shelf.</Text>
      </View>

      <View style={styles.segmentedControl}>
        {sections.map((item) => (
          <TouchableOpacity
            key={item.value}
            style={[styles.segmentChip, section === item.value ? styles.segmentChipActive : undefined]}
            onPress={() => setSection(item.value)}
          >
            <Text
              style={[
                styles.segmentChipText,
                section === item.value ? styles.segmentChipTextActive : undefined,
              ]}
            >
              {item.label}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      {section === "hadith" ? (
        <>
          <View style={styles.hadithHero}>
            <View style={styles.hadithBadge}>
              <Ionicons name="sparkles-outline" size={14} color={palette.secondaryFixed} />
              <Text style={styles.hadithBadgeText}>Daily hadith</Text>
            </View>
            <Text style={styles.hadithQuote}>
              "Whoever follows a path in pursuit of knowledge, Allah will make easy for him a path
              to Paradise."
            </Text>
            <Text style={styles.hadithMeta}>Narrated by Abu Hurairah — Sahih Muslim</Text>
          </View>

          <View style={styles.surfaceCard}>
            <Text style={styles.cardTitle}>Collection</Text>
            <View style={styles.pickerWrap}>
              <Picker
                selectedValue={collection}
                style={styles.picker}
                dropdownIconColor={palette.primary}
                onValueChange={(value) => setCollection(String(value))}
              >
                {hadithCollections.map((item) => (
                  <Picker.Item key={item.value} label={item.label} value={item.value} />
                ))}
              </Picker>
            </View>
          </View>

          {hadithCollections.slice(0, 3).map((item, index) => (
            <View key={item.value} style={styles.collectionCard}>
              <View style={[styles.collectionIcon, index === 0 ? styles.collectionIconPrimary : undefined]}>
                <Ionicons
                  name={index === 1 ? "library-outline" : index === 2 ? "bookmarks-outline" : "book-outline"}
                  size={18}
                  color={index === 0 ? palette.onPrimary : palette.primary}
                />
              </View>
              <Text style={styles.collectionTitle}>{item.label}</Text>
              <Text style={styles.collectionCopy}>Primary source collection available for in-app browsing.</Text>
            </View>
          ))}

          {hadithItems.map((item, index) => (
            (() => {
              const arabicText = String(item.arab ?? item.contents ?? "").trim();
              const translationText = String(
                item.terjemah ?? item.translation ?? item.contents ?? "",
              ).trim();
              const referenceText = getHadithReference(item);

              return (
                <View key={`hadith-${index}`} style={styles.readingCard}>
                  <View style={styles.readingHeader}>
                    <View>
                      <Text style={styles.readingCaption}>Narration</Text>
                      <Text style={styles.readingTitle}>
                        {String(item.number ?? item.id ?? `Hadith ${index + 1}`)}
                      </Text>
                      {referenceText ? <Text style={styles.readingMeta}>{referenceText}</Text> : null}
                    </View>
                    <View style={styles.readingActions}>
                      <Ionicons name="share-social-outline" size={18} color={palette.textMuted} />
                      <Ionicons name="bookmark-outline" size={18} color={palette.textMuted} />
                    </View>
                  </View>
                  {arabicText ? <Text style={styles.arabicBlock}>{arabicText}</Text> : null}
                  {translationText ? (
                    <Text style={[styles.translationBlock, arabicText ? undefined : styles.translationPrimary]}>
                      {translationText}
                    </Text>
                  ) : null}
                </View>
              );
            })()
          ))}
        </>
      ) : null}

      {section === "azkar" ? (
        <>
          <View style={styles.adhkarHero}>
            <Text style={styles.adhkarKicker}>Morning adhkar</Text>
            <Text style={styles.adhkarTitle}>Daily remembrance</Text>
            <Text style={styles.adhkarProgress}>
              {completedAzkar}/{Math.max(azkarEntries.length, 1)} completed
            </Text>
            <View style={styles.progressTrack}>
              <View
                style={[
                  styles.progressFill,
                  { width: `${Math.min(100, (completedAzkar / Math.max(azkarEntries.length, 1)) * 100)}%` },
                ]}
              />
            </View>
          </View>

          <View style={styles.surfaceCard}>
            <Text style={styles.cardTitle}>Azkar reader</Text>
            <View style={styles.modeGroup}>
              {readerModeOptions.map((item) => (
                <Pressable
                  key={item.value}
                  onPress={() => setAzkarMode(item.value)}
                  style={[styles.modeChip, azkarMode === item.value ? styles.modeChipActive : undefined]}
                >
                  <Text
                    style={[
                      styles.modeChipText,
                      azkarMode === item.value ? styles.modeChipTextActive : undefined,
                    ]}
                  >
                    {item.label}
                  </Text>
                </Pressable>
              ))}
            </View>
            <View style={styles.azkarControlRow}>
              <TouchableOpacity
                style={styles.secondaryActionButton}
                onPress={() => moveAzkarSelection(-1)}
              >
                <Ionicons name="play-skip-back" size={18} color={palette.primary} />
              </TouchableOpacity>
              <TouchableOpacity style={styles.primaryPlayButton} onPress={toggleAzkarPlayback}>
                <Ionicons
                  name={isAzkarPlaying ? "stop" : "play"}
                  size={18}
                  color={palette.onPrimary}
                />
                <Text style={styles.primaryPlayButtonText}>
                  {isAzkarPlaying ? "Stop" : "Play current"}
                </Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={styles.secondaryActionButton}
                onPress={() => moveAzkarSelection(1)}
              >
                <Ionicons name="play-skip-forward" size={18} color={palette.primary} />
              </TouchableOpacity>
            </View>
            <Text style={styles.azkarControlMeta}>
              {currentAzkarEntry
                ? `${getAzkarTitle(currentAzkarEntry, currentAzkarIndex)} • Entry ${currentAzkarIndex + 1} of ${azkarEntries.length}`
                : "Load a remembrance category to begin."}
            </Text>
          </View>

          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.categoryRow}>
            {azkarCategories.map((item) => {
              const active = item === azkarCategory;
              return (
                <TouchableOpacity
                  key={item}
                  style={[styles.categoryChip, active ? styles.categoryChipActive : undefined]}
                  onPress={() => setAzkarCategory(item)}
                >
                  <Text
                    style={[
                      styles.categoryChipText,
                      active ? styles.categoryChipTextActive : undefined,
                    ]}
                  >
                    {item}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </ScrollView>

          {(azkarMode === "listen" && currentAzkarEntry ? [currentAzkarEntry] : azkarEntries).map((item, rawIndex) => {
            const index = azkarMode === "listen" ? currentAzkarIndex : rawIndex;
            const requiredCount = Number(item.count ?? item.repeat ?? 1) || 1;
            const count = tasbihCounts[index] ?? 0;
            const active = index === currentAzkarIndex && azkarMode !== "read";
            return (
              <Pressable
                key={`azkar-${index}`}
                onPress={() => {
                  setCurrentAzkarIndex(index);
                  if (azkarMode !== "read") {
                    playAzkarEntry(index);
                  }
                }}
                style={[styles.adhkarCard, active ? styles.adhkarCardActive : undefined]}
              >
                <View style={styles.adhkarHeader}>
                  <View>
                    <Text style={styles.adhkarEntryTitle}>{getAzkarTitle(item, index)}</Text>
                    <Text style={styles.adhkarEntryHint}>
                      {requiredCount} time(s) • Entry {index + 1}
                    </Text>
                  </View>
                  <View style={styles.adhkarHeaderActions}>
                    <View style={styles.countPill}>
                      <Text style={styles.countPillText}>{requiredCount}</Text>
                    </View>
                    <Ionicons
                      name={active && isAzkarPlaying ? "volume-high" : "play-circle-outline"}
                      size={20}
                      color={active ? palette.secondary : palette.textMuted}
                    />
                  </View>
                </View>
                <Text style={[styles.adhkarArabic, active ? styles.adhkarArabicActive : undefined]}>
                  {getAzkarText(item)}
                </Text>
                {item.reference ? <Text style={styles.referenceText}>{String(item.reference)}</Text> : null}
                <TouchableOpacity
                  style={[
                    styles.tasbihButton,
                    count > 0 ? styles.tasbihButtonActive : undefined,
                  ]}
                  onPress={() =>
                    setTasbihCounts((current) => ({
                      ...current,
                      [index]: Math.min(requiredCount, (current[index] ?? 0) + 1),
                    }))
                  }
                >
                  <Text
                    style={[
                      styles.tasbihCount,
                      count > 0 ? styles.tasbihCountActive : undefined,
                    ]}
                  >
                    {count}
                  </Text>
                  <Text style={styles.tasbihLabel}>Tap</Text>
                </TouchableOpacity>
              </Pressable>
            );
          })}
        </>
      ) : null}

      {section === "hisn" ? (
        <>
          <View style={styles.surfaceCard}>
            <Text style={styles.cardTitle}>Hisn Muslim collection</Text>
            <TextInput
              style={styles.input}
              value={hisnCollectionId}
              onChangeText={setHisnCollectionId}
              keyboardType="number-pad"
              placeholder="27"
              placeholderTextColor={palette.outline}
            />
            <TouchableOpacity style={styles.primaryButton} onPress={() => loadActiveSection()}>
              <Text style={styles.primaryButtonText}>Load collection</Text>
            </TouchableOpacity>
          </View>

          {hisnTitle ? (
            <Text style={styles.hisnHeading}>{hisnTitle}</Text>
          ) : null}

          {hisnEntries.map((item, index) => (
            <View key={`hisn-${index}`} style={styles.surfaceCard}>
              <Text style={styles.hisnIndex}>{String(item.ID ?? `Entry ${index + 1}`)}</Text>
              <Text style={styles.adhkarArabic}>{String(item.ARABIC_TEXT ?? item.TEXT ?? "")}</Text>
              {item.TRANSLATED_TEXT ? (
                <Text style={styles.translationBlock}>{String(item.TRANSLATED_TEXT)}</Text>
              ) : null}
            </View>
          ))}
        </>
      ) : null}

      {loading ? <ActivityIndicator color={palette.primary} /> : null}
      {error ? <Text style={styles.errorText}>{error}</Text> : null}
    </ScrollView>
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
    paddingBottom: 126,
    gap: spacing.lg,
  },
  topBar: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
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
  headerBlock: {
    gap: spacing.xs,
  },
  kicker: {
    fontFamily: fonts.bodyBold,
    fontSize: 11,
    letterSpacing: 1.8,
    textTransform: "uppercase",
    color: palette.secondary,
  },
  title: {
    fontFamily: fonts.serifBold,
    fontSize: 34,
    lineHeight: 42,
    color: palette.primary,
  },
  segmentedControl: {
    flexDirection: "row",
    gap: spacing.xs,
    borderRadius: radii.md,
    backgroundColor: palette.surfaceLow,
    padding: spacing.xs,
  },
  segmentChip: {
    flex: 1,
    alignItems: "center",
    borderRadius: radii.sm,
    paddingVertical: 14,
  },
  segmentChipActive: {
    backgroundColor: palette.surfaceLowest,
    ...shadows.soft,
  },
  segmentChipText: {
    fontFamily: fonts.bodySemiBold,
    fontSize: 14,
    color: palette.textMuted,
  },
  segmentChipTextActive: {
    color: palette.primary,
  },
  modeGroup: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.xs,
  },
  modeChip: {
    borderRadius: radii.pill,
    backgroundColor: palette.surfaceLowest,
    paddingHorizontal: spacing.md,
    paddingVertical: 12,
  },
  modeChipActive: {
    backgroundColor: palette.primary,
  },
  modeChipText: {
    fontFamily: fonts.bodySemiBold,
    fontSize: 13,
    color: palette.textMuted,
  },
  modeChipTextActive: {
    color: palette.onPrimary,
  },
  hadithHero: {
    borderRadius: radii.lg,
    backgroundColor: palette.primary,
    padding: spacing.xl,
    gap: spacing.sm,
    ...shadows.ambient,
  },
  hadithBadge: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.xs,
    alignSelf: "flex-start",
    borderRadius: radii.pill,
    backgroundColor: "rgba(255, 224, 136, 0.12)",
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
  },
  hadithBadgeText: {
    fontFamily: fonts.bodyBold,
    fontSize: 10,
    letterSpacing: 1.4,
    textTransform: "uppercase",
    color: palette.secondaryFixed,
  },
  hadithQuote: {
    fontFamily: fonts.serifBold,
    fontSize: 30,
    lineHeight: 42,
    color: palette.onPrimary,
  },
  hadithMeta: {
    fontFamily: fonts.bodyMedium,
    fontSize: 14,
    color: "rgba(255,255,255,0.72)",
  },
  surfaceCard: {
    borderRadius: radii.lg,
    backgroundColor: palette.surfaceLow,
    padding: spacing.lg,
    gap: spacing.sm,
  },
  cardTitle: {
    fontFamily: fonts.serifBold,
    fontSize: 22,
    color: palette.primary,
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
  collectionCard: {
    borderRadius: radii.lg,
    backgroundColor: palette.surfaceLow,
    padding: spacing.lg,
    gap: spacing.xs,
  },
  collectionIcon: {
    width: 46,
    height: 46,
    borderRadius: 16,
    backgroundColor: palette.primaryFixed,
    alignItems: "center",
    justifyContent: "center",
    marginBottom: spacing.xs,
  },
  collectionIconPrimary: {
    backgroundColor: palette.primary,
  },
  collectionTitle: {
    fontFamily: fonts.serifBold,
    fontSize: 20,
    color: palette.primary,
  },
  collectionCopy: {
    fontFamily: fonts.bodyMedium,
    fontSize: 14,
    lineHeight: 22,
    color: palette.textMuted,
  },
  readingCard: {
    borderRadius: radii.lg,
    backgroundColor: palette.surfaceLow,
    padding: spacing.xl,
  },
  readingHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-start",
    marginBottom: spacing.lg,
  },
  readingCaption: {
    fontFamily: fonts.bodyBold,
    fontSize: 10,
    letterSpacing: 1.6,
    textTransform: "uppercase",
    color: palette.outline,
  },
  readingTitle: {
    marginTop: 4,
    fontFamily: fonts.serifBold,
    fontSize: 21,
    color: palette.primary,
  },
  readingMeta: {
    marginTop: spacing.xs,
    fontFamily: fonts.bodyMedium,
    fontSize: 13,
    color: palette.outline,
  },
  readingActions: {
    flexDirection: "row",
    gap: spacing.sm,
  },
  arabicBlock: {
    fontFamily: fonts.serifRegular,
    fontSize: 28,
    lineHeight: 44,
    textAlign: "right",
    color: palette.primaryContainer,
  },
  translationBlock: {
    marginTop: spacing.lg,
    fontFamily: fonts.bodyMedium,
    fontSize: 16,
    lineHeight: 26,
    color: palette.textMuted,
  },
  translationPrimary: {
    marginTop: 0,
    fontSize: 17,
    lineHeight: 28,
    color: palette.text,
  },
  adhkarHero: {
    borderRadius: radii.lg,
    backgroundColor: palette.primaryContainer,
    padding: spacing.xl,
    gap: spacing.sm,
    ...shadows.ambient,
  },
  adhkarKicker: {
    fontFamily: fonts.bodyBold,
    fontSize: 11,
    letterSpacing: 1.8,
    textTransform: "uppercase",
    color: "rgba(255,255,255,0.68)",
  },
  adhkarTitle: {
    fontFamily: fonts.serifBold,
    fontSize: 30,
    color: palette.onPrimary,
  },
  adhkarProgress: {
    fontFamily: fonts.serifRegular,
    fontSize: 26,
    color: palette.secondaryFixed,
  },
  progressTrack: {
    height: 6,
    borderRadius: radii.pill,
    backgroundColor: "rgba(255,255,255,0.12)",
    overflow: 'hidden',
  },
  progressFill: {
    height: "100%",
    borderRadius: radii.pill,
    backgroundColor: palette.secondaryFixed,
  },
  categoryRow: {
    gap: spacing.sm,
  },
  categoryChip: {
    borderRadius: radii.md,
    backgroundColor: palette.surfaceLow,
    paddingHorizontal: spacing.md,
    paddingVertical: 12,
  },
  categoryChipActive: {
    backgroundColor: palette.surfaceHighest,
  },
  categoryChipText: {
    fontFamily: fonts.bodySemiBold,
    fontSize: 13,
    color: palette.textMuted,
  },
  categoryChipTextActive: {
    color: palette.primary,
  },
  azkarControlRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.sm,
  },
  primaryPlayButton: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: spacing.xs,
    borderRadius: radii.md,
    backgroundColor: palette.primary,
    paddingVertical: 14,
  },
  primaryPlayButtonText: {
    fontFamily: fonts.bodyBold,
    fontSize: 12,
    letterSpacing: 1.2,
    textTransform: "uppercase",
    color: palette.onPrimary,
  },
  secondaryActionButton: {
    width: 52,
    height: 52,
    borderRadius: radii.pill,
    backgroundColor: palette.surfaceLowest,
    alignItems: "center",
    justifyContent: "center",
  },
  azkarControlMeta: {
    fontFamily: fonts.bodyMedium,
    fontSize: 13,
    lineHeight: 20,
    color: palette.textMuted,
  },
  adhkarCard: {
    borderRadius: radii.lg,
    backgroundColor: palette.surfaceLow,
    padding: spacing.xl,
    gap: spacing.md,
  },
  adhkarCardActive: {
    borderWidth: 1,
    borderColor: "rgba(15, 73, 56, 0.16)",
    backgroundColor: palette.surfaceHighest,
  },
  adhkarHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  adhkarHeaderActions: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.sm,
  },
  adhkarEntryTitle: {
    fontFamily: fonts.serifBold,
    fontSize: 22,
    color: palette.primary,
  },
  adhkarEntryHint: {
    marginTop: 4,
    fontFamily: fonts.bodyMedium,
    fontSize: 12,
    color: palette.textMuted,
  },
  countPill: {
    borderRadius: radii.pill,
    backgroundColor: "rgba(254, 214, 91, 0.24)",
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
  },
  countPillText: {
    fontFamily: fonts.bodyBold,
    fontSize: 11,
    letterSpacing: 1.2,
    textTransform: "uppercase",
    color: palette.secondary,
  },
  adhkarArabic: {
    fontFamily: fonts.serifRegular,
    fontSize: 30,
    lineHeight: 48,
    textAlign: "right",
    color: palette.primary,
  },
  adhkarArabicActive: {
    color: palette.primaryContainer,
  },
  referenceText: {
    fontFamily: fonts.bodyMedium,
    fontSize: 14,
    lineHeight: 22,
    color: palette.textMuted,
  },
  tasbihButton: {
    alignSelf: "center",
    width: 88,
    height: 88,
    borderRadius: radii.pill,
    backgroundColor: palette.primary,
    alignItems: "center",
    justifyContent: "center",
    ...shadows.soft,
  },
  tasbihButtonActive: {
    backgroundColor: palette.surfaceHighest,
  },
  tasbihCount: {
    fontFamily: fonts.serifBold,
    fontSize: 28,
    color: palette.onPrimary,
  },
  tasbihCountActive: {
    color: palette.secondary,
  },
  tasbihLabel: {
    marginTop: 2,
    fontFamily: fonts.bodyBold,
    fontSize: 10,
    letterSpacing: 1.5,
    textTransform: "uppercase",
    color: "rgba(255,255,255,0.68)",
  },
  input: {
    backgroundColor: palette.surfaceLowest,
    borderRadius: radii.sm,
    paddingHorizontal: spacing.md,
    paddingVertical: 14,
    color: palette.text,
    fontFamily: fonts.bodyMedium,
    fontSize: 15,
  },
  primaryButton: {
    alignItems: "center",
    justifyContent: "center",
    borderRadius: radii.md,
    backgroundColor: palette.primary,
    paddingVertical: 14,
  },
  primaryButtonText: {
    fontFamily: fonts.bodyBold,
    fontSize: 12,
    letterSpacing: 1.2,
    textTransform: "uppercase",
    color: palette.onPrimary,
  },
  hisnHeading: {
    fontFamily: fonts.serifBold,
    fontSize: 28,
    color: palette.primary,
  },
  hisnIndex: {
    fontFamily: fonts.bodyBold,
    fontSize: 11,
    letterSpacing: 1.8,
    textTransform: "uppercase",
    color: palette.secondary,
  },
  errorText: {
    fontFamily: fonts.bodyMedium,
    color: palette.error,
  },
});
