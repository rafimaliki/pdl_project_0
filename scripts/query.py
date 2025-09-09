"""
Script untuk menjalankan query SQL pada database PostgreSQL.
"""

import sys
import os
import psycopg2
import time
from config import DATABASE_CONFIG
from tabulate import tabulate

def query_select_users():
    return """
    SELECT * FROM users LIMIT 10;
    """

def query_user_and_order():
    return """
    SELECT 
        u.full_name AS nama_pelanggan,
        COUNT(DISTINCT gco.group_course_order_id) AS total_group_orders,
        COUNT(DISTINCT pcp.private_course_order_id) AS total_private_orders,
        (
            COUNT(DISTINCT gco.group_course_order_id) 
        + COUNT(DISTINCT pcp.private_course_order_id)
        ) AS total_orders
    FROM users u
    LEFT JOIN groupcourseorder gco ON u.user_id = gco.customer_id
    LEFT JOIN privatecourseorder pcp ON u.user_id = pcp.customer_id
    GROUP BY u.full_name
    ORDER BY total_orders DESC
    LIMIT 10;
    """

QUERIES_TO_RUN = [
    query_select_users,
    query_user_and_order,
]

def run_queries():
    try:
        conn = psycopg2.connect(**DATABASE_CONFIG)
        cur = conn.cursor()
        print("\nBerhasil terhubung ke database. Menjalankan query...\n")
        for idx, query_func in enumerate(QUERIES_TO_RUN):
            sql = query_func()
            print(f"{idx + 1}. Menjalankan query: {query_func.__name__}")
            print("SQL:")
            print(sql)
            try:
                start_time = time.time()
                cur.execute(sql)
                exec_time = int((time.time() - start_time) * 1000)  # ms
                sql_lower = sql.strip().lower()
                if sql_lower.startswith("select"):
                    rows = cur.fetchall()
                    headers = [desc[0] for desc in cur.description]
                    row_count = len(rows)
                    if rows:
                        print(tabulate(rows, headers, tablefmt="grid"))
                    else:
                        print("Tidak ada data yang ditemukan.")
                    print(f"({row_count} baris) {exec_time}ms\n")
                else:
                    affected = None
                    row_count = 0
                    if cur.description is not None:
                        affected = cur.fetchall()
                        headers = [desc[0] for desc in cur.description]
                        row_count = len(affected)
                    else:
                        row_count = cur.rowcount if cur.rowcount != -1 else 0
                    conn.commit()
                    print(f"Query berhasil dijalankan dan di-commit.")
                    if affected is not None:
                        if affected:
                            print("Data yang terpengaruh:")
                            print(tabulate(affected, headers, tablefmt="grid"))
                        else:
                            print("Tidak ada data yang terpengaruh.")
                    print(f"({row_count} baris) {exec_time}ms\n")
            except Exception as e:
                print(f"Terjadi error saat menjalankan {query_func.__name__}: {e}")
                conn.rollback()
        cur.close()
        conn.close()
        print("Semua query telah dijalankan. Koneksi ditutup.\n")
    except Exception as e:
        print(f"Gagal terhubung atau menjalankan query: {e}")

if __name__ == "__main__":
    run_queries()
