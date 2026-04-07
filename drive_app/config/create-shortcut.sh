#!/bin/bash

# Script pour créer un raccourci sur une instance Cozy via l'API de la stack
# Usage: ./create-shortcut.sh <FQDN> <JSON_FILE> [STACK_ADMIN_URL]
#
# Le fichier JSON doit contenir:
# {
#   "name": "Visio",
#   "path": "/",
#   "url": "https://example.com",
#   "icon": "JSON.encode(svg)" (optionnel),
#   "description": "Description du raccourci" (optionnel)
# }

set -euo pipefail

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction d'aide
usage() {
    echo "Usage: $0 <FQDN> <JSON_FILE> [STACK_ADMIN_URL] [COZY_URL]"
    echo ""
    echo "Arguments:"
    echo "  FQDN              Le FQDN de l'instance Cozy (ex: user.cozy.localhost)"
    echo "  JSON_FILE         Fichier JSON contenant les infos du raccourci"
    echo "  STACK_ADMIN_URL   URL du port admin de la stack (défaut: http://localhost:6060)"
    echo "  COZY_URL          URL de l'instance Cozy (défaut: déduit du FQDN)"
    echo ""
    echo "Format du JSON:"
    echo "  {"
    echo "    \"name\": \"Visio\","
    echo "    \"path\": \"/\","
    echo "    \"url\": \"https://example.com\","
    echo "    \"icon\": \"base64_encoded_icon\" (optionnel),"
    echo "    \"description\": \"Description\" (optionnel)"
    echo "  }"
    exit 1
}

# Vérification des arguments
if [ $# -lt 2 ]; then
    echo -e "${RED}Erreur: arguments manquants${NC}"
    usage
fi

FQDN="$1"
JSON_FILE="$2"
STACK_ADMIN_URL="${3:-http://localhost:6060}"
COZY_URL="${4:-}"

# Vérification que le fichier JSON existe
if [ ! -f "$JSON_FILE" ]; then
    echo -e "${RED}Erreur: le fichier JSON '$JSON_FILE' n'existe pas${NC}"
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

echo -e "${GREEN}Création de raccourcis pour l'instance: ${FQDN}${NC}"

# Déterminer l'URL de l'instance Cozy si non fournie
if [ -z "$COZY_URL" ]; then
    # Si STACK_ADMIN_URL contient localhost, on utilise http, sinon https
    if [[ "$STACK_ADMIN_URL" == *"localhost"* ]] || [[ "$STACK_ADMIN_URL" == *"127.0.0.1"* ]]; then
        COZY_URL="http://${FQDN}"
    else
        COZY_URL="https://${FQDN}"
    fi
fi

# Fonction pour créer un raccourci
create_shortcut() {
    local NAME="$1"
    local PATH_DIR="$2"
    local URL="$3"
    local ICON_B64="$4"
    local DESCRIPTION="$5"
    local FILE_PATH="$6"
    local FILE_NAME="$7"
    
    echo -e "${GREEN}[1/4] Création des métadonnées...${NC}"

    METADATA_ATTRS="{}"
    if [ -n "$ICON_B64" ] && [ "$ICON_B64" != "null" ] && [ "$ICON_B64" != "" ]; then
        # L'icône est toujours du SVG avec échappements JSON en entrée
        # Encoder la chaîne en JSON puis décoder pour s'assurer que tous les échappements JSON sont décodés
        METADATA_ATTRS=$(jq -n --arg icon "$ICON_B64" '{icon: $icon}')
    fi

    if [ -n "$DESCRIPTION" ] && [ "$DESCRIPTION" != "null" ] && [ "$DESCRIPTION" != "" ]; then
        METADATA_ATTRS=$(echo "$METADATA_ATTRS" | jq --arg desc "$DESCRIPTION" '. + {description: $desc}')
    fi
    METADATA_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${COZY_URL}/files/upload/metadata" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/vnd.api+json" \
        -d "{
            \"data\": {
                \"type\": \"io.cozy.files.metadata\",
                \"attributes\": ${METADATA_ATTRS}
            }
        }")
    HTTP_CODE=$(echo "$METADATA_RESPONSE" | tail -n1)
    METADATA_BODY=$(echo "$METADATA_RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" -lt 200 ] || [ "$HTTP_CODE" -ge 300 ]; then
        echo -e "${RED}Erreur: impossible de créer les métadonnées (HTTP ${HTTP_CODE})${NC}"
        echo "Réponse: $METADATA_BODY"
        return 1
    fi

    METADATA_ID=$(echo "$METADATA_BODY" | jq -r '.data.id // .data._id // empty')

    if [ -z "$METADATA_ID" ] || [ "$METADATA_ID" == "null" ]; then
        echo -e "${RED}Erreur: impossible de créer les métadonnées${NC}"
        echo "Réponse: $METADATA_BODY"
        return 1
    fi

    echo -e "${GREEN}Métadonnées créées (ID: ${METADATA_ID})${NC}"

    # Étape 3: Obtenir ou créer le répertoire parent
    echo -e "\n${GREEN}[2/4] Préparation du répertoire...${NC}"

    DIRECTORY_ID=""
    if [ "$PATH_DIR" == "/" ]; then
        # Le fichier va à la racine, on doit obtenir l'ID du répertoire racine
        ROOT_RESPONSE=$(curl -s -X GET "${COZY_URL}/files/metadata?Path=/" \
            -H "Authorization: Bearer ${TOKEN}")
        DIRECTORY_ID=$(echo "$ROOT_RESPONSE" | jq -r '.data.id // .data._id // empty')
        
        if [ -z "$DIRECTORY_ID" ] || [ "$DIRECTORY_ID" == "null" ]; then
            echo -e "${RED}Erreur: impossible d'obtenir le répertoire racine${NC}"
            echo "Réponse: $ROOT_RESPONSE"
            return 1
        fi
    else
        # Créer le répertoire récursivement si nécessaire
        CURRENT_PATH=""
        DIRECTORY_ID=""
        
        # Obtenir d'abord le répertoire racine
        ROOT_RESPONSE=$(curl -s -X GET "${COZY_URL}/files/metadata?Path=/" \
            -H "Authorization: Bearer ${TOKEN}")
        DIRECTORY_ID=$(echo "$ROOT_RESPONSE" | jq -r '.data.id // .data._id // empty')
        
        # Parcourir chaque segment du chemin
        IFS='/' read -ra PATH_SEGMENTS <<< "$PATH_DIR"
        for SEGMENT in "${PATH_SEGMENTS[@]}"; do
            if [ -z "$SEGMENT" ]; then
                continue
            fi
            
            CURRENT_PATH="${CURRENT_PATH}/${SEGMENT}"
            
            # Vérifier si le répertoire existe
            DIR_RESPONSE=$(curl -s -X GET "${COZY_URL}/files/metadata?Path=${CURRENT_PATH}" \
                -H "Authorization: Bearer ${TOKEN}")
            
            EXISTING_ID=$(echo "$DIR_RESPONSE" | jq -r '.data.id // .data._id // empty')
            
            if [ -n "$EXISTING_ID" ] && [ "$EXISTING_ID" != "null" ]; then
                DIRECTORY_ID="$EXISTING_ID"
            else
                # Créer le répertoire
                CREATE_DIR_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${COZY_URL}/files/${DIRECTORY_ID}?Type=directory&Name=${SEGMENT}" \
    -H "Authorization: Bearer ${TOKEN}")
                
                HTTP_CODE=$(echo "$CREATE_DIR_RESPONSE" | tail -n1)
                CREATE_DIR_BODY=$(echo "$CREATE_DIR_RESPONSE" | sed '$d')
                
                if [ "$HTTP_CODE" -lt 200 ] || [ "$HTTP_CODE" -ge 300 ]; then
                    echo -e "${RED}Erreur: impossible de créer le répertoire ${CURRENT_PATH} (HTTP ${HTTP_CODE})${NC}"
                    echo "Réponse: $CREATE_DIR_BODY"
                    return 1
                fi
                
                DIRECTORY_ID=$(echo "$CREATE_DIR_BODY" | jq -r '.data.id // .data._id // empty')
                
                if [ -z "$DIRECTORY_ID" ] || [ "$DIRECTORY_ID" == "null" ]; then
                    echo -e "${RED}Erreur: impossible de créer le répertoire ${CURRENT_PATH}${NC}"
                    echo "Réponse: $CREATE_DIR_BODY"
                    return 1
                fi
            fi
        done
    fi

    echo -e "${GREEN}Répertoire prêt (ID: ${DIRECTORY_ID})${NC}"

    # Étape 4: Créer le fichier raccourci
    echo -e "\n${GREEN}[3/4] Création du fichier raccourci...${NC}"

    # Contenu du fichier raccourci au format InternetShortcut
    SHORTCUT_CONTENT="[InternetShortcut]
URL=${URL}"

    # Vérifier si le fichier existe déjà
    EXISTING_FILE_RESPONSE=$(curl -s -X GET "${COZY_URL}/files/metadata?Path=${FILE_PATH}" \
        -H "Authorization: Bearer ${TOKEN}")

    EXISTING_FILE_ID=$(echo "$EXISTING_FILE_RESPONSE" | jq -r '.data.id // .data._id // empty')

    # Encoder les paramètres pour l'URL
    FILE_NAME_ENCODED=$(printf '%s' "$FILE_NAME" | jq -sRr @uri)
    METADATA_ID_ENCODED=$(printf '%s' "$METADATA_ID" | jq -sRr @uri)

    if [ -n "$EXISTING_FILE_ID" ] && [ "$EXISTING_FILE_ID" != "null" ]; then
        # Mettre à jour le fichier existant
        echo -e "${YELLOW}Le fichier existe déjà, mise à jour...${NC}"
        FILE_RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "${COZY_URL}/files/${EXISTING_FILE_ID}?Type=file&Name=${FILE_NAME_ENCODED}&MetadataID=${METADATA_ID_ENCODED}" \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: text/plain" \
            -H "Accept: application/json" \
            --data-binary "$SHORTCUT_CONTENT")
    else
        # Créer le nouveau fichier
        FILE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${COZY_URL}/files/${DIRECTORY_ID}?Type=file&Name=${FILE_NAME_ENCODED}&MetadataID=${METADATA_ID_ENCODED}" \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: text/plain" \
            -H "Accept: application/json" \
            --data-binary "$SHORTCUT_CONTENT")
    fi

    HTTP_CODE=$(echo "$FILE_RESPONSE" | tail -n1)
    FILE_BODY=$(echo "$FILE_RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" -lt 200 ] || [ "$HTTP_CODE" -ge 300 ]; then
        echo -e "${RED}Erreur: impossible de créer le fichier raccourci (HTTP ${HTTP_CODE})${NC}"
        echo "Réponse: $FILE_BODY"
        return 1
    fi

    FILE_ID=$(echo "$FILE_BODY" | jq -r '.data.id // .data._id // empty')

    if [ -z "$FILE_ID" ] || [ "$FILE_ID" == "null" ]; then
        echo -e "${RED}Erreur: impossible de créer le fichier raccourci${NC}"
        echo "Réponse: $FILE_BODY"
        return 1
    fi

    echo -e "${GREEN}✓ Raccourci créé avec succès!${NC}"
    echo -e "${GREEN}  Fichier ID: ${FILE_ID}${NC}"
    echo -e "${GREEN}  Chemin: ${FILE_PATH}${NC}"
    
    return 0
}

# Vérifier si le JSON est un tableau ou un objet
JSON_TYPE=$(jq -r 'if type == "array" then "array" else "object" end' "$JSON_FILE")

if [ "$JSON_TYPE" == "array" ]; then
    # Traiter un tableau de raccourcis
    SHORTCUT_COUNT=$(jq '. | length' "$JSON_FILE")
    echo -e "${GREEN}Nombre de raccourcis à créer: ${SHORTCUT_COUNT}${NC}\n"
    
    # Obtenir le token une seule fois pour tous les raccourcis
    echo -e "${GREEN}[Préparation] Obtention du token CLI...${NC}"
    TOKEN_RESPONSE=$(curl -s -w "\n%{http_code}" -u admin:admin -X POST "${STACK_ADMIN_URL}/instances/token?Domain=${FQDN}&Audience=cli&Scope=io.cozy.files")
    
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
    
    echo -e "${GREEN}Token obtenu${NC}\n"
    
    # Traiter chaque raccourci
    for i in $(seq 0 $((SHORTCUT_COUNT - 1))); do
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}Raccourci $((i + 1))/${SHORTCUT_COUNT}${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
        
        # Extraire les données du raccourci
        SHORTCUT_JSON=$(jq -r ".[$i]" "$JSON_FILE")
        NAME=$(echo "$SHORTCUT_JSON" | jq -r '.name')
        PATH_DIR=$(echo "$SHORTCUT_JSON" | jq -r '.path // "/Settings"')
        URL=$(echo "$SHORTCUT_JSON" | jq -r '.url')
        ICON_B64=$(echo "$SHORTCUT_JSON" | jq -r '.icon // ""')
        DESCRIPTION=$(echo "$SHORTCUT_JSON" | jq -r '.description // ""')
        
        # Validation des champs requis
        if [ "$NAME" == "null" ] || [ -z "$NAME" ]; then
            echo -e "${RED}Erreur: le champ 'name' est requis pour le raccourci #$((i + 1))${NC}"
            continue
        fi
        
        if [ "$URL" == "null" ] || [ -z "$URL" ]; then
            echo -e "${RED}Erreur: le champ 'url' est requis pour le raccourci #$((i + 1))${NC}"
            continue
        fi
        
        # Normalisation du chemin
        if [ "$PATH_DIR" != "/" ]; then
            PATH_DIR="${PATH_DIR%/}"
        fi
        
        FILE_NAME="${NAME}.url"
        FILE_PATH="${PATH_DIR}/${FILE_NAME}"
        
        echo -e "${YELLOW}Nom: ${NAME}${NC}"
        echo -e "${YELLOW}Chemin: ${FILE_PATH}${NC}"
        echo -e "${YELLOW}URL: ${URL}${NC}\n"
        
        # Créer le raccourci (fonction réutilisable)
        create_shortcut "$NAME" "$PATH_DIR" "$URL" "$ICON_B64" "$DESCRIPTION" "$FILE_PATH" "$FILE_NAME"
        
        echo ""
    done
    
    echo -e "${GREEN}✓ Tous les raccourcis ont été traités${NC}"
    exit 0
else
    # Traiter un objet unique (rétrocompatibilité)
    NAME=$(jq -r '.name' "$JSON_FILE")
    PATH_DIR=$(jq -r '.path // "/Settings"' "$JSON_FILE")
    URL=$(jq -r '.url' "$JSON_FILE")
    ICON_B64=$(jq -r '.icon // ""' "$JSON_FILE")
    DESCRIPTION=$(jq -r '.description // ""' "$JSON_FILE")
    
    # Validation des champs requis
    if [ "$NAME" == "null" ] || [ -z "$NAME" ]; then
        echo -e "${RED}Erreur: le champ 'name' est requis dans le JSON${NC}"
        exit 1
    fi
    
    if [ "$URL" == "null" ] || [ -z "$URL" ]; then
        echo -e "${RED}Erreur: le champ 'url' est requis dans le JSON${NC}"
        exit 1
    fi
    
    # Normalisation du chemin
    if [ "$PATH_DIR" != "/" ]; then
        PATH_DIR="${PATH_DIR%/}"
    fi
    
    FILE_NAME="${NAME}.url"
    FILE_PATH="${PATH_DIR}/${FILE_NAME}"
    
    echo -e "${YELLOW}Nom du raccourci: ${NAME}${NC}"
    echo -e "${YELLOW}Chemin: ${FILE_PATH}${NC}"
    echo -e "${YELLOW}URL: ${URL}${NC}\n"
    
    # Obtenir le token pour un objet unique
    echo -e "\n${GREEN}[1/4] Obtention du token CLI...${NC}"
    TOKEN_RESPONSE=$(curl -s -w "\n%{http_code}" -u admin:admin -X POST "${STACK_ADMIN_URL}/instances/token?Domain=${FQDN}&Audience=cli&Scope=io.cozy.files")

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

    echo -e "${GREEN}Token obtenu${NC}\n"
    
    # Créer le raccourci unique
    create_shortcut "$NAME" "$PATH_DIR" "$URL" "$ICON_B64" "$DESCRIPTION" "$FILE_PATH" "$FILE_NAME"
fi

