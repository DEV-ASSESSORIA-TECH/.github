import "isomorphic-fetch";
import fs from "node:fs";
import path from "node:path";
import { DeviceCodeCredential } from "@azure/identity";
import { Client } from "@microsoft/microsoft-graph-client";
import 'dotenv/config';

const TENANT_ID = process.env.TENANT_ID;
const CLIENT_ID = process.env.CLIENT_ID;

if (!TENANT_ID || !CLIENT_ID) {
    throw new Error("Configure TENANT_ID e CLIENT_ID no arquivo .env");
}

const OUTPUT_DIR = "data";
const CSV_FILE = path.join(OUTPUT_DIR, "contacts-preview.csv");

const MAX_MESSAGES_PER_FOLDER = 200;

const IGNORE_DOMAINS = [
    "assessoriatech.com"
];

const IGNORE_PREFIXES = [
    "no-reply",
    "noreply",
    "mailer-daemon",
    "postmaster",
    "bounce",
    "notification",
    "notifications"
];

const credential = new DeviceCodeCredential({
    tenantId: TENANT_ID,
    clientId: CLIENT_ID,
    userPromptCallback: (info) => {
        console.log(info.message);
    }
});

const graphClient = Client.initWithMiddleware({
    authProvider: {
        getAccessToken: async () => {
            const token = await credential.getToken([
                "User.Read",
                "Mail.Read",
                "Contacts.ReadWrite"
            ]);

            return token.token;
        }
    }
});

function normalizeEmail(email) {
    return email?.trim().toLowerCase() || null;
}

function isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function shouldIgnore(email) {
    const normalized = normalizeEmail(email);

    if (!normalized || !isValidEmail(normalized)) return true;

    const [localPart, domain] = normalized.split("@");

    if (IGNORE_DOMAINS.includes(domain)) return true;
    if (IGNORE_PREFIXES.some(prefix => localPart.startsWith(prefix))) return true;

    return false;
}

function addEmail(map, recipient, source) {
    const email = normalizeEmail(recipient?.emailAddress?.address);
    const name = recipient?.emailAddress?.name?.trim();

    if (shouldIgnore(email)) return;

    if (!map.has(email)) {
        map.set(email, {
            name: name || email,
            email,
            sources: new Set()
        });
    }

    map.get(email).sources.add(source);
}

function extractFromMessage(message, map, source) {
    addEmail(map, message.from, `${source}:from`);
    addEmail(map, message.sender, `${source}:sender`);

    for (const recipient of message.toRecipients || []) {
        addEmail(map, recipient, `${source}:to`);
    }

    for (const recipient of message.ccRecipients || []) {
        addEmail(map, recipient, `${source}:cc`);
    }

    for (const recipient of message.bccRecipients || []) {
        addEmail(map, recipient, `${source}:bcc`);
    }
}

async function readFolder(folderName, sourceLabel) {
    let request = graphClient
        .api(`/me/mailFolders/${folderName}/messages`)
        .select("id,subject,from,sender,toRecipients,ccRecipients,bccRecipients")
        .top(50);

    const messages = [];

    while (request && messages.length < MAX_MESSAGES_PER_FOLDER) {
        const result = await request.get();

        messages.push(...(result.value || []));

        if (!result["@odata.nextLink"]) break;

        request = graphClient.api(result["@odata.nextLink"]);
    }

    console.log(`${sourceLabel}: ${messages.length} mensagens lidas`);
    return messages;
}

function toCsvValue(value) {
    const text = String(value ?? "");
    return `"${text.replaceAll('"', '""')}"`;
}

async function main() {
    const contactsMap = new Map();

    const inboxMessages = await readFolder("Inbox", "Caixa de Entrada");
    const sentMessages = await readFolder("SentItems", "Itens Enviados");

    for (const message of inboxMessages) {
        extractFromMessage(message, contactsMap, "inbox");
    }

    for (const message of sentMessages) {
        extractFromMessage(message, contactsMap, "sent");
    }

    const contacts = [...contactsMap.values()].map(contact => ({
        name: contact.name,
        email: contact.email,
        sources: [...contact.sources].join("; ")
    }));

    contacts.sort((a, b) => a.email.localeCompare(b.email));

    const csvLines = [
        "name,email,sources",
        ...contacts.map(contact =>
            [
                toCsvValue(contact.name),
                toCsvValue(contact.email),
                toCsvValue(contact.sources)
            ].join(",")
        )
    ];

    if (!fs.existsSync(OUTPUT_DIR)) {
        fs.mkdirSync(OUTPUT_DIR, { recursive: true });
    }

    fs.writeFileSync(CSV_FILE, csvLines.join("\n"), "utf8");

    console.log(`Encontrados ${contacts.length} contatos únicos.`);
    console.log(`Arquivo gerado: ${CSV_FILE}`);
    console.log("Nenhum contato foi criado ainda.");
}

main().catch(error => {
    console.error("Erro:", error);
    process.exit(1);
});