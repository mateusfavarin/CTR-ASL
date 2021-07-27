state("mednafen")
{}

state("EmuHawk")
{}

state("ePSXe")
{}

init
{
    // Some emulators may need to call a specific module to find where they store the PSX RAM
    var module = modules.First();
    if (game.ProcessName == "EmuHawk") {
        module = modules.Where(m => m.ModuleName == "octoshock.dll").First();
    }

    // Finding where the string "proto8" is inside the RAM
    vars.scanTarget = new SigScanTarget(0, "70 72 6F 74 6F 38 00 00");
    var scanner = new SignatureScanner(game, module.BaseAddress, module.ModuleMemorySize);

    // Storing the game tracker pointer
    vars.gameTracker = scanner.Scan(vars.scanTarget) + 20;
    var gt = vars.gameTracker;

    // We need to figure out which version of the game the user is playing
    // in order to figure out what is the start of the PSX RAM
    vars.version = memory.ReadValue<uint>((IntPtr) gt);

    if (vars.version == 0x80096B20) // NTSC-U
    {
        vars.PSX_RAM = vars.gameTracker - 0x08D2AC;
    }
    else if (vars.version == 0x80096ED8) // PAL
    {
        vars.PSX_RAM = vars.gameTracker - 0x08D644;
    }
    else if (vars.version == 0x80099FD8) // NTSC-J
    {
        vars.PSX_RAM = vars.gameTracker - 0x0906B8;
    }

    // Figuring out the addresses of the game mode and the levID
    vars.gameMode_Addr = (memory.ReadValue<uint>((IntPtr) gt) & 0xFFFFFF) + (long) vars.PSX_RAM;
    vars.levID_Addr = vars.gameMode_Addr + 0x1A10;

    // Changing the refresh rate for more precision, no need to be more than 120FPS
    refreshRate = 120;

    // Storing the last race that you won
    vars.lastRace = -1;
}

update
{
    var gm = vars.gameMode_Addr;
    var lID = vars.levID_Addr;
    vars.gameMode = memory.ReadValue<uint>((IntPtr) gm);
    vars.levID = memory.ReadValue<uint>((IntPtr) lID);
}

start
{
    // if level_id == hub 1 and gameMode != loading
    if ((vars.levID == 0x1A) && ((vars.gameMode & 0x40000000) == 0))
    {
        return true;
    }

    return false;
}

reset
{
    // if level_id == main menu
    if (vars.levID == 0x27)
    {
        return true;
    }

    return false;
}

split
{
    // if gameMode == end of race and levID != lastRace and levID < 18 (adventure tracks)
    if (((vars.gameMode & 0x200000) > 0) && (vars.levID != vars.lastRace) && (vars.levID < 18))
    {
        // avoid multiple splits by setting curr level as the last level that you beat
        vars.lastRace = vars.levID;
        return true;
    }

    return false;
}

isLoading
{
    // if gameMode == loading
	if ((vars.gameMode & 0x40000000) > 0)
    {
        return true;
    }

    return false;
}