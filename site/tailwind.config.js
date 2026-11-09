import animate from "tailwindcss-animate";

/** @type {import('tailwindcss').Config} */
export default {
  darkMode: ["selector", '[data-mode="dark"]'],
  content: ["./src/os/**/*.{ts,tsx,js,jsx}"],
  theme: {
    extend: {
      // Mapped straight onto the design system's radius scale rather than
      // shadcn's `--radius` minus-2px arithmetic, which bottoms out at 0 on a
      // 4px canonical step.
      borderRadius: {
        lg: "var(--radius-md)",
        md: "var(--radius-sm)",
        sm: "var(--radius-xs)",
        pill: "var(--radius-pill)",
      },
      colors: {
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        card: {
          DEFAULT: "hsl(var(--card))",
          foreground: "hsl(var(--card-foreground))",
        },
        popover: {
          DEFAULT: "hsl(var(--popover))",
          foreground: "hsl(var(--popover-foreground))",
        },
        primary: {
          DEFAULT: "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))",
        },
        secondary: {
          DEFAULT: "hsl(var(--secondary))",
          foreground: "hsl(var(--secondary-foreground))",
        },
        muted: {
          DEFAULT: "hsl(var(--muted))",
          foreground: "hsl(var(--muted-foreground))",
        },
        accent: {
          DEFAULT: "hsl(var(--accent))",
          foreground: "hsl(var(--accent-foreground))",
        },
        destructive: {
          DEFAULT: "hsl(var(--destructive))",
          foreground: "hsl(var(--destructive-foreground))",
        },
        // Legacy marchyo-os palette names, mapped onto the design tokens.
        copper: {
          DEFAULT: "hsl(var(--primary))",
          hover: "hsl(var(--primary-hover))",
          subtle: "hsl(var(--accent))",
        },
        ink: {
          DEFAULT: "hsl(var(--foreground))",
          heading: "hsl(var(--heading))",
          muted: "hsl(var(--muted-foreground))",
          faint: "hsl(var(--faint))",
        },
        canvas: {
          DEFAULT: "hsl(var(--background))",
          subtle: "hsl(var(--secondary))",
        },
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
        "primary-hover": "hsl(var(--primary-hover))",
        heading: "hsl(var(--heading))",
        faint: "hsl(var(--faint))",
        brand: "hsl(var(--brand))",
        "border-strong": "hsl(var(--border-strong))",
        decorator: "hsl(var(--decorator))",
        // Structural linework only , never an interaction colour.
        contour: "hsl(var(--contour))",
        status: {
          err: {
            DEFAULT: "hsl(var(--status-err))",
            bg: "hsl(var(--status-err-bg))",
          },
          warn: {
            DEFAULT: "hsl(var(--status-warn))",
            bg: "hsl(var(--status-warn-bg))",
          },
          ok: {
            DEFAULT: "hsl(var(--status-ok))",
            bg: "hsl(var(--status-ok-bg))",
          },
          info: {
            DEFAULT: "hsl(var(--status-info))",
            bg: "hsl(var(--status-info-bg))",
          },
        },
        chart: {
          1: "hsl(var(--chart-1))",
          2: "hsl(var(--chart-2))",
          3: "hsl(var(--chart-3))",
          4: "hsl(var(--chart-4))",
          5: "hsl(var(--chart-5))",
        },
      },
      fontFamily: {
        heading: ["var(--font-heading)"],
        body: ["var(--font-body)"],
        display: ["var(--font-display)"],
        mono: ["var(--font-mono)"],
      },
      keyframes: {
        "accordion-down": {
          from: { height: "0" },
          to: { height: "var(--radix-accordion-content-height)" },
        },
        "accordion-up": {
          from: { height: "var(--radix-accordion-content-height)" },
          to: { height: "0" },
        },
        "fade-in": {
          from: { opacity: "0", transform: "translateY(6px)" },
          to: { opacity: "1", transform: "translateY(0)" },
        },
        blink: { "0%, 100%": { opacity: "1" }, "50%": { opacity: "0" } },
      },
      animation: {
        "accordion-down": "accordion-down 0.2s ease-out",
        "accordion-up": "accordion-up 0.2s ease-out",
        "fade-in": "fade-in 0.25s cubic-bezier(0.2,0.6,0.2,1)",
        blink: "blink 1s step-end infinite",
      },
    },
  },
  plugins: [animate],
};
