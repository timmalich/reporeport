# GitHub Repository Report Generator

This repository contains scripts to generate simple reports of all GitHub repositories in multiple organizations.
The report includes details such as repository name, URL, description, code owners, and additional metadata. The output
is generated in CSV, Markdown, and HTML formats.

## Features

- Fetches repository data using the GitHub CLI (`gh`).
- Extracts `CODEOWNERS` information for each repository.
- Supports additional per-repo metadata from a configuration file.
- Outputs reports in multiple formats: CSV, Markdown, and HTML.
- HTML report includes sortable tables for easy navigation.

## Prerequisites

- [GitHub CLI (`gh`)](https://cli.github.com/) installed and authenticated.
- `jq` for JSON processing.
- Bash shell.

```bash
sudo apt-get install gh jq
```

## Usage

1. **Configure the script**:
    - Create a `gh-report-config.json` file with the required structure (see below).
    - Ensure the `hostname` and `organizations` fields are correctly populated.

2. **Run the scripts**:
    - Fetch data from GitHub:
      ```bash
      ./gh-get-report-data.sh
      ```
    - Generate the report:
      ```bash
      ./gh-generate-report.sh
      ```

3. **View the output**:
    - Reports are saved in the `results` directory:
        - `results/report.csv`
        - `results/report.md`
        - `results/report.html`

## Configuration File (`gh-report-config.json`)

The configuration file should define the GitHub hostname and organizations to fetch data for. It can also include
additional metadata for individual repositories.

Example:

```json
{
  "hostname": "github.com",
  "organizations": {
    "example-org": {
      "repo-name": {
        "component": "Component Name",
        "experts": ["expert1", "expert2"],
        "notes": "Additional notes about the repository"
      }
    }
  }
}
```

## How to extend the Reports

### Adding more data from GitHub

To include additional data from GitHub for each repository:

1. **Add a new function similar to the `fetch_codeowners` function in `gh-get-report-data.sh`:
    - Add a new API call to fetch the required data.
    - Save the fetched data to a JSON file in the `build` directory with the format: $ORG_$REPONAME_myNewDataName.json.

   Example:
   ```bash
   fetch_additional_data() {
     local org="$1"
     local repo="$2"
     local output_file="$3"

     gh api repos/"$org"/"$repo"/some/endpoint \
       --jq '.' \
       > "$output_file" \
       || echo '{}' > "$output_file"
   }
   ```

2. Call the new function in the repository loop:
   ```bash
   fetch_additional_data "$ORG" "$REPO" "$BUILD_DIR/${ORG}_${REPO}_myNewDataName.json"
   ```

3. Update the `gh-generate-report.sh` script to process the new data.
   Example for parsing the new JSON file, from the GitHub api call, into a var using `jq` like this:
   ```bash
   MND_FILE="$BUILD_DIR/${ORG}_${NAME}_myNewDataName.json"
   MY_NEW_DATA=$(jq -r '.content // ""' "$MND_FILE" \
      | base64 --decode 2>/dev/null \
      | tr '\n' ' ' \
      | sed 's/"/""/g' \
      || echo "") 
   ```
4. Adopt the formatting section to include the new data in the report output (CSV, Markdown, or HTML).

   Example (CSV):
   ```bash
   printf '"%s","%s","%s","%s","%s","%s","%s","%s"\n' \
     "$ORG" "$NAME" "$URI" "$COMPONENT" "$DESC" "$CODEOWNERS" \
     "$MY_NEW_DATA" \
     >> "$OUT_CSV"
   ```
   
### Adding More Per-Repo Extras from Config

To extend the report with additional metadata from the configuration file:

1. **Update the configuration file**:
    - Add new fields under each repository in `gh-report-config.json`.

   Example:
   ```json
   {
     "hostname": "github.com",
     "organizations": {
       "example-org": {
         "repo-name": {
           "component": "Component Name",
           "experts": ["expert1", "expert2"],
           "notes": "Additional notes",
           "new-field": "New metadata value"
         }
       }
     }
   }
   ```

2. **Modify the `gh-generate-report.sh` script**:
    - Add logic to extract the new field from the configuration file.

   Example:
   ```bash
   NEW_FIELD=$(jq -r --arg o "$ORG" --arg r "$REPONAME" \
     '.organizations[][$o][$r].new-field // ""' "$CONFIG" | sed 's/"/""/g')
   ```

3. Include the new field in the report output (CSV, Markdown, or HTML).

   Example (CSV):
   ```bash
   printf '"%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' \
     "$ORG" "$NAME" "$URI" "$COMPONENT" "$DESC" "$CODEOWNERS" \
     "$EXPERTS" "$NOTES" "$NEW_FIELD" \
     >> "$OUT_CSV"
   ```

## Store the results in the current repo

1. Create a personal access token with sufficient permissions to read the repositories in the organizations.
2. Save this PAT in the secrets of this repository as `GH_TOKEN`. (Settings > Secrets and variables > Actions > New repository secret).
3. Allow actions to write to the repository (Settings > Actions > General > Workflow permissions > Read and write permissions).
4. Run the GitHub action "Generate GitHub Report" and find the results in the branch "report-results":
   1. [results/report.md](results/report.md)
   2. [results/report.csv](results/report.csv)
   3. [results/report.html](results/report.html)

