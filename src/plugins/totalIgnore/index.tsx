/*
 * Vencord, a modification for Discord's desktop app
 * Copyright (c) 2026 Vencord contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

import { NavContextMenuPatchCallback } from "@api/ContextMenu";
import { definePluginSettings } from "@api/Settings";
import definePlugin, { OptionType } from "@utils/types";
import type { Message, User } from "@vencord/discord-types";
import { findByPropsLazy } from "@webpack";
import { CallStore, ChannelRTCStore, ChannelStore, Forms, GuildMemberStore, MediaEngineStore, Menu, UserStore, VoiceStateStore } from "@webpack/common";
import creatorAvatar from "file://./avatar.png?base64";

const VoiceActions = findByPropsLazy("toggleLocalMute");

const settings = definePluginSettings({
    userIds: {
        description: "User IDs to ignore, separated by commas, spaces, or new lines",
        type: OptionType.STRING,
        default: "",
        multiline: true,
        placeholder: "123456789012345678",
        onChange() {
            notifyParticipantStores();
            syncIgnoredVoiceMutes();
        }
    },
    muteVoice: {
        description: "Locally mute ignored users while they are in voice",
        type: OptionType.BOOLEAN,
        default: true,
        onChange: syncIgnoredVoiceMutes
    },
    muteStateSnapshot: {
        description: "Saved local mute states for ignored users",
        type: OptionType.STRING,
        default: "",
        hidden: true
    }
});

let styleElement: HTMLStyleElement | undefined;
const mutedUsers = new Map<string, boolean>();

function setLocalMute(userId: string, muted: boolean) {
    if (MediaEngineStore.isLocalMute(userId) !== muted)
        VoiceActions.toggleLocalMute(userId);
}

function getMuteStateSnapshots() {
    const snapshots = new Map<string, boolean>();
    for (const entry of settings.store.muteStateSnapshot.split(",")) {
        const match = /^(\d{17,20}):([01])$/.exec(entry);
        if (match) snapshots.set(match[1], match[2] === "1");
    }
    return snapshots;
}

function saveMuteStateSnapshots(snapshots: Map<string, boolean>) {
    settings.store.muteStateSnapshot = Array.from(snapshots, ([userId, muted]) => `${userId}:${Number(muted)}`).join(",");
}

function getIgnoredUserIds() {
    return new Set(
        settings.store.userIds
            .split(/[,\s]+/)
            .map(id => id.trim())
            .filter(id => /^\d{17,20}$/.test(id))
    );
}

function escapeCssString(value: string) {
    return value.replace(/[\0-\x1f\x7f"\\]/g, char => `\\${char.codePointAt(0)!.toString(16)} `);
}

function getCallTileSelector(tileId: string) {
    return `[data-selenium-video-tile="${escapeCssString(tileId)}"]`;
}

function getIgnoredCallTileIds(ignoredUserIds: string[]) {
    const ignoredIds = new Set(ignoredUserIds);
    const channelIds = new Set<string>();

    for (const userId of ignoredUserIds) {
        const channelId = VoiceStateStore.getVoiceStateForUser(userId)?.channelId;
        if (channelId) channelIds.add(channelId);
    }

    for (const call of CallStore.getCalls())
        channelIds.add(call.channelId);

    const tileIds = new Set(ignoredUserIds);
    for (const channelId of channelIds) {
        for (const participant of ChannelRTCStore.getStreamParticipants(channelId)) {
            if (!ignoredIds.has(participant.stream.ownerId)) continue;

            tileIds.add(participant.id);
            if (participant.streamId) tileIds.add(participant.streamId);
        }
    }

    return Array.from(tileIds);
}

function updateIgnoreStyles() {
    if (!styleElement) return;

    const ignoredUserIds = Array.from(getIgnoredUserIds());
    const ignoredCallTileIds = getIgnoredCallTileIds(ignoredUserIds);
    const callTileSelectors = ignoredCallTileIds.map(getCallTileSelector);
    const selectors = [
        ...ignoredCallTileIds.flatMap(tileId => [
            getCallTileSelector(tileId),
            `[class*="wrapper__"]:has(${getCallTileSelector(tileId)})`,
            `[class*="tile_d6271c"]:has(${getCallTileSelector(tileId)})`
        ]),
        ...ignoredUserIds.flatMap(userId => {
            const user = UserStore.getUser(userId);
            const voiceState = VoiceStateStore.getVoiceStateForUser(userId);
            const guildId = voiceState?.guildId ?? (voiceState?.channelId
                ? ChannelStore.getChannel(voiceState.channelId)?.guild_id
                : undefined);
            const nickname = guildId ? GuildMemberStore.getNick(guildId, userId) : null;
            const displayName = user && (nickname ?? user.globalName ?? user.username);
            const voiceNameSelectors = displayName ? [
                `[aria-label="${escapeCssString(displayName)}"]`,
                `[aria-label^="${escapeCssString(displayName)},"]`
            ] : [];

            return [
                ...voiceNameSelectors.map(selector => `[class*="draggable__"]:has(${selector})`),
                ...voiceNameSelectors.map(selector => `[class*="voiceUser__"]:has(${selector})`)
            ];
        })
    ];

    const callGridSelector = callTileSelectors.length
        ? `[class*="videoGrid"] [role="list"]:has(${callTileSelectors.join(", ")})`
        : "";
    const groupCallGridSelector = callTileSelectors.length
        ? `[class*="tiles__"]:has(${callTileSelectors.join(", ")})`
        : "";
    const callGridSelectors = [callGridSelector, groupCallGridSelector].filter(Boolean);
    const centeredLastTileRules = callGridSelectors.flatMap(selector =>
        Array.from(document.querySelectorAll(selector)).flatMap(grid => {
            const visibleTileIds = Array.from(grid.querySelectorAll<HTMLElement>("[data-selenium-video-tile]"))
                .map(tile => tile.getAttribute("data-selenium-video-tile"))
                .filter((tileId): tileId is string => !!tileId && !ignoredCallTileIds.includes(tileId));

            if (!visibleTileIds.length || visibleTileIds.length % 2 === 0) return [];

            const lastTileSelector = getCallTileSelector(visibleTileIds[visibleTileIds.length - 1]);
            return [`${selector} > [class*="row_d6271c"] > :has(${lastTileSelector}) { grid-column: 2 / span 2 !important; }`];
        })
    );
    const rules = [
        selectors.length ? `${selectors.join(",\n")} { display: none !important; }` : "",
        callGridSelector ? `${callGridSelector} { display: grid !important; width: 100% !important; grid-template-columns: repeat(4, minmax(0, 1fr)) !important; }` : "",
        callGridSelector ? `${callGridSelector} > [class*="row_d6271c"] { display: contents !important; }` : "",
        callGridSelector ? `${callGridSelector} > [class*="row_d6271c"] > * { grid-column: span 2 !important; }` : "",
        groupCallGridSelector ? `${groupCallGridSelector} { display: grid !important; width: 100% !important; grid-template-columns: repeat(4, minmax(0, 1fr)) !important; }` : "",
        groupCallGridSelector ? `${groupCallGridSelector} > [class*="row_d6271c"] { display: contents !important; }` : "",
        groupCallGridSelector ? `${groupCallGridSelector} > [class*="row_d6271c"] > * { grid-column: span 2 !important; }` : "",
        ...centeredLastTileRules
    ];

    styleElement.textContent = rules.filter(Boolean).join("\n");
}

function notifyParticipantStores() {
    updateIgnoreStyles();
    ChannelRTCStore.emitChange();
    VoiceStateStore.emitChange();
}

function syncIgnoredVoiceMutes() {
    if (!settings.store.muteVoice) {
        restoreMutedUsers();
        return;
    }

    const ignoredUsers = getIgnoredUserIds();
    const snapshots = getMuteStateSnapshots();

    for (const [userId, wasMuted] of mutedUsers) {
        if (!ignoredUsers.has(userId)) {
            setLocalMute(userId, wasMuted);
            mutedUsers.delete(userId);
            snapshots.delete(userId);
        }
    }

    for (const [userId, wasMuted] of snapshots) {
        if (ignoredUsers.has(userId)) continue;

        setLocalMute(userId, wasMuted);
        snapshots.delete(userId);
    }

    for (const userId of ignoredUsers) {
        if (!mutedUsers.has(userId)) {
            const wasMuted = snapshots.get(userId) ?? MediaEngineStore.isLocalMute(userId);
            mutedUsers.set(userId, wasMuted);
            snapshots.set(userId, wasMuted);
        }

        setLocalMute(userId, true);
    }

    saveMuteStateSnapshots(snapshots);
}

function restoreMutedUsers() {
    for (const [userId, wasMuted] of mutedUsers) {
        setLocalMute(userId, wasMuted);
    }
    mutedUsers.clear();
    settings.store.muteStateSnapshot = "";
}

function toggleIgnoredUser(userId: string) {
    const ignoredUsers = getIgnoredUserIds();
    if (ignoredUsers.has(userId)) ignoredUsers.delete(userId);
    else ignoredUsers.add(userId);

    settings.store.userIds = Array.from(ignoredUsers).join(", ");
    notifyParticipantStores();
    syncIgnoredVoiceMutes();
}

const userContextMenuPatch: NavContextMenuPatchCallback = (children, { user }: { user: User; }) => {
    if (!user || user.id === UserStore.getCurrentUser()?.id) return;

    const isIgnored = getIgnoredUserIds().has(user.id);
    children.push(
        <Menu.MenuItem
            id="vc-total-ignore-toggle"
            label={isIgnored ? "Stop ignoring user" : "Ignore user"}
            action={() => toggleIgnoredUser(user.id)}
        />
    );
};

export default definePlugin({
    name: "TotalIgnore",
    description: "Hides selected users from supported Discord UI surfaces and locally mutes them in voice. Created by Dr. Avinash Mandre.",
    tags: ["Privacy", "Voice", "Appearance"],
    authors: [{ name: "Dr. Avinash Mandre", id: 0n }],
    settings,
    settingsAboutComponent: () => (
        <div style={{ display: "flex", alignItems: "center", gap: 16 }}>
            <img
                src={`data:image/png;base64,${creatorAvatar}`}
                alt="Creator avatar for Dr. Avinash Mandre"
                width={88}
                height={88}
                style={{ borderRadius: "50%", objectFit: "cover" }}
            />
            <div>
                <Forms.FormTitle tag="h3">Created by Dr. Avinash Mandre</Forms.FormTitle>
                <Forms.FormText>TotalIgnore is an independent community plugin for Vencord.</Forms.FormText>
            </div>
        </div>
    ),

    patches: [
        {
            find: '"MessageStore"',
            replacement: {
                match: /(?<=MESSAGE_CREATE:function\((\i)\){)/,
                replace: (_, props) => `if($self.shouldIgnoreMessage(${props}.message))return;`
            }
        },
        {
            find: '"ReadStateStore"',
            replacement: {
                match: /(?<=MESSAGE_CREATE:function\((\i)\){)/,
                replace: (_, props) => `if($self.shouldIgnoreMessage(${props}.message))return;`
            }
        },
    ],

    contextMenus: {
        "user-context": userContextMenuPatch
    },

    flux: {
        VOICE_STATE_UPDATES() {
            updateIgnoreStyles();
            syncIgnoredVoiceMutes();
        },
        GUILD_MEMBER_UPDATE() {
            updateIgnoreStyles();
        },
        GUILD_MEMBER_LIST_UPDATE() {
            updateIgnoreStyles();
        },
        CALL_CREATE() {
            updateIgnoreStyles();
            syncIgnoredVoiceMutes();
        },
        CALL_UPDATE() {
            updateIgnoreStyles();
            syncIgnoredVoiceMutes();
        },
        CALL_DELETE() {
            updateIgnoreStyles();
            syncIgnoredVoiceMutes();
        },
        RTC_CONNECTION_ROSTER_MAP_UPDATE() {
            updateIgnoreStyles();
            syncIgnoredVoiceMutes();
        },
        RTC_CONNECTION_STATE() {
            updateIgnoreStyles();
            syncIgnoredVoiceMutes();
        },
        STREAM_CREATE() {
            updateIgnoreStyles();
        },
        STREAM_UPDATE() {
            updateIgnoreStyles();
        },
        STREAM_DELETE() {
            updateIgnoreStyles();
        },
        STREAM_START() {
            updateIgnoreStyles();
        },
        STREAM_STOP() {
            updateIgnoreStyles();
        },
        STREAMING_UPDATE() {
            updateIgnoreStyles();
        },
        STREAM_SERVER_UPDATE() {
            updateIgnoreStyles();
        },
        STREAM_LAYOUT_UPDATE() {
            updateIgnoreStyles();
        },
        STREAM_UPDATE_SELF_HIDDEN() {
            updateIgnoreStyles();
        },
        STREAM_SET_PAUSED() {
            updateIgnoreStyles();
        },
        RTC_CONNECTION_CLIENT_CONNECT() {
            syncIgnoredVoiceMutes();
        }
    },

    start() {
        styleElement = document.createElement("style");
        document.head.appendChild(styleElement);
        updateIgnoreStyles();
        syncIgnoredVoiceMutes();
    },

    stop() {
        styleElement?.remove();
        styleElement = undefined;
        restoreMutedUsers();
    },

    shouldIgnoreMessage(message: Message | undefined) {
        return message?.author?.id != null && getIgnoredUserIds().has(message.author.id);
    },

    shouldIgnoreUser(userId: string | undefined) {
        return userId != null && getIgnoredUserIds().has(userId);
    }
});
