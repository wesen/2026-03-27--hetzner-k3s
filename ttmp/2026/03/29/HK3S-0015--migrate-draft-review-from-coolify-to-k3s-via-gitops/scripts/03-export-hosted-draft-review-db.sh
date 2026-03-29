#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./00-common.sh
source "$SCRIPT_DIR/00-common.sh"

require_cmd ssh
require_cmd sha256sum

OUTPUT_PATH="${1:-$VAR_DIR/hosted-draft-review-data.sql}"
RAW_OUTPUT_PATH="${OUTPUT_PATH}.raw"

ssh "root@${HOSTED_HOST}" \
  "docker exec ${HOSTED_POSTGRES_CONTAINER} pg_dump \
    -U postgres \
    -d ${HOSTED_DATABASE} \
    --data-only \
    --column-inserts \
    --disable-dollar-quoting \
    --no-owner \
    --no-privileges \
    --exclude-table=public.schema_migrations \
    --exclude-table=public.author_sessions \
    --exclude-table=public.email_verification_tokens \
    --exclude-table=public.password_reset_tokens \
    --exclude-table=public.review_sessions" \
  >"$RAW_OUTPUT_PATH"

python3 - "$RAW_OUTPUT_PATH" "$OUTPUT_PATH" <<'PY'
from pathlib import Path
import shlex
import subprocess
import sys

raw = Path(sys.argv[1])
out = Path(sys.argv[2])

skip_prefixes = ("\\restrict ", "\\unrestrict ")
skip_exact = {"SET transaction_timeout = 0;"}

with raw.open() as src, out.open("w") as dst:
    skipping_article_sections = False
    for line in src:
        stripped = line.rstrip("\n")
        if stripped.startswith("-- Data for Name: article_sections; Type: TABLE DATA;"):
            skipping_article_sections = True
            continue
        if skipping_article_sections:
            if stripped.startswith("-- Data for Name: "):
                skipping_article_sections = False
            else:
                continue
        if stripped in skip_exact:
            continue
        if any(stripped.startswith(prefix) for prefix in skip_prefixes):
            continue
        dst.write(line)

    dst.write("\n--\n")
    dst.write("-- Data for Name: article_sections; Type: TABLE DATA; Schema: public; Owner: -\n")
    dst.write("--\n\n")
    article_sections_query = """
select format(
  'INSERT INTO public.article_sections (id, article_version_id, section_key, "position", title, body_markdown, estimated_read_seconds, created_at, updated_at) VALUES (%L, %L, %L, %s, %L, %L, %s, %L, %L);',
  id,
  article_version_id,
  section_key,
  "position",
  title,
  body_markdown,
  estimated_read_seconds,
  created_at,
  updated_at
)
from public.article_sections
order by created_at, id
    """.strip()
    remote_command = (
        "docker exec go1o5tbegalwy3kesshq3hcp "
        "psql -U postgres -d draft_review -At "
        f"-c {shlex.quote(article_sections_query)}"
    )
    article_sections_sql = subprocess.check_output(
        f"ssh root@89.167.52.236 {shlex.quote(remote_command)}",
        shell=True,
        text=True,
    )
    dst.write(article_sections_sql)
    if not article_sections_sql.endswith("\n"):
        dst.write("\n")

raw.unlink()
PY

echo "wrote hosted Draft Review export to $OUTPUT_PATH"
sha256sum "$OUTPUT_PATH"
