# ==============================================================================
# templates/_helpers.tpl
# ==============================================================================
{{- define "openslides.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "openslides.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "openslides.labels" -}}
helm.sh/chart: {{ include "openslides.name" . }}
app.kubernetes.io/name: {{ include "openslides.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "openslides.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openslides.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

