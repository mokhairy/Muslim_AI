export const palette = {
  background: "#fbf9f5",
  surface: "#fbf9f5",
  surfaceBright: "#fbf9f5",
  surfaceLow: "#f5f3ef",
  surfaceContainer: "#efeeea",
  surfaceHigh: "#eae8e4",
  surfaceHighest: "#e4e2de",
  surfaceLowest: "#ffffff",
  surfaceVariant: "#e4e2de",
  primary: "#003527",
  primaryContainer: "#064e3b",
  primaryFixed: "#b0f0d6",
  primaryFixedDim: "#95d3ba",
  onPrimary: "#ffffff",
  onPrimaryContainer: "#80bea6",
  secondary: "#735c00",
  secondaryContainer: "#fed65b",
  secondaryFixed: "#ffe088",
  onSecondaryFixed: "#241a00",
  text: "#1b1c1a",
  textMuted: "#404944",
  outline: "#707974",
  outlineVariant: "#bfc9c3",
  error: "#ba1a1a",
  errorContainer: "#ffdad6",
  success: "#0f8a5f",
  glass: "rgba(251, 249, 245, 0.82)",
  glassStrong: "rgba(251, 249, 245, 0.92)",
};

export const spacing = {
  xxs: 4,
  xs: 8,
  sm: 12,
  md: 16,
  lg: 24,
  xl: 32,
  xxl: 40,
};

export const radii = {
  sm: 16,
  md: 24,
  lg: 32,
  pill: 999,
};

export const fonts = {
  serifRegular: "NotoSerif_400Regular",
  serifBold: "NotoSerif_700Bold",
  bodyRegular: "Manrope_400Regular",
  bodyMedium: "Manrope_500Medium",
  bodySemiBold: "Manrope_600SemiBold",
  bodyBold: "Manrope_700Bold",
};

export const shadows = {
  ambient: {
    shadowColor: palette.text,
    shadowOpacity: 0.06,
    shadowRadius: 24,
    shadowOffset: { width: 0, height: 8 },
    elevation: 8,
  },
  soft: {
    shadowColor: palette.text,
    shadowOpacity: 0.04,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: 6 },
    elevation: 4,
  },
};
