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

function getUser() {
	graphql "$(cat payloads/GetUser.json | sed "s/USER_ID/${1}/g")"
}

echo -n "Getting hacktivities... "
DISCLOSURES=$(getDisclosures)
COUNT=$(parse "${DISCLOSURES}" ".data.query.items | length")
echo -en "found ${COUNT} disclosures!\n\n"

for (( i = 0; i <= $COUNT-1; i++ )); do
	DATA="$(parse "${DISCLOSURES}" ".data.query.items[${i}]")"

	ID="$(parse "${DATA}" ".id")"
	[[ "$(cat "${LOG}")" =~ "${ID}" ]] && continue

	echo -e "Processing disclosure ${ID}..."

	CVE="$(parse "${DATA}" ".cve_id")"
	[[ "${CVE}" == "null" ]] && CVE=""
	CWE="$(parse "${DATA}" ".cwe.description")"
	[[ "${CWE}" == "null" || "${CWE}" == "" ]] && CWE="$(parse "${DATA}" ".cwe.title")"

	REPO="$(parse "${DATA}" ".repository.owner")/$(parse "${DATA}" ".repository.name")"
	PATCH="https://github.com/${REPO}/commit/$(parse "${DATA}" ".patch_commit_sha")"
	[[ "${PATCH^^}" == *N/A ]] && PATCH="N/A"

	USER="$(getUser "$(parse "${DATA}" ".disclosure.activity.user.id")")"

	REPORTER="$(parse "${USER}" ".data.query.settings.twitter")"
	if [[ "${REPORTER}" != "null" ]] && [[ "${REPORTER}" != "" ]]; then
		REPORTER="@$(sed 's/^@//' <(echo "${REPORTER}"))"
	else
		REPORTER="$(parse "${DATA}" ".disclosure.activity.user.preferred_username")"
	fi

	TWEET="$(./tweet -author="${REPORTER}" -cve="${CVE}" -cwe="${CWE}" -id="${ID}" -patch="${PATCH}" -repo="${REPO}")"
	[[ $? -ne 0 ]] && echo -e "${TWEET}" || {
		echo "OK!"
		echo "${ID}" >> "${LOG}"
	}
	echo
done
