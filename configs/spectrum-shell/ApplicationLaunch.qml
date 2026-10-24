pragma Singleton
import Quickshell
import Quickshell.Hyprland

Singleton {
    function shellQuote(value): string {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function dispatchCommand(argv, delayMs = 0): string {
        let command = argv.map(shellQuote).join(" ");
        if (delayMs > 0)
            command = "sleep " + (delayMs / 1000).toFixed(3) + "; exec " + command;
        let separator = "=";
        while (command.includes("]" + separator + "]")) separator += "=";
        return "hl.dsp.exec_cmd([" + separator + "[" + command + "]" + separator + "])";
    }

    function start(argv, delayMs = 0): void {
        // El compositor crea un token nuevo antes de cualquier espera o arranque lento.
        if (argv[0] === "uwsm" && argv[1] === "app" && !argv.includes("-t"))
            argv = argv.slice(0, 2).concat(["-t", "scope"], argv.slice(2));
        Hyprland.dispatch(dispatchCommand(argv, delayMs));
    }
}
