# frozen_string_literal: true

module Buzzsprout
  class Animation
    # Default Buzzsprout wordmark as braille (logo mark + "Buzzsprout").
    # Derived from the Figma Default lockup; stored as source, not image files.
    WIDTH = 76
    HEIGHT = 9
    DELAY = 0.055
    BOLT_COLOR = '#61D752'
    MARK_COLOR = '#214538'

    WORDMARK = [
      '    ⢰⡇       ⣀⣀⣀⣀⡀                                                          ',
      '   ⢀⣿⡇       ⣿⣿⣿⣿⣿⣷⡀                                                    ⢠⣤⡄ ',
      '   ⣾⣿⣿⣿⣿⠃    ⣿⣿⠁⠈⣻⣿⡇⢀⣀⡀ ⢀⣀⣀⢀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⡀⢀⣠⣤⣤⣀⢀⣀⣀⢀⣤⣤⡀ ⢀⣀⣀⣀⣤ ⢀⣠⣤⣄⡀ ⢀⣀⣀  ⣀⣀⢠⣾⣿⣇⣀',
      '  ⣼⣿⣿⣿⣿⠇     ⣿⣿⣶⣶⣿⣿⠁⢸⣿⡇ ⢸⣿⣿⢸⣿⣿⣿⣿⠇⢿⣿⣿⣿⣿⢁⣾⣿⠿⢿⣿⢸⣿⣿⣿⣿⣿⣿⣆⢸⣿⣿⣿⣿⣰⣿⣿⣿⣿⣿⣆⢸⣿⣿  ⣿⣿⢸⣿⣿⣿⣿',
      '⣿⣿⣦⡀ ⣿⡏⣠⣾⣿⡇  ⣿⣿⠛⠛⢿⣿⣧⢸⣿⡇ ⢸⣿⣿  ⣼⣿⡏  ⢀⣾⣿⠃⠘⣿⣿⣶⣦⣌⢸⣿⣿⠁ ⠘⣿⣿⢸⣿⣿⠃⢀⣿⣿⠁ ⠘⣿⣿⢸⣿⣿  ⣿⣿ ⢸⣿⡇ ',
      '⢹⣿⣿⣿⣆⠿⣼⣿⣿⣿⠃  ⣿⣿  ⣸⣿⣿⢸⣿⣧ ⣸⣿⣿ ⣰⣿⡟   ⣼⣿⠏  ⣌⠙⠛⣿⣿⡎⣿⣿⣄ ⣠⣿⣿⢸⣿⣿  ⣿⣿⣄ ⣠⣿⣿⢸⣿⣿ ⣸⣿⣿ ⢸⣿⡇ ',
      ' ⠹⣿⣿⣿⣸⣿⣿⡿⠃   ⣿⣿⣿⣿⣿⣿⠏⠘⣿⣿⣿⣿⣿⣿⢰⣿⣿⣿⣿⣿⣸⣿⣿⣿⣿⡇⣿⣿⣿⣿⡿⢱⣿⣿⣿⣿⣿⣿⠋⢸⣿⣿  ⠙⣿⣿⣿⣿⡿⠃⠘⣿⣿⣿⣿⣿⣿ ⠸⣿⣿⣿',
      '  ⠈⠙⠛⠛⠛⠉     ⠉⠉⠉⠉⠉   ⠈⠉⠉ ⠉⠉⠈⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠁⠈⠉⠉⠉ ⢸⣿⣿⠈⠉⠉⠁ ⠈⠉⠉    ⠉⠉⠉   ⠈⠉⠉⠁⠉⠉  ⠈⠉⠉',
      '                                            ⢸⣿⣿                             '
    ].freeze

    KIND = [
      '....bb.......mmmmm..........................................................',
      '...bbb.......mmmmmmm....................................................mmm.',
      '...bbbbbb....mmmmmmmmmm.mmmmmmmmmmmmmmmmmmmmmmmmmmm.mmmmm.mmmmm.mmm..mmmmmmm',
      '..bbbbbb.....mmmmmmmmmm.mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm..mmmmmmm',
      'mmmm.bbmmmm..mmmmmmmmmm.mmm..mmm..mmmmmmmmmmmmmm.mmmmmmmmmmm.mmmmmm..mm.mmm.',
      'mmmmmbmmmmm..mm..mmmmmm.mmm.mmm...mmm..mmmmmmmmm.mmmmmm..mmm.mmmmmm.mmm.mmm.',
      '.mmmmmmmmm...mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm..mmmmmmmmmmmmmm.mmmm',
      '..mmmmmm.....mmmmm...mmm.mmmmmmmmmmmmmmmmmm.mmmmmmm.mmm....mmm...mmmmmm..mmm',
      '............................................mmm.............................'
    ].freeze

  end
end
