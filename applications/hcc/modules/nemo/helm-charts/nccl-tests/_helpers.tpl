{{/* mega-config template */}}
{{- define "mega-config" -}}
{{- tpl (Files.Get "templates/mega-test.yaml") . -}} 
{{- end -}}

{{/* ultra-config template */}}
{{- define "ultra-config" -}}
{{- tpl (Files.Get "templates/ultra-test.yaml") . -}}
{{- end -}}