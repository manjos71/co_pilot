#!/usr/bin/env bash
# Gera o scaffold Android do Flutter com o package ai.gcodeflow SEM sobrescrever
# os arquivos deste projeto (lib/, pubspec.yaml, AndroidManifest.xml, Kotlin).
set -euo pipefail

cd "$(dirname "$0")"

command -v flutter >/dev/null || { echo "Flutter não encontrado no PATH."; exit 1; }

# --org ai + --project-name gcodeflow  =>  applicationId = ai.gcodeflow
flutter create --org ai --project-name gcodeflow --platforms android .

# O template cria um MainActivity.kt em outro caminho; remove duplicatas de ai.gcodeflow.
find android/app/src/main/kotlin -name 'MainActivity.kt' -not -path '*/ai/gcodeflow/*' -delete 2>/dev/null || true

rm -f test/widget_test.dart
flutter pub get
echo
echo "Pronto. Rode:  flutter run          (debug no aparelho)"
echo "              flutter build apk --release"
