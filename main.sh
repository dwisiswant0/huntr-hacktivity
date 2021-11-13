#!/bin/bash

LOG="log.txt"
X_API_KEY="da2-fql7xoajcng6pilmew4lfbi6ga"

function graphql() {
	curl "https://mnk2smepzzdp5djxpbthzr6odq.appsync-api.eu-west-1.amazonaws.com/graphql" \
	  -H "x-api-key: ${X_API_KEY}" \
	  -H "content-type: application/json" \
	  -H "origin: https://huntr.dev" \
	  -H "referer: https://huntr.dev/" \
	  -skL --compressed \
	  --data-raw "${1}"
}

function parse() {
	echo "${1}" | jq -r "${2}"
}

function getDisclosures() {
	graphql "$(cat payloads/fetchValidDisclosures.json)" # | jq .data.query.items[]
}

# function getVulnerability() {
# 	graphql "$(cat payloads/GetVulnerability.json | sed "s/VULNERABILITY_ID/${1}/g")"
# }

echo -n "Getting hacktivities... "
DISCLOSURES=$(getDisclosures)
COUNT=$(parse "${DISCLOSURES}" ".data.query.items | length")
echo -en "found ${COUNT} disclosures!\n\n"

for (( i = 0; i <= $COUNT-1; i++ )); do
	DATA="$(parse "${DISCLOSURES}" ".data.query.items[${i}]")"

	ID="$(parse "${DATA}" ".id")"
	[[ "$(cat "${LOG}")" =~ "${ID}" ]] && continue

	echo -e "Processing disclosure ${ID}..."

	# CVE="$(parse "${DATA}" ".cve_id")"
	CWE="$(parse "${DATA}" ".cwe.description")"
	[[ -z "${CWE}" ]] && CWE="$(parse "${DATA}" ".cwe.title")"

	REPO="https://github.com/$(parse "${DATA}" ".repository.owner")/$(parse "${DATA}" ".repository.name")"
	PATCH="${REPO}/commit/$(parse "${DATA}" ".patch_commit_sha")"
	REPORTER="$(parse "${DATA}" ".disclosure.activity.user.preferred_username")"

	LINK="https://huntr.dev/bounties/${ID}/"
	TITLE="${CWE} in ${REPO}"
	# [[ "${CVE}" != "null" ]] && TITLE+=" (${CVE})"

	CONTENT="${TITLE} reported by @${REPORTER} - Patch: ${PATCH}\n${LINK} #bugbounty #opensource"

	echo -e "Tweeting: ${CONTENT}"
	echo -e "${CONTENT}" | ./tweet
	echo "${ID}" >> "${LOG}"
done
