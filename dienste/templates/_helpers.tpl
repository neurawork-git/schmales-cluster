{{/* Name eines Teils: <release>-<teil>, z. B. dienste-postgres */}}
{{- define "dienste.name" -}}
{{- printf "%s-%s" .root.Release.Name .teil | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Labels. app.kubernetes.io/instance = Name des Release = Name der Argo-CD-Anwendung:
     daran erkennt Argo CD, welche Objekte zu ihm gehören. */}}
{{- define "dienste.labels" -}}
app.kubernetes.io/name: {{ .teil }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .root.Chart.Name .root.Chart.Version }}
{{- end -}}

{{/* Selektor: verbindet Service und Pods. Nach dem ersten Ausrollen nicht mehr ändern. */}}
{{- define "dienste.selector" -}}
app.kubernetes.io/name: {{ .teil }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
{{- end -}}

{{/* Namespace der Grundausstattung (Eingang, Argo CD, KEDA). Die Pipeline rollt sie dorthin aus. */}}
{{- define "dienste.grundausstattung" -}}grundausstattung{{- end -}}

{{/* Geheimnis mit Datenbank-Passwort und Schlüssel von Open WebUI. Legt die Pipeline an, nicht das Chart. */}}
{{- define "dienste.geheim" -}}{{ .Release.Name }}-geheim{{- end -}}

{{/* Ein Ingress: Adresse <vorsatz>.<basis> → Service:Port im angegebenen Namespace.
     Erwartet: root, teil, namespace, vorsatz, service, port */}}
{{- define "dienste.ingress" -}}
{{- $host := printf "%s.%s" .vorsatz .root.Values.eingang.basis -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "dienste.name" . }}
  namespace: {{ .namespace }}
  labels: {{- include "dienste.labels" . | nindent 4 }}
  {{- if .root.Values.eingang.tls }}
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
  {{- end }}
spec:
  ingressClassName: traefik
  {{- if .root.Values.eingang.tls }}
  tls:
    - hosts: [{{ $host }}]
      secretName: {{ include "dienste.name" . }}-tls
  {{- end }}
  rules:
    - host: {{ $host }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ .service }}
                port:
                  number: {{ .port }}
{{- end -}}
