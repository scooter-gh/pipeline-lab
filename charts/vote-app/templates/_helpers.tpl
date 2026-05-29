{{- define "vote-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "vote-app.labels" -}}
helm.sh/chart: {{ include "vote-app.name" . }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "vote-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "vote-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "vote-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
