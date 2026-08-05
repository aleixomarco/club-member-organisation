import fs from "fs";

const file = "app/page.tsx";
let content = fs.readFileSync(file, "utf8");
let lines = content.split("\n");

const startIdx = lines.findIndex((l) => l.includes("function ChatView({ user, channels, setChannels, activeId, setActiveId })"));
if (startIdx === -1) { console.error("FEHLER: ChatView-Anker nicht gefunden."); process.exit(1); }
let sendEndIdx = -1;
for (let i = startIdx; i < startIdx + 15; i++) {
  if (lines[i] && lines[i].includes('setText("");')) { sendEndIdx = i; break; }
}
if (sendEndIdx === -1) { console.error("FEHLER: setText(\"\"); Zeile nicht gefunden."); process.exit(1); }
console.log(`ChatView-Funktionskopf: Zeile ${startIdx + 1}, send()-Ende bei Zeile ${sendEndIdx + 1}`);

lines[startIdx] = lines[startIdx].replace(
  "function ChatView({ user, channels, setChannels, activeId, setActiveId }) {",
  "function ChatView({ user, channels, setChannels, activeId, setActiveId, members }) {"
);

const notifyBlock = [
  '    if (supabase && Array.isArray(members)) {',
  '      const recipients = members',
  '        .filter((m) => m.id !== user.id && (isAdmin(m) || ((!active.team || active.team === m.team) && (!active.visibleRoles || active.visibleRoles.some((r) => m.roles.includes(r))))))',
  '        .map((m) => m.id)',
  '        .filter((id) => /^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(String(id)));',
  '      if (recipients.length > 0) {',
  '        supabase.rpc("notify_many", { target_memberships: recipients, p_notif_type: "chat", p_title: `Neue Nachricht · ${active.name || "Chat"}`, p_body: `${user.name}: ${text.trim()}` });',
  '      }',
  '    }',
];

lines.splice(sendEndIdx, 0, ...notifyBlock);
content = lines.join("\n");
fs.writeFileSync(file, content, "utf8");
console.log("ChatView erfolgreich gepatcht.");
