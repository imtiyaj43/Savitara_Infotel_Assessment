"""
Helper script to download required Terraform providers via IPv4
and configure local provider cache/mirror.
"""
import os
import socket
import sys
import urllib.request
import zipfile
import io

# Force IPv4 resolution
orig_getaddrinfo = socket.getaddrinfo
def getaddrinfo_v4(*args, **kwargs):
    res = orig_getaddrinfo(*args, **kwargs)
    return [r for r in res if r[0] == socket.AF_INET]
socket.getaddrinfo = getaddrinfo_v4

PROVIDERS = [
    {
        "name": "aws",
        "version": "5.50.0",
        "url": "https://releases.hashicorp.com/terraform-provider-aws/5.50.0/terraform-provider-aws_5.50.0_windows_amd64.zip"
    },
    {
        "name": "random",
        "version": "3.6.3",
        "url": "https://releases.hashicorp.com/terraform-provider-random/3.6.3/terraform-provider-random_3.6.3_windows_amd64.zip"
    },
    {
        "name": "tls",
        "version": "4.0.5",
        "url": "https://releases.hashicorp.com/terraform-provider-tls/4.0.5/terraform-provider-tls_4.0.5_windows_amd64.zip"
    }
]

target_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "terraform-plugins", "registry.terraform.io", "hashicorp"))

def install_providers():
    for p in PROVIDERS:
        dest_dir = os.path.join(target_dir, p["name"], p["version"], "windows_amd64")
        os.makedirs(dest_dir, exist_ok=True)
        print(f"Downloading {p['name']} v{p['version']}...")
        req = urllib.request.Request(p["url"], headers={"User-Agent": "Terraform-Installer"})
        with urllib.request.urlopen(req, timeout=30) as resp:
            content = resp.read()
        print(f"Extracting {p['name']} ({len(content)} bytes) to {dest_dir}...")
        with zipfile.ZipFile(io.BytesIO(content)) as z:
            z.extractall(dest_dir)
        print(f"Successfully installed {p['name']}.")

if __name__ == "__main__":
    install_providers()
    print("All providers successfully cached in local mirror!")
