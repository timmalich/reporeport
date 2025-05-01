#!/usr/bin/env bash
set -euo pipefail

CONFIG="gh-report-config.json"
BUILD_DIR="build"

mkdir -p results
OUT_CSV="results/report.csv"
OUT_MD="results/report.md"
OUT_HTML="results/report.html"

# — CSV Header
cat > "$OUT_CSV" <<EOF
org,repo-name,repo-uri,component,repo-description,code-owners,experts,notes
EOF

# — README.md Header
cat > "$OUT_MD" <<'EOF'
| Org | Repo Name | Repo URI | Component | Description | Code Owners | Experts | Notes | Latest commit | Commit date | Top contributor | Contri Commits | Languages |
|-----|-----------|----------|-----------|-------------|-------------|---------|-------|---------------|-------------|-----------------|----------------|-----------|
EOF

# — HTML Header
cat > "$OUT_HTML" <<'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>GitHub Repo Report</title>
  <style>
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #ddd; padding: 8px; }
    th { cursor: pointer; background-color: #f2f2f2; }
    pre { margin:0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  </style>
</head>
<body>
  <h2>GitHub Repository Report</h2>
  <input type="text" id="searchBarInput" onkeyup="filterTable()" placeholder="Search for repositories...">

  <table id="repoTable">
    <thead>
      <tr>
        <th onclick="sortTable(0)">Org<br><input type="text" onkeyup="filterColumn(0)" placeholder="Filter Org"></th>
        <th onclick="sortTable(1)">Repo Name<br><input type="text" onkeyup="filterColumn(1)" placeholder="Filter Repo Name"></th>
        <th onclick="sortTable(2)">Repo URI<br><input type="text" onkeyup="filterColumn(2)" placeholder="Filter Repo URI"></th>
        <th onclick="sortTable(3)">Component<br><input type="text" onkeyup="filterColumn(3)" placeholder="Filter Component"></th>
        <th onclick="sortTable(4)">Description<br><input type="text" onkeyup="filterColumn(4)" placeholder="Filter Description"></th>
        <th onclick="sortTable(5)">Code Owners<br><input type="text" onkeyup="filterColumn(5)" placeholder="Filter Code Owners"></th>
        <th onclick="sortTable(6)">Experts<br><input type="text" onkeyup="filterColumn(6)" placeholder="Filter Experts"></th>
        <th onclick="sortTable(7)">Notes<br><input type="text" onkeyup="filterColumn(7)" placeholder="Filter Notes"></th>
        <th onclick="sortTable(8)">Latest commit<br><input type="text" onkeyup="filterColumn(8)" placeholder="Filter Latest commit"></th>
        <th onclick="sortTable(9)">Commit date<br><input type="text" onkeyup="filterColumn(9)" placeholder="Filter Commit date"></th>
        <th onclick="sortTable(10)">Top contributor<br><input type="text" onkeyup="filterColumn(10)" placeholder="Filter contributor"></th>
        <th onclick="sortTable(11)">Contri commits<br><input type="text" onkeyup="filterColumn(11)" placeholder="amount"></th>
        <th onclick="sortTable(12)">Languages<br><input type="text" onkeyup="filterColumn(12)" placeholder="Filter Langs"></th>
      </tr>
    </thead>
    <tbody>
EOF


for REPOLIST in "$BUILD_DIR"/*_repolist.json; do
  ORG=$(basename "$REPOLIST" _repolist.json)

  jq -c '.[]' "$REPOLIST" | while read -r REC; do
    echo "Generating report for $ORG/${REC}."

    REPONAME=$(echo "$REC" | jq -r '.name')
    DATA_PATH="$BUILD_DIR/${ORG}_${REPONAME}_"
    #######################################################################################################
    ##################################### DATA PARSING ####################################################
    #######################################################################################################
    URI=$(echo "$REC" | jq -r '.url')
    DESC=$(echo "$REC" | jq -r '.description // ""' | sed 's/"/""/g')

    # load per-repo extras from config
    COMPONENT=$(jq -r --arg o "$ORG" --arg r "$REPONAME" \
      '.organizations[][$o][$r].component // ""' "$CONFIG" | sed 's/"/""/g')
    EXPERTS=$(jq -r --arg o "$ORG" --arg r "$REPONAME" \
      '.organizations[][$o][$r].experts // [] | join(",")' "$CONFIG" | sed 's/"/""/g')
    NOTES=$(jq -r --arg o "$ORG" --arg r "$REPONAME" \
      '.organizations[][$o][$r].notes // ""' "$CONFIG" | sed 's/"/""/g')

    # Parse distinct code owners from a github CODEOWNERS file
    CODEOWNERS=$(jq -r '.content // ""' "${DATA_PATH}codeowners.json" \
    | base64 --decode 2>/dev/null \
    | grep -vE '^\s*(#|$)' \
    | awk '{print $NF}' \
    | sort -u \
    | tr '\n' ' ' \
    | sed 's/"/""/g' \
    || echo "")

    LATEST_JSON="${DATA_PATH}latest_commit.json"
    LATEST_SHA=$(jq -r '.sha' "$LATEST_JSON")
    LATEST_DATE=$(jq -r '.commit.author.date' "$LATEST_JSON")

    LANGS=$(jq -r 'keys | join(",")' "${DATA_PATH}languages.json")

    CONTRIB_FILE="$BUILD_DIR/${ORG}_${REPONAME}_contributors.json"
    TOP_CONTRIBUTOR=$(jq -r '.[0].login // ""' "$CONTRIB_FILE")
    TOP_COMMITS=$(jq -r '.[0].contributions // 0' "$CONTRIB_FILE")

    #######################################################################################################
    ##################################### OUTPUT FORMATTING ###############################################
    #######################################################################################################
    # CSV row
    printf '"%s","%s","%s","%s","%s","%s","%s","%s,"%s","%s","%s",%s,"%s"\n' \
      "$ORG" "$REPONAME" "$URI" "$COMPONENT" "$DESC" "$CODEOWNERS" \
      "$EXPERTS" "$NOTES" "$LATEST_SHA" "$LATEST_DATE" "$TOP_CONTRIBUTOR" "$TOP_COMMITS" "$LANGS" \
      >> "$OUT_CSV"

    # .md row
    echo "| $ORG | $REPONAME | [$REPONAME]($URI) | $COMPONENT | $DESC | $CODEOWNERS | $EXPERTS | $NOTES | $LATEST_SHA | $LATEST_DATE | $TOP_CONTRIBUTOR | $TOP_COMMITS | $LANGS " \
      >> "$OUT_MD"

    # HTML row
    echo "      <tr>" \
         "<td>$ORG</td>" \
         "<td>$REPONAME</td>" \
         "<td><a href=\"$URI\">$URI</a></td>" \
         "<td>$COMPONENT</td>" \
         "<td>$DESC</td>" \
         "<td>$CODEOWNERS</td>" \
         "<td>$EXPERTS" \
         "<td>$NOTES</td>" \
         "<td>$LATEST_SHA</td>" \
         "<td>$LATEST_DATE</td>" \
         "<td>$TOP_CONTRIBUTOR</td>" \
         "<td>$TOP_COMMITS</td>" \
         "<td>$LANGS</td>" \
         "</tr>" \
      >> "$OUT_HTML"
  done
done

# HTML Footer + sort script
cat >> "$OUT_HTML" <<'EOF'
    </tbody>
  </table>
  <script>
    function sortTable(n) {
      const table = document.getElementById("repoTable");
      const rows = Array.from(table.tBodies[0].rows);
      const currentDir = table.getAttribute("data-sort-dir") === "asc" ? "desc" : "asc";

      rows.sort((rowA, rowB) => {
        const cellA = rowA.cells[n].textContent.trim();
        const cellB = rowB.cells[n].textContent.trim();

        const isNumeric = !isNaN(cellA) && !isNaN(cellB);
        if (isNumeric) {
          return currentDir === "asc" ? cellA - cellB : cellB - cellA;
        } else {
          return currentDir === "asc" ? cellA.localeCompare(cellB) : cellB.localeCompare(cellA);
        }
      });

      rows.forEach(row => table.tBodies[0].appendChild(row));
      table.setAttribute("data-sort-dir", currentDir);
    }

    function filterColumn(columnIndex) {
      const table = document.getElementById("repoTable");
      const rows = table.getElementsByTagName("tr");
      const input = table.tHead.rows[0].cells[columnIndex].getElementsByTagName("input")[0];
      const filter = input.value.toLowerCase();

      for (let i = 1; i < rows.length; i++) { // Skip the header row
        const cell = rows[i].cells[columnIndex];
        if (cell) {
          const text = cell.textContent.toLowerCase();
          rows[i].style.display = text.includes(filter) ? "" : "none";
        }
      }
    }

    function filterTable() {
      const input = document.getElementById("searchBarInput");
      const filter = input.value.toLowerCase();
      const table = document.getElementById("repoTable");
      const rows = table.getElementsByTagName("tr");

      for (let i = 1; i < rows.length; i++) { // Skip the header row
        const cells = rows[i].getElementsByTagName("td");
        let match = false;

        for (let j = 0; j < cells.length; j++) {
          if (cells[j] && cells[j].textContent.toLowerCase().includes(filter)) {
            match = true;
            break;
          }
        }

        rows[i].style.display = match ? "" : "none";
      }
    }
  </script>
</body>
</html>
EOF

echo "✅ Reports generated:"
echo "   • $OUT_CSV"
echo "   • $OUT_MD"
echo "   • $OUT_HTML"
