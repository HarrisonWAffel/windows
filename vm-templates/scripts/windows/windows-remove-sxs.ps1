# Remove outdated components from the Windows Side-by-Side (SxS) store to reduce disk space usage.
DISM.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase