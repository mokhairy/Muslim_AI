import { Ionicons } from "@expo/vector-icons";
import { Picker } from "@react-native-picker/picker";
import { setAudioModeAsync, useAudioPlayer, useAudioPlayerStatus } from "expo-audio";
import { useEffect, useState } from "react";
import {
  ActivityIndicator,
  Linking,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";

import { fetchRadioStations, type RadioStation } from "../lib/api";
import { fonts, palette, radii, shadows, spacing } from "../theme";

const LIVE_WEB_URL = "https://muslimai.geointel.ca/";

const platformNotes = [
  "The mobile shell already consumes the same prayer, Quran, hadith, azkar, and radio APIs as the web app.",
  "The Stitch pack now acts as the design source for the native UI language, not just a visual reference.",
  "Next shipping step is Expo EAS builds for Android and iOS after API edge cases are hardened.",
];

export function MoreScreen() {
  const [stations, setStations] = useState<RadioStation[]>([]);
  const [selectedStationId, setSelectedStationId] = useState<number | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const player = useAudioPlayer(null, {
    updateInterval: 250,
    downloadFirst: true,
    keepAudioSessionActive: true,
  });
  const playerStatus = useAudioPlayerStatus(player);
  const isPlaying = Boolean(playerStatus?.playing);

  const selectedStation =
    stations.find((station) => station.id === selectedStationId) ?? stations[0] ?? null;

  async function loadStations() {
    setLoading(true);
    setError("");
    try {
      const nextStations = await fetchRadioStations();
      setStations(nextStations);
      setSelectedStationId(nextStations[0]?.id ?? null);
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : "Unable to load stations.");
    } finally {
      setLoading(false);
    }
  }

  function toggleRadio() {
    if (!selectedStation) {
      return;
    }

    if (playerStatus?.playing) {
      player.pause();
      return;
    }

    player.replace(selectedStation.url);
    player.seekTo(0);
    player.play();
  }

  useEffect(() => {
    setAudioModeAsync({
      playsInSilentMode: true,
      interruptionMode: "doNotMix",
      shouldPlayInBackground: false,
    }).catch(() => null);
    loadStations().catch(() => null);
  }, []);

  return (
    <ScrollView style={styles.page} contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
      <View style={styles.topBar}>
        <Text style={styles.brand}>Muslim AI</Text>
        <View style={styles.profileDot} />
      </View>

      <View style={styles.headerBlock}>
        <Text style={styles.kicker}>Support layer</Text>
        <Text style={styles.title}>Radio, deployment references, and the shipping path.</Text>
      </View>

      <View style={styles.radioHero}>
        <Text style={styles.radioKicker}>Islamic radio</Text>
        <Text style={styles.radioTitle}>
          {selectedStation?.name ?? "Select a live station"}
        </Text>
        <Text style={styles.radioCopy}>
          Keep audio tools separate from the reading tabs while preserving the same sanctuary atmosphere.
        </Text>
      </View>

      <View style={styles.surfaceCard}>
        <Text style={styles.cardTitle}>Station selector</Text>
        <View style={styles.pickerWrap}>
          <Picker
            selectedValue={selectedStationId}
            style={styles.picker}
            dropdownIconColor={palette.primary}
            onValueChange={(value) => setSelectedStationId(Number(value))}
          >
            {stations.map((station) => (
              <Picker.Item key={station.id} label={station.name} value={station.id} />
            ))}
          </Picker>
        </View>
        <View style={styles.actionRow}>
          <TouchableOpacity style={styles.primaryButton} onPress={toggleRadio}>
            <Ionicons name={isPlaying ? "pause" : "play"} size={16} color={palette.onPrimary} />
            <Text style={styles.primaryButtonText}>{isPlaying ? "Pause radio" : "Play radio"}</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.secondaryButton} onPress={() => loadStations()}>
            <Text style={styles.secondaryButtonText}>Refresh stations</Text>
          </TouchableOpacity>
        </View>
        {loading ? <ActivityIndicator color={palette.primary} style={styles.loader} /> : null}
        {error ? <Text style={styles.errorText}>{error}</Text> : null}
      </View>

      <View style={styles.platformCard}>
        <Text style={styles.platformTitle}>Live web reference</Text>
        <Text style={styles.platformCopy}>
          The Railway deployment remains the reference surface while the native app grows feature parity.
        </Text>
        <TouchableOpacity style={styles.linkButton} onPress={() => Linking.openURL(LIVE_WEB_URL)}>
          <Text style={styles.linkButtonText}>{LIVE_WEB_URL}</Text>
        </TouchableOpacity>
      </View>

      <View style={styles.notesList}>
        {platformNotes.map((note) => (
          <View key={note} style={styles.noteCard}>
            <Ionicons name="sparkles-outline" size={18} color={palette.secondary} />
            <Text style={styles.noteText}>{note}</Text>
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
  radioHero: {
    borderRadius: radii.lg,
    backgroundColor: palette.surfaceLow,
    padding: spacing.xl,
    gap: spacing.xs,
  },
  radioKicker: {
    fontFamily: fonts.bodyBold,
    fontSize: 11,
    letterSpacing: 1.8,
    textTransform: "uppercase",
    color: palette.textMuted,
  },
  radioTitle: {
    fontFamily: fonts.serifBold,
    fontSize: 28,
    lineHeight: 38,
    color: palette.primary,
  },
  radioCopy: {
    fontFamily: fonts.bodyMedium,
    fontSize: 15,
    lineHeight: 24,
    color: palette.textMuted,
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
  actionRow: {
    gap: spacing.sm,
  },
  primaryButton: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: spacing.xs,
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
  platformCard: {
    borderRadius: radii.lg,
    backgroundColor: palette.primaryContainer,
    padding: spacing.xl,
    gap: spacing.sm,
    ...shadows.ambient,
  },
  platformTitle: {
    fontFamily: fonts.serifBold,
    fontSize: 26,
    color: palette.onPrimary,
  },
  platformCopy: {
    fontFamily: fonts.bodyMedium,
    fontSize: 15,
    lineHeight: 24,
    color: "rgba(255,255,255,0.76)",
  },
  linkButton: {
    alignSelf: "flex-start",
    borderRadius: radii.md,
    backgroundColor: palette.secondaryFixed,
    paddingHorizontal: spacing.lg,
    paddingVertical: 12,
  },
  linkButtonText: {
    fontFamily: fonts.bodyBold,
    fontSize: 12,
    letterSpacing: 0.3,
    color: palette.onSecondaryFixed,
  },
  notesList: {
    gap: spacing.sm,
  },
  noteCard: {
    flexDirection: "row",
    alignItems: "flex-start",
    gap: spacing.sm,
    borderRadius: radii.md,
    backgroundColor: palette.surfaceHighest,
    padding: spacing.md,
  },
  noteText: {
    flex: 1,
    fontFamily: fonts.bodyMedium,
    fontSize: 14,
    lineHeight: 22,
    color: palette.text,
  },
});
