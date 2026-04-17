# Release Fix Implementation Plan

> **Goal:** Fix two critical issues in the macOS app release process

## Issue 1: Notarization (PRIORITY)

**Problem:** Sparkle shows "improperly signed" error when validating updates. The Developer ID signature alone is insufficient for macOS Catalina+ - notarization is required.

**Solution:** Add notarization step to GitHub Actions workflow after DMG signing.

### Required Secrets (add to GitHub Settings > Secrets and variables > Actions)

| Secret Name | Value |
|-------------|-------|
| `APPLE_ID` | Your Apple Developer email |
| `APPLE_PASSWORD` | App-specific password (create at appleid.apple.com > App-Specific Passwords) |
| `APPLE_TEAM_ID` | Your Team ID (found in developer.apple.com or in your certificate) |

### Workflow Changes

Add after "Sign DMG" step (before "Create Release"):

```yaml
- name: Notarize DMG
  env:
    APPLE_ID: ${{ secrets.APPLE_ID }}
    APPLE_PASSWORD: ${{ secrets.APPLE_PASSWORD }}
    APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
  run: |
    echo "Submitting DMG for notarization..."
    xcrun notarytool submit MiniMaxUsage.dmg \
      --apple-id "$APPLE_ID" \
      --password "$APPLE_PASSWORD" \
      --team-id "$APPLE_TEAM_ID" \
      --wait

    echo "Stapling notarization ticket..."
    xcrun stapler staple MiniMaxUsage.dmg

    echo "Verifying staple..."
    xcrun stapler verify MiniMaxUsage.dmg
```

### Security Notes
- Never use your regular Apple ID password - use app-specific passwords only
- APPLE_TEAM_ID is not secret but keeping it in secrets is convenient
- `--wait` flag waits for Apple to process (typically 5-15 minutes)

---

## Issue 2: Update appcast.xml via GitHub API (no git push)

**Problem:** Current workflow does `git push origin main` which causes branch divergence between local and remote when tag trigger checkout differs from main.

**Solution:** Use GitHub REST API to update appcast.xml directly without git push.

### How it works

1. **GET** `https://api.github.com/repos/{owner}/{repo}/contents/appcast.xml` to obtain current file SHA
2. **PUT** same URL with new content and SHA to update file

### Benefits
- No branch divergence
- No git push required
- Uses built-in GITHUB_TOKEN (no additional secrets)
- No need for sparse checkout of main

### Workflow Changes

Replace the entire `update-appcast` job with:

```yaml
update-appcast:
  runs-on: macos-latest
  steps:
    - name: Get file SHA
      id: sha
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        REPO: ${{ github.repository }}
      run: |
        FILE_SHA=$(curl -L \
          -X GET "https://api.github.com/repos/${REPO}/contents/appcast.xml" \
          -H "Authorization: Bearer ${GITHUB_TOKEN}" \
          -H "Accept: application/vnd.github+json" \
          -H "X-GitHub-Api-Version: 2022-11-28" | jq -r '.sha')
        echo "FILE_SHA=$FILE_SHA" >> $GITHUB_OUTPUT

    - name: Update appcast.xml via API
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        TAG_NAME: ${{ github.ref_name }}
        REPO: ${{ github.repository }}
        FILE_SHA: ${{ steps.sha.outputs.FILE_SHA }}
      run: |
        VERSION=${TAG_NAME#v}

        # Get previous tag
        ALL_TAGS=$(git tag --sort=-v:refname)
        PREV_TAG=$(echo "$ALL_TAGS" | sed -n '2p')

        if [ -z "$PREV_TAG" ]; then
          BUILD_NUM=1
        else
          BUILD_NUM=$(git tag --sort=-v:refname | grep -n "^v${VERSION}$" | cut -d: -f1)
        fi

        # Build release notes
        if [ -z "$PREV_TAG" ]; then
          CHANGELOG=$(git log --oneline -20)
        else
          CHANGELOG=$(git log --oneline "$PREV_TAG..$TAG_NAME")
        fi

        RELEASE_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")
        DMG_URL="https://github.com/${REPO}/releases/download/v${VERSION}/MiniMaxUsage.dmg"

        # Create appcast.xml content
        cat > appcast.xml << 'APPCAST'
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>MiniMaxUsage Updates</title>
    <link>https://github.com/Remper1997/MiniMaxUsage/releases</link>
    <description>MiniMaxUsage update feed</description>
    <language>en</language>
  <item>
    <title>Version VERSION_PLACEHOLDER</title>
    <sparkle:version>BUILD_NUM_PLACEHOLDER</sparkle:version>
    <sparkle:shortVersionString>VERSION_PLACEHOLDER</sparkle:shortVersionString>
    <description><![CDATA[
CHANGELOG_PLACEHOLDER
    ]]></description>
    <pubDate>DATE_PLACEHOLDER</pubDate>
    <enclosure url="URL_PLACEHOLDER" sparkle:version="BUILD_NUM_PLACEHOLDER" sparkle:shortVersionString="VERSION_PLACEHOLDER" type="application/octet-stream" />
  </item>
  </channel>
</rss>
APPCAST

        # Replace placeholders
        sed -i '' "s/VERSION_PLACEHOLDER/$VERSION/g" appcast.xml
        sed -i '' "s/BUILD_NUM_PLACEHOLDER/$BUILD_NUM/g" appcast.xml
        sed -i '' "s|DATE_PLACEHOLDER|$RELEASE_DATE|g" appcast.xml
        sed -i '' "s|URL_PLACEHOLDER|$DMG_URL|g" appcast.xml
        sed -i '' "s|CHANGELOG_PLACEHOLDER|$CHANGELOG|g" appcast.xml

        # Update via GitHub API
        curl -L \
          -X PUT "https://api.github.com/repos/${REPO}/contents/appcast.xml" \
          -H "Authorization: Bearer ${GITHUB_TOKEN}" \
          -H "Accept: application/vnd.github+json" \
          -H "Content-Type: application/json" \
          -H "X-GitHub-Api-Version: 2022-11-28" \
          -d '{
            "message": "Update appcast.xml for v'"${VERSION}"'",
            "committer": {
              "name": "github-actions[bot]",
              "email": "github-actions[bot]@users.noreply.github.com"
            },
            "content": "'"$(base64 -i appcast.xml | tr -d '\n')"'",
            "sha": "'"${FILE_SHA}"'"
          }'
```

### Benefits over git push
| Aspect | git push | GitHub API |
|--------|----------|------------|
| Branch divergence | Yes | No |
| Requires checkout | Yes (full clone) | No (single API call) |
| Race conditions | Can conflict | SHA prevents overwrites |
| Authentication | SSH or token | Built-in GITHUB_TOKEN |

---

## Implementation Order

1. ~~**Step 1:** Add notarization secrets to GitHub~~ ✅
2. ~~**Step 2:** Add notarization step to workflow~~ ✅
3. **Step 3:** Test with new tag (verifica notarization funziona)
4. ~~**Step 4:** Replace update-appcast job with GitHub API approach~~ ✅
5. **Step 5:** Test full flow (verifica nessun git push, appcast si aggiorna via API)

---

## References

- [xcrun notarytool documentation](https://developer.apple.com/documentation/xcode/notarizing-macos-software-before-distribution)
- [GitHub REST API: Update file](https://docs.github.com/en/rest/repos/contents#update-a-file)
- [App-specific passwords](https://appleid.apple.com/account/manage > App-Specific Passwords)
