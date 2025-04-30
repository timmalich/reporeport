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
| Org | Repo Name | Repo URI | Component | Description | Code Owners | Experts | Notes |
|-----|-----------|----------|-----------|-------------|-------------|---------|-------|
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
  <table id="repoTable">
    <thead>
      <tr>
        <th onclick="sortTable(0)">Org</th>
        <th onclick="sortTable(1)">Repo Name</th>
        <th onclick="sortTable(2)">Repo URI</th>
        <th onclick="sortTable(3)">Component</th>
        <th onclick="sortTable(4)">Description</th>
        <th onclick="sortTable(5)">Code Owners</th>
        <th onclick="sortTable(6)">Experts</th>
        <th onclick="sortTable(7)">Notes</th>
      </tr>
    </thead>
    <tbody>
EOF

for REPOLIST in "$BUILD_DIR"/*_repolist.json; do
  ORG=$(basename "$REPOLIST" _repolist.json)

  jq -c '.[]' "$REPOLIST" | while read -r REC; do
    echo "Generating report for $ORG/${REC}."
    REPONAME=$(echo "$REC" | jq -r '.name')
    URI=$(echo "$REC" | jq -r '.url')
    DESC=$(echo "$REC" | jq -r '.description // ""' | sed 's/"/""/g')

    # Parse distinct code owners from a github CODEOWNERS file
    CO_FILE="$BUILD_DIR/${ORG}_${REPONAME}_codeowners.json"
    CODEOWNERS=$(jq -r '.content // ""' "$CO_FILE" \
    | base64 --decode 2>/dev/null \
    | grep -vE '^\s*(#|$)' \
    | awk '{print $NF}' \
    | sort -u \
    | tr '\n' ' ' \
    | sed 's/"/""/g' \
    || echo "")

    # load per-repo extras from config
    COMPONENT=$(jq -r --arg o "$ORG" --arg r "$REPONAME" \
      '.organizations[][$o][$r].component // ""' "$CONFIG" | sed 's/"/""/g')
    EXPERTS=$(jq -r --arg o "$ORG" --arg r "$REPONAME" \
      '.organizations[][$o][$r].experts // [] | join(",")' "$CONFIG" | sed 's/"/""/g')
    NOTES=$(jq -r --arg o "$ORG" --arg r "$REPONAME" \
      '.organizations[][$o][$r].notes // ""' "$CONFIG" | sed 's/"/""/g')

    # CSV row
    printf '"%s","%s","%s","%s","%s","%s","%s","%s"\n' \
      "$ORG" "$REPONAME" "$URI" "$COMPONENT" "$DESC" "$CODEOWNERS" \
      "$EXPERTS" "$NOTES" \
      >> "$OUT_CSV"

    # .md row
    echo "| $ORG | $REPONAME | [$REPONAME]($URI) | $COMPONENT | $DESC | $CODEOWNERS | $EXPERTS | $NOTES |" \
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
      var table = document.getElementById("repoTable"),
          rows = table.tBodies[0].rows,
          switching = true, dir = "asc";
      while (switching) {
        switching = false;
        for (let i=0; i<rows.length-1; i++) {
          let x = rows[i].cells[n].textContent.toLowerCase(),
              y = rows[i+1].cells[n].textContent.toLowerCase(),
              shouldSwitch = (dir==="asc" ? x>y : x<y);
          if (shouldSwitch) {
            rows[i].parentNode.insertBefore(rows[i+1], rows[i]);
            switching = true;
          }
        }
        if (!switching && dir==="asc") { dir="desc"; switching=true; }
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
