#!/bin/bash

# Script pour modifier les feature flags d'une instance Cozy via l'API de la stack
# Usage: ./change-features.sh <FQDN> <FEATURES_JSON_FILE> [STACK_ADMIN_URL]
#
# Le fichier JSON doit contenir un objet avec les flags et leurs valeurs:
# {
#   "foo": true,
#   "bar": 1,
#   "baz": "baz",
#   "feature.to.remove": null
# }

set -euo pipefail

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction d'aide
usage() {
    echo "Usage: $0 <FQDN> <FEATURES_JSON_FILE> [STACK_ADMIN_URL]"
    echo ""
    echo "Arguments:"
    echo "  FQDN                Le FQDN de l'instance Cozy (ex: user.cozy.localhost:8080)"
    echo "  FEATURES_JSON_FILE  Fichier JSON contenant les flags à modifier"
    echo "  STACK_ADMIN_URL     URL du port admin de la stack (défaut: http://localhost:6060)"
    echo ""
    echo "Format du JSON:"
    echo "  {"
    echo "    \"feature1\": true,"
    echo "    \"feature2\": 1,"
    echo "    \"feature3\": \"value\","
    echo "    \"feature.to.remove\": null"
    echo "  }"
    echo ""
    echo "Note: Pour supprimer un flag, utilisez null comme valeur"
    exit 1
}

# Vérification des arguments
if [ $# -lt 2 ]; then
    echo -e "${RED}Erreur: arguments manquants${NC}"
    usage
fi

FQDN="$1"
FEATURES_FILE="$2"
STACK_ADMIN_URL="${3:-http://localhost:6060}"

# Vérification que le fichier JSON existe
if [ ! -f "$FEATURES_FILE" ]; then
    echo -e "${RED}Erreur: le fichier JSON '$FEATURES_FILE' n'existe pas${NC}"
    exit 1
fi

# Vérification que jq est installé
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Erreur: jq n'est pas installé. Installez-le avec: apt-get install jq ou brew install jq${NC}"
    exit 1
fi

# Vérification que curl est installé
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Erreur: curl n'est pas installé${NC}"
    exit 1
fi

# Validation du JSON
if ! jq empty "$FEATURES_FILE" 2>/dev/null; then
    echo -e "${RED}Erreur: le fichier JSON n'est pas valide${NC}"
    exit 1
fi

echo -e "${GREEN}Modification des feature flags pour l'instance: ${FQDN}${NC}"

# Afficher les flags à modifier
echo -e "\n${YELLOW}Flags à modifier:${NC}"
jq -r 'to_entries[] | "  \(.key): \(.value)"' "$FEATURES_FILE"

# Obtenir un token admin pour l'API de la stack
# Note: L'API feature/flags ne nécessite pas de scope spécifique, juste un token CLI
echo -e "\n${GREEN}[1/2] Obtention du token admin...${NC}"
TOKEN_RESPONSE=$(curl -s -w "\n%{http_code}" -u admin:admin -X POST "${STACK_ADMIN_URL}/instances/token?Domain=${FQDN}&Audience=cli")

HTTP_CODE=$(echo "$TOKEN_RESPONSE" | tail -n1)
TOKEN_BODY=$(echo "$TOKEN_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -lt 200 ] || [ "$HTTP_CODE" -ge 300 ]; then
    echo -e "${RED}Erreur: impossible d'obtenir le token (HTTP ${HTTP_CODE})${NC}"
    echo "Réponse: $TOKEN_BODY"
    exit 1
fi

TOKEN=$(echo "$TOKEN_BODY" | tr -d '"' | tr -d '\n')
if [ -z "$TOKEN" ]; then
    echo -e "${RED}Erreur: réponse vide du serveur pour le token${NC}"
    echo "Réponse: $TOKEN_BODY"
    exit 1
fi

echo -e "${GREEN}Token obtenu${NC}"

# Modifier les feature flags
echo -e "\n${GREEN}[2/2] Modification des feature flags...${NC}"

FEATURES_JSON=$(cat "$FEATURES_FILE")
FEATURES_RESPONSE=$(curl -s -w "\n%{http_code}" -u admin:admin -X PATCH "${STACK_ADMIN_URL}/instances/${FQDN}/feature/flags" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$FEATURES_JSON")

HTTP_CODE=$(echo "$FEATURES_RESPONSE" | tail -n1)
FEATURES_BODY=$(echo "$FEATURES_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -lt 200 ] || [ "$HTTP_CODE" -ge 300 ]; then
    echo -e "${RED}Erreur: impossible de modifier les feature flags (HTTP ${HTTP_CODE})${NC}"
    echo "Réponse: $FEATURES_BODY"
    exit 1
fi

echo -e "${GREEN}✓ Feature flags modifiés avec succès!${NC}"

# Afficher la réponse si elle contient des données
if [ -n "$FEATURES_BODY" ] && [ "$FEATURES_BODY" != "null" ]; then
    echo -e "\n${YELLOW}Réponse du serveur:${NC}"
    echo "$FEATURES_BODY" | jq '.' 2>/dev/null || echo "$FEATURES_BODY"
fi
