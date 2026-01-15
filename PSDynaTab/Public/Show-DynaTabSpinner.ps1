function Show-DynaTabSpinner {
    <#
    .SYNOPSIS
        Displays an animated loading spinner on the DynaTab 75X display
    .DESCRIPTION
        Shows a rotating spinner animation (- \ | /) at the leftmost character position
        with custom text for a specified duration. Optionally displays completion text
        when the animation finishes.
    .PARAMETER Text
        Text to display next to the spinner (max 9 characters)
    .PARAMETER Seconds
        Duration to run the spinner animation in seconds
    .PARAMETER CompletionText
        Optional text to display when spinner completes (max 10 characters)
    .PARAMETER FrameDelayMs
        Milliseconds between spinner frame updates (default: 250ms)
    .EXAMPLE
        Show-DynaTabSpinner -Text "LOADING" -Seconds 5
        Displays "- LOADING" with rotating spinner for 5 seconds
    .EXAMPLE
        Show-DynaTabSpinner -Text "WAIT" -Seconds 3 -CompletionText "READY"
        Shows spinner for 3 seconds, then displays "READY"
    .EXAMPLE
        Show-DynaTabSpinner -Text "BUSY" -Seconds 10 -FrameDelayMs 200
        Shows spinner with faster animation (200ms frames)
    .NOTES
        Requires active connection (use Connect-DynaTab first)
        Spinner character takes 1 character space, leaving 9 for text
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position=0)]
        [ValidateLength(1, 9)]
        [string]$Text,

        [Parameter(Mandatory, Position=1)]
        [ValidateRange(1, 3600)]
        [int]$Seconds,

        [Parameter()]
        [ValidateLength(1, 10)]
        [string]$CompletionText,

        [Parameter()]
        [ValidateRange(100, 1000)]
        [int]$FrameDelayMs = 250
    )

    if ($PSCmdlet.ShouldProcess("DynaTab display", "Show spinner animation")) {
        try {
            # Verify connection
            if (-not $script:DeviceConnected) {
                throw "Not connected to DynaTab. Use Connect-DynaTab first."
            }

            # Spinner animation frames
            $spinnerFrames = @('-', '\', '|', '/')

            # Calculate total frames to display
            $totalFrames = [Math]::Ceiling($Seconds * 1000 / $FrameDelayMs)

            Write-Verbose "Starting spinner animation: '$Text' for $Seconds seconds ($totalFrames frames)"

            # Animate spinner
            for ($frameIndex = 0; $frameIndex -lt $totalFrames; $frameIndex++) {
                # Select current spinner character (cycle through frames)
                $spinnerChar = $spinnerFrames[$frameIndex % $spinnerFrames.Count]

                # Combine spinner + text
                $displayText = "$spinnerChar $Text"

                # Display current frame
                Set-DynaTabText -Text $displayText -Alignment Left

                # Wait before next frame
                Start-Sleep -Milliseconds $FrameDelayMs
            }

            Write-Verbose "Spinner animation completed"

            # Display completion text if specified
            if ($CompletionText) {
                Write-Verbose "Displaying completion text: '$CompletionText'"
                Set-DynaTabText -Text $CompletionText -Alignment Center
            }

        } catch {
            throw "Failed to show spinner: $($_.Exception.Message)"
        }
    }
}
