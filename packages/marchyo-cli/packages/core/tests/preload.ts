// Loaded before every test file (bunfig.toml). Spawned CLI children inherit
// this env, so no test run writes the host's real greeter theme marker.
process.env.MARCHYO_GREETER_THEME_DIR = "/nonexistent/marchyo-test-greeter";
