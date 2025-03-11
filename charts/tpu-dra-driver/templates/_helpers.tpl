{{/*
Expand the name of the chart.
*/}}
{{- define "tpu-dra-driver.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "tpu-dra-driver.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Allow the release namespace to be overridden for multi-namespace deployments in combined charts
*/}}
{{- define "tpu-dra-driver.namespace" -}}
  {{- if .Values.namespaceOverride -}}
    {{- .Values.namespaceOverride -}}
  {{- else -}}
    {{- .Release.Namespace -}}
  {{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tpu-dra-driver.chart" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" $name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "tpu-dra-driver.labels" -}}
helm.sh/chart: {{ include "tpu-dra-driver.chart" . }}
{{ include "tpu-dra-driver.templateLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Template labels
*/}}
{{- define "tpu-dra-driver.templateLabels" -}}
app.kubernetes.io/name: {{ include "tpu-dra-driver.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Values.selectorLabelsOverride }}
{{ toYaml .Values.selectorLabelsOverride }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tpu-dra-driver.selectorLabels" -}}
{{- if .Values.selectorLabelsOverride -}}
{{ toYaml .Values.selectorLabelsOverride }}
{{- else -}}
{{ include "tpu-dra-driver.templateLabels" . }}
{{- end }}
{{- end }}

{{/*
Full image name with tag
*/}}
{{- define "tpu-dra-driver.fullimage" -}}
{{- $tag := printf "v%s" .Chart.AppVersion }}
{{- .Values.image.repository -}}:{{- .Values.image.tag | default $tag -}}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "tpu-dra-driver.serviceAccountName" -}}
{{- $name := printf "%s-service-account" (include "tpu-dra-driver.fullname" .) }}
{{- if .Values.serviceAccount.create }}
{{- default $name .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
