import * as Location from "expo-location";
import {
  createContext,
  type ReactNode,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";

type AppLocationValue = {
  latitude: number;
  longitude: number;
  label: string;
  isResolving: boolean;
  refreshFromDevice: () => Promise<boolean>;
  setManualCoordinates: (latitude: number, longitude: number) => Promise<void>;
};

const DEFAULT_LATITUDE = 23.588;
const DEFAULT_LONGITUDE = 58.3829;
const DEFAULT_LABEL = "Muscat, Oman";

const AppLocationContext = createContext<AppLocationValue | null>(null);

function formatCoordinateLabel(latitude: number, longitude: number) {
  return `${latitude.toFixed(4)}, ${longitude.toFixed(4)}`;
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

export function AppLocationProvider({ children }: { children: ReactNode }) {
  const [latitude, setLatitude] = useState(DEFAULT_LATITUDE);
  const [longitude, setLongitude] = useState(DEFAULT_LONGITUDE);
  const [label, setLabel] = useState(DEFAULT_LABEL);
  const [isResolving, setIsResolving] = useState(false);

  const setManualCoordinates = useCallback(async (nextLatitude: number, nextLongitude: number) => {
    setLatitude(nextLatitude);
    setLongitude(nextLongitude);
    setLabel(await resolveLocationLabel(nextLatitude, nextLongitude));
  }, []);

  const refreshFromDevice = useCallback(async () => {
    setIsResolving(true);
    try {
      let permission = await Location.getForegroundPermissionsAsync();
      if (!permission.granted && permission.canAskAgain !== false) {
        permission = await Location.requestForegroundPermissionsAsync();
      }

      if (!permission.granted) {
        return false;
      }

      const position = await Location.getCurrentPositionAsync({});
      const nextLatitude = position.coords.latitude;
      const nextLongitude = position.coords.longitude;
      setLatitude(nextLatitude);
      setLongitude(nextLongitude);
      setLabel(await resolveLocationLabel(nextLatitude, nextLongitude));
      return true;
    } catch {
      return false;
    } finally {
      setIsResolving(false);
    }
  }, []);

  useEffect(() => {
    refreshFromDevice().catch(() => null);
  }, [refreshFromDevice]);

  const value = useMemo(
    () => ({
      latitude,
      longitude,
      label,
      isResolving,
      refreshFromDevice,
      setManualCoordinates,
    }),
    [isResolving, label, latitude, longitude, refreshFromDevice, setManualCoordinates],
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
