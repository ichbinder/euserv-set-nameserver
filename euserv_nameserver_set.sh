#!/bin/bash

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo "Fehler: jq ist nicht installiert. Bitte jq installieren."
  exit 1
fi

# Step 1: Get session ID
echo "Hole Session-ID..."
sessionResponse=$(curl -s "https://support.euserv.com/?method=json")
sess_id=$(echo "$sessionResponse" | jq -r '.result.sess_id.value')
if [ -z "$sess_id" ]; then
    echo "Fehler: Session-ID konnte nicht abgerufen werden."
    exit 1
fi
echo "Session-ID: $sess_id"

# Step 2: Get the domain list
# Assumes that the domain list is returned as an array under .result.domains with the fields dom_id and dom_name

echo "Hole Domainliste..."
domainResponse=$(curl -s "https://support.euserv.com/?subaction=show_kc2_domain_dns&method=json&sess_id=${sess_id}")

# Check if the response indicates a successful operation
message=$(echo "$domainResponse" | jq -r '.message')
if [ "$message" != "success" ]; then
    echo "Fehler beim Abrufen der Domainliste: $message"
    exit 1
fi

# Extract the list of domains (assuming the JSON contains an array under .result.domains with the fields dom_id and dom_name)
domains=$(echo "$domainResponse" | jq -r '.result.domains[] | "\(.dom_id) \(.dom_name)"')
domainCount=$(echo "$domainResponse" | jq '.result.domains | length')

if [ "$domainCount" -eq 0 ]; then
    echo "Keine Domains gefunden."
    exit 1
fi

# Step 3: Display the domains and let the user choose one
echo "Verfügbare Domains:"
i=1
declare -A domain_map
while IFS= read -r line; do
    dom_id=$(echo "$line" | awk '{print $1}')
    dom_name=$(echo "$line" | awk '{print $2}')
    echo "$i) $dom_name"
    domain_map[$i]="$dom_id;$dom_name"
    ((i++))
done <<< "$domains"

read -p "Bitte wählen Sie die Nummer der Domain, für die NS gesetzt werden soll: " domain_choice
if [ -z "${domain_map[$domain_choice]}" ]; then
    echo "Ungültige Wahl."
    exit 1
fi

chosen_entry="${domain_map[$domain_choice]}"
chosen_dom_id=$(echo "$chosen_entry" | cut -d ';' -f 1)
chosen_dom_name=$(echo "$chosen_entry" | cut -d ';' -f 2)

echo "Ausgewählte Domain: $chosen_dom_name (dom_id: $chosen_dom_id)"

# Step 4: Ask the user for NS entries
read -p "Bitte NS1 eingeben: " ns1
read -p "Bitte NS2 eingeben: " ns2

# Step 5: Set the nameservers using the API
echo "Setze Nameserver..."
setResponse=$(curl -s "https://support.euserv.com/?subaction=kc2_domain_nameserver_set&method=json&sess_id=${sess_id}&dom_id=${chosen_dom_id}&dom_nserver1=${ns1}&dom_nserver2=${ns2}")

echo "Antwort von NS-Setzen API:"
echo "$setResponse" 