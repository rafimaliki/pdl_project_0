"""
Script untuk menjalankan query SQL pada database PostgreSQL.
"""

import sys
import os
import psycopg2
from config import DATABASE_CONFIG
from tabulate import tabulate

def query_select_users():
    return "SELECT * FROM users LIMIT 10;"

QUERIES_TO_RUN = [
    query_select_users,
]

def run_queries():
    try:
        conn = psycopg2.connect(**DATABASE_CONFIG)
        cur = conn.cursor()
        print("\nBerhasil terhubung ke database. Menjalankan query...\n")
        for query_func in QUERIES_TO_RUN:
            sql = query_func()
            print(f"Menjalankan query: {query_func.__name__}")
            try:
                cur.execute(sql)
                sql_lower = sql.strip().lower()
                if sql_lower.startswith("select"):
                    rows = cur.fetchall()
                    headers = [desc[0] for desc in cur.description]
                    if rows:
                        print(tabulate(rows, headers, tablefmt="grid"))
                    else:
                        print("Tidak ada data yang ditemukan.")
                else:
                    affected = None
                    if cur.description is not None:
                        affected = cur.fetchall()
                        headers = [desc[0] for desc in cur.description]
                    conn.commit()
                    print(f"Query berhasil dijalankan dan di-commit.")
                    if affected is not None:
                        if affected:
                            print("Data yang terpengaruh:")
                            print(tabulate(affected, headers, tablefmt="grid"))
                        else:
                            print("Tidak ada data yang terpengaruh.")
            except Exception as e:
                print(f"Terjadi error saat menjalankan {query_func.__name__}: {e}")
                conn.rollback()
        cur.close()
        conn.close()
        print("\nSemua query telah dijalankan. Koneksi ditutup.\n")
    except Exception as e:
        print(f"Gagal terhubung atau menjalankan query: {e}")

if __name__ == "__main__":
    run_queries()
