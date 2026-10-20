$lines = Get-Content lib/screens/home_screen.dart
$newLines = @()
$skip = $false
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '// ── build ──') {
        $newLines += '  // ── build ──'
        $newLines += '  @override'
        $newLines += '  Widget build(BuildContext context) {'
        $newLines += '    // Subtle pattern color - uses accent with very low opacity'
        $newLines += '    final patternColor = _C.accent.withAlpha(15); // ~6% opacity'
        $newLines += ''
        $newLines += '    return Scaffold('
        $newLines += '      key: _scaffoldKey,'
        $newLines += '      backgroundColor: _C.bg,'
        $skip = $true
        continue
    }
    if ($skip -and $lines[$i] -match 'return Scaffold\(') {
        $skip = $false
        continue
    }
    if ($skip -and ($lines[$i] -match 'key: _scaffoldKey' -or $lines[$i] -match 'backgroundColor: _C\.bg')) {
        continue
    }
    if ($skip) {
        continue
    }
    $newLines += $lines[$i]
}
Set-Content lib/screens/home_screen.dart -Value $newLines