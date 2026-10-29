# ==============================================================================
# DOECISORY - APP MAIN (STANDALONE RUNNER & CLOUD ENTRY POINT)
# ==============================================================================
# Description: Entry point for standalone executions, Docker containers,
#              and cloud environments (Hugging Face Spaces).
# ==============================================================================

using DoECISORY

DoECISORY.launch(; wait=true)