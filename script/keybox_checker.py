#!/usr/bin/python

import time
import requests
import os
import xml.etree.ElementTree as ET
from cryptography import x509
from cryptography.hazmat.backends import default_backend
import argparse
from colorama import Fore, Style, init

# Inisialisasi colorama
init(autoreset=True)

# ANSI escape codes for bold text
BOLD = '\033[1m'
RESET = '\033[0m'

# Setup argument parser
parser = argparse.ArgumentParser(description='Check keybox files or a single file for certificate validity against CRL.')
parser.add_argument('path', type=str, nargs='?', default=os.getcwd(),
                    help='Path to a directory or a single keybox file (default: current directory)')
args = parser.parse_args()

# Fetch the Certificate Revocation List (CRL)
# crl = requests.get('https://android.googleapis.com/attestation/status', headers={'Cache-Control': 'no-cache'}).json()
# url = f'https://android.googleapis.com/attestation/status?t={int(time.time())}'
# crl = requests.get(url, headers={'Cache-Control': 'no-cache', 'Pragma': 'no-cache'}).json()
crl = requests.get(f'https://android.googleapis.com/attestation/status?t={time.time()}', headers={'Cache-Control': 'no-cache', 'Pragma': 'no-cache'}).json()

# Function to extract content between <AndroidAttestation> tags
def extract_android_attestation(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
        start_tag = '<AndroidAttestation>'
        end_tag = '</AndroidAttestation>'
        start_idx = content.find(start_tag)
        end_idx = content.find(end_tag)
        if start_idx != -1 and end_idx != -1:
            return content[start_idx:end_idx + len(end_tag)]
        return None

# Function to parse certificate serial number
def parse_cert(cert):
    clean_cert = "\n".join(line.strip() for line in cert.strip().splitlines())
    parsed = x509.load_pem_x509_certificate(clean_cert.encode(), backend=default_backend())
    return f'{parsed.serial_number:x}'

# Initialize counters
total_keyboxes = 0
revoked_keyboxes = 0
valid_keyboxes = 0
invalid_keyboxes = 0
invalid_files = 0

# Get list of files
input_path = args.path
file_paths = [input_path] if os.path.isfile(input_path) else [
    os.path.join(input_path, f) for f in os.listdir(input_path) if os.path.isfile(os.path.join(input_path, f))
]

# Process each file
for file_path in file_paths:
    filename = os.path.basename(file_path)
    total_keyboxes += 1

    attestation_content = extract_android_attestation(file_path)
    if not attestation_content:
        print(f"{Fore.YELLOW}{BOLD}{filename} does not contain valid <AndroidAttestation> tags.{RESET}\n")
        invalid_keyboxes += 1
        continue

    try:
        root = ET.fromstring(attestation_content)
        certs = [elem.text for elem in root.iter() if elem.tag == 'Certificate']

        if not certs:
            print(f"{Fore.YELLOW}{BOLD}{filename} does not contain any certificate to check.{RESET}\n")
            invalid_keyboxes += 1
            continue

        # Ambil cert pertama (EC), dan keempat (RSA) jika ada
        ec_cert_sn = parse_cert(certs[0]) if len(certs) >= 1 else None
        rsa_cert_sn = parse_cert(certs[3]) if len(certs) >= 4 else None

        revoked = False
        if ec_cert_sn and ec_cert_sn in crl["entries"]:
            revoked = True
        if rsa_cert_sn and rsa_cert_sn in crl["entries"]:
            revoked = True

        if revoked:
            print(f'{Fore.RED}{BOLD}{filename}: Key is Revoked!{RESET}')
        else:
            print(f'{Fore.GREEN}{BOLD}{filename}: Key is still Valid!{RESET}')

        if ec_cert_sn:
            print(f'   Primary Cert SN: {ec_cert_sn}')
        if rsa_cert_sn:
            print(f'   Secondary Cert SN: {rsa_cert_sn}')
        if not rsa_cert_sn:
            print(f'   Secondary Cert SN: [Not Found]')
        print()

        if revoked:
            revoked_keyboxes += 1
        else:
            valid_keyboxes += 1

    except ET.ParseError:
        print(f"{BOLD}{filename} could not be parsed as XML within <AndroidAttestation> tags.{RESET}\n")
        invalid_files += 1
    except Exception as e:
        print(f"{BOLD}{filename} encountered an error: {str(e)}{RESET}\n")
        invalid_files += 1

# Summary
print(f'\n{Fore.CYAN}{BOLD}Summary:{RESET}')
print(f'  Total File: {total_keyboxes}')
print(f'  Valid Key: {valid_keyboxes}')
print(f'  Revoked Key: {revoked_keyboxes}')
print(f'  Invalid Key: {invalid_keyboxes}')
print(f'  Invalid File: {invalid_files}')