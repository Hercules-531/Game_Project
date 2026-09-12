# Pinned development tooling

- Godot 4.7.2 stable, matching Windows x86_64 export templates.
- GUT v9.7.1: https://github.com/bitwes/Gut/tree/v9.7.1
  Commit aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605.
- Phantom Camera v0.11.0.3:
  https://github.com/ramokz/phantom-camera/tree/v0.11.0.3
  Commit cb6e0966ac305202c47f1d1a81c105966e29da96.
- Existing Godot AI bridge v4.1.0 is preserved. Its export plugin strips the
  runtime MCP helper from exported games; export verification must check this.

Run from PowerShell:

```powershell
./tools/verify.ps1 -Godot 'C:/Users/shiva/Desktop/Godot_v4.7.2-stable_win64.exe' -Export
```

This imports, runs all GUT tests, exports Windows and launches the exported game
headlessly with --verify-export. That probe checks advancing process/physics,
the camera runtime dependency, and the absence of the development bridge, then
exits with an explicit verified marker. Graphical verification uses the live Godot AI bridge
as a separate acceptance check. The workflow runs these same commands on push.
Hosted CI results cannot be claimed until the user pushes the repository.

Source addon licenses are retained under their respective addon directories.
