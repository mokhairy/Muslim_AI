import * as Location from "expo-location";
import { AppState, Linking, type AppStateStatus } from "react-native";
import {
  createContext,
  type ReactNode,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";

type LocationPermissionState = "granted" | "denied" | "undetermined";

type AppLocationValue = {
  latitude: number;
  longitude: number;
  label: string;
  isResolving: boolean;
  permissionState: LocationPermissionState;
  locationServicesEnabled: boolean;
  statusMessage: string;
  refreshFromDevice: () => Promise<boolean>;
  setManualCoordinates: (latitude: number, longitude: number) => Promise<void>;
  openSystemSettings: () => Promise<void>;
};

const DEFAULT_LATITUDE = 23.588;
const DEFAULT_LONGITUDE = 58.3829;
const DEFAULT_LABEL = "Muscat, Oman";
const DEFAULT_STATUS_MESSAGE = "Using the current device location when permission is available.";

const AppLocationContext = createContext<AppLocationValue | null>(null);

function formatCoordinateLabel(latitude: number, longitude: number) {
  return `${latitude.toFixed(4)}, ${longitude.toFixed(4)}`;
}

function permissionStateFromResponse(
  permissionResponse: Location.LocationPermissionResponse,
): LocationPermissionState {
  if (permissionResponse.granted) {
    return "granted";
  }
  return permissionResponse.canAskAgain === false ? "denied" : "undetermined";
}

function formatLocationLabel(place?: Location.LocationGeocodedAddress | null) {
  if (!place) {
    return "";
  }

  const parts = [place.city, place.region, place.country].filter(Boolean);
  return parts.join(", ");
}

async function resolveLocationLabel(latitude: number, longitude: number) {
  try {
    const places = await Location.reverseGeocodeAsync({ latitude, longitude });
    return formatLocationLabel(places[0]) || formatCoordinateLabel(latitude, longitude);
  } catch {
    return formatCoordinateLabel(latitude, longitude);
  }
}

async function getLocationServicesEnabled() {
  try {
    return await Location.hasServicesEnabledAsync();
  } catch {
    return true;
  }
}

export function AppLocationProvider({ children }: { children: ReactNode }) {
  const [latitude, setLatitude] = useState(DEFAULT_LATITUDE);
  const [longitude, setLongitude] = useState(DEFAULT_LONGITUDE);
  const [label, setLabel] = useState(DEFAULT_LABEL);
  const [isResolving, setIsResolving] = useState(false);
  const [permissionState, setPermissionState] = useState<LocationPermissionState>("undetermined");
  const [locationServicesEnabled, setLocationServicesEnabled] = useState(true);
  const [statusMessage, setStatusMessage] = useState(DEFAULT_STATUS_MESSAGE);

  const refreshPermissionState = useCallback(async () => {
    const servicesEnabled = await getLocationServicesEnabled();
    setLocationServicesEnabled(servicesEnabled);
    if (!servicesEnabled) {
      setPermissionState("denied");
      setStatusMessage("Location Services are turned off. Turn them on in Settings to use current prayer times.");
      return false;
    }

    const permission = await Location.getForegroundPermissionsAsync();
    const nextPermissionState = permissionStateFromResponse(permission);
    setPermissionState(nextPermissionState);

    if (nextPermissionState === "granted") {
      setStatusMessage("Current prayer times can follow your device location.");
      return true;
    }

    if (nextPermissionState === "denied") {
      setStatusMessage("Location access is blocked. Allow location access in Settings, then return to refresh prayer times.");
      return false;
    }

    setStatusMessage("Allow location access to use your current prayer times and qibla.");
    return false;
  }, []);

  const setManualCoordinates = useCallback(async (nextLatitude: number, nextLongitude: number) => {
    setLatitude(nextLatitude);
    setLongitude(nextLongitude);
    setLabel(await resolveLocationLabel(nextLatitude, nextLongitude));
    setStatusMessage("Manual coordinates are active for prayer times and qibla.");
  }, []);

  const refreshFromDevice = useCallback(async () => {
    setIsResolving(true);
    try {
      const servicesEnabled = await getLocationServicesEnabled();
      setLocationServicesEnabled(servicesEnabled);
      if (!servicesEnabled) {
        setPermissionState("denied");
        setStatusMessage("Location Services are turned off. Turn them on in Settings to use current prayer times.");
        return false;
      }

      let permission = await Location.getForegroundPermissionsAsync();
      if (!permission.granted && permission.canAskAgain !== false) {
        permission = await Location.requestForegroundPermissionsAsync();
      }

      const nextPermissionState = permissionStateFromResponse(permission);
      setPermissionState(nextPermissionState);
      if (!permission.granted) {
        setStatusMessage(
          nextPermissionState === "denied"
            ? "Location access is blocked. Allow location access in Settings, then return to refresh prayer times."
            : "Allow location access to use your current prayer times and qibla.",
        );
        return false;
      }

      const position =
        (await Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.Balanced }).catch(
          () => null,
        )) ??
        (await Location.getLastKnownPositionAsync().catch(() => null));

      if (!position) {
        setStatusMessage("Current location is unavailable right now. Move to an open area, then try again.");
        return false;
      }

      const nextLatitude = position.coords.latitude;
      const nextLongitude = position.coords.longitude;
      setLatitude(nextLatitude);
      setLongitude(nextLongitude);
      setLabel(await resolveLocationLabel(nextLatitude, nextLongitude));
      setStatusMessage("Current prayer times are using your live device location.");
      return true;
    } catch {
      setStatusMessage("The app could not refresh your current location. Check Settings and try again.");
      return false;
    } finally {
      setIsResolving(false);
    }
  }, []);

  const openSystemSettings = useCallback(async () => {
    await Linking.openSettings();
  }, []);

  useEffect(() => {
    refreshFromDevice().catch(() => null);
  }, [refreshFromDevice]);

  useEffect(() => {
    const subscription = AppState.addEventListener("change", (nextState: AppStateStatus) => {
      if (nextState === "active") {
        refreshPermissionState().catch(() => null);
      }
    });
    return () => {
      subscription.remove();
    };
  }, [refreshPermissionState]);

  const value = useMemo(
    () => ({
      latitude,
      longitude,
      label,
      isResolving,
      permissionState,
      locationServicesEnabled,
      statusMessage,
      refreshFromDevice,
      setManualCoordinates,
      openSystemSettings,
    }),
    [
      isResolving,
      label,
      latitude,
      locationServicesEnabled,
      longitude,
      openSystemSettings,
      permissionState,
      refreshFromDevice,
      setManualCoordinates,
      statusMessage,
    ],
  );

  return <AppLocationContext.Provider value={value}>{children}</AppLocationContext.Provider>;
}

export function useAppLocation() {
  const value = useContext(AppLocationContext);
  if (!value) {
    throw new Error("useAppLocation must be used within AppLocationProvider.");
  }
  return value;
}
