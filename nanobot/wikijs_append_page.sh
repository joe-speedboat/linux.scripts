#!/usr/bin/env bash
set -e

# wikijs_append_page.sh
# =====================
# Appends a new entry to a Wiki.js page using the GraphQL API.
# This script fetches the current page content, appends a new entry with timestamp,
# and updates the page with the new content.
#
# Requirements:
# - curl
# - jq (JSON processor)
# - Wiki.js instance with GraphQL API enabled
# - Valid API key with appropriate permissions
#
# Usage:
#   1. Set the configuration variables at the top of the script:
#      - WIKI_URL: URL to your Wiki.js GraphQL endpoint
#      - API_KEY: Your Wiki.js API key
#      - PAGE_ID: ID of the page to append to
#
#   2. Run the script in one of two ways:
#      a) Pass the note as a command-line argument:
#         ./wikijs_append_page.sh "Your note content here"
#
#      b) Pipe content to the script:
#         echo "Your note content here" | ./wikijs_append_page.sh
#         cat note.txt | ./wikijs_append_page.sh
#
# Example:
#   ./wikijs_append_page.sh "Meeting notes from today's standup"
#
#   echo -e "Project update:\n- Completed task A\n- Started task B" | ./wikijs_append_page.sh
#
# The script will:
# 1. Fetch the current page content
# 2. Create a new entry with timestamp and code block formatting
# 3. Append the new entry to the existing content
# 4. Update the page with the new content
# 5. Display the API response

# ----------------------------------- NANOBOT TOOLS.md INSTRUCTIONS (remove comment) --------------------------------------------------
# ## Wiki Notekeeper - exec /home/nanobot/bin/wikijs_append.sh
# Store notes in the Wiki by calling a local helper script.
# ### Trigger
# If a user message **starts with `:wiki`**, store the message in the Wiki.
# Everything **after `:wiki`** becomes the note content.
# ### Image Processing
# When an image is detected in a message:
# 1. Extract all readable text from the image
# 2. Use the extracted text as the note content
# 3. Preserve the text exactly as extracted, including line breaks and special characters
# 4. Execute the wiki append command with the extracted text
# 5. Respond with "Wiki note stored." after successful storage
# ### Behavior
# 1. Detect the trigger `:wiki` at the **beginning** of the message.
# 2. Remove the trigger `:wiki` from the message.
# 3. Determine the content to store:
#    **If the message contains text:**
#    * Treat the remaining text as the note content.
#    **If the message contains an image:** follow "Image Processing" rules
# 4. Execute the following command to append the note to the Wiki:
# ```bash
# cat <<'EOF' | /home/nanobot/bin/wikijs_append.sh
# <multiline
# note
# content>
# EOF
# ```
# ### Important Rules
# * Preserve **all characters exactly as written or extracted**.
# * Preserve **all line breaks**.
# * Do **not modify or summarize the text**.
# * Do **not interpret variables** such as `$VAR`, `$(command)`, or backticks.
# * The heredoc must remain **quoted (`<<'EOF'`)** to prevent shell expansion.
# ### Response
# After the command executes successfully, Nanobot should respond with:
# ```
# Wiki note stored.
# ```
# ----------------------------------- NANOBOT TOOLS.md INSTRUCTIONS (end of instructions) --------------------------------------------------

WIKI_URL="https://wiki.domain.tld/graphql"
API_KEY="enable api - create token - restict access - insert here"
PAGE_ID=999

# read note from argument or stdin
if [ $# -gt 0 ]; then
   NOTE="$1"
else
   NOTE="$(cat)"
fi


# remove possible leading newline (common with heredoc)
NOTE="${NOTE#$'\n'}"

if [ -z "$NOTE" ]; then
  echo "usage: $0 \"text to append\""
  echo "   or: cat note.txt | $0"
  exit 1
fi

echo "Fetching current page..."

CONTENT=$(curl -s \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"query\":\"query(\$id:Int!){pages{single(id:\$id){content}}}\",\"variables\":{\"id\":$PAGE_ID}}" \
  "$WIKI_URL" | jq -r '.data.pages.single.content')

if [ "$CONTENT" = "null" ]; then
  echo "Failed to fetch page content"
  exit 1
fi


ENTRY=$(printf "\n\n### %s\n\n\`\`\`\`\n%s\n\`\`\`\`\n" "$(date '+%Y-%m-%d %H:%M')" "$NOTE")

NEW_CONTENT="${CONTENT}${ENTRY}"

echo "Updating page..."

REQUEST=$(jq -n \
  --argjson id "$PAGE_ID" \
  --arg content "$NEW_CONTENT" '
{
  query: "mutation($id:Int!,$content:String!){
    pages{
      update(
        id:$id
        content:$content
        editor:\"markdown\"
        isPublished:true
        tags:[]
      ){
        responseResult{
          succeeded
          message
        }
      }
    }
  }",
  variables: {
    id: $id,
    content: $content
  }
}')

RESPONSE=$(curl -s \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$REQUEST" \
  "$WIKI_URL")

echo "$RESPONSE" | jq

SUCCESS=$(echo "$RESPONSE" | jq -r '.data.pages.update.responseResult.succeeded')

if [ "$SUCCESS" != "true" ]; then
  echo "Update failed"
  exit 1
fi
