{{/* mega-config template */}}
{{- define "mega-config" -}}
{{- tpl (Files.Get "templates/mega-test.yaml") . -}}  {{/* 注意 templates/ 前缀 */}}
{{- end -}}

{{/* ultra-config template */}}
{{- define "ultra-config" -}}
{{- tpl (Files.Get "templates/ultra-test.yaml") . -}} {{/* 注意 templates/ 前缀 */}}
{{- end -}}