import { Ionicons } from "@expo/vector-icons";
import {
  DefaultTheme,
  NavigationContainer,
  type Theme as NavigationTheme,
} from "@react-navigation/native";
import { createBottomTabNavigator } from "@react-navigation/bottom-tabs";
import { StatusBar } from "expo-status-bar";
import { useFonts } from "expo-font";
import {
  Manrope_400Regular,
  Manrope_500Medium,
  Manrope_600SemiBold,
  Manrope_700Bold,
} from "@expo-google-fonts/manrope";
import { NotoSerif_400Regular, NotoSerif_700Bold } from "@expo-google-fonts/noto-serif";
import { ActivityIndicator, View } from "react-native";
import { SafeAreaProvider } from "react-native-safe-area-context";

import { AppLocationProvider } from "./src/context/AppLocationContext";
import { HomeScreen } from "./src/screens/HomeScreen";
import { LibraryScreen } from "./src/screens/LibraryScreen";
import { MoreScreen } from "./src/screens/MoreScreen";
import { PrayerScreen } from "./src/screens/PrayerScreen";
import { QuranScreen } from "./src/screens/QuranScreen";
import { fonts, palette, radii, shadows } from "./src/theme";

type RootTabParamList = {
  Home: undefined;
  Prayer: undefined;
  Quran: undefined;
  Library: undefined;
  More: undefined;
};

const Tab = createBottomTabNavigator<RootTabParamList>();

const navigationTheme: NavigationTheme = {
  ...DefaultTheme,
  colors: {
    ...DefaultTheme.colors,
    background: palette.background,
    card: palette.surface,
    primary: palette.primary,
    text: palette.text,
    border: "rgba(112, 121, 116, 0.14)",
    notification: palette.secondary,
  },
  fonts: {
    ...DefaultTheme.fonts,
    regular: {
      fontFamily: fonts.bodyRegular,
      fontWeight: "400",
    },
    medium: {
      fontFamily: fonts.bodyMedium,
      fontWeight: "500",
    },
    bold: {
      fontFamily: fonts.bodyBold,
      fontWeight: "700",
    },
    heavy: {
      fontFamily: fonts.serifBold,
      fontWeight: "700",
    },
  },
};

const iconByRoute: Record<keyof RootTabParamList, keyof typeof Ionicons.glyphMap> = {
  Home: "home-outline",
  Prayer: "time-outline",
  Quran: "book-outline",
  Library: "library-outline",
  More: "radio-outline",
};

export default function App() {
  const [fontsLoaded] = useFonts({
    NotoSerif_400Regular,
    NotoSerif_700Bold,
    Manrope_400Regular,
    Manrope_500Medium,
    Manrope_600SemiBold,
    Manrope_700Bold,
  });

  if (!fontsLoaded) {
    return (
      <SafeAreaProvider>
        <View
          style={{
            flex: 1,
            alignItems: "center",
            justifyContent: "center",
            backgroundColor: palette.background,
          }}
        >
          <ActivityIndicator color={palette.primary} size="large" />
        </View>
      </SafeAreaProvider>
    );
  }

  return (
    <SafeAreaProvider>
      <AppLocationProvider>
        <NavigationContainer theme={navigationTheme}>
          <StatusBar style="dark" />
          <Tab.Navigator
            screenOptions={({ route }) => ({
              headerShown: false,
              sceneStyle: {
                backgroundColor: palette.background,
              },
              tabBarLabelStyle: {
                fontFamily: fonts.bodySemiBold,
                fontSize: 11,
                letterSpacing: 0.3,
              },
              tabBarStyle: {
                position: "absolute",
                left: 18,
                right: 18,
                bottom: 18,
                height: 76,
                paddingTop: 10,
                paddingBottom: 10,
                borderTopWidth: 0,
                borderRadius: radii.lg,
                backgroundColor: palette.glass,
                ...shadows.ambient,
              },
              tabBarItemStyle: {
                borderRadius: radii.md,
                marginHorizontal: 2,
              },
              tabBarActiveTintColor: palette.primary,
              tabBarInactiveTintColor: "rgba(27, 28, 26, 0.48)",
              tabBarIcon: ({ color, size, focused }) => (
                <Ionicons
                  name={focused ? iconByRoute[route.name as keyof RootTabParamList].replace("-outline", "") as keyof typeof Ionicons.glyphMap : iconByRoute[route.name as keyof RootTabParamList]}
                  size={size}
                  color={color}
                />
              ),
            })}
          >
            <Tab.Screen name="Home">
              {({ navigation }) => <HomeScreen navigateTo={(tab) => navigation.navigate(tab)} />}
            </Tab.Screen>
            <Tab.Screen name="Prayer" component={PrayerScreen} />
            <Tab.Screen name="Quran" component={QuranScreen} />
            <Tab.Screen name="Library" component={LibraryScreen} />
            <Tab.Screen name="More" component={MoreScreen} />
          </Tab.Navigator>
        </NavigationContainer>
      </AppLocationProvider>
    </SafeAreaProvider>
  );
}
