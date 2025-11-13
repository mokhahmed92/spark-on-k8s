{{/*
Expand the name of the chart.
*/}}
{{- define "spark-on-k8s.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "spark-on-k8s.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "spark-on-k8s.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "spark-on-k8s.labels" -}}
helm.sh/chart: {{ include "spark-on-k8s.chart" . }}
{{ include "spark-on-k8s.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "spark-on-k8s.selectorLabels" -}}
app.kubernetes.io/name: {{ include "spark-on-k8s.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "spark-on-k8s.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "spark-on-k8s.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "spark-on-k8s.annotations" -}}
{{- with .Values.commonAnnotations }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Team namespace labels
*/}}
{{- define "spark-on-k8s.team.labels" -}}
{{- $labels := .labels }}
name: {{ .name }}
{{- range $key, $value := $labels }}
{{ $key }}: {{ $value }}
{{- end }}
{{- end }}

{{/*
Generate Spark Operator job namespaces list
*/}}
{{- define "spark-on-k8s.jobNamespaces" -}}
{{- $namespaces := list }}
{{- range .Values.teams.defaultScheduler }}
{{- $namespaces = append $namespaces .name }}
{{- end }}
{{- range .Values.teams.volcanoScheduler }}
{{- $namespaces = append $namespaces .name }}
{{- end }}
{{- toJson $namespaces }}
{{- end }}

{{/*
Check if team uses Volcano scheduler
*/}}
{{- define "spark-on-k8s.team.isVolcano" -}}
{{- $teamName := .name }}
{{- $isVolcano := false }}
{{- range $.Values.teams.volcanoScheduler }}
{{- if eq .name $teamName }}
{{- $isVolcano = true }}
{{- end }}
{{- end }}
{{- $isVolcano }}
{{- end }}
