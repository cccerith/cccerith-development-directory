#!/usr/bin/env python3
"""
SERVARR CONFIGURATION SANITIZATION ENGINE
==========================================
Advanced sanitization tool for Servarr application configurations.
Removes sensitive data while preserving functional settings.
==========================================
"""

import os
import re
import json
import sqlite3
import xml.etree.ElementTree as ET
import argparse
import logging
import hashlib
import shutil
from pathlib import Path
from typing import Dict, List, Tuple, Any
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class ServarrConfigSanitizer:
    """Advanced configuration sanitizer for Servarr applications"""
    
    def __init__(self, config_dir: str, output_dir: str, app_name: str):
        self.config_dir = Path(config_dir)
        self.output_dir = Path(output_dir)
        self.app_name = app_name.lower()
        
        # Ensure output directory exists
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        # Sensitive data patterns (more comprehensive)
        self.sensitive_patterns = {
            'api_keys': [
                r'("?[Aa]pi[Kk]ey"?\s*[:=]\s*["\']?)([^"\'<>\n]+)',
                r'("?api_key"?\s*[:=]\s*["\']?)([^"\'<>\n]+)',
                r'("?API_KEY"?\s*[:=]\s*["\']?)([^"\'<>\n]+)',
                r'("?X-Api-Key"?\s*[:=]\s*["\']?)([^"\'<>\n]+)',
            ],
            'passwords': [
                r'("?[Pp]assword"?\s*[:=]\s*["\']?)([^"\'<>\n]+)',
                r'("?PASSWORD"?\s*[:=]\s*["\']?)([^"\'<>\n]+)',
                r'("?rpc-password"?\s*[:=]\s*["\']?)([^"\'<>\n]+)',
                r'("?ControlPassword"?\s*[:=]\s*["\']?)([^"\'<>\n]+)',
            ],
            'usernames': [
                r'("?[Uu]sername"?\s*[:=]\s*["\']?)([^"\'<>\n]+)',
                r'("?USERNAME"?\s*[:=]\s*["\']?)([^"\'<>\n]+)',
                r'("?rpc-username"?\s*[:=]\s*["\']?)([^"\'<>\n]+)',
                r'("?ControlUsername"?\s*[:=]\s*["\']?)([^"\'<>\n]+)',
            ],
            'secrets': [
                r'("?[Ss]ecret"?\s*[:=]\s*["\']?)([^"\'<>\n]+)',
                r'("?SECRET"?\s*[:=]\s*["\']?)([^"\'<>\n]+)',
                r'("?client_secret"?\s*[:=]\s*["\']?)([^"\'<>\n]+)',
            ],
            'tokens': [
                r'("?[Tt]oken"?\s*[:=]\s*["\']?)([^"\'<>\n]+)',
                r'("?TOKEN"?\s*[:=]\s*["\']?)([^"\'<>\n]+)',
                r'("?access_token"?\s*[:=]\s*["\']?)([^"\'<>\n]+)',
                r'("?refresh_token"?\s*[:=]\s*["\']?)([^"\'<>\n]+)',
            ],
            'auth': [
                r'("?[Aa]uth"?\s*[:=]\s*["\']?)([^"\'<>\n]+)',
                r'("?authorization"?\s*[:=]\s*["\']?)([^"\'<>\n]+)',
            ]
        }
        
        # Database column patterns
        self.sensitive_columns = [
            'apikey', 'password', 'secret', 'token', 'auth',
            'username', 'user', 'pass', 'key'
        ]
        
        # Statistics tracking
        self.stats = {
            'files_processed': 0,
            'databases_processed': 0,
            'sensitive_items_found': 0,
            'sensitive_items_sanitized': 0
        }
    
    def sanitize_all(self) -> Dict[str, Any]:
        """Sanitize all configuration files and databases"""
        logger.info(f"Starting sanitization of {self.app_name} configurations")
        logger.info(f"Source: {self.config_dir}")
        logger.info(f"Output: {self.output_dir}")
        
        # Copy all files to output directory first
        self._copy_configs()
        
        # Process different file types
        self._sanitize_databases()
        self._sanitize_xml_files()
        self._sanitize_json_files()
        self._sanitize_config_files()
        
        # Generate sanitization report
        report = self._generate_report()
        
        logger.info(f"Sanitization completed. Processed {self.stats['files_processed']} files")
        logger.info(f"Found and sanitized {self.stats['sensitive_items_sanitized']} sensitive items")
        
        return report
    
    def _copy_configs(self):
        """Copy all configuration files to output directory"""
        try:
            if self.config_dir.exists():
                for item in self.config_dir.rglob('*'):
                    if item.is_file():
                        # Calculate relative path and create in output directory
                        rel_path = item.relative_to(self.config_dir)
                        output_path = self.output_dir / rel_path
                        output_path.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(item, output_path)
                        logger.debug(f"Copied: {rel_path}")
        except Exception as e:
            logger.error(f"Error copying configurations: {e}")
    
    def _sanitize_databases(self):
        """Sanitize SQLite database files"""
        db_files = list(self.output_dir.rglob('*.db'))
        
        for db_file in db_files:
            try:
                logger.info(f"Sanitizing database: {db_file.name}")
                self._sanitize_sqlite_database(db_file)
                self.stats['databases_processed'] += 1
            except Exception as e:
                logger.error(f"Error sanitizing database {db_file}: {e}")
    
    def _sanitize_sqlite_database(self, db_path: Path):
        """Sanitize a single SQLite database"""
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        try:
            # Get all tables
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
            tables = cursor.fetchall()
            
            for (table_name,) in tables:
                # Get table schema
                cursor.execute(f"PRAGMA table_info({table_name});")
                columns = cursor.fetchall()
                
                # Find sensitive columns
                sensitive_cols = []
                for col_info in columns:
                    col_name = col_info[1].lower()
                    for pattern in self.sensitive_columns:
                        if pattern in col_name:
                            sensitive_cols.append(col_info[1])
                            break
                
                # Sanitize sensitive columns
                for col_name in sensitive_cols:
                    placeholder = f"PLACEHOLDER_{col_name.upper()}"
                    cursor.execute(f"UPDATE {table_name} SET {col_name} = ? WHERE {col_name} IS NOT NULL AND {col_name} != ''", (placeholder,))
                    
                    # Count affected rows
                    affected_rows = cursor.rowcount
                    if affected_rows > 0:
                        self.stats['sensitive_items_found'] += affected_rows
                        self.stats['sensitive_items_sanitized'] += affected_rows
                        logger.debug(f"Sanitized {affected_rows} rows in {table_name}.{col_name}")
            
            conn.commit()
            
        finally:
            conn.close()
    
    def _sanitize_xml_files(self):
        """Sanitize XML configuration files"""
        xml_files = list(self.output_dir.rglob('*.xml'))
        
        for xml_file in xml_files:
            try:
                logger.info(f"Sanitizing XML file: {xml_file.name}")
                self._sanitize_xml_file(xml_file)
                self.stats['files_processed'] += 1
            except Exception as e:
                logger.error(f"Error sanitizing XML file {xml_file}: {e}")
    
    def _sanitize_xml_file(self, xml_path: Path):
        """Sanitize a single XML file"""
        try:
            tree = ET.parse(xml_path)
            root = tree.getroot()
            
            # Recursively sanitize XML elements
            self._sanitize_xml_element(root)
            
            # Write sanitized XML back
            tree.write(xml_path, encoding='utf-8', xml_declaration=True)
            
        except ET.ParseError as e:
            logger.warning(f"Could not parse XML file {xml_path}: {e}")
            # Fall back to text-based sanitization
            self._sanitize_text_file(xml_path)
    
    def _sanitize_xml_element(self, element):
        """Recursively sanitize XML element and its children"""
        # Check element text
        if element.text:
            original_text = element.text
            element.text = self._sanitize_text_content(element.text)
            if element.text != original_text:
                self.stats['sensitive_items_found'] += 1
                self.stats['sensitive_items_sanitized'] += 1
        
        # Check element attributes
        for attr_name, attr_value in element.attrib.items():
            original_value = attr_value
            element.attrib[attr_name] = self._sanitize_text_content(attr_value)
            if element.attrib[attr_name] != original_value:
                self.stats['sensitive_items_found'] += 1
                self.stats['sensitive_items_sanitized'] += 1
        
        # Recursively process children
        for child in element:
            self._sanitize_xml_element(child)
    
    def _sanitize_json_files(self):
        """Sanitize JSON configuration files"""
        json_files = list(self.output_dir.rglob('*.json'))
        
        for json_file in json_files:
            try:
                logger.info(f"Sanitizing JSON file: {json_file.name}")
                self._sanitize_json_file(json_file)
                self.stats['files_processed'] += 1
            except Exception as e:
                logger.error(f"Error sanitizing JSON file {json_file}: {e}")
    
    def _sanitize_json_file(self, json_path: Path):
        """Sanitize a single JSON file"""
        try:
            with open(json_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            # Recursively sanitize JSON data
            sanitized_data = self._sanitize_json_object(data)
            
            # Write sanitized JSON back
            with open(json_path, 'w', encoding='utf-8') as f:
                json.dump(sanitized_data, f, indent=2, ensure_ascii=False)
                
        except json.JSONDecodeError as e:
            logger.warning(f"Could not parse JSON file {json_path}: {e}")
            # Fall back to text-based sanitization
            self._sanitize_text_file(json_path)
    
    def _sanitize_json_object(self, obj):
        """Recursively sanitize JSON object"""
        if isinstance(obj, dict):
            sanitized = {}
            for key, value in obj.items():
                sanitized_value = self._sanitize_json_object(value)
                
                # Check if key suggests sensitive data
                if self._is_sensitive_key(key) and isinstance(value, str) and value:
                    original_value = sanitized_value
                    sanitized_value = f"PLACEHOLDER_{key.upper()}"
                    if sanitized_value != original_value:
                        self.stats['sensitive_items_found'] += 1
                        self.stats['sensitive_items_sanitized'] += 1
                
                sanitized[key] = sanitized_value
            return sanitized
            
        elif isinstance(obj, list):
            return [self._sanitize_json_object(item) for item in obj]
            
        elif isinstance(obj, str):
            return self._sanitize_text_content(obj)
            
        else:
            return obj
    
    def _sanitize_config_files(self):
        """Sanitize other configuration files (.conf, .properties, etc.)"""
        config_files = []
        for pattern in ['*.conf', '*.cfg', '*.ini', '*.properties']:
            config_files.extend(self.output_dir.rglob(pattern))
        
        for config_file in config_files:
            try:
                logger.info(f"Sanitizing config file: {config_file.name}")
                self._sanitize_text_file(config_file)
                self.stats['files_processed'] += 1
            except Exception as e:
                logger.error(f"Error sanitizing config file {config_file}: {e}")
    
    def _sanitize_text_file(self, file_path: Path):
        """Sanitize a text-based configuration file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            original_content = content
            content = self._sanitize_text_content(content)
            
            if content != original_content:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
        
        except UnicodeDecodeError:
            # Try with different encoding
            try:
                with open(file_path, 'r', encoding='latin-1') as f:
                    content = f.read()
                
                original_content = content
                content = self._sanitize_text_content(content)
                
                if content != original_content:
                    with open(file_path, 'w', encoding='latin-1') as f:
                        f.write(content)
            except Exception as e:
                logger.error(f"Could not process file {file_path}: {e}")
    
    def _sanitize_text_content(self, text: str) -> str:
        """Apply sanitization patterns to text content"""
        if not text or not isinstance(text, str):
            return text
        
        sanitized_text = text
        
        # Apply all sensitive patterns
        for category, patterns in self.sensitive_patterns.items():
            for pattern in patterns:
                matches = re.findall(pattern, sanitized_text, re.IGNORECASE)
                if matches:
                    self.stats['sensitive_items_found'] += len(matches)
                    self.stats['sensitive_items_sanitized'] += len(matches)
                    
                    # Replace with placeholder
                    placeholder = f"PLACEHOLDER_{category.upper().rstrip('S')}"
                    sanitized_text = re.sub(pattern, f'\\g<1>{placeholder}', sanitized_text, flags=re.IGNORECASE)
        
        return sanitized_text
    
    def _is_sensitive_key(self, key: str) -> bool:
        """Check if a key name suggests sensitive data"""
        key_lower = key.lower()
        sensitive_keywords = [
            'api', 'key', 'password', 'secret', 'token', 'auth',
            'username', 'user', 'pass', 'credential'
        ]
        
        return any(keyword in key_lower for keyword in sensitive_keywords)
    
    def _generate_report(self) -> Dict[str, Any]:
        """Generate sanitization report"""
        report = {
            'app_name': self.app_name,
            'timestamp': datetime.now().isoformat(),
            'source_directory': str(self.config_dir),
            'output_directory': str(self.output_dir),
            'statistics': self.stats.copy(),
            'files_processed': [],
            'sanitization_patterns': {}
        }
        
        # List processed files
        for file_path in self.output_dir.rglob('*'):
            if file_path.is_file():
                report['files_processed'].append({
                    'path': str(file_path.relative_to(self.output_dir)),
                    'size': file_path.stat().st_size,
                    'type': file_path.suffix or 'no_extension'
                })
        
        # Document sanitization patterns
        report['sanitization_patterns'] = {
            'description': 'Patterns used to identify and sanitize sensitive data',
            'categories': list(self.sensitive_patterns.keys()),
            'database_columns': self.sensitive_columns
        }
        
        # Write report to file
        report_path = self.output_dir / 'sanitization-report.json'
        with open(report_path, 'w', encoding='utf-8') as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
        
        logger.info(f"Sanitization report written to: {report_path}")
        
        return report


def main():
    parser = argparse.ArgumentParser(description='Sanitize Servarr application configurations')
    parser.add_argument('config_dir', help='Source configuration directory')
    parser.add_argument('output_dir', help='Output directory for sanitized configurations')
    parser.add_argument('app_name', help='Application name (sonarr, radarr, etc.)')
    parser.add_argument('--verbose', '-v', action='store_true', help='Enable verbose logging')
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Validate inputs
    config_dir = Path(args.config_dir)
    if not config_dir.exists():
        logger.error(f"Configuration directory does not exist: {config_dir}")
        return 1
    
    # Create sanitizer and run
    sanitizer = ServarrConfigSanitizer(
        config_dir=args.config_dir,
        output_dir=args.output_dir,
        app_name=args.app_name
    )
    
    try:
        report = sanitizer.sanitize_all()
        
        print("\n" + "="*50)
        print(" SANITIZATION COMPLETED SUCCESSFULLY")
        print("="*50)
        print(f"Application: {report['app_name']}")
        print(f"Files processed: {report['statistics']['files_processed']}")
        print(f"Databases processed: {report['statistics']['databases_processed']}")
        print(f"Sensitive items sanitized: {report['statistics']['sensitive_items_sanitized']}")
        print(f"Output directory: {report['output_directory']}")
        print(f"Report: {Path(report['output_directory']) / 'sanitization-report.json'}")
        print("="*50)
        
        return 0
        
    except Exception as e:
        logger.error(f"Sanitization failed: {e}")
        return 1


if __name__ == '__main__':
    exit(main())