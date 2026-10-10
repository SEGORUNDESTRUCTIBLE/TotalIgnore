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
import { definePluginSettings, migratePluginSetting, migratePluginSettings } from "@api/Settings";
import definePlugin, { OptionType } from "@utils/types";
import type { Message, User } from "@vencord/discord-types";
import { findByPropsLazy } from "@webpack";
import { CallStore, ChannelRTCStore, ChannelStore, Forms, GuildMemberStore, MediaEngineStore, Menu, UserStore, VoiceStateStore } from "@webpack/common";
import creatorAvatar from "file://./avatar.png?base64";

migratePluginSettings("BLOCK++", "TotalIgnore", "BLOCK++++");
migratePluginSetting("BLOCK++", "userIds", "blockedUserIds");
migratePluginSetting("BLOCK++", "muteVoice", "blockVoice");
migratePluginSetting("BLOCK++", "muteStateSnapshot", "blockMuteStateSnapshot");

const VoiceActions = findByPropsLazy("toggleLocalMute");

const settings = definePluginSettings({
    blockedUserIds: {
        description: "User IDs to block, separated by commas, spaces, or new lines",
        type: OptionType.STRING,
        default: "",
        multiline: true,
        placeholder: "123456789012345678",
        onChange() {
            notifyParticipantStores();
            syncBlockedVoiceMutes();
        }
    },
    blockVoice: {
        description: "Locally mute blocked users while they are in voice",
        type: OptionType.BOOLEAN,
        default: true,
        onChange: syncBlockedVoiceMutes
    },
    blockMuteStateSnapshot: {
        description: "Saved local mute states for blocked users",
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
    for (const entry of settings.store.blockMuteStateSnapshot.split(",")) {
        const match = /^(\d{17,20}):([01])$/.exec(entry);
        if (match) snapshots.set(match[1], match[2] === "1");
    }
    return snapshots;
}

function saveMuteStateSnapshots(snapshots: Map<string, boolean>) {
    settings.store.blockMuteStateSnapshot = Array.from(snapshots, ([userId, muted]) => `${userId}:${Number(muted)}`).join(",");
}

function getBlockedUserIds() {
    return new Set(
        settings.store.blockedUserIds
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

function getBlockedCallTileIds(blockedUserIds: string[]) {
    const blockedIds = new Set(blockedUserIds);
    const channelIds = new Set<string>();

    for (const userId of blockedUserIds) {
        const channelId = VoiceStateStore.getVoiceStateForUser(userId)?.channelId;
        if (channelId) channelIds.add(channelId);
    }

    for (const call of CallStore.getCalls())
        channelIds.add(call.channelId);

    const tileIds = new Set(blockedUserIds);
    for (const channelId of channelIds) {
        for (const participant of ChannelRTCStore.getStreamParticipants(channelId)) {
            if (!blockedIds.has(participant.stream.ownerId)) continue;

            tileIds.add(participant.id);
            if (participant.streamId) tileIds.add(participant.streamId);
        }
    }

    return Array.from(tileIds);
}

function updateBlockStyles() {
    if (!styleElement) return;

    const blockedUserIds = Array.from(getBlockedUserIds());
    const blockedCallTileIds = getBlockedCallTileIds(blockedUserIds);
    const selectors = [
        ...blockedCallTileIds.flatMap(tileId => [
            getCallTileSelector(tileId),
            `[class*="wrapper__"]:has(${getCallTileSelector(tileId)})`,
            `[class*="tile_d6271c"]:has(${getCallTileSelector(tileId)})`
        ]),
        ...blockedUserIds.flatMap(userId => {
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

    styleElement.textContent = selectors.length
        ? `${selectors.join(",\n")} { display: none !important; }`
        : "";
}

function notifyParticipantStores() {
    updateBlockStyles();
    ChannelRTCStore.emitChange();
    VoiceStateStore.emitChange();
}

function syncBlockedVoiceMutes() {
    if (!settings.store.blockVoice) {
        restoreBlockedUsers();
        return;
    }

    const blockedUsers = getBlockedUserIds();
    const snapshots = getMuteStateSnapshots();

    for (const [userId, wasMuted] of mutedUsers) {
        if (!blockedUsers.has(userId)) {
            setLocalMute(userId, wasMuted);
            mutedUsers.delete(userId);
            snapshots.delete(userId);
        }
    }

    for (const [userId, wasMuted] of snapshots) {
        if (blockedUsers.has(userId)) continue;

        setLocalMute(userId, wasMuted);
        snapshots.delete(userId);
    }

    for (const userId of blockedUsers) {
        if (!mutedUsers.has(userId)) {
            const wasMuted = snapshots.get(userId) ?? MediaEngineStore.isLocalMute(userId);
            mutedUsers.set(userId, wasMuted);
            snapshots.set(userId, wasMuted);
        }

        setLocalMute(userId, true);
    }

    saveMuteStateSnapshots(snapshots);
}

function restoreBlockedUsers() {
    for (const [userId, wasMuted] of mutedUsers) {
        setLocalMute(userId, wasMuted);
    }
    mutedUsers.clear();
    settings.store.blockMuteStateSnapshot = "";
}

function toggleBlockedUser(userId: string) {
    const blockedUsers = getBlockedUserIds();
    if (blockedUsers.has(userId)) blockedUsers.delete(userId);
    else blockedUsers.add(userId);

    settings.store.blockedUserIds = Array.from(blockedUsers).join(", ");
    notifyParticipantStores();
    syncBlockedVoiceMutes();
}

const userContextMenuPatch: NavContextMenuPatchCallback = (children, { user }: { user: User; }) => {
    if (!user || user.id === UserStore.getCurrentUser()?.id) return;

    const isBlocked = getBlockedUserIds().has(user.id);
    children.push(
        <Menu.MenuItem
            id="vc-block-plus-plus-toggle"
            label={isBlocked ? "Unblock user" : "Block user"}
            action={() => toggleBlockedUser(user.id)}
        />
    );
};

export default definePlugin({
    name: "BLOCK++",
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
                <Forms.FormText>BLOCK++ is an independent community plugin for Vencord.</Forms.FormText>
            </div>
        </div>
    ),

    patches: [
        {
            find: '"MessageStore"',
            replacement: {
                match: /(?<=MESSAGE_CREATE:function\((\i)\){)/,
                replace: (_, props) => `if($self.shouldBlockMessage(${props}.message))return;`
            }
        },
        {
            find: '"ReadStateStore"',
            replacement: {
                match: /(?<=MESSAGE_CREATE:function\((\i)\){)/,
                replace: (_, props) => `if($self.shouldBlockMessage(${props}.message))return;`
            }
        },
    ],

    contextMenus: {
        "user-context": userContextMenuPatch
    },

    flux: {
        VOICE_STATE_UPDATES() {
            updateBlockStyles();
            syncBlockedVoiceMutes();
        },
        GUILD_MEMBER_UPDATE() {
            updateBlockStyles();
        },
        GUILD_MEMBER_LIST_UPDATE() {
            updateBlockStyles();
        },
        CALL_CREATE() {
            updateBlockStyles();
            syncBlockedVoiceMutes();
        },
        CALL_UPDATE() {
            updateBlockStyles();
            syncBlockedVoiceMutes();
        },
        CALL_DELETE() {
            updateBlockStyles();
            syncBlockedVoiceMutes();
        },
        RTC_CONNECTION_ROSTER_MAP_UPDATE() {
            updateBlockStyles();
            syncBlockedVoiceMutes();
        },
        RTC_CONNECTION_STATE() {
            updateBlockStyles();
            syncBlockedVoiceMutes();
        },
        STREAM_CREATE() {
            updateBlockStyles();
        },
        STREAM_UPDATE() {
            updateBlockStyles();
        },
        STREAM_DELETE() {
            updateBlockStyles();
        },
        STREAM_START() {
            updateBlockStyles();
        },
        STREAM_STOP() {
            updateBlockStyles();
        },
        STREAMING_UPDATE() {
            updateBlockStyles();
        },
        STREAM_SERVER_UPDATE() {
            updateBlockStyles();
        },
        STREAM_LAYOUT_UPDATE() {
            updateBlockStyles();
        },
        STREAM_UPDATE_SELF_HIDDEN() {
            updateBlockStyles();
        },
        STREAM_SET_PAUSED() {
            updateBlockStyles();
        },
        RTC_CONNECTION_CLIENT_CONNECT() {
            syncBlockedVoiceMutes();
        }
    },

    start() {
        styleElement = document.createElement("style");
        document.head.appendChild(styleElement);
        updateBlockStyles();
        syncBlockedVoiceMutes();
    },

    stop() {
        styleElement?.remove();
        styleElement = undefined;
        restoreBlockedUsers();
    },

    shouldBlockMessage(message: Message | undefined) {
        return message?.author?.id != null && getBlockedUserIds().has(message.author.id);
    },

    shouldBlockUser(userId: string | undefined) {
        return userId != null && getBlockedUserIds().has(userId);
    }
});
