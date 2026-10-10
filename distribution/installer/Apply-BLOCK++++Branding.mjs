import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";

const root = path.resolve(process.argv[2] ?? ".");

const replacements = [
    {
        file: "src/plugins/_core/settings.tsx",
        from: 'description: "Where to put the Vencord settings section",',
        to: 'description: "Where to put the BLOCK++++ settings section",'
    },
    {
        file: "src/plugins/_core/settings.tsx",
        from: 'description: "Also copy Vencord info (Vencord, Electron, Chromium) when clicking the version info in the bottom left area of the Settings page",',
        to: 'description: "Also copy BLOCK++++, Electron, and Chromium info when clicking the version info in the bottom left area of the Settings page",'
    },
    {
        file: "src/plugins/_core/settings.tsx",
        from: 'title: "Vencord",',
        to: 'title: "BLOCK++++",'
    },
    {
        file: "src/plugins/_core/settings.tsx",
        from: 'panelTitle: "Vencord Settings",',
        to: 'panelTitle: "BLOCK++++ Settings",'
    },
    {
        file: "src/plugins/_core/settings.tsx",
        from: 'panelTitle: "Vencord Updater",',
        to: 'panelTitle: "BLOCK++++ Updater",'
    },
    {
        file: "src/plugins/_core/settings.tsx",
        from: 'panelTitle: "Vencord Cloud",',
        to: 'panelTitle: "BLOCK++++ Cloud",'
    },
    {
        file: "src/plugins/_core/settings.tsx",
        from: 'useTitle: () => "Vencord Settings",',
        to: 'useTitle: () => "BLOCK++++ Settings",'
    },
    {
        file: "src/plugins/_core/settings.tsx",
        from: 'const rows = [`Vencord ${gitHash}${additionalInfo}`];',
        to: 'const rows = [`BLOCK++++ ${gitHash}${additionalInfo}`];'
    },
    {
        file: "src/components/settings/tabs/vencord/index.tsx",
        from: 'wrapTab(VencordSettings, "Vencord Settings")',
        to: 'wrapTab(VencordSettings, "BLOCK++++ Settings")'
    },
    {
        file: "src/utils/types.ts",
        from: "export interface PluginDef {\n    name: string;",
        to: "export interface PluginDef {\n    name: string;\n    displayName?: string;"
    },
    {
        file: "src/components/settings/tabs/plugins/PluginCard.tsx",
        from: "name={plugin.name}",
        to: "name={plugin.displayName ?? plugin.name}"
    },
    {
        file: "src/components/settings/tabs/plugins/PluginModal.tsx",
        from: '<BaseText tag="h1" weight="semibold" size="lg">{plugin.name}</BaseText>',
        to: '<BaseText tag="h1" weight="semibold" size="lg">{plugin.displayName ?? plugin.name}</BaseText>'
    },
    {
        file: "src/components/settings/tabs/plugins/index.tsx",
        from: "            plugin.name.toLowerCase().includes(search) ||",
        to: "            plugin.name.toLowerCase().includes(search) ||\n            plugin.displayName?.toLowerCase().includes(search) ||"
    }
];

for (const { file, from, to } of replacements) {
    const fullPath = path.join(root, file);
    const source = await readFile(fullPath, "utf8");
    const firstIndex = source.indexOf(from);
    if (firstIndex === -1 || source.indexOf(from, firstIndex + from.length) !== -1)
        throw new Error(`Expected exactly one branding patch target in ${file}`);

    await writeFile(fullPath, source.slice(0, firstIndex) + to + source.slice(firstIndex + from.length));
}

console.log(`Applied ${replacements.length} BLOCK++++ branding changes to ${root}`);
