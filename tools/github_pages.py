"""Publish this repository using Git's existing credential helper; never log secrets."""
import argparse
import json
import os
import subprocess
import urllib.error
import urllib.request

REPO = "kurono966/physoul"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["create", "pages", "status", "dispatch"])
    args = parser.parse_args()
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0", GCM_INTERACTIVE="never")
    result = subprocess.run(["git", "credential", "fill"], input="protocol=https\nhost=github.com\n\n", text=True, capture_output=True, env=env)
    credential = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
    token = credential.get("password")
    if not token:
        raise SystemExit("No existing GitHub credential available in Git Credential Manager.")

    def api(method, path, data=None):
        request = urllib.request.Request("https://api.github.com" + path,
            data=json.dumps(data).encode() if data is not None else None,
            headers={"Authorization": "Bearer " + token, "Accept": "application/vnd.github+json", "Content-Type": "application/json", "User-Agent": "physoul-publisher"}, method=method)
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                body = response.read()
                return json.loads(body) if body else {}
        except urllib.error.HTTPError as error:
            body = json.loads(error.read())
            raise RuntimeError(f"GitHub {error.code}: {body.get('message', 'request failed')}") from None

    if args.command == "create":
        user = api("GET", "/user")
        if user["login"].lower() != "kurono966":
            raise SystemExit("Git credential account does not match kurono966.")
        repo = api("POST", "/user/repos", {"name": "physoul", "description": "Physics-based top-down soulslike prototype in Godot 4. Play on GitHub Pages.", "private": False, "auto_init": False})
        print(json.dumps({"repository": repo["html_url"], "visibility": repo["visibility"]}))
    elif args.command == "pages":
        pages = api("POST", f"/repos/{REPO}/pages", {"build_type": "workflow"})
        print(json.dumps({"url": pages.get("html_url"), "build_type": pages.get("build_type")}))
    elif args.command == "dispatch":
        api("POST", f"/repos/{REPO}/actions/workflows/pages.yml/dispatches", {"ref": "main"})
        print("Web deployment dispatched")
    else:
        runs = api("GET", f"/repos/{REPO}/actions/runs?per_page=3")
        print(json.dumps([{k: run.get(k) for k in ["id", "status", "conclusion", "html_url", "head_sha"]} for run in runs.get("workflow_runs", [])]))


if __name__ == "__main__":
    main()
