{{/* vim: set filetype=mustache: */}}

{{/*
  Functions here are intended for Deployment resources use only
*/}}


{{/* Generate Deployment's container section */}}
{{/* Input: Dict with "dot", "name" and "spec" keys */}}
{{- define "handover-simulator.deployment.containers" -}}
{{- $name := .name -}}
{{- $spec := .spec -}}
{{- $dot := . -}}
{{- with .dot -}}
{{- range $owner, $containerSpec := $spec.containers }}
- name: {{ $owner }}
  image: "{{ $containerSpec.image.repository }}:{{ $containerSpec.image.tag }}"
  imagePullPolicy: {{ $containerSpec.image.pullPolicy }}
  {{- with $containerSpec.env }}
  env:
    {{- range $containerSpec.env }}
    {{/* This is ugly but helm's tpl required root object */}}
    - name: {{ .name }}
      value: {{ tpl .value $dot.dot | quote }}
    {{- end }}
  {{- end }}
  {{- with $containerSpec.command }}
  command:
    - {{ $containerSpec.command }}
  {{- end }}
  {{- with $containerSpec.args }}
  args:
    - {{ $containerSpec.args }}
  {{- end }}
  {{- with $containerSpec.volumeMounts }}
  volumeMounts:
    {{- range $containerSpec.volumeMounts }}
    - name: {{ .name }}
      mountPath: {{ .mountPath }}
    {{- end }}
  {{- end }}
  ports:
  {{- range $spec.service.ports }}
  {{- if eq $owner .owner }}
    - name: {{ .name }}
      containerPort: {{ .port }}
      protocol: TCP
  {{- end }}
  {{- end }}
  {{- with $containerSpec.volumes }}
  volumes: {{ toYaml . | nindent 4 }}
  {{- end }}
  {{- with $spec.livenessProbe }}
  livenessProbe:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $spec.readinessProbe }}
  readinessProbe:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $spec.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
{{- end -}}
{{- end -}}
