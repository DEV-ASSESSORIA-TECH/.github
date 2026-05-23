import "isomorphic-fetch";
import fs from "node:fs";
import path from "node:path";
import readline from "node:readline/promises";
import { stdin as input, stdout as output } from "node:process";
import { DeviceCodeCredential } from "@azure/identity";
import { Client } from "@microsoft/microsoft-graph-client";
import 'dotenv/config';

const TENANT_ID = process.env.TENANT_ID;
const CLIENT_ID = process.env.CLIENT_ID;

if (!TENANT_ID || !CLIENT_ID) {
    throw new Error("Configure TENANT_ID e CLIENT_ID no arquivo .env");
}

const CSV_FILE = path.join("data", "contacts-preview.csv");

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

function splitCsvLine(line) {
    const result = [];
    let current = "";
    let insideQuotes = false;

    for (let i = 0; i < line.length; i++) {
        const char = line[i];
        const nextChar = line[i + 1];

        if (char === '"' && nextChar === '"') {
            current += '"';
            i++;
            continue;
        }

        if (char === '"') {
            insideQuotes = !insideQuotes;
            continue;
        }

        if (char === "," && !insideQuotes) {
            result.push(current);
            current = "";
            continue;
        }

        current += char;
    }

    result.push(current);

    return result;
}

function readContactsFromCsv() {
    if (!fs.existsSync(CSV_FILE)) {
        throw new Error(`Arquivo não encontrado: ${CSV_FILE}`);
    }

    const content = fs.readFileSync(CSV_FILE, "utf8").trim();

    if (!content) {
        return [];
    }

    const lines = content.split(/\r?\n/);

    const header = splitCsvLine(lines[0]).map(column => column.trim().toLowerCase());

    const nameIndex = header.indexOf("name");
    const emailIndex = header.indexOf("email");
    const sourcesIndex = header.indexOf("sources");

    if (nameIndex === -1 || emailIndex === -1) {
        throw new Error("CSV inválido. O arquivo precisa ter as colunas name e email.");
    }

    const contacts = [];

    for (const line of lines.slice(1)) {
        if (!line.trim()) continue;

        const columns = splitCsvLine(line);

        const name = columns[nameIndex]?.trim();
        const email = normalizeEmail(columns[emailIndex]);
        const sources = sourcesIndex >= 0 ? columns[sourcesIndex]?.trim() : "";

        if (!email || !isValidEmail(email)) continue;

        contacts.push({
            name: name || email,
            email,
            sources
        });
    }

    const uniqueContacts = new Map();

    for (const contact of contacts) {
        if (!uniqueContacts.has(contact.email)) {
            uniqueContacts.set(contact.email, contact);
        }
    }

    return [...uniqueContacts.values()];
}

async function listExistingContacts() {
    const existing = new Set();

    let request = graphClient
        .api("/me/contacts")
        .select("id,emailAddresses")
        .top(100);

    while (request) {
        const result = await request.get();

        for (const contact of result.value || []) {
            for (const emailObj of contact.emailAddresses || []) {
                const address = normalizeEmail(emailObj.address);

                if (address) {
                    existing.add(address);
                }
            }
        }

        if (!result["@odata.nextLink"]) break;

        const nextPath = result["@odata.nextLink"].replace(
            "https://graph.microsoft.com/v1.0",
            ""
        );

        request = graphClient.api(nextPath);
    }

    return existing;
}

function splitName(fullName, email) {
    const cleanName = fullName?.trim();

    if (!cleanName || cleanName.toLowerCase() === email.toLowerCase()) {
        const localPart = email.split("@")[0];

        return {
            givenName: localPart,
            surname: ""
        };
    }

    const parts = cleanName.split(/\s+/);

    if (parts.length === 1) {
        return {
            givenName: parts[0],
            surname: ""
        };
    }

    return {
        givenName: parts.slice(0, -1).join(" "),
        surname: parts[parts.length - 1]
    };
}

async function createContact(contact) {
    const { givenName, surname } = splitName(contact.name, contact.email);

    return graphClient.api("/me/contacts").post({
        givenName,
        surname,
        emailAddresses: [
            {
                address: contact.email,
                name: contact.name
            }
        ]
    });
}

async function askConfirmation(contactsToCreate) {
    console.log("");
    console.log("Resumo da importação:");
    console.log(`Contatos novos que serão criados: ${contactsToCreate.length}`);
    console.log("");

    console.log("Primeiros contatos da lista:");
    for (const contact of contactsToCreate.slice(0, 10)) {
        console.log(`- ${contact.name} <${contact.email}>`);
    }

    if (contactsToCreate.length > 10) {
        console.log(`... e mais ${contactsToCreate.length - 10} contatos.`);
    }

    console.log("");
    console.log("Para confirmar a criação dos contatos, digite exatamente:");
    console.log("IMPORTAR");
    console.log("");

    const rl = readline.createInterface({ input, output });

    const answer = await rl.question("Confirma a importação? ");

    rl.close();

    return answer.trim() === "IMPORTAR";
}

async function main() {
    console.log("Lendo CSV...");
    const contactsFromCsv = readContactsFromCsv();

    console.log(`Contatos encontrados no CSV: ${contactsFromCsv.length}`);

    console.log("Consultando contatos existentes no Outlook...");
    const existingContacts = await listExistingContacts();

    console.log(`Contatos já existentes no Outlook: ${existingContacts.size}`);

    const contactsToCreate = contactsFromCsv.filter(
        contact => !existingContacts.has(contact.email)
    );

    if (contactsToCreate.length === 0) {
        console.log("Nenhum contato novo para criar.");
        return;
    }

    const confirmed = await askConfirmation(contactsToCreate);

    if (!confirmed) {
        console.log("Importação cancelada. Nenhum contato foi criado.");
        return;
    }

    console.log("");
    console.log("Criando contatos...");

    let created = 0;
    let failed = 0;

    for (const contact of contactsToCreate) {
        try {
            await createContact(contact);
            created++;
            console.log(`Criado: ${contact.name} <${contact.email}>`);
        } catch (error) {
            failed++;
            console.error(`Erro ao criar ${contact.email}: ${error.message}`);
        }
    }

    console.log("");
    console.log("Importação finalizada.");
    console.log(`Criados: ${created}`);
    console.log(`Falhas: ${failed}`);
}

main().catch(error => {
    console.error("Erro:", error);
    process.exit(1);
});