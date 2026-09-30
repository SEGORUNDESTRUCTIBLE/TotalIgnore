# TotalIgnore

Created and published by **Dr. Avinash Mandre**.

Add Discord user IDs in the plugin settings, or use **Ignore user** from a
user's context menu. The plugin filters new messages from configured users,
filters matching users from voice-channel member and video-call tile
components, including screen-share video owned by an ignored user, and locally
mutes them when they join a voice channel or call.
Their local mute state is kept while they are ignored, including across voice
reconnects, and is restored to its previous value when they are unignored.
Ignored call and screen-share tiles are removed from the layout so remaining
participants reflow without empty slots. With five or more visible tiles, the
grid uses three columns in fullscreen/wide layouts and two columns in
normal/narrow windows; smaller groups use two columns. Row count follows the
visible tiles, and incomplete final rows are centered. Existing tile spacing
is retained. Voice-member rows are hidden at their outer draggable wrapper so
the sidebar list collapses the row instead of reserving an empty slot.

This is best-effort client-side filtering, not true invisibility. Discord still
delivers voice and presence information to the client. Existing messages,
notifications, and UI surfaces whose markup differs may still reveal an
ignored user.
