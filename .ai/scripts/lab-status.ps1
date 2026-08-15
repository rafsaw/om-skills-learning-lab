#Requires -Version 5.1
<#
.SYNOPSIS
    Reports whether om-skills-learning-lab is ready for the next learning session.

.DESCRIPTION
    Prints the repository's branch and working-tree state, the health of the
    .claude\skills discovery entries, and the latest recorded experiment and
    finding, then a READY / NOT READY verdict backed by the exit code.

    Strictly read-only: it never writes to the repository, never makes a network
    call, and never repairs anything it finds. Needs nothing beyond Windows
    PowerShell 5.1, and degrades rather than failing when git is absent.

.PARAMETER Help
    Print usage and exit 0.

.EXAMPLE
    .\.ai\scripts\lab-status.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .ai\scripts\lab-status.ps1
#>
[CmdletBinding()]
param(
    [switch] $Help
)

Set-StrictMode -Version Latest

# Never let a single failed read abort the report: every check that can fail is
# wrapped locally with -ErrorAction Stop inside a try, and everything else is
# expected to continue.
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# ---------------------------------------------------------------------------
# Layout constants. See the UI/UX section of the spec: a fixed label column with
# values left-aligned after it, detail lines indented into the value column, and
# plain ASCII only - no color, no box drawing, no emoji.
# ---------------------------------------------------------------------------
$script:BodyIndent = '  '
$script:LabelWidth = 18
$script:DetailWidth = 10
$script:TitleMaxLength = 60
$script:FindingWidth = 78

# ---------------------------------------------------------------------------
# Collected findings. No check exits early: a repository with three problems
# reports three problems in one run.
# ---------------------------------------------------------------------------
$script:Blockers = @()
$script:Warnings = @()
$script:DiscoveryFindings = 0

# The verdict travels in a script-scope variable rather than a return value:
# every report line is written to the success stream, so a function that also
# returned its exit code would hand back the whole report along with it.
$script:ExitCode = 0

function Add-Blocker {
    param(
        [Parameter(Mandatory = $true)][string] $Message,
        [switch] $Discovery
    )
    $script:Blockers += $Message
    if ($Discovery) { $script:DiscoveryFindings++ }
}

function Add-Warning {
    param(
        [Parameter(Mandatory = $true)][string] $Message,
        [switch] $Discovery
    )
    $script:Warnings += $Message
    if ($Discovery) { $script:DiscoveryFindings++ }
}

# ---------------------------------------------------------------------------
# Output helpers.
# ---------------------------------------------------------------------------

function Write-Blank {
    Write-Output ''
}

function Write-Section {
    param([Parameter(Mandatory = $true)][string] $Title)
    Write-Output $Title
}

function Write-Row {
    param(
        [Parameter(Mandatory = $true)][string] $Label,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string] $Value
    )
    Write-Output ($script:BodyIndent + $Label.PadRight($script:LabelWidth) + $Value)
}

# A detail line hangs under the row it belongs to, starting in the value column.
# The caller passes one width for the whole group so the values line up with each
# other; the default keeps the two-space gap after the common short kinds.
function Write-Detail {
    param(
        [Parameter(Mandatory = $true)][string] $Kind,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string] $Value,
        [int] $Width = 0
    )
    if ($Width -le 0) { $Width = $script:DetailWidth }
    $pad = ' ' * ($script:BodyIndent.Length + $script:LabelWidth)
    Write-Output ($pad + "${Kind}:".PadRight($Width) + $Value)
}

# The width a group of detail lines shares: the spec's two-space gap after the
# short kinds, widened only when a longer kind would otherwise collide.
function Get-DetailWidth {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]] $Kinds)
    $width = $script:DetailWidth
    foreach ($kind in $Kinds) {
        $needed = $kind.Length + 2
        if ($needed -gt $width) { $width = $needed }
    }
    return $width
}

# The Windows console default code page mangles non-ASCII, and this output ends
# up in log captures and agent transcripts, so text lifted out of repository
# documents is folded down to ASCII before it is printed.
function ConvertTo-AsciiText {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string] $Text)

    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $Text.ToCharArray()) {
        switch ([int]$ch) {
            0x2013 { [void]$sb.Append('-');  break }   # en dash
            0x2014 { [void]$sb.Append('-');  break }   # em dash
            0x2018 { [void]$sb.Append("'");  break }   # left single quote
            0x2019 { [void]$sb.Append("'");  break }   # right single quote
            0x201C { [void]$sb.Append('"');  break }   # left double quote
            0x201D { [void]$sb.Append('"');  break }   # right double quote
            0x2026 { [void]$sb.Append('...'); break }  # ellipsis
            0x00A0 { [void]$sb.Append(' ');  break }   # non-breaking space
            default {
                if ([int]$ch -ge 32 -and [int]$ch -le 126) {
                    [void]$sb.Append($ch)
                } else {
                    [void]$sb.Append('?')
                }
            }
        }
    }
    return $sb.ToString()
}

# Findings wrap with a hanging indent so a two-line message stays readable:
#
#   [blocker] om-root-cause resolves outside this repository, so dispatching it
#             executes a different checkout's copy of the skill.
function Write-Finding {
    param(
        [Parameter(Mandatory = $true)][string] $Severity,
        [Parameter(Mandatory = $true)][string] $Message
    )
    $prefix = "[$Severity] "
    $hang = ' ' * $prefix.Length
    $width = $script:FindingWidth
    $line = ''
    $first = $true

    foreach ($word in ($Message -split '\s+' | Where-Object { $_ -ne '' })) {
        if ($line -eq '') {
            $line = $word
        } elseif (($line.Length + 1 + $word.Length) -le $width) {
            $line = $line + ' ' + $word
        } else {
            if ($first) { Write-Output ($script:BodyIndent + $prefix + $line); $first = $false }
            else        { Write-Output ($script:BodyIndent + $hang + $line) }
            $line = $word
        }
    }
    if ($line -ne '') {
        if ($first) { Write-Output ($script:BodyIndent + $prefix + $line) }
        else        { Write-Output ($script:BodyIndent + $hang + $line) }
    }
}

function Format-Count {
    param(
        [Parameter(Mandatory = $true)][int] $Count,
        [Parameter(Mandatory = $true)][string] $Singular,
        [Parameter(Mandatory = $true)][string] $Plural
    )
    if ($Count -eq 1) { return "$Count $Singular" }
    return "$Count $Plural"
}

function Show-Usage {
    Write-Output 'lab-status.ps1 - is this repository ready for the next learning session?'
    Write-Output ''
    Write-Output 'Usage:'
    Write-Output '  .\.ai\scripts\lab-status.ps1 [-Help]'
    Write-Output '  powershell -NoProfile -ExecutionPolicy Bypass -File .ai\scripts\lab-status.ps1'
    Write-Output ''
    Write-Output 'Reports the branch and working-tree state, the health of the .claude\skills'
    Write-Output 'discovery entries, and the latest recorded experiment and finding. Read-only:'
    Write-Output 'it never writes to the repository, never uses the network, and never repairs'
    Write-Output 'what it finds.'
    Write-Output ''
    Write-Output 'Exit codes:'
    Write-Output '  0  READY - no blockers found. Warnings may still have been printed.'
    Write-Output '  1  NOT READY - at least one blocker was found.'
    Write-Output '  2  Wrong context - the script is not anchored inside this lab.'
}

# ---------------------------------------------------------------------------
# Sections.
# ---------------------------------------------------------------------------

# Run git against the anchored root rather than the caller's directory, and hand
# back success plus output instead of letting a non-zero exit escape as an error.
function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)][string] $RepoRoot,
        [Parameter(Mandatory = $true)][string[]] $GitArgs
    )

    $global:LASTEXITCODE = 0
    $output = & git '-C' $RepoRoot @GitArgs 2>$null
    return [pscustomobject]@{
        Ok    = ($global:LASTEXITCODE -eq 0)
        Lines = @($output | Where-Object { $null -ne $_ })
    }
}

function Show-RepositorySection {
    param([Parameter(Mandatory = $true)][string] $RepoRoot)

    Write-Section 'Repository'

    if (-not (Get-Command 'git' -CommandType Application -ErrorAction SilentlyContinue)) {
        Write-Row 'Branch' 'unavailable'
        Write-Row 'Working tree' 'unavailable'
        Add-Warning 'git is not on PATH, so the branch and working-tree state could not be read. Skill discovery is unaffected.'
        return
    }

    $inside = Invoke-Git -RepoRoot $RepoRoot -GitArgs @('rev-parse', '--is-inside-work-tree')
    if (-not $inside.Ok -or ($inside.Lines -join '') -ne 'true') {
        Write-Row 'Branch' 'unavailable'
        Write-Row 'Working tree' 'unavailable'
        Add-Warning 'The repository root is not a git work tree, so the branch and working-tree state could not be read. Skill discovery is unaffected.'
        return
    }

    # symbolic-ref answers on a branch, including an unborn one; it fails on a
    # detached HEAD, which is what the short-sha fallback is for.
    $branch = 'unknown'
    $symbolic = Invoke-Git -RepoRoot $RepoRoot -GitArgs @('symbolic-ref', '--quiet', '--short', 'HEAD')
    if ($symbolic.Ok -and $symbolic.Lines.Count -gt 0) {
        $branch = [string]$symbolic.Lines[0]
    } else {
        $head = Invoke-Git -RepoRoot $RepoRoot -GitArgs @('rev-parse', '--short', 'HEAD')
        if ($head.Ok -and $head.Lines.Count -gt 0) {
            $branch = '(detached at ' + [string]$head.Lines[0] + ')'
        }
    }
    Write-Row 'Branch' (ConvertTo-AsciiText $branch)

    $status = Invoke-Git -RepoRoot $RepoRoot -GitArgs @('status', '--porcelain')
    if (-not $status.Ok) {
        Write-Row 'Working tree' 'unavailable'
        Add-Warning 'git status failed, so the working-tree state could not be read. Skill discovery is unaffected.'
        return
    }

    $entries = @($status.Lines | Where-Object { $_.ToString().Trim() -ne '' })
    if ($entries.Count -eq 0) {
        Write-Row 'Working tree' 'clean'
    } else {
        Write-Row 'Working tree' ('dirty (' + (Format-Count $entries.Count 'entry' 'entries') + ')')
        Add-Warning ('Working tree is dirty (' + (Format-Count $entries.Count 'entry' 'entries') + '). A pull request opened from here may carry work nobody meant to ship.')
    }
}

# Strict mode turns a reference to an absent property into an error, and the
# properties this script reads are provider-supplied rather than guaranteed, so
# every one of them goes through here.
function Get-PropertyOrNull {
    param(
        [Parameter(Mandatory = $true)][AllowNull()] $InputObject,
        [Parameter(Mandatory = $true)][string] $Name
    )
    if ($null -eq $InputObject) { return $null }
    if ($InputObject.PSObject.Properties.Match($Name).Count -eq 0) { return $null }
    return $InputObject.PSObject.Properties[$Name].Value
}

# Drive-letter casing, a trailing separator, and '.'/'..' segments must not be
# able to produce a false 'foreign' verdict, so both sides of every comparison
# are normalized through here first.
function Get-NormalizedPath {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string] $Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    try {
        return [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    } catch {
        return $Path.TrimEnd('\', '/')
    }
}

# The entries in this checkout are NTFS junctions, not symbolic links: Git Bash
# on Windows without the privilege to create symlinks produces junctions, and
# every one of them here reports LinkType 'Junction'. Both types are accepted -
# demanding SymbolicLink would report a perfectly healthy lab as all blockers.
function Get-EntryLinkInfo {
    param(
        [Parameter(Mandatory = $true)] $Item,
        [Parameter(Mandatory = $true)][string] $ParentDir
    )

    $linkType = [string](Get-PropertyOrNull -InputObject $Item -Name 'LinkType')
    $isLink = ($linkType -eq 'Junction' -or $linkType -eq 'SymbolicLink')

    $target = ''
    if ($isLink) {
        $raw = Get-PropertyOrNull -InputObject $Item -Name 'Target'
        $first = @($raw) | Where-Object { $null -ne $_ -and [string]$_ -ne '' } | Select-Object -First 1
        if ($null -ne $first) {
            $targetText = [string]$first
            # A symbolic link may record a relative target; resolve it against
            # the directory the link itself lives in, never the caller's cwd.
            if (-not [System.IO.Path]::IsPathRooted($targetText)) {
                $targetText = Join-Path $ParentDir $targetText
            }
            $target = Get-NormalizedPath $targetText
        }
    }

    return [pscustomobject]@{
        IsLink   = $isLink
        LinkType = $linkType
        Target   = $target
    }
}

function Read-LockfileSkillNames {
    param([Parameter(Mandatory = $true)][string] $LockPath)

    try {
        if (-not (Test-Path -LiteralPath $LockPath -PathType Leaf)) { throw 'not found' }
        # -Encoding UTF8 explicitly: Windows PowerShell 5.1 otherwise decodes with
        # the host's ANSI code page, and the repository's files are UTF-8 without
        # a BOM, so the default is only correct on a host whose code page happens
        # to be 65001.
        $raw = Get-Content -LiteralPath $LockPath -Raw -Encoding UTF8 -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($raw)) { throw 'empty' }
        $json = ConvertFrom-Json -InputObject $raw -ErrorAction Stop
        $skills = Get-PropertyOrNull -InputObject $json -Name 'skills'
        if ($null -eq $skills) { throw 'no skills object' }
        return @($skills.PSObject.Properties | ForEach-Object { $_.Name })
    } catch {
        # The lockfile is never allowed to abort the report.
        return $null
    }
}

function Show-SkillsSection {
    param([Parameter(Mandatory = $true)][string] $RepoRoot)

    Write-Section 'Skills'

    $vendoredRoot  = Join-Path $RepoRoot '.agents\skills'
    $discoveryRoot = Join-Path $RepoRoot '.claude\skills'

    $vendored = @(Get-ChildItem -LiteralPath $vendoredRoot -Directory -Force -ErrorAction SilentlyContinue |
        Sort-Object Name)
    Write-Row 'Vendored' ('' + $vendored.Count + ' under .agents/skills/')

    # Enumerate the discovery directory once. A listing includes a link whose
    # target no longer exists, which a Test-Path probe on the entry would not.
    $entries = @{}
    if (Test-Path -LiteralPath $discoveryRoot -PathType Container) {
        foreach ($entry in @(Get-ChildItem -LiteralPath $discoveryRoot -Force -ErrorAction SilentlyContinue)) {
            $entries[$entry.Name] = $entry
        }
    }

    $matched  = @{}
    $details  = @()
    $okCount  = 0

    foreach ($skill in $vendored) {
        $name = $skill.Name
        $expected = Get-NormalizedPath (Join-Path $vendoredRoot $name)

        if (-not (Test-Path -LiteralPath (Join-Path $skill.FullName 'SKILL.md') -PathType Leaf)) {
            Add-Warning ".agents\skills\$name has no SKILL.md, so it is not a dispatchable skill even though it is counted as vendored."
        }

        if (-not $entries.ContainsKey($name)) {
            $details += [pscustomobject]@{ Kind = 'missing'; Value = $name }
            Add-Blocker -Discovery "$name has no .claude\skills entry and cannot be dispatched."
            continue
        }

        $item = $entries[$name]
        $matched[$item.Name] = $true
        $link = Get-EntryLinkInfo -Item $item -ParentDir $discoveryRoot

        if (-not $link.IsLink) {
            $details += [pscustomobject]@{ Kind = 'not-a-link'; Value = $name }
            Add-Blocker -Discovery "$name is a real directory rather than a link, so dispatching it executes a forked copy instead of this checkout's skill."
            continue
        }

        if ($link.Target -eq '' -or -not (Test-Path -LiteralPath $link.Target)) {
            $details += [pscustomobject]@{ Kind = 'broken'; Value = $name }
            Add-Blocker -Discovery "$name is a link whose target no longer exists, so dispatching it fails; the entry has to be deleted before it can be recreated."
            continue
        }

        if ($link.Target -ne $expected) {
            $details += [pscustomobject]@{ Kind = 'foreign'; Value = ($name + ' -> ' + $link.Target) }
            Add-Blocker -Discovery "$name resolves outside this repository, so dispatching it executes a different checkout's copy of the skill."
            continue
        }

        $okCount++
    }

    foreach ($entryName in @($entries.Keys | Sort-Object)) {
        if (-not $matched.ContainsKey($entryName)) {
            $details += [pscustomobject]@{ Kind = 'orphan'; Value = $entryName }
            Add-Warning -Discovery ".claude\skills\$entryName has no counterpart under .agents\skills\, so nothing in this repository dispatches it."
        }
    }

    Write-Row 'Discovery' ('' + $okCount + ' of ' + $vendored.Count + ' resolve into this repository')
    $detailWidth = Get-DetailWidth @($details | ForEach-Object { $_.Kind } | Select-Object -Unique)
    foreach ($kind in @('missing', 'not-a-link', 'broken', 'foreign', 'orphan')) {
        foreach ($detail in @($details | Where-Object { $_.Kind -eq $kind })) {
            Write-Detail -Kind $kind -Value (ConvertTo-AsciiText $detail.Value) -Width $detailWidth
        }
    }

    # Compare only the set of names. Recomputing the skills CLI's content hash
    # would report drift on every local edit, which a learning lab expects.
    $lockNames = Read-LockfileSkillNames -LockPath (Join-Path $RepoRoot 'skills-lock.json')
    if ($null -eq $lockNames) {
        Write-Row 'Lockfile' 'unreadable'
        Add-Warning 'skills-lock.json is missing or could not be parsed, so the installed set could not be compared against .agents\skills\.'
        return
    }

    $vendoredNames = @($vendored | ForEach-Object { $_.Name })
    $onlyInLock   = @($lockNames | Where-Object { $vendoredNames -notcontains $_ } | Sort-Object)
    $onlyVendored = @($vendoredNames | Where-Object { $lockNames -notcontains $_ } | Sort-Object)

    if ($onlyInLock.Count -eq 0 -and $onlyVendored.Count -eq 0) {
        Write-Row 'Lockfile' ('' + $lockNames.Count + ' entries, matching')
        return
    }

    Write-Row 'Lockfile' ('' + $lockNames.Count + ' entries, differs from .agents/skills/')
    $lockDetailWidth = Get-DetailWidth @('not vendored', 'not in lock')
    foreach ($name in $onlyInLock)   { Write-Detail -Kind 'not vendored' -Value $name -Width $lockDetailWidth }
    foreach ($name in $onlyVendored) { Write-Detail -Kind 'not in lock'  -Value $name -Width $lockDetailWidth }
    Add-Warning ('skills-lock.json and .agents\skills\ disagree on the installed set (' +
        (Format-Count $onlyInLock.Count 'entry' 'entries') + ' in the lockfile only, ' +
        (Format-Count $onlyVendored.Count 'entry' 'entries') +
        ' vendored only), so the next reproducible install would be wrong.')
}

# Scan a learning-log document for its highest-numbered entry heading.
#
# Fence-awareness is structural, not incidental: EXPERIMENTS.md carries an entry
# template inside a fenced block whose heading is '## Experiment NNN'. A
# digit-anchored pattern skips that one only because the placeholder is literally
# NNN - anyone filling it in with digits, or pasting a fenced sample of a real
# entry, would otherwise create a phantom 'latest' entry.
#
# Highest-numbered rather than last-in-file is also deliberate: it is stable
# under an out-of-order append, and both files number sequentially by convention.
function Get-LatestLogEntry {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][string] $Kind
    )

    $result = [pscustomobject]@{
        Found  = $false
        Reason = ''
        Number = ''
        Title  = ''
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $result.Reason = 'is missing'
        return $result
    }

    $lines = $null
    try {
        # -Encoding UTF8 is load-bearing, not decoration. Windows PowerShell 5.1
        # decodes with the host's ANSI code page when no encoding is given, and
        # these documents are UTF-8 without a BOM: on a cp1252 host the em dash
        # in a heading such as '## Finding 005 - ...' would arrive as three
        # mojibake characters, survive the separator trim below, and print as
        # '?' substitutions in front of the title.
        $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8 -ErrorAction Stop)
    } catch {
        $result.Reason = 'could not be read'
        return $result
    }

    $pattern = '^##\s+' + $Kind + '\s+(\d{3})\b(.*)$'
    $inFence = $false
    $bestNumber = -1
    $bestTitle = ''

    foreach ($line in $lines) {
        $text = [string]$line
        if ($text.TrimStart().StartsWith('```')) {
            $inFence = -not $inFence
            continue
        }
        if ($inFence) { continue }

        $match = [regex]::Match($text, $pattern)
        if (-not $match.Success) { continue }

        $number = [int]$match.Groups[1].Value
        if ($number -le $bestNumber) { continue }

        $bestNumber = $number
        # Heading suffixes are not uniform - an em dash, a hyphen, a colon, a
        # parenthesis, or nothing at all all occur - so the title is whatever
        # follows the number once the separators are trimmed off.
        $bestTitle = ($match.Groups[2].Value -replace '^[\s:\-\u2012\u2013\u2014]+', '').Trim()
    }

    if ($bestNumber -lt 0) {
        $result.Reason = "has no `"## $Kind NNN`" heading outside a code fence"
        return $result
    }

    $title = ConvertTo-AsciiText $bestTitle
    if ($title.Length -gt $script:TitleMaxLength) {
        $title = $title.Substring(0, $script:TitleMaxLength - 3) + '...'
    }

    $result.Found = $true
    $result.Number = '{0:d3}' -f $bestNumber
    $result.Title = $title
    return $result
}

function Show-LearningLogSection {
    param([Parameter(Mandatory = $true)][string] $RepoRoot)

    Write-Section 'Learning log'

    $documents = @(
        [pscustomobject]@{ Label = 'Latest experiment'; File = 'EXPERIMENTS.md'; Kind = 'Experiment'; Noun = 'experiment' },
        [pscustomobject]@{ Label = 'Latest finding';    File = 'FINDINGS.md';    Kind = 'Finding';    Noun = 'finding' }
    )

    foreach ($document in $documents) {
        $entry = Get-LatestLogEntry -Path (Join-Path $RepoRoot $document.File) -Kind $document.Kind
        if (-not $entry.Found) {
            Write-Row $document.Label 'none recorded'
            Add-Warning ($document.File + ' ' + $entry.Reason + ', so the latest recorded ' + $document.Noun + ' could not be reported. A lab with no log is unusual but not broken.')
            continue
        }

        $value = $entry.Number
        if ($entry.Title -ne '') { $value = $value + ' - ' + $entry.Title }
        Write-Row $document.Label $value
    }
}

function Show-Verdict {
    $blockerCount = @($script:Blockers).Count
    $warningCount = @($script:Warnings).Count

    Write-Blank

    if ($blockerCount -eq 0) {
        if ($warningCount -eq 0) {
            Write-Output 'READY - no blockers found.'
        } else {
            Write-Output ('READY - no blockers found, ' + (Format-Count $warningCount 'warning' 'warnings') + '.')
        }
    } else {
        $verdict = 'NOT READY - ' + (Format-Count $blockerCount 'blocker' 'blockers')
        if ($warningCount -gt 0) {
            $verdict = $verdict + ', ' + (Format-Count $warningCount 'warning' 'warnings')
        }
        Write-Output ($verdict + '.')
    }

    if (($blockerCount + $warningCount) -gt 0) {
        Write-Blank
        foreach ($message in $script:Blockers) { Write-Finding 'blocker' $message }
        foreach ($message in $script:Warnings) { Write-Finding 'warning' $message }
    }

    if ($script:DiscoveryFindings -gt 0) {
        Write-Blank
        Write-Output ($script:BodyIndent + 'Discovery entries are recreated by the snippet in README.md, "Start here".')
    }

    if ($blockerCount -gt 0) { $script:ExitCode = 1 } else { $script:ExitCode = 0 }
}

# ---------------------------------------------------------------------------
# Entry point.
# ---------------------------------------------------------------------------

function Invoke-Main {
    if ($Help) {
        Show-Usage
        $script:ExitCode = 0
        return
    }

    # The root is derived from the script's own location, never from the current
    # directory: running this by absolute path from inside an unrelated
    # repository must not produce a confident report about that repository.
    if ([string]::IsNullOrEmpty($PSScriptRoot)) {
        [Console]::Error.WriteLine('lab-status: cannot determine the script location, so the repository root cannot be anchored.')
        $script:ExitCode = 2
        return
    }
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

    $anchorSkills = Join-Path $repoRoot '.agents\skills'
    $anchorConfig = Join-Path $repoRoot '.ai\agentic.config.json'
    if (-not (Test-Path -LiteralPath $anchorSkills -PathType Container) -or
        -not (Test-Path -LiteralPath $anchorConfig -PathType Leaf)) {
        [Console]::Error.WriteLine("lab-status: '$repoRoot' is not om-skills-learning-lab.")
        [Console]::Error.WriteLine('lab-status: expected both .agents\skills\ and .ai\agentic.config.json two levels above this script.')
        $script:ExitCode = 2
        return
    }

    Write-Output 'om-skills-learning-lab - status'
    Write-Blank

    Show-RepositorySection -RepoRoot $repoRoot
    Write-Blank
    Show-SkillsSection -RepoRoot $repoRoot
    Write-Blank
    Show-LearningLogSection -RepoRoot $repoRoot

    Show-Verdict
}

Invoke-Main
exit $script:ExitCode
