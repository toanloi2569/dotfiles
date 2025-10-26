alias nowrfc="date -u +\"%Y-%m-%dT%H:%M:%S+07:00\""
 
 
# Function to delete pods in Evicted, Error, or CrashLoopBackOff state
kpods-clean() {
  if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: kpods-clean"
    echo "Delete pods in Evicted, Error, or CrashLoopBackOff state."
    return 0
  fi

  kubectl get pods | grep -E 'Evicted|Error|CrashLoopBackOff' | awk '{print $1}' | xargs -r kubectl delete pod
}

kjob_clean() {
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "Usage: kjob-clean"
        echo "Delete jobs in Failed or Complete state."
        return 0
    fi

    kubectl get jobs | grep -E '0/1' | awk '{print $1}' | xargs -r kubectl delete job
}

# Function to get logs from pods with label selector
klogs-label() {
    local label_selector=""
    local namespace_opt=""
    local extra_args=()

    # Handle --help or -h
    for arg in "$@"; do
        if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
            echo "Usage: klogs-label [-n namespace] [-l label_selector] [kubectl logs options]"
            echo
            echo "If -l is not provided, a label list will be shown for selection via fzf."
            echo "Examples:"
            echo "  klogs-label --tail=100"
            echo "  klogs-label -n mynamespace --tail=50"
            echo "  klogs-label -l \"app=myapp\" --since=5m"
            echo
            echo "You can add any kubectl logs options after the label/namespace flags."
            return 0
        fi
    done
 
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--selector)
                label_selector="$2"
                shift 2
                ;;
            -n|--namespace)
                namespace_opt="-n $2"
                shift 2
                ;;
            *)
                extra_args+=("$1")
                shift
                ;;
        esac
    done
 
    # If label_selector is empty we collect labels from pods and prompt via fzf
    if [[ -z "$label_selector" ]]; then
        label_selector=$(kubectl get pods $namespace_opt --show-labels --no-headers | \
            awk '{print $NF}' | tr ',' '\n' | sort | uniq | fzf --prompt="Select label: ")
        if [[ -z "$label_selector" ]]; then
            echo "❌ No label selected."
            return 1
        fi
    fi
 
    kubectl get pods -l "$label_selector" $namespace_opt -o name | cut -d/ -f2 | while read -r pod; do
        echo "==== Logs from $pod ===="
        kubectl logs "${extra_args[@]}" $namespace_opt "$pod"
        echo
    done
}

# Function to exec into pods with label selector
kexec-label() {
    local label_selector=""
    local namespace_opt=""
    local extra_args=()
    local user_cmd=()

    # Handle --help or -h
    for arg in "$@"; do
        if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
            echo "Usage: kexec-label [-n namespace] [-l label_selector] -- <command>"
            echo
            echo "If you don't provide -l, it will display a label list to select (fzf)."
            echo "Examples:"
            echo "  kexec-label -- ls /data"
            echo "  kexec-label -n myns -- cat logs/predict.log"
            echo "  kexec-label -l \"app=myapp\" -- ls"
            echo
            echo "Note:"
            echo "- For complex commands (like cd, &&, pipe), use:"
            echo "  kexec-label -- /bin/sh -c 'cd logs && ls'"
            return 0
        fi
    done
 
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--selector)
                label_selector="$2"
                shift 2
                ;;
            -n|--namespace)
                namespace_opt="-n $2"
                shift 2
                ;;
            --)
                shift
                user_cmd=("$@")
                break
                ;;
            *)
                extra_args+=("$1")
                shift
                ;;
        esac
    done
 
    if [[ -z "$label_selector" ]]; then
        label_selector=$(kubectl get pods $namespace_opt --show-labels --no-headers | \
            awk '{print $NF}' | tr ',' '\n' | sort | uniq | fzf --prompt="Select label: ")
        [[ -z "$label_selector" ]] && echo "❌ No label selected." && return 1
    fi
 
    if [[ ${#user_cmd[@]} -eq 0 ]]; then
        echo "❌ You must provide a command to exec in pods (e.g., ls, cat logs/predict.log, ...)"
        echo "👉 Usage: kexec-label -l \"app=myapp\" -- ls"
        return 1
    fi
 
    kubectl get pods -l "$label_selector" $namespace_opt -o name | cut -d/ -f2 | while read -r pod; do
        echo "==== Exec on $pod ===="
        kubectl exec $namespace_opt "$pod" -- "${user_cmd[@]}"
        echo
    done
}

# Function to get pod image by label selector
kimg-label() {
  if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: kimg-label [-n namespace] -l label_selector"
    echo
    echo "If -l is not provided, a label list will be shown for selection via fzf."
    echo "Examples:"
    echo "  kimg-label -l \"app=myapp\""
    echo "  kimg-label -l \"app=myapp\" -n mynamespace"
    echo
    return 0
  fi
 
  local label_selector=""
  local namespace_opt=""
 
  while [[ $# -gt 0 ]]; do
      case "$1" in
          -l|--selector)
              label_selector="$2"
              shift 2
              ;;
          -n|--namespace)
              namespace_opt="-n $2"
              shift 2
              ;;
          *)
              shift
              ;;
      esac
  done
 
  # If label_selector is not provided, use fzf to select
  if [[ -z "$label_selector" ]]; then
      label_selector=$(kubectl get pods $namespace_opt --show-labels --no-headers | \
          awk '{print $NF}' | tr ',' '\n' | sort | uniq | fzf --prompt="Select label: ")
      [[ -z "$label_selector" ]] && echo "❌ No label selected." && return 1
  fi
 
  # Get all image which match the label selector
  kubectl get pods -l "$label_selector" $namespace_opt -o jsonpath='{.items[*].spec.containers[*].image}' | \
      tr ' ' '\n' | sort | uniq
}

# List deployment/image pairs for all deployments in the current namespace
kimg-all() {
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "Usage: kimg-all"
        echo "List deployment/image pairs in the current namespace."
        return 0
    fi

    setopt local_options noxtrace noverbose typesetsilent

    local restore_xtrace=0
    if [[ -o xtrace ]]; then
        set +x
        restore_xtrace=1
    fi

    local deploy_rows
    if ! deploy_rows=$(
        setopt local_options pipefail noxtrace noverbose
        kubectl get deployments -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[*].image}{"\n"}{end}'
    ); then
        echo "❌ Unable to fetch deployments."
        if (( restore_xtrace )); then
            set -x
        fi
        return 1
    fi

    if [[ -z "$deploy_rows" ]]; then
        echo "(no deployments)"
        if (( restore_xtrace )); then
            set -x
        fi
        return 0
    fi

    local -a pairs
    local line
    for line in "${(@f)deploy_rows}"; do
        [[ -z "$line" ]] && continue
        local deploy images image
        IFS=$'\t' read -r deploy images <<< "$line"
        [[ -z "$deploy" || -z "$images" ]] && continue
        for image in ${(s: :)images}; do
            [[ -z "$image" ]] && continue
            pairs+=("$deploy, $image")
        done
    done

    if [[ ${#pairs[@]} -eq 0 ]]; then
        echo "(no deployments)"
        if (( restore_xtrace )); then
            set -x
        fi
        return 0
    fi

    printf '%s\n' "${(ou)pairs[@]}"

    if (( restore_xtrace )); then
        set -x
    fi
}

# List deployment/image pairs for deployments across every context exposed by kubectx
kimg-all-ctx() {
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "Usage: kimg-all-ctx [timeout_seconds]"
        echo "List deployment/image pairs for each context using its default namespace from kubeconfig."
        echo "timeout_seconds (default 5) applies to every kubectl/kubectx call."
        return 0
    fi

    local timeout_seconds="5"
    if [[ $# -gt 0 ]]; then
        timeout_seconds="$1"
        shift
    fi

    if ! [[ "$timeout_seconds" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo "❌ Timeout must be a numeric value (seconds)."
        return 1
    fi

    if ! command -v timeout >/dev/null 2>&1; then
        echo "❌ timeout command is not available on this machine."
        return 1
    fi

    if ! command -v kubectx >/dev/null 2>&1; then
        echo "❌ kubectx command not found. Please install kubectx first."
        return 1
    fi

    local contexts_output
    if ! contexts_output=$(timeout "${timeout_seconds}s" kubectx 2>/dev/null); then
        local ctx_status=$?
        if (( ctx_status == 124 )); then
            echo "⏱️ kubectx exceeded ${timeout_seconds}s."
        else
            echo "❌ Failed to retrieve contexts via kubectx."
        fi
        return 1
    fi

    contexts_output=$(printf '%s\n' "$contexts_output" | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g')

    setopt local_options noxtrace noverbose typesetsilent

    local restore_xtrace=0
    if [[ -o xtrace ]]; then
        set +x
        restore_xtrace=1
    fi

    local contexts=()
    while IFS= read -r line; do
        line=${line#"${line%%[![:space:]]*}"}
        [[ "${line:0:1}" == "*" ]] && line=${line:1}
        line=${line#"${line%%[![:space:]]*}"}
        line=${line%"${line##*[![:space:]]}"}
        [[ -n "$line" ]] && contexts+=("$line")
    done <<< "$contexts_output"

    if [[ ${#contexts[@]} -eq 0 ]]; then
        echo "❌ No Kubernetes contexts found."
        if (( restore_xtrace )); then
            set -x
        fi
        return 1
    fi

    local ctx
    for ctx in "${contexts[@]}"; do
        local namespace
        namespace=$(
            setopt local_options noxtrace noverbose
            timeout "${timeout_seconds}s" kubectl config view -o jsonpath="{.contexts[?(@.name==\"${ctx}\")].context.namespace}" 2>/dev/null
        )
        local namespace_status=$?
        if (( namespace_status == 124 )); then
            echo "⏱️ Fetching namespace for context $ctx exceeded ${timeout_seconds}s. Using default."
            namespace=""
        fi

        if (( namespace_status != 0 )) || [[ -z "$namespace" ]]; then
            namespace="default"
        fi

        echo "==== Context: $ctx (ns: $namespace) ===="
        local deploy_rows
        deploy_rows=$(
            setopt local_options pipefail noxtrace noverbose
            timeout "${timeout_seconds}s" kubectl --context "$ctx" -n "$namespace" get deployments -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}' 2>/dev/null
        )
        local cmd_status=$?

        if (( cmd_status == 124 )); then
            echo "⏱️ Timed out after ${timeout_seconds}s while fetching deployments (ns: $namespace)."
            echo
            continue
        elif (( cmd_status != 0 )); then
            echo "❌ Unable to fetch deployments (ns: $namespace)."
            echo
            continue
        fi

        if [[ -z "$deploy_rows" ]]; then
            echo "(no deployments)"
        else
            local -a pairs=()
            local line
            for line in "${(@f)deploy_rows}"; do
                [[ -z "$line" ]] && continue
                local deploy image
                IFS=$'\t' read -r deploy image <<< "$line"
                [[ -z "$deploy" || -z "$image" ]] && continue
                pairs+=("$deploy, $image")
            done

            if [[ ${#pairs[@]} -eq 0 ]]; then
                echo "(no deployments)"
            else
                printf '%s\n' "${(ou)pairs[@]}"
            fi
        fi
        echo
    done

    if (( restore_xtrace )); then
        set -x
    fi
}

# Render Kubernetes secret data as stringData with decoded values
ksec() {
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "Usage: ksec [-n namespace] <secret_name>"
        echo
        echo "Fetches a secret and prints it in YAML stringData format with base64-decoded values."
        return 0
    fi

    local namespace_opt=""
    local namespace_value=""
    local secret_name=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--namespace)
                namespace_value="$2"
                namespace_opt="-n $2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: ksec [-n namespace] <secret_name>"
                echo
                echo "Fetches a secret and prints it in YAML stringData format with base64-decoded values."
                return 0
                ;;
            *)
                secret_name="$1"
                shift
                ;;
        esac
    done

    if [[ -z "$secret_name" ]]; then
        local secret_candidates
        if ! secret_candidates=$(kubectl get secrets $namespace_opt -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null); then
            if [[ -n "$namespace_value" ]]; then
                echo "❌ Unable to list secrets in namespace '$namespace_value'."
            else
                echo "❌ Unable to list secrets in the current namespace."
            fi
            return 1
        fi

        local -a secret_options
        secret_options=(${(f)secret_candidates})
        secret_options=(${secret_options:#sh.helm.release.v1.*})

        if [[ ${#secret_options[@]} -eq 0 ]]; then
            echo "❌ No secrets available for selection (Helm defaults are excluded)."
            return 1
        fi

        secret_name=$(printf '%s\n' "${secret_options[@]}" | fzf --prompt="Select secret: ")
        if [[ -z "$secret_name" ]]; then
            echo "❌ No secret selected."
            return 1
        fi
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        echo "❌ python3 is required to decode secret data."
        return 1
    fi

    setopt local_options noxtrace noverbose typesetsilent

    local restore_xtrace=0
    if [[ -o xtrace ]]; then
        set +x
        restore_xtrace=1
    fi

    local secret_json
    if ! secret_json=$(kubectl get secret "$secret_name" $namespace_opt -o json 2>/dev/null); then
        if (( restore_xtrace )); then
            set -x
        fi
        if [[ -n "$namespace_value" ]]; then
            echo "❌ Unable to fetch secret '$secret_name' in namespace '$namespace_value'."
        else
            echo "❌ Unable to fetch secret '$secret_name'."
        fi
        return 1
    fi

    printf '%s\n' "$secret_json" | python3 - <<'PY'
import sys
import json
import base64

try:
    payload = json.load(sys.stdin)
except json.JSONDecodeError as exc:
    print(f"❌ Failed to parse secret JSON: {exc}")
    sys.exit(1)

data = payload.get("data") or {}
print("stringData:")
if not data:
    print("  # secret has no data keys")
    sys.exit(0)

for key in sorted(data):
    try:
        decoded = base64.b64decode(data[key]).decode("utf-8", errors="replace")
    except Exception as exc:  # pragma: no cover
        print(f"  # failed to decode {key}: {exc}")
        continue

    if "\n" in decoded:
        trimmed = decoded.rstrip("\n")
        print(f"  {key}: |-")
        if trimmed:
            for line in trimmed.split("\n"):
                print(f"    {line}")
        if decoded.endswith("\n"):
            print("    ")
    elif decoded == "":
        print(f"  {key}: \"\"")
    else:
        import json as _json  # local alias to reuse json.dumps
        print(f"  {key}: {_json.dumps(decoded)}")
PY

    local render_status=$?

    if (( restore_xtrace )); then
        set -x
    fi

    return $render_status
}

# Function to get labels of a pod
klabels() {
    local pod_name=""
    local namespace_opt=""
 
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--namespace)
                namespace_opt="-n $2"
                shift 2
                ;;
            *)
                pod_name="$1"
                shift
                ;;
        esac
    done
 
    # If pod_name is not provided, use fzf to select
    if [[ -z "$pod_name" ]]; then
        pod_name=$(kubectl get pods $namespace_opt --no-headers | awk '{print $1}' | fzf --prompt="Select pod: ")
        [[ -z "$pod_name" ]] && echo "❌ No pod selected." && return 1
    fi
 
    # If labels are separated by ",", list all labels in a new line
    kubectl  get pod $pod_name $namespace_opt --show-labels --no-headers | \
        awk '{print $NF}' | tr ',' '\n' | sort | uniq
}

kctxmerge() {
  local MERGED_CONFIG="$HOME/.kube/config"
  local BACKUP_CONFIG="$MERGED_CONFIG.bak"
 
  # Backup existing kubeconfig if present
  if [ -f "$MERGED_CONFIG" ]; then
    cp "$MERGED_CONFIG" "$BACKUP_CONFIG"
    echo "[INFO] Backed up kubeconfig to $BACKUP_CONFIG"
  fi
 
  # Collect all kubeconfig files
  local KUBECONFIG_FILES=()
  for file in "$HOME/.kube/config" $(find "$HOME/.kube/" -type f \( -name "kubeconfig.*.yml" -o -name "kubeconfig.*.yaml" \)); do
    [ -f "$file" ] && KUBECONFIG_FILES+=("$file")
  done
 
  if [ ${#KUBECONFIG_FILES[@]} -eq 0 ]; then
    echo "[ERROR] No kubeconfig files found."
    return 1
  fi
 
  # Merge them into a single kubeconfig
  local MERGE_INPUT=$(IFS=:; echo "${KUBECONFIG_FILES[*]}")
  KUBECONFIG=$MERGE_INPUT kubectl config view --flatten > "$MERGED_CONFIG"
 
  echo "[INFO] Merged kubeconfig written to $MERGED_CONFIG"
  echo "[INFO] Current context: $(kubectl config current-context)"
}

kexec-pod() {
    # Help
    for arg in "$@"; do
        if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
            echo "Usage: kexec-pod [--] [command ...]"
            echo
            echo "Description:"
            echo "  - List pods in the current namespace via fzf and exec into the selection."
            echo "  - Default command: kubectl exec -it <pod> -- bash"
            echo "  - Passing arguments after -- overrides the default (e.g. sh, /bin/bash -c 'cmd')."
            echo
            echo "Examples:"
            echo "  kexec-pod                      # open pod with bash (falls back to sh if bash is missing)"
            echo "  kexec-pod -- sh                # open pod with sh"
            echo "  kexec-pod -- /bin/bash -c 'echo hi && ls -la'"
            return 0
        fi
    done

    # Collect the user command (after --). Default to bash if nothing provided.
    local user_cmd=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --)
                shift
                user_cmd=("$@")
                break
                ;;
            *)
                # Allow commands without explicitly providing --
                user_cmd+=("$1")
                shift
                ;;
        esac
    done

    # Select a pod interactively
    local pod
    pod=$(kubectl get pods --no-headers 2>/dev/null | awk '{print $1}' | \
          fzf --prompt="Select pod to exec > ")
    if [[ -z "$pod" ]]; then
        echo "❌ No pod selected."
        return 1
    fi

    # Execute inside the pod
    if [[ ${#user_cmd[@]} -eq 0 ]]; then
        # Default to bash, falling back to sh if bash is unavailable
        kubectl exec -it "$pod" -- bash 2>/dev/null || kubectl exec -it "$pod" -- sh
    else
        kubectl exec -it "$pod" -- "${user_cmd[@]}"
    fi
}

# Backward-compatible aliases and hyphenated entry points
alias kdelbadpods='kpods-clean'
alias kdelbadjobs='kjob-clean'
alias kloglb='klogs-label'
alias kexeclb='kexec-label'

alias kimlb='kimg-label'
alias kgimlb='kimg-label'
alias kgimall='kimg-all'
alias kimall='kimg-all'
alias kgimallctx='kimg-all-ctx'
alias kimallctx='kimg-all-ctx'

alias klb='klabels'
alias kxp='kexec-pod'
 
k8s_helper_commands() {
    cat <<'EOF'
Kubernetes Helper Commands (fzf-powered)

1) nowrfc
   - Print the current time in RFC3339 with +07:00 offset
   - Usage:
       nowrfc

2) kpods-clean
   - Delete pods in Evicted, Error, or CrashLoopBackOff status within the current namespace
   - Usage:
       kpods-clean

3) klogs-label
   - Tail logs from pods matching a label selector (pick labels via fzf when -l is omitted)
   - Usage:
       klogs-label [-n namespace] [-l label_selector] [kubectl logs options...]
   - Examples:
       klogs-label --tail=100
       klogs-label -n myns --tail=50
       klogs-label -l "app=myapp" --since=5m

4) kexec-label
   - Exec into pods matching a label selector (fzf prompt if -l is omitted)
   - Usage:
       kexec-label [-n namespace] [-l label_selector] -- <command>
   - Examples:
       kexec-label -- ls /data
       kexec-label -n myns -- cat logs/predict.log
       kexec-label -l "app=myapp" -- /bin/sh -c 'cd logs && ls'

5) kimg-label
   - List container images for pods matching a label selector (fzf prompt if -l is omitted)
   - Usage:
       kimg-label [-n namespace] -l label_selector
   - Examples:
       kimg-label -l "app=myapp"
       kimg-label -l "app=myapp" -n myns

6) klabels
   - Print every label on a pod (fzf selection if no pod name provided)
   - Usage:
       klabels [-n namespace] [pod_name]

7) kctxmerge
   - Merge kubeconfig files in ~/.kube into ~/.kube/config and report the current context
   - Usage:
       kctxmerge

8) kexec-pod
   - Select a pod via fzf in the current namespace and exec -it into it
   - Default command is bash; falls back to sh if bash is missing
   - Provide any command after -- to override the default
   - Usage:
       kexec-pod [--] [command ...]
   - Examples:
       kexec-pod
       kexec-pod -- sh
       kexec-pod -- /bin/bash -c 'echo hi && ls -la'

9) ksec
   - Fetch a secret and print it as YAML stringData with decoded values
   - Usage:
       ksec [-n namespace] <secret_name>
EOF
}
