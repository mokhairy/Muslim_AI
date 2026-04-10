import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useEffect, useMemo, useState } from "react";
import {
  ActivityIndicator,
  Alert,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from "react-native";

import { useAppLocation } from "../context/AppLocationContext";
import { fetchPrayerTimes, fetchQibla, type PrayerTimesResponse, type QiblaResponse } from "../lib/api";
import { fonts, palette, radii, shadows, spacing } from "../theme";

function todayIsoDate() {
  return new Date().toISOString().slice(0, 10);
}

function nextPrayerLabel(prayerData: PrayerTimesResponse | null) {
  if (!prayerData) {
    return null;
  }

  const now = new Date();
  const currentDate = now.toISOString().slice(0, 10);
  for (const timing of prayerData.timings) {
    const [hours, minutes] = timing.time.split(":").map(Number);
    const prayerTime = new Date(`${currentDate}T${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}:00`);
    if (prayerTime.getTime() > now.getTime()) {
      return timing;
    }
  }

  return prayerData.timings[0] ?? null;
}

export function PrayerScreen() {
  const {
    latitude: sharedLatitude,
    longitude: sharedLongitude,
    label,
    isResolving,
    refreshFromDevice,
    setManualCoordinates,
  } = useAppLocation();
  const [latitude, setLatitude] = useState(sharedLatitude.toFixed(6));
  const [longitude, setLongitude] = useState(sharedLongitude.toFixed(6));
  const [prayerDate, setPrayerDate] = useState(todayIsoDate());
  const [prayerData, setPrayerData] = useState<PrayerTimesResponse | null>(null);
  const [qiblaData, setQiblaData] = useState<QiblaResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function loadPrayerDashboard(nextLatitude = latitude, nextLongitude = longitude) {
    const parsedLatitude = Number(nextLatitude);
    const parsedLongitude = Number(nextLongitude);
    if (Number.isNaN(parsedLatitude) || Number.isNaN(parsedLongitude)) {
      setError("Latitude and longitude must be valid numbers.");
      return;
    }

    setLoading(true);
    setError("");
    try {
      const [timings, qibla] = await Promise.all([
        fetchPrayerTimes(prayerDate, parsedLatitude, parsedLongitude),
        fetchQibla(parsedLatitude, parsedLongitude),
      ]);
      setPrayerData(timings);
      setQiblaData(qibla);
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : "Unable to load prayer data.");
    } finally {
      setLoading(false);
    }
  }

  async function useCurrentLocation() {
    const refreshed = await refreshFromDevice();
    if (!refreshed) {
      Alert.alert("Location permission denied", "Enable location access to use current prayer times.");
      return;
    }
  }

  useEffect(() => {
    const nextLatitude = sharedLatitude.toFixed(6);
    const nextLongitude = sharedLongitude.toFixed(6);
    setLatitude(nextLatitude);
    setLongitude(nextLongitude);
    loadPrayerDashboard(nextLatitude, nextLongitude).catch(() => null);
  }, [sharedLatitude, sharedLongitude]);

  async function refreshScheduleWithDraftCoordinates() {
    const parsedLatitude = Number(latitude);
    const parsedLongitude = Number(longitude);
    if (Number.isNaN(parsedLatitude) || Number.isNaN(parsedLongitude)) {
      setError("Latitude and longitude must be valid numbers.");
      return;
    }

    await loadPrayerDashboard(latitude, longitude);
    await setManualCoordinates(parsedLatitude, parsedLongitude);
  }

  const nextPrayer = useMemo(() => nextPrayerLabel(prayerData), [prayerData]);
  const qiblaRotation = qiblaData ? `${qiblaData.direction}deg` : "0deg";

  return (
    <ScrollView style={styles.page} contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
      <View style={styles.topBar}>
        <View>
          <Text style={styles.brand}>Qibla Direction</Text>
          <Text style={styles.caption}>Prayer compass and schedule</Text>
        </View>
        <TouchableOpacity style={styles.iconButton} onPress={useCurrentLocation}>
          <Ionicons name="locate-outline" size={18} color={palette.primary} />
        </TouchableOpacity>
      </View>

      <View style={styles.heroHeader}>
        <View style={styles.locationChip}>
          <Ionicons name="location-outline" size={14} color={palette.primary} />
          <Text style={styles.locationText}>{label}</Text>
        </View>
        <Text style={styles.heroTitle}>Finding the sacred.</Text>
        <Text style={styles.heroSubtitle}>
          Align prayer direction, refresh from device location, and keep the daily schedule on one calm screen.
        </Text>
      </View>

      <View style={styles.compassSection}>
        <View style={styles.compassRing}>
          <View style={styles.compassDisk}>
            <Text style={[styles.cardinal, styles.cardinalTop]}>N</Text>
            <Text style={[styles.cardinal, styles.cardinalRight]}>E</Text>
            <Text style={[styles.cardinal, styles.cardinalBottom]}>S</Text>
            <Text style={[styles.cardinal, styles.cardinalLeft]}>W</Text>
            <View style={[styles.needleWrap, { transform: [{ rotate: qiblaRotation }] }]}>
              <View style={styles.needleStem} />
              <View style={styles.needleHead}>
                <Ionicons name="navigate" size={20} color={palette.primary} />
              </View>
            </View>
            <View style={styles.centerDot} />
          </View>
        </View>
        <Text style={styles.degreeValue}>
          {qiblaData ? `${qiblaData.direction.toFixed(1)}°` : "--°"}
        </Text>
        <Text style={styles.degreeLabel}>Qibla bearing</Text>
      </View>

      <View style={styles.infoGrid}>
        <View style={styles.infoCard}>
          <Ionicons name="moon-outline" size={18} color={palette.primary} />
          <Text style={styles.infoLabel}>Hijri date</Text>
          <Text style={styles.infoValue}>{prayerData?.hijriDate ?? "Loading"}</Text>
        </View>
        <View style={styles.infoCard}>
          <Ionicons name="time-outline" size={18} color={palette.primary} />
          <Text style={styles.infoLabel}>Up next</Text>
          <Text style={styles.infoValue}>{nextPrayer?.name ?? "Loading"}</Text>
        </View>
      </View>

      <LinearGradient colors={[palette.primaryContainer, palette.primary]} style={styles.alignmentCard}>
        <Ionicons name="information-circle-outline" size={20} color={palette.secondaryFixed} />
        <Text style={styles.alignmentTitle}>Alignment guide</Text>
        <Text style={styles.alignmentCopy}>
          Hold the phone flat, recalibrate if necessary, and stay clear of strong magnetic interference for the most accurate direction.
        </Text>
      </LinearGradient>

      <View style={styles.formCard}>
        <Text style={styles.formTitle}>Location lookup</Text>
        <TextInput
          style={styles.input}
          value={prayerDate}
          onChangeText={setPrayerDate}
          placeholder="YYYY-MM-DD"
          placeholderTextColor={palette.outline}
        />
        <TextInput
          style={styles.input}
          value={latitude}
          onChangeText={setLatitude}
          placeholder="Latitude"
          placeholderTextColor={palette.outline}
          keyboardType="decimal-pad"
        />
        <TextInput
          style={styles.input}
          value={longitude}
          onChangeText={setLongitude}
          placeholder="Longitude"
          placeholderTextColor={palette.outline}
          keyboardType="decimal-pad"
        />
        <View style={styles.actionRow}>
          <TouchableOpacity style={styles.primaryButton} onPress={refreshScheduleWithDraftCoordinates}>
            <Text style={styles.primaryButtonText}>Refresh schedule</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.secondaryButton} onPress={useCurrentLocation}>
            <Text style={styles.secondaryButtonText}>
              {isResolving ? "Locating..." : "Use current location"}
            </Text>
          </TouchableOpacity>
        </View>
        {loading ? <ActivityIndicator color={palette.primary} style={styles.loader} /> : null}
        {error ? <Text style={styles.errorText}>{error}</Text> : null}
      </View>

      <View style={styles.scheduleHeader}>
        <Text style={styles.scheduleTitle}>Daily prayer times</Text>
        <Text style={styles.scheduleMeta}>{prayerData?.calculationMethod ?? "Calculation method"}</Text>
      </View>

      <View style={styles.scheduleList}>
        {prayerData?.timings.map((timing) => (
          <View
            key={timing.name}
            style={[
              styles.scheduleCard,
              nextPrayer?.name === timing.name ? styles.scheduleCardActive : undefined,
            ]}
          >
            <View>
              <Text
                style={[
                  styles.scheduleName,
                  nextPrayer?.name === timing.name ? styles.scheduleNameActive : undefined,
                ]}
              >
                {timing.name}
              </Text>
              <Text
                style={[
                  styles.scheduleHint,
                  nextPrayer?.name === timing.name ? styles.scheduleHintActive : undefined,
                ]}
              >
                {nextPrayer?.name === timing.name ? "Current focus" : prayerData.timezone}
              </Text>
            </View>
            <Text
              style={[
                styles.scheduleTime,
                nextPrayer?.name === timing.name ? styles.scheduleTimeActive : undefined,
              ]}
            >
              {timing.time}
            </Text>
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
    fontSize: 24,
    color: palette.primary,
  },
  caption: {
    marginTop: 4,
    fontFamily: fonts.bodyBold,
    fontSize: 10,
    letterSpacing: 1.8,
    textTransform: "uppercase",
    color: palette.textMuted,
  },
  iconButton: {
    width: 40,
    height: 40,
    borderRadius: radii.pill,
    backgroundColor: palette.surfaceLow,
    alignItems: "center",
    justifyContent: "center",
  },
  heroHeader: {
    alignItems: "center",
    gap: spacing.sm,
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
  heroTitle: {
    fontFamily: fonts.serifBold,
    fontSize: 38,
    color: palette.primary,
  },
  heroSubtitle: {
    textAlign: "center",
    fontFamily: fonts.bodyMedium,
    fontSize: 15,
    lineHeight: 24,
    color: palette.textMuted,
  },
  compassSection: {
    alignItems: "center",
    gap: spacing.sm,
  },
  compassRing: {
    width: 300,
    height: 300,
    borderRadius: 160,
    borderWidth: 1,
    borderColor: "rgba(112, 121, 116, 0.18)",
    alignItems: "center",
    justifyContent: "center",
  },
  compassDisk: {
    width: 250,
    height: 250,
    borderRadius: 140,
    backgroundColor: palette.surfaceLowest,
    alignItems: "center",
    justifyContent: "center",
    ...shadows.ambient,
  },
  cardinal: {
    position: "absolute",
    fontFamily: fonts.bodyBold,
    fontSize: 11,
    letterSpacing: 2,
    color: "rgba(64, 73, 68, 0.46)",
  },
  cardinalTop: {
    top: 18,
  },
  cardinalRight: {
    right: 18,
  },
  cardinalBottom: {
    bottom: 18,
  },
  cardinalLeft: {
    left: 18,
  },
  needleWrap: {
    width: 8,
    height: 160,
    alignItems: "center",
  },
  needleStem: {
    width: 4,
    height: 118,
    borderRadius: radii.pill,
    backgroundColor: palette.primaryContainer,
  },
  needleHead: {
    position: "absolute",
    top: -4,
    width: 44,
    height: 44,
    borderRadius: radii.pill,
    backgroundColor: palette.surfaceLowest,
    alignItems: "center",
    justifyContent: "center",
    ...shadows.soft,
  },
  centerDot: {
    position: "absolute",
    width: 18,
    height: 18,
    borderRadius: radii.pill,
    backgroundColor: palette.primaryContainer,
    borderWidth: 5,
    borderColor: "rgba(6, 78, 59, 0.12)",
  },
  degreeValue: {
    fontFamily: fonts.serifBold,
    fontSize: 46,
    color: palette.primary,
  },
  degreeLabel: {
    fontFamily: fonts.bodyBold,
    fontSize: 11,
    letterSpacing: 1.8,
    textTransform: "uppercase",
    color: palette.textMuted,
  },
  infoGrid: {
    flexDirection: "row",
    gap: spacing.sm,
  },
  infoCard: {
    flex: 1,
    gap: spacing.xs,
    borderRadius: radii.md,
    backgroundColor: palette.surfaceLow,
    padding: spacing.lg,
  },
  infoLabel: {
    fontFamily: fonts.bodyBold,
    fontSize: 10,
    letterSpacing: 1.6,
    textTransform: "uppercase",
    color: palette.textMuted,
  },
  infoValue: {
    fontFamily: fonts.serifBold,
    fontSize: 22,
    color: palette.primary,
  },
  alignmentCard: {
    borderRadius: radii.lg,
    padding: spacing.xl,
    gap: spacing.xs,
    ...shadows.ambient,
  },
  alignmentTitle: {
    fontFamily: fonts.serifBold,
    fontSize: 24,
    color: palette.onPrimary,
  },
  alignmentCopy: {
    fontFamily: fonts.bodyMedium,
    fontSize: 14,
    lineHeight: 22,
    color: "rgba(255,255,255,0.78)",
  },
  formCard: {
    borderRadius: radii.lg,
    backgroundColor: palette.surfaceLow,
    padding: spacing.lg,
    gap: spacing.sm,
  },
  formTitle: {
    fontFamily: fonts.serifBold,
    fontSize: 22,
    color: palette.primary,
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
  actionRow: {
    gap: spacing.sm,
    marginTop: spacing.xs,
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
  secondaryButton: {
    alignItems: "center",
    justifyContent: "center",
    borderRadius: radii.md,
    backgroundColor: palette.surfaceHighest,
    paddingVertical: 14,
  },
  secondaryButtonText: {
    fontFamily: fonts.bodyBold,
    fontSize: 12,
    letterSpacing: 1.2,
    textTransform: "uppercase",
    color: palette.primary,
  },
  loader: {
    marginTop: spacing.xs,
  },
  errorText: {
    fontFamily: fonts.bodyMedium,
    color: palette.error,
  },
  scheduleHeader: {
    gap: spacing.xs,
  },
  scheduleTitle: {
    fontFamily: fonts.serifBold,
    fontSize: 24,
    color: palette.primary,
  },
  scheduleMeta: {
    fontFamily: fonts.bodyMedium,
    fontSize: 13,
    color: palette.textMuted,
  },
  scheduleList: {
    gap: spacing.sm,
  },
  scheduleCard: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    borderRadius: radii.md,
    backgroundColor: palette.surfaceLowest,
    padding: spacing.lg,
    ...shadows.soft,
  },
  scheduleCardActive: {
    backgroundColor: palette.primary,
  },
  scheduleName: {
    fontFamily: fonts.serifBold,
    fontSize: 21,
    color: palette.primary,
  },
  scheduleNameActive: {
    color: palette.onPrimary,
  },
  scheduleHint: {
    marginTop: 4,
    fontFamily: fonts.bodyBold,
    fontSize: 10,
    letterSpacing: 1.6,
    textTransform: "uppercase",
    color: palette.textMuted,
  },
  scheduleHintActive: {
    color: "rgba(255,255,255,0.62)",
  },
  scheduleTime: {
    fontFamily: fonts.serifBold,
    fontSize: 30,
    color: palette.primary,
  },
  scheduleTimeActive: {
    color: palette.secondaryFixed,
  },
});
