#!/usr/bin/python

import time
import requests
import os
import xml.etree.ElementTree as ET
import argparse
from colorama import Fore, Style, init
import subprocess

# Colorama initialization
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

# Function to parse certificate serial number using openssl command
def parse_cert(cert_pem):
    try:
        # Clean the certificate string
        clean_cert_str = "\n".join(line.strip() for line in cert_pem.strip().splitlines())
        
        # Use openssl command to get the serial number
        process = subprocess.run(
            ['openssl', 'x509', '-inform', 'PEM', '-noout', '-serial'],
            input=clean_cert_str, # Pass string directly, as text=True
            capture_output=True,
            check=True,
            text=True # This means input and output are handled as strings
        )
        # The output is typically "serial=HEX_STRING\n"
        serial_hex = process.stdout.strip().split("=")[1]
        return serial_hex.lower()
    except subprocess.CalledProcessError as e:
        # print(f"Error calling openssl: {e.stderr}") # Suppress this error for cleaner output
        return None
    except Exception as e:
        # print(f"An unexpected error occurred during certificate parsing: {e}") # Suppress this error for cleaner output
        return None

# Initialize counters
total_keyboxes = 0
revoked_keyboxes = 0
valid_keyboxes = 0
partial_revoked_keyboxes = 0 # New counter for partially revoked keys
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

        ec_cert_sn = parse_cert(certs[0]) if len(certs) >= 1 else None
        rsa_cert_sn = parse_cert(certs[3]) if len(certs) >= 4 else None

        ec_is_revoked = False
        rsa_is_revoked = False

        if ec_cert_sn:
            if ec_cert_sn in crl["entries"]:
                ec_is_revoked = True
        
        if rsa_cert_sn:
            if rsa_cert_sn in crl["entries"]:
                rsa_is_revoked = True

        # Determine overall keybox status based on new logic
        has_ec = ec_cert_sn is not None
        has_rsa = rsa_cert_sn is not None

        if has_ec and has_rsa:
            if ec_is_revoked and rsa_is_revoked:
                print(f'{Fore.RED}{BOLD}{filename}: Key is Revoked!{RESET}')
                revoked_keyboxes += 1
            elif (ec_is_revoked and not rsa_is_revoked) or (not ec_is_revoked and rsa_is_revoked):
                print(f'{Fore.YELLOW}{BOLD}{filename}: Key is Partial Revoked!{RESET}')
                partial_revoked_keyboxes += 1
            else:
                print(f'{Fore.GREEN}{BOLD}{filename}: Key is still Valid!{RESET}')
                valid_keyboxes += 1
        elif has_ec:
            if ec_is_revoked:
                print(f'{Fore.RED}{BOLD}{filename}: Key is Revoked!{RESET}')
                revoked_keyboxes += 1
            else:
                print(f'{Fore.GREEN}{BOLD}{filename}: Key is still Valid!{RESET}')
                valid_keyboxes += 1
        elif has_rsa:
            if rsa_is_revoked:
                print(f'{Fore.RED}{BOLD}{filename}: Key is Revoked!{RESET}')
                revoked_keyboxes += 1
            else:
                print(f'{Fore.GREEN}{BOLD}{filename}: Key is still Valid!{RESET}')
                valid_keyboxes += 1
        else:
            # This case should ideally be caught by 'if not certs:'
            print(f"{Fore.YELLOW}{BOLD}{filename}: No valid certificates found for checking.{RESET}\n")
            invalid_keyboxes += 1

        # Print individual serial numbers with specific colors and labels
        if ec_cert_sn:
            color = Fore.RED if ec_is_revoked else Fore.GREEN
            status_label = '( Revoked )' if ec_is_revoked else '( Valid )'
            print(f'   Primary Cert SN: {ec_cert_sn} {color}{BOLD}{status_label}{RESET}')
        if rsa_cert_sn:
            color = Fore.RED if rsa_is_revoked else Fore.GREEN
            status_label = '( Revoked )' if rsa_is_revoked else '( Valid )'
            print(f'   Secondary Cert SN: {rsa_cert_sn} {color}{BOLD}{status_label}{RESET}')
        if not rsa_cert_sn:
            print(f'   Secondary Cert SN: [Not Found]')
        print()

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
print(f'  Partial Revoked Key: {partial_revoked_keyboxes}') # Display new counter
print(f'  Invalid Key: {invalid_keyboxes}')
print(f'  Invalid File: {invalid_files}')
