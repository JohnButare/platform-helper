
# Use colors, but only if connected to a terminal, and that terminal
# supports them.
if [ -t 1 ]; then
  RB_RED=$(printf '\033[38;5;196m')
  RB_ORANGE=$(printf '\033[38;5;202m')
  RB_YELLOW=$(printf '\033[38;5;226m')
  RB_GREEN=$(printf '\033[38;5;082m')
  RB_BLUE=$(printf '\033[38;5;021m')
  RB_INDIGO=$(printf '\033[38;5;093m')
  RB_VIOLET=$(printf '\033[38;5;163m')

  BOLD=$(printf '\033[1m')
  RESET=$(printf '\033[00m')
  PAD=$(printf '\033[25m') # use not blinking as a pad
  
  BLUE=$(printf '\033[34m')
  GREEN=$(printf '\033[32m')
  GREY=$(printf '\033[90m')
  RED=$(printf '\033[31m')
  WHITE=$(printf '\033[97m')
  YELLOW=$(printf '\033[33m')

  LGREY=$(printf '\033[90m')

else
  RB_RED=""
  RB_ORANGE=""
  RB_YELLOW=""
  RB_GREEN=""
  RB_BLUE=""
  RB_INDIGO=""
  RB_VIOLET=""

  BOLD=""
  RESET=

  BLUE=""
  GREEN=""
  GREY=""
  RED=""
  WHITE=""
  YELLOW=""

  LGREY=""
fi
