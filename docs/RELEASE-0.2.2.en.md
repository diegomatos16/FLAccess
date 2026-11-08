# FLAccess 0.2.2

Match sounds follow the controlled player's position and use the pitch axes.
In Player and vertical views, the opponent's goal is ahead. In sideline views,
left and right follow the camera's side of the pitch.
In Player view, the ball radar uses the camera's orientation to align with
the game's ball sounds. The radar is centered during personal possession.

Offline audio tests verified the orientation. Alignment with stick movement
still needs to be checked in a live match.

The Player radar panel offers distance and player-count modes with a shared
radius. Open teammates, marked teammates and opponents each have a count
limit, volume, toggle and a fixed sound with preview. The radar starts off.
When enabled, it plays while your team has possession.

Each effect has a toggle, volume from 0 to 300%, and speed from 25 to 200%
with pitch preserved in both the preview and the match.
Home and End change categories, Page Up and Page Down change options, Hyphen
and Equals adjust values, and 0 confirms. F4 previews the sound and F5 resets
the option. F1 reads the active panel's instructions. Automatic help defaults
to speaking only when switching modules.

When you have the ball, the pressure cue signals a nearby opponent. The
default radius is 3 meters and can be adjusted. Yellow and red cards are
announced during play and in player details. Game Plan announces transitions
between starters, substitutes, and unselected players. The shirt number
screen reads the number followed by the player's name.

The shared tournament reader announces group changes and the upcoming
fixture. Both teams' possession percentages are available through manual
review on the halftime and full-time statistics screens.

This is build 98 for Football Life 27 on Windows. Offline tests cover menu
reading, sound effects, and orientation. Libertadores announcements and the
decorative OK suppression in Skill Training still need in-game testing.
