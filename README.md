# schmales-cluster: eigene Dienste auf einem kleinen Kubernetes-Cluster

## Für wen

Devs und Plattform-Verantwortliche, die eigene Dienste wie Open WebUI, eine Datenbank und einen selbst gebauten MCP-Server heute per Compose auf einer VM betreiben und sie auf ein kleines, verwaltetes Cluster in Azure bringen wollen, ohne Kubernetes in der Tiefe zu lernen.

## Was es tut

Eine OpenTofu-Datei legt das Cluster an, zwei Helm-Charts beschreiben, was darauf läuft, und eine GitHub Action rollt bei jedem Push aus; du pflegst nur `dienste/values.yaml`.

| Datei | Was darin steht |
|---|---|
| `cluster/main.tf` | das Cluster in Azure: Ressourcengruppe, AKS im kostenlosen Tarif mit zwei Rechnern und KEDA als Zusatz von AKS, eine Identität, mit der sich die Pipeline ohne Passwort anmeldet |
| `grundausstattung/` | was jedes Cluster einmal braucht, aus fremden Charts: Eingang (Traefik), Zertifikate (cert-manager), Oberfläche (Argo CD), Skalieren auf null (HTTP-Zusatz für KEDA) |
| `dienste/` | deine Dienste: MCP-Dienst, Postgres, Open WebUI; **`dienste/values.yaml` ist die Datei, die du änderst** |
| `.github/workflows/deploy.yml` | rollt bei jedem Push auf `main` erst die Grundausstattung, dann die Dienste aus und nennt am Ende die öffentliche IP |

Die Werte, die du pflegst:

```yaml
eingang:
  basis: ""          # leer: noch keine Adressen. Zum Testen <IP>.nip.io, für den Betrieb der eigene DNS-Name
  tls: false         # true, sobald ein eigener DNS-Name auf die IP zeigt
mcp:
  image: traefik/whoami:v1.10   # Platzhalter für deinen eigenen Dienst
  port: 80
  aufNull: true      # ohne Anfragen null Kopien, die nächste Anfrage weckt den Dienst
openwebui:
  image: ghcr.io/open-webui/open-webui:v0.13.3
  speicher: 5Gi
postgres:
  speicher: 8Gi
argocd:
  repo: https://github.com/<organisation>/<repo>
```

Daraus entstehen drei Adressen: `chat.<basis>` (Open WebUI), `mcp.<basis>` (MCP-Dienst), `argo.<basis>` (Argo CD).

## Was du brauchst

- **Ein Azure-Abo**, in dem du Rollen vergeben darfst (Rolle „Besitzer“, oder „Mitwirkender“ zusammen mit „Benutzerzugriffsadministrator“). OpenTofu gibt der Pipeline das Recht, dieses eine Cluster anzusprechen.
- **Ein GitHub-Konto**, unter dem du ein Repo anlegen darfst.
- **WSL mit Ubuntu**, eingerichtet wie in Teil 1 der Reihe. Alle Befehle hier laufen in einem Terminal in WSL; Git und curl bringt Ubuntu mit.
- **Fünf Werkzeuge**, installiert nach den Anleitungen der Hersteller (`sudo` fragt nach deinem Passwort):
  ```bash
  # az (Azure CLI), learn.microsoft.com/cli/azure/install-azure-cli-linux
  curl -fsSL 'https://azurecliprod.blob.core.windows.net/$root/deb_install.sh' | sudo bash

  # tofu (OpenTofu), opentofu.org/docs/intro/install/deb/
  curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh
  chmod +x install-opentofu.sh
  ./install-opentofu.sh --install-method deb
  rm -f install-opentofu.sh

  # helm, Version 4
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 | bash

  # kubectl
  curl -fsSLO "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -m 0755 kubectl /usr/local/bin/kubectl

  # gh (GitHub CLI), github.com/cli/cli/blob/trunk/docs/install_linux.md
  (type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)) \
  	&& sudo mkdir -p -m 755 /etc/apt/keyrings \
  	&& out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  	&& cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
  	&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  	&& sudo mkdir -p -m 755 /etc/apt/sources.list.d \
  	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  	&& sudo apt update \
  	&& sudo apt install gh -y
  ```
  Danach einmal `az login` und `gh auth login`.

## Installation

1. **Eigenes Repo und Cluster anlegen.** Auf GitHub ein neues, leeres Repo anlegen (*New repository*, ohne README); das wird dein Repo, in das du pushst. Dann den Präfix holen, mit dem GitHub die Läufe dieses Repos ausweist:
   ```bash
   gh api repos/<organisation>/<repo>/actions/oidc/customization/sub --jq .sub_claim_prefix
   ```
   Im Ordner dieser Vorlage:
   ```bash
   cd cluster
   tofu init
   tofu apply
   ```
   `tofu apply` fragt nach `github_oidc_sub_praefix`, dort die Ausgabe des `gh`-Befehls einfügen, und nach deinem Abo (`az account show --query id -o tsv`). Nach `yes` legt es fünf Ressourcen an, das dauert rund fünf Minuten. Am Ende steht `github_variablen` mit fünf Werten. Trag sie in deinem Repo unter *Settings → Secrets and variables → Actions → Variables* ein, je *New repository variable*, Name genau wie in der Ausgabe (etwa `AZURE_CLIENT_ID`), Wert ohne Anführungszeichen.
2. **Vorlage ins Repo pushen.** In `dienste/values.yaml` bei `argocd.repo` die Adresse deines Repos eintragen. Dann im Ordner dieser Vorlage:
   ```bash
   cd ..
   git init -b main
   git add .
   git commit -m "Schmales Cluster"
   git remote add origin https://github.com/<organisation>/<repo>.git
   git push -u origin main
   ```
   Der Push startet die Pipeline. Sie rollt Grundausstattung und Dienste aus, der erste Lauf braucht einige Minuten. Jeder Lauf setzt durch, was im Repo steht, auch gegen Änderungen von Hand am Cluster und gegen Felder, die Azure selbst ergänzt. In der Zusammenfassung des Laufs (*Actions → deploy → Summary*) steht die öffentliche IP des Eingangs. Einen Lauf von Hand startest du unter *Actions → deploy → Run workflow*.
3. **Adressen eintragen.** In `dienste/values.yaml` bei `eingang.basis` die IP mit `.nip.io` eintragen, etwa `basis: "203.0.113.10.nip.io"`, committen, pushen. Nach dem Lauf öffnet `http://chat.203.0.113.10.nip.io` Open WebUI. **Leg sofort das erste Konto an:** Das erste Konto wird Administrator, und die Adresse ist für jeden im Internet erreichbar.

**Abends abbauen:** `tofu destroy` in `cluster/` löscht die Ressourcengruppe mit allem darin, auch die Platten mit den Daten.

## Beispiel

Eingabe (`beispiel/eingabe.yaml`): `dienste/values.yaml` nach Schritt 3, mit der Basis `203.0.113.10.nip.io` und dem Repo `beispiel-org/schmales-cluster`.

Ausgabe (`beispiel/erwartet.yaml`): was Helm daraus macht, erzeugt mit `helm template dienste ./dienste --namespace dienste -f beispiel/eingabe.yaml`, genau so, wie die Pipeline es ausrollt. Zwölf Objekte; hier die Adresse von Open WebUI und der MCP-Dienst auf null, gekürzt um die Labels:

```yaml
kind: Ingress
metadata:
  name: dienste-openwebui
  namespace: dienste
spec:
  ingressClassName: traefik
  rules:
    - host: chat.203.0.113.10.nip.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: dienste-openwebui
                port:
                  number: 80
---
kind: Ingress
metadata:
  name: dienste-mcp
  namespace: grundausstattung
spec:
  ingressClassName: traefik
  rules:
    - host: mcp.203.0.113.10.nip.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: keda-add-ons-http-interceptor-proxy
                port:
                  number: 8080
---
kind: HTTPScaledObject
metadata:
  name: dienste-mcp
spec:
  hosts:
    - mcp.203.0.113.10.nip.io
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: dienste-mcp
    service: dienste-mcp
    port: 80
  replicas:
    min: 0
    max: 1
  scaledownPeriod: 60      # Sekunden ohne Anfrage, bis auf null gestellt wird
```

Die Kette der Ports: `chat.…` → Traefik → Service `dienste-openwebui` auf Port 80 → Container auf Port 8080. Beim MCP-Dienst steht dazwischen der Abfang-Dienst des KEDA-HTTP-Zusatzes auf Port 8080: Er weckt den Dienst, hält die Anfrage, bis eine Kopie bereit ist, und reicht sie an `dienste-mcp` Port 80 weiter.

## Adressen und Zertifikate

**Zum Testen: `<IP>.nip.io`, ohne Zertifikat.** Der öffentliche Dienst nip.io beantwortet `chat.203.0.113.10.nip.io` mit der IP `203.0.113.10`, ganz ohne DNS-Eintrag; nip.io sieht dabei nur die Namensanfrage, nicht deine Daten. Alles läuft über http. Jeder im Internet kann diese Adressen erreichen, darum nur Testdaten. `tls` bleibt `false`; das Chart bricht mit einer Meldung ab, wenn du für eine nip.io-Adresse ein Zertifikat verlangst.

**Für den Betrieb: eigener DNS-Name mit Zertifikat.**

1. Beim DNS-Anbieter einen A-Eintrag `*.<basis>` auf die öffentliche IP setzen, etwa `*.demo.example.org`.
2. In `dienste/values.yaml`: `basis: "demo.example.org"` und `tls: true`, pushen.

cert-manager holt dann für `chat`, `mcp` und `argo` je ein Zertifikat bei Let's Encrypt und verlängert es selbst. Let's Encrypt stellt für dieselben Namen nur wenige Zertifikate je Woche aus; `tls` darum nicht ständig hin- und herschalten.

Die IP gehört dem Cluster, solange es steht. Nach `tofu destroy` und einem neuen `tofu apply` gibt es eine neue IP: Schritt 3 wiederholen bzw. den DNS-Eintrag anpassen. Nach dem endgültigen Abbau den DNS-Eintrag löschen, sonst zeigt dein Name auf eine IP, die Azure jemand anderem gibt.

## Deinen eigenen Dienst eintragen

Im Block `mcp` von `dienste/values.yaml` stehen Image und Port:

```yaml
mcp:
  image: ghcr.io/<organisation>/<dein-dienst>:1.0.0   # öffentliches Image, fester Tag
  port: 8000                                          # Port, auf dem der Container lauscht
  aufNull: true
```

Das Image baut das Repo deines Dienstes, etwa mit einer GitHub Action, die es in die GitHub Container Registry legt. Hier steht nur sein Name mit einem festen Tag: Ein neuer Stand ist ein neuer Tag in dieser Zeile, committet und gepusht.

**Einfacher Einstieg:** `aufNull: false` — der Dienst läuft dauerhaft in einer Kopie, ohne Abfang-Dienst und ohne Wartezeit bei der ersten Anfrage; auf null stellst du um, wenn er läuft.

## Argo CD öffnen

Adresse `http://argo.<basis>`, Benutzer `admin`. Das Startpasswort liest du so aus, erst den Zugang einrichten (der Befehl steht auch in der Ausgabe von `tofu apply` unter `kubectl_kontext`):

```bash
az aks get-credentials --resource-group rg-schmales-cluster --name aks-schmales-cluster --context schmales-cluster
kubectl --context schmales-cluster -n grundausstattung get secret argocd-initial-admin-secret -o go-template='{{.data.password | base64decode}}'
```

Argo CD zeigt die Anwendung `dienste`: grün, wenn das Cluster dem Repo entspricht, gelb „OutOfSync“, sobald jemand etwas direkt im Cluster ändert. Argo CD gleicht selbst nichts ab; ausgerollt wird nur über die Pipeline. Die Abweichung wird in der Oberfläche angezeigt. Eine Benachrichtigung per E-Mail ist ein Zusatz: Argo CD Notifications mit einem eigenen Mailzugang (SMTP), den die Vorlage nicht mitbringt. Ist dein Repo privat, braucht Argo CD Lesezugriff: in der Oberfläche unter *Settings → Repositories* mit einem Token, das nur lesen darf.

## Lokal rendern ohne Azure

Was die Pipeline ausrollen würde, siehst du ohne Azure, ohne Anmeldung und ohne Cluster. Dafür reichen Git und Helm, im Terminal in WSL.

**1. Vorlage holen.**

```bash
git clone https://github.com/neurawork-git/schmales-cluster.git
cd schmales-cluster
```

**2. Rendern und darin suchen.**

```bash
helm template dienste ./dienste -f dienste/values.yaml > gerendert.yaml
grep "^kind:" gerendert.yaml
grep -E "containerPort|targetPort|port:" gerendert.yaml
```

Die erste Suche listet alle Objekte, die zweite die Kette der Ports. Solange `basis` leer ist, findet `grep "host:" gerendert.yaml` nichts. Trag in `dienste/values.yaml` `basis: "203.0.113.10.nip.io"` ein und rendere erneut:

```bash
helm template dienste ./dienste -f dienste/values.yaml > gerendert.yaml
grep "host:" gerendert.yaml
```

Jetzt stehen die drei Adressen darin: `chat.`, `mcp.` und `argo.203.0.113.10.nip.io`. Die Templates bleiben gleich, nur die Werte wandern an ihre Stellen.

## Was es kostet

Die Steuerungsebene im kostenlosen Tarif kostet nichts. Bezahlt werden die zwei Rechner (`Standard_D4as_v7`), solange sie laufen, dazu die Platten von Postgres und Open WebUI, die öffentliche IP und der Load Balancer. Die aktuellen Preise für deine Region: `azure.microsoft.com/de-de/pricing/details/kubernetes-service/` und der Preisrechner unter `azure.microsoft.com/de-de/pricing/calculator/`. Was tatsächlich anfällt, zeigt das Azure-Portal in der Kostenanalyse der Ressourcengruppe `rg-schmales-cluster`. Ein Cluster, das nur zum Testen da ist, baust du abends mit `tofu destroy` ab.

## Wann es nicht passt

- **Der Dienst darf kurz weg sein, und es gibt nur eine Umgebung.** Dann reicht Compose auf einer VM.
- **Mehrere Umgebungen oder Kunden.** Die Vorlage beschreibt genau eine Umgebung mit einer `values.yaml`. Für weitere braucht es je Umgebung einen eigenen Satz Werte und eine eigene Pipeline.
- **Open WebUI in mehreren Kopien.** Dafür braucht Open WebUI einen gemeinsamen Zwischenspeicher wie Redis und eine Ablage, die mehrere Rechner zugleich beschreiben können. Die Vorlage hält bewusst eine Kopie auf einer Platte.
- **Echte Daten vor dem eigenen DNS-Namen.** Über `<IP>.nip.io` läuft alles unverschlüsselt und öffentlich.
- **Du darfst im Abo keine Rollen vergeben.** Dann scheitert `tofu apply` an der Rolle für die Pipeline; das muss jemand mit diesem Recht ausführen.
- **Das Cluster darf nicht aus dem Internet erreichbar sein.** Die Vorlage hat einen öffentlichen Eingang.

## Die Regel dahinter

Darf der Dienst kurz weg sein und gibt es nur eine Umgebung, reicht Compose — sonst ein schmales, verwaltetes Cluster.

Du änderst die Datei im Repo, nicht die Maschine — das Cluster hält, was ausgerollt wurde, und Argo CD zeigt jede Abweichung an.
