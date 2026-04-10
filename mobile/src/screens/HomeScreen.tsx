import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useEffect, useMemo, useState } from "react";
import {
  ActivityIndicator,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";

import { fetchPrayerTimes, type PrayerTimesResponse } from "../lib/api";
import { fonts, palette, radii, shadows, spacing } from "../theme";

type Props = {
  navigateTo: (tab: "Prayer" | "Quran" | "Library" | "More") => void;
};

const DEFAULT_LATITUDE = 23.588;
const DEFAULT_LONGITUDE = 58.3829;

const quickActions: Array<{
  title: string;
  subtitle: string;
  icon: keyof typeof Ionicons.glyphMap;
  route: "Prayer" | "Quran" | "Library" | "More";
}> = [
  { title: "Prayer Times", subtitle: "Current day schedule", icon: "time-outline", route: "Prayer" },
  { title: "Read Quran", subtitle: "Resume recitation flow", icon: "book-outline", route: "Quran" },
  { title: "Hadith & Azkar", subtitle: "Daily knowledge shelf", icon: "library-outline", route: "Library" },
  { title: "Radio & Tools", subtitle: "Listen and browse", icon: "radio-outline", route: "More" },
];

const reflections = [
  "Thumb-first navigation for daily check-ins and habitual use.",
  "Editorial spacing and serif hierarchy inspired by the Stitch sanctuary layouts.",
  "A surface model ready to scale into full Android and iOS builds.",
];

function todayIsoDate() {
  return new Date().toISOString().slice(0, 10);
}

function getNextPrayer(prayerData: PrayerTimesResponse | null) {
  if (!prayerData) {
    return null;
  }

  const now = new Date();
  const currentDate = now.toISOString().slice(0, 10);
  for (const timing of prayerData.timings) {
    const [hours, minutes] = timing.time.split(":").map(Number);
    const prayerTime = new Date(`${currentDate}T${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}:00`);
    if (prayerTime.getTime() > now.getTime()) {
      const differenceMinutes = Math.max(1, Math.round((prayerTime.getTime() - now.getTime()) / 60000));
      const hoursRemaining = Math.floor(differenceMinutes / 60);
      const minutesRemaining = differenceMinutes % 60;
      return {
        ...timing,
        remaining:
          hoursRemaining > 0 ? `${hoursRemaining}h ${minutesRemaining}m` : `${minutesRemaining}m`,
      };
    }
  }

  return {
    ...prayerData.timings[0],
    remaining: "tomorrow",
  };
}

export function HomeScreen({ navigateTo }: Props) {
  const [prayerData, setPrayerData] = useState<PrayerTimesResponse | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchPrayerTimes(todayIsoDate(), DEFAULT_LATITUDE, DEFAULT_LONGITUDE)
      .then(setPrayerData)
      .finally(() => setLoading(false));
  }, []);

  const nextPrayer = useMemo(() => getNextPrayer(prayerData), [prayerData]);
  const formattedDate = useMemo(
    () =>
      new Intl.DateTimeFormat("en-GB", {
        weekday: "long",
        day: "numeric",
        month: "long",
        year: "numeric",
      }).format(new Date()),
    [],
  );

  return (
    <ScrollView style={styles.page} contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
      <View style={styles.topBar}>
        <View>
          <Text style={styles.brand}>Muslim AI</Text>
          <Text style={styles.locationLabel}>Current location</Text>
        </View>
        <View style={styles.locationChip}>
          <Ionicons name="location-outline" size={14} color={palette.primary} />
          <Text style={styles.locationText}>Muscat, Oman</Text>
        </View>
      </View>

      <View style={styles.headerBlock}>
        <Text style={styles.greeting}>Assalamu Alaikum</Text>
        <Text style={styles.dateLine}>{formattedDate}</Text>
        <Text style={styles.subtleLine}>
          {prayerData?.hijriDate ?? "22 Shawwal 1447 AH"} • {prayerData?.timezone ?? "Asia/Muscat"}
        </Text>
      </View>

      <LinearGradient colors={[palette.primaryContainer, palette.primary]} style={styles.hero}>
        <View style={styles.heroGlow} />
        <Text style={styles.heroKicker}>Up next</Text>
        <Text style={styles.heroPrayer}>{nextPrayer?.name ?? "Loading"}</Text>
        <Text style={styles.heroCopy}>
          {nextPrayer ? `Starts in ${nextPrayer.remaining}` : "Fetching the live prayer sequence."}
        </Text>

        <View style={styles.heroFooter}>
          <View style={styles.heroMetaCard}>
            <Text style={styles.heroMetaLabel}>Prayer time</Text>
            <Text style={styles.heroMetaValue}>{nextPrayer?.time ?? "--:--"}</Text>
          </View>
          <TouchableOpacity style={styles.heroButton} onPress={() => navigateTo("Prayer")}>
            <Text style={styles.heroButtonText}>Open prayer view</Text>
          </TouchableOpacity>
        </View>
      </LinearGradient>

      <View style={styles.sectionHeader}>
        <Text style={styles.sectionTitle}>Quick access</Text>
        <Text style={styles.sectionLabel}>Daily workflow</Text>
      </View>

      <View style={styles.actionGrid}>
        {quickActions.map((item) => (
          <TouchableOpacity
            key={item.title}
            style={styles.actionCard}
            activeOpacity={0.9}
            onPress={() => navigateTo(item.route)}
          >
            <View style={styles.actionIcon}>
              <Ionicons name={item.icon} size={20} color={palette.primary} />
            </View>
            <Text style={styles.actionTitle}>{item.title}</Text>
            <Text style={styles.actionSubtitle}>{item.subtitle}</Text>
          </TouchableOpacity>
        ))}
      </View>

      <View style={styles.sectionHeader}>
        <Text style={styles.sectionTitle}>Daily prayer times</Text>
        <Text style={styles.sectionLabel}>Umm al-Qura aligned</Text>
      </View>

      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.prayerRow}>
        {loading ? (
          <View style={styles.loadingCard}>
            <ActivityIndicator color={palette.primary} />
          </View>
        ) : (
          prayerData?.timings.map((timing) => (
            <View
              key={timing.name}
              style={[
                styles.prayerCard,
                nextPrayer?.name === timing.name ? styles.prayerCardActive : undefined,
              ]}
            >
              <Text
                style={[
                  styles.prayerName,
                  nextPrayer?.name === timing.name ? styles.prayerNameActive : undefined,
                ]}
              >
                {timing.name}
              </Text>
              <Text
                style={[
                  styles.prayerTime,
                  nextPrayer?.name === timing.name ? styles.prayerTimeActive : undefined,
                ]}
              >
                {timing.time}
              </Text>
            </View>
          ))
        )}
      </ScrollView>

      <View style={styles.quoteCard}>
        <Text style={styles.quoteKicker}>Design direction</Text>
        <Text style={styles.quoteText}>
          A mobile sanctuary that lets the user move between prayer, recitation, and remembrance
          without feeling like they left the same sacred space.
        </Text>
      </View>

      <View style={styles.reflectionList}>
        {reflections.map((item) => (
          <View key={item} style={styles.reflectionCard}>
            <Ionicons name="sparkles-outline" size={18} color={palette.secondary} />
            <Text style={styles.reflectionText}>{item}</Text>
          </View>
        ))}
      </View>
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
    fontSize: 22,
    color: palette.primary,
  },
  locationLabel: {
    marginTop: 4,
    fontFamily: fonts.bodyBold,
    fontSize: 10,
    letterSpacing: 1.8,
    textTransform: "uppercase",
    color: palette.textMuted,
  },
  locationChip: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.xs,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
    borderRadius: radii.pill,
    backgroundColor: palette.surfaceLow,
  },
  locationText: {
    fontFamily: fonts.bodySemiBold,
    fontSize: 12,
    color: palette.primary,
  },
  headerBlock: {
    gap: spacing.xs,
  },
  greeting: {
    fontFamily: fonts.serifBold,
    fontSize: 34,
    lineHeight: 42,
    color: palette.primary,
  },
  dateLine: {
    fontFamily: fonts.bodySemiBold,
    fontSize: 15,
    color: palette.text,
  },
  subtleLine: {
    fontFamily: fonts.bodyMedium,
    fontSize: 12,
    textTransform: "uppercase",
    letterSpacing: 1.6,
    color: palette.textMuted,
  },
  hero: {
    overflow: "hidden",
    borderRadius: radii.lg,
    padding: spacing.xl,
    minHeight: 280,
    justifyContent: "space-between",
    ...shadows.ambient,
  },
  heroGlow: {
    position: "absolute",
    top: -40,
    right: -20,
    width: 180,
    height: 180,
    borderRadius: radii.pill,
    backgroundColor: "rgba(255, 224, 136, 0.12)",
  },
  heroKicker: {
    fontFamily: fonts.bodyBold,
    fontSize: 11,
    letterSpacing: 2.4,
    textTransform: "uppercase",
    color: "rgba(255,255,255,0.72)",
  },
  heroPrayer: {
    marginTop: spacing.sm,
    fontFamily: fonts.serifBold,
    fontSize: 58,
    color: palette.onPrimary,
  },
  heroCopy: {
    fontFamily: fonts.bodyMedium,
    fontSize: 18,
    color: "rgba(255,255,255,0.82)",
  },
  heroFooter: {
    flexDirection: "row",
    alignItems: "flex-end",
    justifyContent: "space-between",
    gap: spacing.md,
  },
  heroMetaCard: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderRadius: radii.md,
    backgroundColor: "rgba(255,255,255,0.10)",
  },
  heroMetaLabel: {
    fontFamily: fonts.bodyBold,
    fontSize: 10,
    textTransform: "uppercase",
    letterSpacing: 1.8,
    color: "rgba(255,255,255,0.56)",
  },
  heroMetaValue: {
    marginTop: 4,
    fontFamily: fonts.bodyBold,
    fontSize: 24,
    color: palette.onPrimary,
  },
  heroButton: {
    backgroundColor: palette.secondaryFixed,
    borderRadius: radii.md,
    paddingHorizontal: spacing.lg,
    paddingVertical: 14,
  },
  heroButtonText: {
    fontFamily: fonts.bodyBold,
    fontSize: 12,
    letterSpacing: 1,
    textTransform: "uppercase",
    color: palette.onSecondaryFixed,
  },
  sectionHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-end",
  },
  sectionTitle: {
    fontFamily: fonts.serifBold,
    fontSize: 22,
    color: palette.primary,
  },
  sectionLabel: {
    fontFamily: fonts.bodyBold,
    fontSize: 10,
    textTransform: "uppercase",
    letterSpacing: 1.6,
    color: palette.textMuted,
  },
  actionGrid: {
    gap: spacing.md,
  },
  actionCard: {
    borderRadius: radii.md,
    backgroundColor: palette.surfaceLowest,
    padding: spacing.lg,
    gap: spacing.xs,
    ...shadows.soft,
  },
  actionIcon: {
    width: 44,
    height: 44,
    borderRadius: 14,
    backgroundColor: "rgba(0, 53, 39, 0.06)",
    alignItems: "center",
    justifyContent: "center",
    marginBottom: spacing.xs,
  },
  actionTitle: {
    fontFamily: fonts.serifBold,
    fontSize: 19,
    color: palette.primary,
  },
  actionSubtitle: {
    fontFamily: fonts.bodyMedium,
    fontSize: 14,
    lineHeight: 22,
    color: palette.textMuted,
  },
  prayerRow: {
    gap: spacing.sm,
  },
  loadingCard: {
    width: 120,
    height: 120,
    borderRadius: radii.md,
    backgroundColor: palette.surfaceLow,
    alignItems: "center",
    justifyContent: "center",
  },
  prayerCard: {
    width: 132,
    borderRadius: radii.md,
    backgroundColor: palette.surfaceLow,
    padding: spacing.md,
    gap: spacing.md,
  },
  prayerCardActive: {
    backgroundColor: palette.primary,
  },
  prayerName: {
    fontFamily: fonts.bodyBold,
    fontSize: 11,
    letterSpacing: 1.8,
    textTransform: "uppercase",
    color: palette.textMuted,
  },
  prayerNameActive: {
    color: "rgba(255,255,255,0.64)",
  },
  prayerTime: {
    fontFamily: fonts.serifBold,
    fontSize: 28,
    color: palette.primary,
  },
  prayerTimeActive: {
    color: palette.onPrimary,
  },
  quoteCard: {
    borderRadius: radii.lg,
    padding: spacing.xl,
    backgroundColor: palette.surfaceLow,
  },
  quoteKicker: {
    fontFamily: fonts.bodyBold,
    fontSize: 11,
    letterSpacing: 1.8,
    textTransform: "uppercase",
    color: palette.secondary,
  },
  quoteText: {
    marginTop: spacing.sm,
    fontFamily: fonts.serifRegular,
    fontSize: 24,
    lineHeight: 34,
    color: palette.primary,
  },
  reflectionList: {
    gap: spacing.sm,
  },
  reflectionCard: {
    flexDirection: "row",
    alignItems: "flex-start",
    gap: spacing.sm,
    borderRadius: radii.md,
    backgroundColor: palette.surfaceHighest,
    padding: spacing.md,
  },
  reflectionText: {
    flex: 1,
    fontFamily: fonts.bodyMedium,
    fontSize: 14,
    lineHeight: 22,
    color: palette.text,
  },
});
