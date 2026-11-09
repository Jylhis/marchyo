import { useTheme } from "@/lib/theme";

// Unicode is the icon set (jylhis/design): ☀ light, ☾ dark. No icon fonts.
export default function ThemeToggle({ className = "" }) {
  const { theme, toggle } = useTheme();
  const dark = theme === "dark";
  return (
    <button
      type="button"
      onClick={toggle}
      aria-label={dark ? "Switch to light theme" : "Switch to dark theme"}
      title={dark ? "light" : "dark"}
      className={`inline-flex h-7 w-7 items-center justify-center border border-border
        font-mono text-sm text-ink-muted transition-colors hover:text-copper
        hover:border-copper focus-visible:outline-hidden focus-visible:ring-2
        focus-visible:ring-ring focus-visible:ring-offset-2
        focus-visible:ring-offset-background ${className}`}
    >
      {dark ? "☀" : "☾"}
    </button>
  );
}
