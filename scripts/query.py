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
    
def query_coach_of_the_month_2024():
    return """
    WITH
        coach_pc_monthly_revenue_2024 AS (
            SELECT
                c.coach_id,
                c.coach_name,
                DATE_PART('month', pc.date)::INT AS month,
                SUM(p.total_payment) AS total_revenue
            FROM 
                coaches c
            JOIN 
                coachavailability pc ON c.coach_id = pc.coach_id  
            JOIN
                privatecourseorderdetail pcod ON pcod.coach_availability_id = pc.coach_availability_id
            JOIN 
                privatecourseorder pco ON pco.private_course_order_id = pcod.private_course_order_id
            JOIN
                payments p ON p.payment_id = pco.payment_id
            WHERE
                p.status = 'accepted'
                AND DATE_PART('year', pc.date)::INT = 2024
            GROUP BY 
                c.coach_id, c.coach_name, month
        ),
        coach_gc_monthly_revenue_2024 AS (
            SELECT
                c.coach_id,
                c.coach_name,
                DATE_PART('month', gc.date)::INT AS month,
                SUM(p.total_payment) AS total_revenue
            FROM 
                coaches c
            JOIN
                groupcourses gc ON c.coach_id = gc.coach_id
            JOIN
                groupcourseorderdetail gcod ON gcod.course_id = gc.course_id
            JOIN 
                groupcourseorder gco ON gco.group_course_order_id = gcod.group_course_order_id
            JOIN
                payments p ON p.payment_id = gco.payment_id
            WHERE
                p.status = 'accepted'
                AND DATE_PART('year', gc.date)::INT = 2024
            GROUP BY 
                c.coach_id, c.coach_name, month
        ),
        combined AS (
            SELECT * FROM coach_pc_monthly_revenue_2024
            UNION ALL
            SELECT * FROM coach_gc_monthly_revenue_2024
        ),
        summed AS (
            SELECT
                coach_id,
                coach_name,
                month,
                SUM(total_revenue) AS total_revenue
            FROM combined
            GROUP BY coach_id, coach_name, month
        ),
        ranked AS (
            SELECT
                coach_id,
                coach_name,
                month,
                total_revenue,
                ROW_NUMBER() OVER (PARTITION BY month ORDER BY total_revenue DESC) AS rn
            FROM summed
        )
    SELECT
        month,
        coach_name,
        total_revenue::BIGINT
    FROM ranked
    WHERE rn = 1
    ORDER BY month;

    """

def query_user_priority():
    return """
    WITH
        user_expenses_pc AS (
            SELECT
                u.user_id,
                u.full_name,
                SUM(p.total_payment) AS total_expenses
            FROM
                users u
            JOIN
                privatecourseorder pco ON u.user_id = pco.customer_id
            JOIN
                payments p ON p.payment_id = pco.payment_id
            WHERE
                p.status = 'accepted'
            GROUP BY
                u.user_id, u.full_name
        ),
        user_expenses_gc AS (
            SELECT
                u.user_id,
                u.full_name,
                SUM(p.total_payment) AS total_expenses
            FROM
                users u
            JOIN
                groupcourseorder gco ON u.user_id = gco.customer_id
            JOIN
                payments p ON p.payment_id = gco.payment_id
            WHERE
                p.status = 'accepted'
            GROUP BY
                u.user_id, u.full_name
        ),
        combined AS (
            SELECT * FROM user_expenses_pc
            UNION ALL
            SELECT * FROM user_expenses_gc
        ),
        summed AS (
            SELECT
                user_id,
                full_name,
                SUM(total_expenses) AS total_expenses
            FROM combined
            GROUP BY user_id, full_name
        )
    SELECT
        user_id,
        full_name,
        total_expenses::BIGINT
    FROM summed
    WHERE total_expenses >= 8000000
    ORDER BY total_expenses DESC;
    """

def query_find_need_discount_groupcourse():
    return """
    SELECT gc.*
    FROM groupcourses gc
    LEFT JOIN groupcourseorderdetail gco_d
        ON gc.course_id = gco_d.course_id
    WHERE gc.date >= DATE '2025-09-11'
    AND gc.date <= DATE '2025-09-17'
    AND gco_d.course_id IS NULL
    ORDER BY gc.date, gc.start_hour;
    """
    
def query_discount_groupcourse():
    return """ 
    UPDATE groupcourses
    SET course_price = course_price * 0.75
    WHERE course_id IN (
        SELECT gc.course_id
        FROM groupcourses gc
        LEFT JOIN groupcourseorderdetail gco_d
            ON gc.course_id = gco_d.course_id
        WHERE gc.date >= DATE '2025-09-11'
        AND gc.date <= DATE '2025-09-17'
        AND gco_d.course_id IS NULL
    );
    """
    
def query_find_expiring_vouchers():
    return """
    SELECT *
    FROM vouchers
    WHERE used = false
    AND expired_at BETWEEN DATE '2025-09-11' AND DATE '2025-09-13';
    """

def query_increase_voucher_discount():
    return """
    UPDATE vouchers
    SET discount = LEAST(discount + 5, 45) 
    WHERE used = false
    AND expired_at >= DATE '2025-09-11'
    AND expired_at <= DATE '2025-09-13';
    """

QUERIES_TO_RUN = [
    # query_coach_of_the_month_2024,
    # query_user_priority,
    # query_find_need_discount_groupcourse,
    query_find_expiring_vouchers,
    # query_discount_groupcourse,
    query_increase_voucher_discount,
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
                exec_time = round((time.time() - start_time) * 1000, 3) 
                sql_lower = sql.strip().lower()
                if sql_lower.startswith("select"):
                    rows = cur.fetchall()
                    headers = [desc[0] for desc in cur.description]
                    row_count = len(rows)
                    if rows:
                        print(tabulate(rows, headers, tablefmt="grid"))
                    else:
                        print("Tidak ada data.")
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
                    if affected is not None:
                        if affected:
                            print(tabulate(affected, headers, tablefmt="grid"))
                        else:
                            print("Tidak ada data.")
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
