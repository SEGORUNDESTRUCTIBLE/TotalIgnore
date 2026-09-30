# TotalIgnore

Created and published by **Dr. Avinash Mandre**.

Add Discord user IDs in the plugin settings, or use **Ignore user** from a
user's context menu. The plugin filters new messages from configured users,
filters matching users from voice-channel member and video-call tile
components, including screen-share video owned by an ignored user, and locally
mutes them when they join a voice channel or call.
Their local mute state is kept while they are ignored, including across voice
reconnects, and is restored to its previous value when they are unignored.
Ignored call and screen-share tiles are hidden without overriding Discord's
call-grid layout. Discord arranges the remaining visible tiles using its own
responsive layout and spacing. Voice-member rows are hidden at their outer
draggable wrapper so the sidebar list collapses the row instead of reserving
an empty slot.

This is best-effort client-side filtering, not true invisibility. Discord still
delivers voice and presence information to the client. Existing messages,
notifications, and UI surfaces whose markup differs may still reveal an
ignored user.
