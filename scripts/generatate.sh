#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_DIR="${1:-}"
REPO_NAME="${2:-}"
BASE_PACKAGE="${3:-}"
APP_CLASS="${4:-}"

if [[ -z "${TEMPLATE_DIR}" || -z "${REPO_NAME}" || -z "${BASE_PACKAGE}" || -z "${APP_CLASS}" ]]; then
  echo "Usage: generate.sh <template_dir> <repo_name> <base_package> <application_class>"
  exit 1
fi

OLD_PACKAGE="com.bankofabyssinia.spring_template"
OLD_PACKAGE_PATH="com/bankofabyssinia/spring_template"
NEW_PACKAGE_PATH="${BASE_PACKAGE//./\/}"

# 1) Replace package strings in all Java files
find "${TEMPLATE_DIR}/src" -type f -name "*.java" -print0 | xargs -0 sed -i \
  "s/${OLD_PACKAGE}/${BASE_PACKAGE}/g"

# 2) Move directories for main + test sources (if they exist)
for ROOT in "src/main/java" "src/test/java"; do
  if [[ -d "${TEMPLATE_DIR}/${ROOT}/${OLD_PACKAGE_PATH}" ]]; then
    mkdir -p "${TEMPLATE_DIR}/${ROOT}/${NEW_PACKAGE_PATH}"
    shopt -s dotglob
    mv "${TEMPLATE_DIR}/${ROOT}/${OLD_PACKAGE_PATH}/"* "${TEMPLATE_DIR}/${ROOT}/${NEW_PACKAGE_PATH}/" || true
    shopt -u dotglob
    rmdir -p "${TEMPLATE_DIR}/${ROOT}/${OLD_PACKAGE_PATH}" 2>/dev/null || true
  fi
done

# 3) Rename main application class file + update references
OLD_MAIN_FILE="${TEMPLATE_DIR}/src/main/java/${NEW_PACKAGE_PATH}/SpringTemplateApplication.java"
NEW_MAIN_FILE="${TEMPLATE_DIR}/src/main/java/${NEW_PACKAGE_PATH}/${APP_CLASS}.java"

if [[ -f "${OLD_MAIN_FILE}" ]]; then
  mv "${OLD_MAIN_FILE}" "${NEW_MAIN_FILE}"
fi

find "${TEMPLATE_DIR}/src" -type f -name "*.java" -print0 | xargs -0 sed -i \
  -e "s/SpringTemplateApplication/${APP_CLASS}/g"

# 4) Update pom.xml (Maven)
POM="${TEMPLATE_DIR}/pom.xml"
if [[ -f "${POM}" ]]; then
  GROUP_ID="${BASE_PACKAGE%.*}"
  if [[ "${GROUP_ID}" == "${BASE_PACKAGE}" ]]; then
    GROUP_ID="${BASE_PACKAGE}"
  fi

  sed -i "s#<groupId>com\\.bankofabyssinia</groupId>#<groupId>${GROUP_ID}</groupId>#g" "${POM}"
  sed -i "s#<artifactId>spring-template</artifactId>#<artifactId>${REPO_NAME}</artifactId>#g" "${POM}"

  if grep -q "<name/>" "${POM}"; then
    sed -i "s#<name/>#<name>${REPO_NAME}</name>#g" "${POM}"
  else
    sed -i "s#<name>.*</name>#<name>${REPO_NAME}</name>#g" "${POM}"
  fi
fi

echo "Generated project:"
echo "  repo_name=${REPO_NAME}"
echo "  base_package=${BASE_PACKAGE}"
echo "  application_class=${APP_CLASS}"