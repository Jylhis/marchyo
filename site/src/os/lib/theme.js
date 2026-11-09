import { useCallback, useEffect, useState } from "react";

const KEY = "marchyo-theme";

function currentTheme() {
  if (typeof document === "undefined") return "light";
  return document.documentElement.dataset.mode === "dark" ? "dark" : "light";
}

// Small theme controller: sets data-mode on <html>, persists the
// choice, and notifies subscribers so chart/SVG components can re-read colors.
export function useTheme() {
  const [theme, setThemeState] = useState(currentTheme);

  useEffect(() => {
    const onChange = () => setThemeState(currentTheme());
    window.addEventListener("marchyo-theme-change", onChange);
    return () => window.removeEventListener("marchyo-theme-change", onChange);
  }, []);

  const setTheme = useCallback((next) => {
    document.documentElement.dataset.mode = next;
    try {
      localStorage.setItem(KEY, next);
    } catch (e) {
      /* ignore private-mode write failures */
    }
    window.dispatchEvent(new Event("marchyo-theme-change"));
  }, []);

  const toggle = useCallback(
    () => setTheme(currentTheme() === "dark" ? "light" : "dark"),
    [setTheme],
  );

  return { theme, setTheme, toggle };
}
