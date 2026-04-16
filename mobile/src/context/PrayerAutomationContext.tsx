import AsyncStorage from "@react-native-async-storage/async-storage";
import { setAudioModeAsync, useAudioPlayer } from "expo-audio";
import Constants from "expo-constants";
import { AppState, type AppStateStatus, Platform } from "react-native";
import {
  createContext,
  type ReactNode,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";

import { fetchPrayerTimes } from "../lib/api";
import { useAppLocation } from "./AppLocationContext";

type NotificationsModule = typeof import("expo-notifications");
type NotificationPermissionResponse = {
  granted: boolean;
  canAskAgain: boolean;
};

const Notifications: NotificationsModule | null =
  Constants.executionEnvironment === "storeClient"
    ? null
    : (require("expo-notifications") as NotificationsModule);

if (Notifications) {
  Notifications.setNotificationHandler({
    handleNotification: async () => ({
      shouldShowBanner: true,
      shouldShowList: true,
      shouldPlaySound: false,
      shouldSetBadge: false,
    }),
  });
}

const STORAGE_KEY = "muslimai:prayer-automation:v1";
const PRAYER_NOTIFICATION_CHANNEL_ID = "prayer-reminders";
const DEFAULT_ADHAN_STREAM_URL = "https://www.islamcan.com/audio/adhan/azan1.mp3";
const SCHEDULE_LOOKAHEAD_DAYS = 7;
const PRAYER_NAMES = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"] as const;
const NOTIFICATIONS_UNAVAILABLE_MESSAGE =
  "Prayer reminders require a development build or standalone app. Expo Go does not support them here.";

type PrayerName = (typeof PRAYER_NAMES)[number];
type PermissionState = "granted" | "denied" | "undetermined";

type PersistedPrayerAutomationState = {
  enabled: boolean;
  selectedPrayers: PrayerName[];
  scheduledNotificationIds: string[];
  lastSyncedAt: string | null;
};

type PrayerReminder = {
  key: string;
  prayerName: PrayerName;
  date: Date;
  timeLabel: string;
};

type PrayerAutomationValue = {
  enabled: boolean;
  selectedPrayers: PrayerName[];
  permissionState: PermissionState;
  isSyncing: boolean;
  syncError: string;
  lastSyncedLabel: string;
  nextReminderLabel: string;
  statusMessage: string;
  enableAutomation: () => Promise<boolean>;
  disableAutomation: () => Promise<void>;
  togglePrayerSelection: (prayerName: PrayerName) => Promise<void>;
  resyncSchedule: () => Promise<void>;
};

const DEFAULT_STATE: PersistedPrayerAutomationState = {
  enabled: false,
  selectedPrayers: [...PRAYER_NAMES],
  scheduledNotificationIds: [],
  lastSyncedAt: null,
};

const PrayerAutomationContext = createContext<PrayerAutomationValue | null>(null);

function formatLocalIsoDate(date: Date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function buildLocalDateTime(dateString: string, timeLabel: string) {
  const [year, month, day] = dateString.split("-").map(Number);
  const [hours, minutes] = timeLabel.split(":").map(Number);
  return new Date(year, (month || 1) - 1, day || 1, hours || 0, minutes || 0, 0, 0);
}

function formatReminderLabel(date: Date) {
  return `${date.toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
  })} at ${date.toLocaleTimeString(undefined, {
    hour: "numeric",
    minute: "2-digit",
  })}`;
}

async function loadStoredState() {
  try {
    const rawValue = await AsyncStorage.getItem(STORAGE_KEY);
    if (!rawValue) {
      return DEFAULT_STATE;
    }
    const parsedValue = JSON.parse(rawValue) as Partial<PersistedPrayerAutomationState>;
    const selectedPrayers = Array.isArray(parsedValue.selectedPrayers)
      ? parsedValue.selectedPrayers.filter((value): value is PrayerName =>
          PRAYER_NAMES.includes(value as PrayerName),
        )
      : DEFAULT_STATE.selectedPrayers;
    return {
      enabled: Boolean(parsedValue.enabled),
      selectedPrayers: selectedPrayers.length ? selectedPrayers : [...PRAYER_NAMES],
      scheduledNotificationIds: Array.isArray(parsedValue.scheduledNotificationIds)
        ? parsedValue.scheduledNotificationIds.filter((value): value is string => typeof value === "string")
        : [],
      lastSyncedAt:
        typeof parsedValue.lastSyncedAt === "string" ? parsedValue.lastSyncedAt : null,
    };
  } catch {
    return DEFAULT_STATE;
  }
}

async function persistState(state: PersistedPrayerAutomationState) {
  await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

async function cancelScheduledNotifications(notificationIds: string[]) {
  if (!Notifications) {
    return;
  }
  await Promise.all(
    notificationIds.map((notificationId) =>
      Notifications.cancelScheduledNotificationAsync(notificationId).catch(() => null),
    ),
  );
}

async function ensureNotificationPermission() {
  if (!Notifications) {
    return {
      granted: false,
      canAskAgain: false,
    } satisfies NotificationPermissionResponse;
  }
  let permissionResponse = await Notifications.getPermissionsAsync();
  if (!permissionResponse.granted && permissionResponse.canAskAgain !== false) {
    permissionResponse = await Notifications.requestPermissionsAsync();
  }
  return permissionResponse;
}

function toPermissionState(permissionResponse: NotificationPermissionResponse): PermissionState {
  if (permissionResponse.granted) {
    return "granted";
  }
  return permissionResponse.canAskAgain === false ? "denied" : "undetermined";
}

async function buildUpcomingPrayerReminders(
  latitude: number,
  longitude: number,
  selectedPrayers: PrayerName[],
) {
  const now = Date.now() + 10_000;
  const upcomingReminders: PrayerReminder[] = [];
  const startDate = new Date();
  startDate.setHours(0, 0, 0, 0);

  for (let offset = 0; offset < SCHEDULE_LOOKAHEAD_DAYS; offset += 1) {
    const targetDate = new Date(startDate);
    targetDate.setDate(startDate.getDate() + offset);
    const dateString = formatLocalIsoDate(targetDate);
    const prayerTimes = await fetchPrayerTimes(dateString, latitude, longitude);
    for (const timing of prayerTimes.timings) {
      if (!selectedPrayers.includes(timing.name as PrayerName)) {
        continue;
      }
      const triggerDate = buildLocalDateTime(dateString, timing.time);
      if (triggerDate.getTime() <= now) {
        continue;
      }
      upcomingReminders.push({
        key: `${dateString}:${timing.name}`,
        prayerName: timing.name as PrayerName,
        date: triggerDate,
        timeLabel: timing.time,
      });
    }
  }

  upcomingReminders.sort((left, right) => left.date.getTime() - right.date.getTime());
  return upcomingReminders;
}

export function PrayerAutomationProvider({ children }: { children: ReactNode }) {
  const { latitude, longitude, label } = useAppLocation();
  const [persistedState, setPersistedState] = useState<PersistedPrayerAutomationState>(DEFAULT_STATE);
  const [permissionState, setPermissionState] = useState<PermissionState>("undetermined");
  const [isSyncing, setIsSyncing] = useState(false);
  const [syncError, setSyncError] = useState("");
  const [isHydrated, setIsHydrated] = useState(false);
  const [resyncToken, setResyncToken] = useState(0);
  const [upcomingReminders, setUpcomingReminders] = useState<PrayerReminder[]>([]);
  const [appState, setAppState] = useState<AppStateStatus>(AppState.currentState);
  const foregroundPlaybackTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const lastPlayedReminderKeyRef = useRef<string | null>(null);
  const player = useAudioPlayer(null, {
    downloadFirst: true,
    keepAudioSessionActive: true,
    updateInterval: 250,
  });

  const selectedPrayersSignature = useMemo(
    () => persistedState.selectedPrayers.slice().sort().join("|"),
    [persistedState.selectedPrayers],
  );

  useEffect(() => {
    setAudioModeAsync({
      playsInSilentMode: true,
      interruptionMode: "doNotMix",
      shouldPlayInBackground: false,
    }).catch(() => null);
  }, []);

  useEffect(() => {
    if (!Notifications || Platform.OS !== "android") {
      return;
    }
    Notifications.setNotificationChannelAsync(PRAYER_NOTIFICATION_CHANNEL_ID, {
      name: "Prayer reminders",
      importance: Notifications.AndroidImportance.MAX,
      lockscreenVisibility: Notifications.AndroidNotificationVisibility.PUBLIC,
      bypassDnd: false,
      sound: "default",
    }).catch(() => null);
  }, []);

  useEffect(() => {
    let isCancelled = false;

    async function hydrateState() {
      const storedState = await loadStoredState();
      if (isCancelled) {
        return;
      }

      setPersistedState(storedState);
      const permissionResponse: NotificationPermissionResponse = Notifications
        ? await Notifications.getPermissionsAsync()
        : {
            granted: false,
            canAskAgain: false,
          };
      if (isCancelled) {
        return;
      }

      setPermissionState(toPermissionState(permissionResponse));
    }

    hydrateState()
      .catch(() => null)
      .finally(() => {
        setIsHydrated(true);
      });

    return () => {
      isCancelled = true;
    };
  }, []);

  useEffect(() => {
    const subscription = AppState.addEventListener("change", (nextAppState) => {
      setAppState(nextAppState);
      if (nextAppState === "active") {
        setResyncToken((currentValue) => currentValue + 1);
      }
    });
    return () => {
      subscription.remove();
    };
  }, []);

  const updatePersistedState = useCallback(
    async (nextState: PersistedPrayerAutomationState) => {
      setPersistedState(nextState);
      await persistState(nextState);
    },
    [],
  );

  const runScheduleSync = useCallback(
    async (stateToSync: PersistedPrayerAutomationState) => {
      if (!stateToSync.enabled) {
        await cancelScheduledNotifications(stateToSync.scheduledNotificationIds);
        const clearedState = {
          ...stateToSync,
          scheduledNotificationIds: [],
          lastSyncedAt: null,
        };
        await updatePersistedState(clearedState);
        setUpcomingReminders([]);
        setSyncError("");
        return;
      }

      if (!stateToSync.selectedPrayers.length) {
        await cancelScheduledNotifications(stateToSync.scheduledNotificationIds);
        const clearedState = {
          ...stateToSync,
          scheduledNotificationIds: [],
          lastSyncedAt: null,
        };
        await updatePersistedState(clearedState);
        setUpcomingReminders([]);
        setSyncError("Select at least one prayer reminder to keep automation active.");
        return;
      }

      setIsSyncing(true);
      setSyncError("");
      try {
        if (!Notifications) {
          throw new Error(NOTIFICATIONS_UNAVAILABLE_MESSAGE);
        }

        const permissionResponse = await ensureNotificationPermission();
        const nextPermissionState = toPermissionState(permissionResponse);
        setPermissionState(nextPermissionState);
        if (!permissionResponse.granted) {
          throw new Error("Notification permission is required to schedule prayer reminders.");
        }

        await cancelScheduledNotifications(stateToSync.scheduledNotificationIds);
        const reminders = await buildUpcomingPrayerReminders(
          latitude,
          longitude,
          stateToSync.selectedPrayers,
        );
        const notificationIds: string[] = [];
        for (const reminder of reminders) {
          const notificationId = await Notifications.scheduleNotificationAsync({
            content: {
              title: `${reminder.prayerName} prayer time`,
              body: `${reminder.prayerName} is due for ${label}.`,
              sound: "default",
              data: {
                prayerName: reminder.prayerName,
                timeLabel: reminder.timeLabel,
                localOnly: true,
              },
            },
            trigger: {
              type: Notifications.SchedulableTriggerInputTypes.DATE,
              channelId: PRAYER_NOTIFICATION_CHANNEL_ID,
              date: reminder.date,
            },
          });
          notificationIds.push(notificationId);
        }

        const nextState = {
          ...stateToSync,
          scheduledNotificationIds: notificationIds,
          lastSyncedAt: new Date().toISOString(),
        };
        await updatePersistedState(nextState);
        setUpcomingReminders(reminders);
      } catch (caughtError) {
        setUpcomingReminders([]);
        setSyncError(
          caughtError instanceof Error
            ? caughtError.message
            : "Unable to schedule prayer reminders right now.",
        );
      } finally {
        setIsSyncing(false);
      }
    },
    [label, latitude, longitude, updatePersistedState],
  );

  useEffect(() => {
    if (!isHydrated) {
      return;
    }
    runScheduleSync(persistedState).catch(() => null);
  }, [
    isHydrated,
    persistedState.enabled,
    selectedPrayersSignature,
    latitude,
    longitude,
    label,
    resyncToken,
    runScheduleSync,
  ]);

  useEffect(() => {
    if (foregroundPlaybackTimerRef.current) {
      clearTimeout(foregroundPlaybackTimerRef.current);
      foregroundPlaybackTimerRef.current = null;
    }

    if (!persistedState.enabled || appState !== "active" || !upcomingReminders.length) {
      return;
    }

    const nextReminder = upcomingReminders[0];
    const delayMs = nextReminder.date.getTime() - Date.now();
    if (delayMs <= 0) {
      if (lastPlayedReminderKeyRef.current !== nextReminder.key) {
        lastPlayedReminderKeyRef.current = nextReminder.key;
        player.replace(DEFAULT_ADHAN_STREAM_URL);
        player.seekTo(0);
        player.play();
        setUpcomingReminders((currentValue) =>
          currentValue.filter((reminder) => reminder.key !== nextReminder.key),
        );
      }
      return;
    }

    foregroundPlaybackTimerRef.current = setTimeout(() => {
      if (lastPlayedReminderKeyRef.current === nextReminder.key) {
        return;
      }
      lastPlayedReminderKeyRef.current = nextReminder.key;
      player.replace(DEFAULT_ADHAN_STREAM_URL);
      player.seekTo(0);
      player.play();
      setUpcomingReminders((currentValue) =>
        currentValue.filter((reminder) => reminder.key !== nextReminder.key),
      );
    }, delayMs);

    return () => {
      if (foregroundPlaybackTimerRef.current) {
        clearTimeout(foregroundPlaybackTimerRef.current);
        foregroundPlaybackTimerRef.current = null;
      }
    };
  }, [appState, persistedState.enabled, player, upcomingReminders]);

  const enableAutomation = useCallback(async () => {
    if (!Notifications) {
      setPermissionState("denied");
      setSyncError(NOTIFICATIONS_UNAVAILABLE_MESSAGE);
      return false;
    }

    const permissionResponse = await ensureNotificationPermission();
    const nextPermissionState = toPermissionState(permissionResponse);
    setPermissionState(nextPermissionState);
    if (!permissionResponse.granted) {
      setSyncError("Notification permission is required to enable prayer reminders.");
      return false;
    }

    const nextState = {
      ...persistedState,
      enabled: true,
    };
    await updatePersistedState(nextState);
    setResyncToken((currentValue) => currentValue + 1);
    return true;
  }, [persistedState, updatePersistedState]);

  const disableAutomation = useCallback(async () => {
    player.pause();
    const nextState = {
      ...persistedState,
      enabled: false,
    };
    await updatePersistedState(nextState);
    setResyncToken((currentValue) => currentValue + 1);
  }, [persistedState, player, updatePersistedState]);

  const togglePrayerSelection = useCallback(
    async (prayerName: PrayerName) => {
      const nextSelectedPrayers = persistedState.selectedPrayers.includes(prayerName)
        ? persistedState.selectedPrayers.filter((value) => value !== prayerName)
        : [...persistedState.selectedPrayers, prayerName];
      const nextState = {
        ...persistedState,
        selectedPrayers: nextSelectedPrayers,
      };
      await updatePersistedState(nextState);
      setResyncToken((currentValue) => currentValue + 1);
    },
    [persistedState, updatePersistedState],
  );

  const resyncSchedule = useCallback(async () => {
    setResyncToken((currentValue) => currentValue + 1);
  }, []);

  const nextReminderLabel = upcomingReminders[0]
    ? `${upcomingReminders[0].prayerName} on ${formatReminderLabel(upcomingReminders[0].date)}`
    : persistedState.enabled
      ? "No upcoming reminders scheduled yet."
      : "Prayer reminders are off.";

  const lastSyncedLabel = persistedState.lastSyncedAt
    ? new Date(persistedState.lastSyncedAt).toLocaleString()
    : "Not scheduled yet";

  const statusMessage = persistedState.enabled
    ? "This phase schedules local reminders and plays adhan on this device while the app is open."
    : Notifications
      ? "Enable local prayer reminders to schedule adhan alerts on this device only."
      : NOTIFICATIONS_UNAVAILABLE_MESSAGE;

  const value = useMemo(
    () => ({
      enabled: persistedState.enabled,
      selectedPrayers: persistedState.selectedPrayers,
      permissionState,
      isSyncing,
      syncError,
      lastSyncedLabel,
      nextReminderLabel,
      statusMessage,
      enableAutomation,
      disableAutomation,
      togglePrayerSelection,
      resyncSchedule,
    }),
    [
      disableAutomation,
      enableAutomation,
      isSyncing,
      lastSyncedLabel,
      nextReminderLabel,
      persistedState.enabled,
      persistedState.selectedPrayers,
      permissionState,
      resyncSchedule,
      statusMessage,
      syncError,
      togglePrayerSelection,
    ],
  );

  return (
    <PrayerAutomationContext.Provider value={value}>
      {children}
    </PrayerAutomationContext.Provider>
  );
}

export function usePrayerAutomation() {
  const value = useContext(PrayerAutomationContext);
  if (!value) {
    throw new Error("usePrayerAutomation must be used within PrayerAutomationProvider.");
  }
  return value;
}
