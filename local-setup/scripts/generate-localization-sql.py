#!/usr/bin/env python3
"""Extract localization messages from Postman collection into SQL."""
import json
import uuid
import sys

def extract_messages(collection_path, output_path):
    with open(collection_path) as f:
        collection = json.load(f)

    messages = []
    for folder in collection.get('item', []):
        if folder.get('name') == 'Auth':
            continue
        for request_item in folder.get('item', []):
            body = request_item.get('request', {}).get('body', {})
            raw = body.get('raw', '{}')
            try:
                payload = json.loads(raw)
            except json.JSONDecodeError:
                continue
            for msg in payload.get('messages', []):
                messages.append({
                    'locale': msg.get('locale', ''),
                    'code': msg.get('code', ''),
                    'message': msg.get('message', ''),
                    'module': msg.get('module', ''),
                })

    with open(output_path, 'w') as out:
        out.write("-- Localization seed data: {} messages\n".format(len(messages)))
        out.write("-- Generated from Localization_Seed_Script.postman_collection.json\n\n")

        for msg in messages:
            msg_id = str(uuid.uuid5(uuid.NAMESPACE_DNS,
                f"{msg['module']}:{msg['code']}:{msg['locale']}"))
            escaped_message = msg['message'].replace("'", "''")
            escaped_code = msg['code'].replace("'", "''")
            out.write(
                f"INSERT INTO message (id, locale, code, message, tenantid, module, createdby, createddate) "
                f"VALUES ('{msg_id}', '{msg['locale']}', '{escaped_code}', '{escaped_message}', "
                f"'mz', '{msg['module']}', 1, NOW()) ON CONFLICT (id) DO NOTHING;\n"
            )

    print(f"Generated {len(messages)} INSERT statements to {output_path}")

if __name__ == '__main__':
    extract_messages(
        'seeds/Localization_Seed_Script.postman_collection .json',
        'db/03_localization_seed_data.sql'
    )
