#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Universeller Bank CSV zu YNAB Konverter
Unterstützt: MBank, TFW/Wise
"""

import re
import csv
import sys
import os

def replace_umlauts(text):
    """Ersetzt deutsche Umlaute"""
    replacements = {
        'ä': 'ae', 'Ä': 'Ae',
        'ö': 'oe', 'Ö': 'Oe', 
        'ü': 'ue', 'Ü': 'Ue',
        'ß': 'ss'
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text

def convert_mbank_date(date_str):
    """Konvertiert dd.mm.yy zu m/dd/yyyy"""
    match = re.match(r'^(\d{1,2})\.(\d{1,2})\.(\d{2})$', date_str.strip())
    if match:
        day = match.group(1)
        month = match.group(2)
        year = match.group(3)
        day_formatted = day.zfill(2)
        month_int = int(month)
        return f"{month_int}/{day_formatted}/20{year}"
    return date_str

def convert_wise_date(date_str):
    """Konvertiert dd-mm-yyyy zu m/dd/yyyy"""
    match = re.match(r'^(\d{2})-(\d{2})-(\d{4})$', date_str.strip())
    if match:
        day = match.group(1)
        month = match.group(2)
        year = match.group(3)
        month_int = int(month)
        return f"{month_int}/{day}/{year}"
    return date_str

def cleanup_payee(payee):
    """Bereinigt und vereinheitlicht Payee-Namen"""
    if not payee:
        return payee
    
    # Liste von Ersetzungsregeln (Pattern → Ersatz)
    # Reihenfolge ist wichtig - spezifischere Regeln zuerst
    cleanup_rules = [
        # Exakte Matches oder Prefix-Matches
        (r'^Audible Gmbh.*', 'Audible'),
        (r'^Ex Libris Ag.*', 'Ex Libris'),
        (r'^Paypal\s*\*.*', 'Paypal'),
        (r'^Bolt\.eu/.*', 'Bolt'),
        (r'^Amazon\*.*', 'Amazon'),
        (r'^Park Hyatt\*.*', 'Park Hyatt'),
        (r'^Brezelkonig AG.*', 'Brezelkonig'),
        (r'^Peking Garden Oerlikon.*', 'Peking Garden'),
        (r'^Molino Select.*', 'Molino'),
        (r'^Uber\s+\*Eats.*', 'Uber Eats'),
        (r'^Wohnzimmer LEEUWARDEN.*', 'Wohnzimmer'),
        
        # Enthält bestimmten Text (case-insensitive)
        (r'.*Avec Beyond.*', 'Avec'),
        (r'.*Gamsgo.*', 'Gamsgo'),
        (r'^Coop-\d+.*', 'Coop'),
        (r'.*Avia.*', 'Avia'),
        (r'.*Lidl.*', 'Lidl'),
        (r'.*Migros.*', 'Migros'),
        (r'^MM\s+.*', 'Migros'),
        (r'^M\s+.*', 'Migros'),
        (r'.*Aldi.*', 'Aldi'),
        (r'.*Denner.*', 'Denner'),
        (r'.*Spar.*', 'Spar'),
    ]
    
    # Wende alle Regeln an
    for pattern, replacement in cleanup_rules:
        if re.match(pattern, payee, re.IGNORECASE):
            return replacement
    
    # Keine Regel gefunden, gebe Original zurück
    return payee

def extract_payee(buchungstext):
    """Extrahiert Firmenname aus MBank Buchungstext"""
    text = buchungstext.strip()
    
    # TWINT Transaktionen
    if text.upper().startswith('TWINT BELASTUNG') or text.upper().startswith('TWINT GUTSCHRIFT'):
        payee = re.sub(r'^TWINT\s+(Belastung|Gutschrift)\s+', '', text, flags=re.IGNORECASE)
        payee = re.sub(r'\s+\d{10,}$', '', payee).strip()
        payee = re.sub(r'\s+\d{1,2}$', '', payee).strip()
        
        # Bereinige und gebe zurück
        return cleanup_payee(payee)
    
    # Bleibt unverändert
    keep_as_is = ['Verguetung', 'Belastung', 'Dauerauftrag', 
                  'Zahlungseingang', 'Uebertrag', 'Sollzins', 
                  'Gutschrift', 'Spesen']
    
    for keyword in keep_as_is:
        if text.startswith(keyword):
            return keyword
    
    # Bancomatbezug
    if text.startswith('Bancomatbezug'):
        return 'Bancomatbezug'
    
    # Einkauf Pattern: "Einkauf FIRMENNAME Datum Zeit Karte..."
    einkauf_match = re.match(r'Einkauf\s+(.+?)\s+\d{2}\.\d{2}\.\d{4}', text)
    if einkauf_match:
        firm = einkauf_match.group(1).strip()
        firm = re.sub(r'\s*-\s*\d+.*$', '', firm).strip()
        
        # Bereinige und gebe zurück
        return cleanup_payee(firm)
    
    # Fallback: Erstes Wort
    payee = text.split()[0] if text else ''
    return cleanup_payee(payee)

def detect_bank_type(filepath, first_line):
    """Erkennt Bank-Typ anhand Dateiname und Header"""
    filename = os.path.basename(filepath).upper()
    
    if 'MBANK' in filename:
        return 'mbank'
    elif 'TFW' in filename or 'WISE' in filename:
        return 'wise'
    
    # Fallback: anhand Header erkennen
    if 'TransferWise ID' in first_line or 'Merchant' in first_line:
        return 'wise'
    elif 'Datum' in first_line and 'Buchungstext' in first_line:
        return 'mbank'
    
    return 'unknown'

def process_mbank(content):
    """Verarbeitet MBank CSV"""
    # Umlaute ersetzen
    content = replace_umlauts(content)
    
    # Fehlerhafte Datumsformate bereinigen
    content = re.sub(r'(\d{1,2})\.0(\d{2})\.(\d{2})', r'\1.\2.\3', content)
    
    lines = content.split('\n')
    output_rows = []
    
    for i, line in enumerate(lines):
        if not line.strip():
            continue
        
        parts = line.split(';')
        
        # Header
        if i == 0 or 'Datum' in parts[0]:
            output_rows.append(['Date', 'Payee', 'Memo', 'Amount'])
            continue
        
        # Datenzeilen: Datum;Buchungstext;Betrag;Valuta
        if len(parts) >= 3:
            datum = convert_mbank_date(parts[0])
            buchungstext = parts[1] if len(parts) > 1 else ''
            payee = extract_payee(buchungstext)
            betrag = parts[2] if len(parts) > 2 else '0.00'
            
            output_rows.append([datum, payee, buchungstext, betrag])
    
    return output_rows

def process_wise(content):
    """Verarbeitet Wise/TFW CSV"""
    lines = content.split('\n')
    output_rows = []
    
    # Header-Zeile parsen
    reader = csv.DictReader(lines)
    
    output_rows.append(['Date', 'Payee', 'Memo', 'Amount'])
    
    for row in reader:
        try:
            # Wise Format: Date, Amount, Description, Merchant
            date = convert_wise_date(row['Date'])
            amount = row['Amount']
            description = row['Description']
            merchant = row['Merchant'] if row['Merchant'] else 'Unknown'
            
            # Bereinige Merchant-Namen
            merchant = cleanup_payee(merchant)
            
            # YNAB Format: Date, Payee (Merchant), Memo (Description), Amount
            output_rows.append([date, merchant, description, amount])
        except KeyError as e:
            print(f"Warning: Missing column {e} in row, skipping...")
            continue
    
    return output_rows

def convert_to_ynab(input_file, output_file):
    """Hauptfunktion für Konvertierung"""
    print(f"Reading from: {input_file}")
    
    # Datei einlesen - verschiedene Encodings probieren
    try:
        with open(input_file, 'r', encoding='utf-8') as f:
            content = f.read()
    except UnicodeDecodeError:
        try:
            with open(input_file, 'r', encoding='latin-1') as f:
                content = f.read()
        except UnicodeDecodeError:
            with open(input_file, 'r', encoding='cp1252') as f:
                content = f.read()
    
    print(f"File read successfully. Processing {len(content)} characters...")
    
    # Bank-Typ erkennen
    first_line = content.split('\n')[0] if content else ''
    bank_type = detect_bank_type(input_file, first_line)
    
    print(f"Detected bank type: {bank_type.upper()}")
    
    # Verarbeiten je nach Bank-Typ
    if bank_type == 'mbank':
        output_rows = process_mbank(content)
    elif bank_type == 'wise':
        output_rows = process_wise(content)
    else:
        print(f"ERROR: Unknown bank type for file {input_file}")
        print(f"First line: {first_line[:100]}")
        return False, 0, 0
    
    input_records = len(output_rows) - 1  # Minus header
    
    # Speichern mit CSV writer (Komma + Anführungszeichen)
    with open(output_file, 'w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f, quoting=csv.QUOTE_ALL)
        writer.writerows(output_rows)
    
    output_records = len(output_rows) - 1  # Minus header
    
    print(f"Conversion complete!")
    print(f"Output saved to: {output_file}")
    print(f"Records: {input_records} → {output_records}")
    
    return True, input_records, output_records

if __name__ == "__main__":
    # ========================================================================
    # HIER DEIN INPUT-VERZEICHNIS EINTRAGEN:
    # ========================================================================
    
    # Input-Verzeichnis (alle MBank/Wise/TFW CSV-Dateien werden verarbeitet)
    input_directory = r'C:\Users\SonGoku78\OneDrive\Finance\YNAB'
    
    # Das Skript verarbeitet automatisch alle *.csv Dateien mit:
    # - "MBank" im Namen
    # - "Wise" im Namen
    # - "TFW" im Namen
    
    # ========================================================================
    
    import glob
    
    print("=" * 80)
    print("BANK TO YNAB BATCH CONVERTER")
    print("=" * 80)
    print(f"Searching in: {input_directory}")
    print()
    
    # Finde alle CSV-Dateien im Verzeichnis
    all_csv_files = glob.glob(os.path.join(input_directory, "*.csv"))
    
    # Filtere nur Bank-Dateien (MBank, Wise, TFW) - aber nicht bereits konvertierte
    bank_files = []
    for file in all_csv_files:
        filename = os.path.basename(file).upper()
        # Überspringe Dateien die bereits "_YNAB_READY" im Namen haben
        if '_YNAB_READY' in filename:
            continue
        # Prüfe ob es eine Bank-Datei ist
        if any(keyword in filename for keyword in ['MBANK', 'WISE', 'TFW']):
            bank_files.append(file)
    
    if not bank_files:
        print("ERROR: No bank CSV files found in directory.")
        print(f"Looking for files containing: MBank, Wise, or TFW")
        print(f"Found CSV files: {len(all_csv_files)}")
        sys.exit(1)
    
    print(f"Found {len(bank_files)} bank CSV file(s) to process:")
    for i, file in enumerate(bank_files, 1):
        print(f"  {i}. {os.path.basename(file)}")
    print()
    print("=" * 80)
    print()
    
    # Verarbeite jede Datei
    success_count = 0
    error_count = 0
    file_stats = []  # Liste für detaillierte Statistik
    total_input_records = 0
    total_output_records = 0
    
    for i, input_file in enumerate(bank_files, 1):
        print(f"Processing file {i}/{len(bank_files)}:")
        print(f"Input: {os.path.basename(input_file)}")
        
        # Generiere Output-Dateinamen
        input_dir = os.path.dirname(input_file)
        input_basename = os.path.basename(input_file)
        input_name, input_ext = os.path.splitext(input_basename)
        output_file = os.path.join(input_dir, f"{input_name}_ynab_ready{input_ext}")
        
        print(f"Output: {os.path.basename(output_file)}")
        print()
        
        try:
            success, input_recs, output_recs = convert_to_ynab(input_file, output_file)
            if success:
                success_count += 1
                total_input_records += input_recs
                total_output_records += output_recs
                file_stats.append({
                    'input': os.path.basename(input_file),
                    'output': os.path.basename(output_file),
                    'input_records': input_recs,
                    'output_records': output_recs
                })
            else:
                error_count += 1
        except Exception as e:
            print(f"ERROR: {str(e)}")
            error_count += 1
        
        print()
        print("-" * 80)
        print()
    
    # Detaillierte Statistik
    print("=" * 80)
    print("BATCH CONVERSION STATISTICS")
    print("=" * 80)
    print()
    
    # Pro-Datei Statistik
    print("FILES PROCESSED:")
    print("-" * 80)
    print(f"{'Input File':<45} {'Records':<10} {'Output File':<45} {'Records':<10}")
    print("-" * 80)
    
    for stat in file_stats:
        input_name = stat['input'][:44]
        output_name = stat['output'][:44]
        print(f"{input_name:<45} {stat['input_records']:<10} {output_name:<45} {stat['output_records']:<10}")
    
    print("-" * 80)
    print()
    
    # Gesamt-Statistik
    print("SUMMARY:")
    print("-" * 80)
    print(f"Total input files read:       {len(bank_files)}")
    print(f"Total output files written:   {success_count}")
    print(f"Total input records:          {total_input_records}")
    print(f"Total output records:         {total_output_records}")
    print(f"Successful conversions:       {success_count}")
    print(f"Failed conversions:           {error_count}")
    print("=" * 80)
    
    if error_count > 0:
        sys.exit(1)
