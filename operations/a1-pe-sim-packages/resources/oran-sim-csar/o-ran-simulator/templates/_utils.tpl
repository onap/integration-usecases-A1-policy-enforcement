{{/* vim: set filetype=mustache: */}}

{{/*
  Functions here define utilities for unique name/labels generation
*/}}


{{/* Generate Deployment labels */}}
{{/* Input: Dict with "dot", "name" and "spec" keys */}}
{{- define "handover-simulator.utils.labels" -}}
{{- $name := .name -}}
{{- $spec := .spec -}}
{{- with .dot -}}
app: {{ $name }}
{{ include "handover-simulator.common.labels" . }}
{{- end -}}
{{- end -}}


{{/* Generate Resource name based unique between different chart instances */}}
{{/* Input: List with strings */}}
{{/* Output: Provided elements joined with dash and trimmed according to DNS requirements */}}
{{- define "handover-simulator.utils.name" -}}
res-{{- join "-" . | trunc 59 | trimSuffix "-" -}}
{{- end -}}
