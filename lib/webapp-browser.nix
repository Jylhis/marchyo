# Chromium-family command used for `--app=` windows: marchyo.webapps.browser,
# else marchyo.defaults.browser when chromium-based, else chromium.
{ osConfig }:
let
  mc = osConfig.marchyo or { };
  chromiumFamily = {
    brave = "brave";
    google-chrome = "google-chrome";
    chromium = "chromium";
  };
  explicit = (mc.webapps or { }).browser or null;
  defaultBrowser = (mc.defaults or { }).browser or null;
  resolved =
    if explicit != null then
      chromiumFamily.${explicit}
    else if defaultBrowser != null && chromiumFamily ? ${defaultBrowser} then
      chromiumFamily.${defaultBrowser}
    else
      null;
in
{
  command = if resolved != null then resolved else "chromium";
  needsChromium = resolved == null;
}
