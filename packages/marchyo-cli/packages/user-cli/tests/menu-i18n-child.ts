import { gumChoose } from "../src/commands/menu.ts";

console.log(await gumChoose("Power", ["Lock", "Suspend", "Reboot"]));
