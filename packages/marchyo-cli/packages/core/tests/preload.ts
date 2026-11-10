// Loaded before every test file (bunfig.toml). Spawned CLI children inherit
// this env, so no test run writes the host's real greeter theme marker.
process.env.MARCHYO_GREETER_THEME_DIR = "/nonexistent/marchyo-test-greeter";
// The shared CLI translator reads the language override from the state dir; a
// missing one keeps every test on English whatever the host has set.
process.env.XDG_STATE_HOME = "/nonexistent/marchyo-test-state";
