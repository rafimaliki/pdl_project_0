"""
Script Seeding Database 
"""

import sys
import os
import random
import hashlib
import psycopg2
from faker import Faker
from datetime import datetime, timedelta

from config import DATABASE_CONFIG, SEEDING_CONFIG

class DatabaseSeeder:
    def __init__(self):
        self.fake = Faker()
        self.connection = None
        self.cursor = None
        
        self.users = []
        self.coaches = []
        self.fields = []
        self.coach_availabilities = []
        self.field_bookings = []
        self.group_courses = []
        self.payments = []
        self.group_course_orders = []
        self.private_course_orders = []
    
    def connect_database(self):
        """Membuat koneksi ke database"""
        try:
            self.connection = psycopg2.connect(**DATABASE_CONFIG)
            self.cursor = self.connection.cursor()
            print("\nBerhasil terhubung ke database PostgreSQL")
        except Exception as e:
            print(f"\nGagal terhubung ke database: {e}")
            raise
    
    def close_connection(self):
        """Menutup koneksi database"""
        if self.cursor:
            self.cursor.close()
        if self.connection:
            self.connection.close()
        print("Koneksi database ditutup\n")
    
    def hash_password(self, password):
        """Generate hash password"""
        return hashlib.sha256(password.encode()).hexdigest()
    
    def generate_email_from_name(self, full_name):
        """Generate email dari nama lengkap dalam format: namatanpaspasi@email.com"""
        clean_name = full_name.replace(" ", "").lower()
        
        random_suffix = random.randint(1, 999)
        return f"{clean_name}{random_suffix}@email.com"
    
    def generate_indonesian_phone(self):
        """Generate nomor telepon Indonesia dalam format: +62xxxxxxxxxx"""
        digits = ''.join([str(random.randint(0, 9)) for _ in range(11)])
        return f"+62{digits}"
    
    def clear_all_data(self):
        """Menghapus semua data yang ada dari tabel database"""
        print("Menghapus semua data yang ada dari database...")
        
        tables_to_clear = [
            'vouchers',
            'privatecourseorderdetail',
            'privatecourseorder', 
            'groupcourseorderdetail',
            'groupcourseorder',
            'payments',
            'groupcourses',
            'fieldbookingdetail',
            'coachavailability',
            'coaches',
            'fields',
            'users'
        ]
        
        try:
            self.cursor.execute("SET session_replication_role = replica;")
            
            for table in tables_to_clear:
                self.cursor.execute(f"TRUNCATE TABLE {table} RESTART IDENTITY CASCADE;")
            
            self.cursor.execute("SET session_replication_role = DEFAULT;")
            
            self.connection.commit()
            print("Semua tabel database berhasil dikosongkan!")
            
        except Exception as e:
            print(f"Gagal menghapus data database: {e}")
            self.connection.rollback()
            raise
    
    def seed_users(self):
        """Seeding tabel users"""
        print("\nMelakukan seeding tabel users...")
        
        for i in range(SEEDING_CONFIG['users']['admin_count']):
            full_name = self.fake.name()
            user_data = (
                full_name,
                self.hash_password('admin123'),
                self.generate_email_from_name(full_name),
                self.generate_indonesian_phone(),
                'admin'
            )
            
            self.cursor.execute("""
                INSERT INTO users (full_name, password_hash, email, phone_number, type)
                VALUES (%s, %s, %s, %s, %s) RETURNING user_id
            """, user_data)
            
            user_id = self.cursor.fetchone()[0]
            self.users.append({'id': user_id, 'type': 'admin'})
        
        for i in range(SEEDING_CONFIG['users']['customer_count']):
            full_name = self.fake.name()
            user_data = (
                full_name,
                self.hash_password('customer123'),
                self.generate_email_from_name(full_name),
                self.generate_indonesian_phone(),
                'customer'
            )
            
            self.cursor.execute("""
                INSERT INTO users (full_name, password_hash, email, phone_number, type)
                VALUES (%s, %s, %s, %s, %s) RETURNING user_id
            """, user_data)
            
            user_id = self.cursor.fetchone()[0]
            self.users.append({'id': user_id, 'type': 'customer'})
        
        self.connection.commit()
        print(f"  Berhasil membuat {len(self.users)} users")
    
    def seed_coaches(self):
        """Seeding tabel coaches"""
        print("Melakukan seeding tabel coaches...")
        
        sport_configs = {
            'tennis': SEEDING_CONFIG['coaches']['tennis_coaches'],
            'pickleball': SEEDING_CONFIG['coaches']['pickleball_coaches'],
            'padel': SEEDING_CONFIG['coaches']['padel_coaches']
        }
        
        for sport, count in sport_configs.items():
            available_prices = SEEDING_CONFIG['coaches']['predefined_prices'][sport]
            
            for i in range(count):
                coach_data = (
                    f"Coach {self.fake.name()}",
                    sport,
                    random.choice(available_prices)
                )
                
                self.cursor.execute("""
                    INSERT INTO coaches (coach_name, sport, course_price)
                    VALUES (%s, %s, %s) RETURNING coach_id
                """, coach_data)
                
                coach_id = self.cursor.fetchone()[0]
                self.coaches.append({
                    'id': coach_id,
                    'sport': sport,
                    'price': coach_data[2]
                })
        
        self.connection.commit()
        print(f"  Berhasil membuat {len(self.coaches)} coaches")
    
    def seed_fields(self):
        """Seeding tabel fields"""
        print("Melakukan seeding tabel fields...")
        
        sport_configs = {
            'tennis': SEEDING_CONFIG['fields']['tennis_fields'],
            'pickleball': SEEDING_CONFIG['fields']['pickleball_fields'],
            'padel': SEEDING_CONFIG['fields']['padel_fields']
        }
        
        field_counter = 1
        for sport, count in sport_configs.items():
            available_prices = SEEDING_CONFIG['fields']['predefined_rental_prices'][sport]
            
            for i in range(count):
                field_data = (
                    f"Lapangan {sport.capitalize()} {field_counter}",
                    sport,
                    random.choice(available_prices)
                )
                
                self.cursor.execute("""
                    INSERT INTO fields (field_name, sport, rental_price)
                    VALUES (%s, %s, %s) RETURNING field_id
                """, field_data)
                
                field_id = self.cursor.fetchone()[0]
                self.fields.append({
                    'id': field_id,
                    'sport': sport,
                    'price': field_data[2]
                })
                field_counter += 1
        
        self.connection.commit()
        print(f"  Berhasil membuat {len(self.fields)} fields")
    
    def seed_coach_availability(self):
        """Seeding tabel coachavailability"""
        print("Melakukan seeding tabel coachavailability...")
        
        config = SEEDING_CONFIG['coachavailability']
        start_date = datetime.now().date()
        
        used_combinations = set()
        
        for coach in self.coaches:
            coach_slots_created = 0
            max_attempts = config['slots_per_coach'] * 3
            attempts = 0
            
            while coach_slots_created < config['slots_per_coach'] and attempts < max_attempts:
                date = start_date + timedelta(days=random.randint(0, config['days_ahead']))
                hour = random.randint(config['hours_range'][0], config['hours_range'][1])
                
                combination = (coach['id'], date, hour)
                
                if combination not in used_combinations:
                    try:
                        self.cursor.execute("""
                            INSERT INTO coachavailability (coach_id, date, hour)
                            VALUES (%s, %s, %s) RETURNING coach_availability_id
                        """, combination)
                        
                        availability_id = self.cursor.fetchone()[0]
                        self.coach_availabilities.append({
                            'id': availability_id,
                            'coach_id': coach['id'],
                            'date': date,
                            'hour': hour
                        })
                        
                        used_combinations.add(combination)
                        coach_slots_created += 1
                        
                    except psycopg2.IntegrityError:
                        self.connection.rollback()
                
                attempts += 1
            
        print(f"  Berhasil membuat {len(self.coach_availabilities)} total coachavailability")
    
    def seed_field_bookings(self):
        """Seeding tabel fieldbookingdetail"""
        print("Melakukan seeding tabel fieldbookingdetail...")
        
        config = SEEDING_CONFIG['fieldbookingdetail']
        start_date = datetime.now().date()
        
        used_field_times = set()
        
        for field in self.fields:
            bookings_for_field = int(config['bookings_percentage'] * 20) 
            
            for _ in range(bookings_for_field):
                date = start_date + timedelta(days=random.randint(0, 14))
                hour = random.randint(6, 20)  
                
                current_hour_combo = (field['id'], date, hour)
                next_hour_combo = (field['id'], date, hour + 1)
                
                if current_hour_combo not in used_field_times and next_hour_combo not in used_field_times:
                    try:
                        self.cursor.execute("""
                            INSERT INTO fieldbookingdetail (field_id, date, hour)
                            VALUES (%s, %s, %s) RETURNING field_booking_detail_id
                        """, (field['id'], date, hour))
                        
                        booking_id = self.cursor.fetchone()[0]
                        self.field_bookings.append({
                            'id': booking_id,
                            'field_id': field['id'],
                            'date': date,
                            'hour': hour
                        })
                        
                        used_field_times.add(current_hour_combo)
                        used_field_times.add(next_hour_combo)
                        
                    except psycopg2.IntegrityError:
                        self.connection.rollback()
        
        self.connection.commit()
        print(f"  Berhasil membuat {len(self.field_bookings)} fieldbookingdetail")
    
    def seed_payments(self):
        """Seeding tabel payments"""
        print("Melakukan seeding tabel payments...")

        config = SEEDING_CONFIG['payments']
        status_options = ['waiting', 'accepted', 'rejected']
        
        for i in range(config['base_count']):
            amount = random.randint(100000, 2000000)
            status = random.choices(
                status_options,
                weights=[
                    config['status_distribution']['waiting'],
                    config['status_distribution']['accepted'],
                    config['status_distribution']['rejected']
                ]
            )[0]
            
            payment_proof = self.fake.text(max_nb_chars=100) if status in ['accepted', 'rejected'] else None
            payment_date = self.fake.date_time_between(start_date='-30d', end_date='now')
            
            self.cursor.execute("""
                INSERT INTO payments (total_payment, payment_proof, status, payment_date)
                VALUES (%s, %s, %s, %s) RETURNING payment_id
            """, (amount, payment_proof, status, payment_date))
            
            payment_id = self.cursor.fetchone()[0]
            self.payments.append({
                'id': payment_id,
                'amount': amount,
                'status': status
            })
        
        self.connection.commit()
        print(f"  Berhasil membuat {len(self.payments)} payments")
    
    def seed_group_courses(self):
        """Seeding tabel groupcourses"""
        print("Melakukan seeding tabel groupcourses...")

        config = SEEDING_CONFIG['groupcourses']
        start_date = datetime.now().date()
        sports = ['tennis', 'pickleball', 'padel']
        
        field_bookings_map = {}
        for booking in self.field_bookings:
            field_id = booking['field_id']
            date = booking['date']
            hour = booking['hour']
            
            if field_id not in field_bookings_map:
                field_bookings_map[field_id] = set()
            
            field_bookings_map[field_id].add((date, hour))
            field_bookings_map[field_id].add((date, hour + 1))
        
        successful_courses = 0
        max_attempts = config['total'] * 3
        
        for attempt in range(max_attempts):
            if successful_courses >= config['total']:
                break
                
            sport = random.choice(sports)
            
            sport_coaches = [c for c in self.coaches if c['sport'] == sport]
            sport_fields = [f for f in self.fields if f['sport'] == sport]
            
            if not sport_coaches or not sport_fields:
                continue
            
            coach = random.choice(sport_coaches)
            field = random.choice(sport_fields)
            
            date = start_date + timedelta(days=random.randint(0, config['days_ahead']))
            start_hour = random.randint(6, 20)
            
            field_id = field['id']
            if field_id in field_bookings_map:
                if (date, start_hour) in field_bookings_map[field_id] or (date, start_hour + 1) in field_bookings_map[field_id]:
                    continue
            
            quota = random.randint(config['quota_range'][0], config['quota_range'][1])
            course_price = random.choice(config['predefined_prices'][sport])
            
            try:
                self.cursor.execute("""
                    INSERT INTO groupcourses (course_name, coach_id, sport, field_id, date, start_hour, course_price, quota)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s) RETURNING course_id
                """, (
                    f"Kursus Grup {sport.capitalize()} {successful_courses + 1}",
                    coach['id'],
                    sport,
                    field['id'],
                    date,
                    start_hour,
                    course_price,
                    quota
                ))
                
                course_id = self.cursor.fetchone()[0]
                self.group_courses.append({
                    'id': course_id,
                    'sport': sport,
                    'quota': quota,
                    'price': course_price
                })
                
                if field_id not in field_bookings_map:
                    field_bookings_map[field_id] = set()
                field_bookings_map[field_id].add((date, start_hour))
                field_bookings_map[field_id].add((date, start_hour + 1))
                
                successful_courses += 1
                
            except psycopg2.IntegrityError:
                self.connection.rollback()
        
        self.connection.commit()
        print(f"  Berhasil membuat {len(self.group_courses)} groupcourses")
    
    def seed_group_course_orders(self):
        """Seeding tabel groupcoursesorders dan groupcourseorderdetail"""
        print("Melakukan seeding tabel groupcoursesorders dan groupcoursesorderdetail...")
        
        config = SEEDING_CONFIG['groupcourseorder']
        customer_users = [u for u in self.users if u['type'] == 'customer']
        accepted_payments = [p for p in self.payments if p['status'] == 'accepted']
        
        courses_to_order = random.sample(
            self.group_courses,
            int(len(self.group_courses) * config['orders_percentage'])
        )
        
        for course in courses_to_order:
            if not accepted_payments:
                break
                
            customer = random.choice(customer_users)
            payment = accepted_payments.pop()
            
            self.cursor.execute("""
                INSERT INTO groupcourseorder (customer_id, payment_id)
                VALUES (%s, %s) RETURNING group_course_order_id
            """, (customer['id'], payment['id']))
            
            order_id = self.cursor.fetchone()[0]
            
            pax_count = random.randint(1, min(course['quota'], 10))
            
            self.cursor.execute("""
                INSERT INTO groupcourseorderdetail (group_course_order_id, course_id, pax_count)
                VALUES (%s, %s, %s)
            """, (order_id, course['id'], pax_count))
            
            self.group_course_orders.append({
                'id': order_id,
                'course_id': course['id'],
                'pax_count': pax_count
            })
        
        self.connection.commit()
        print(f"  Berhasil membuat {len(self.group_course_orders)} groupcourseorders dan groupcourseorderdetail")
    
    def seed_private_course_orders(self):
        """Seeding tabel privatecourseorder dan privatecourseorderdetail"""
        print("Melakukan seeding tabel privatecourseorder dan privatecourseorderdetail...")
        
        config = SEEDING_CONFIG['privatecourseorder']
        customer_users = [u for u in self.users if u['type'] == 'customer']
        accepted_payments = [p for p in self.payments if p['status'] == 'accepted']
        
        availabilities_to_book = random.sample(
            self.coach_availabilities,
            int(len(self.coach_availabilities) * config['orders_percentage'])
        )
        
        for availability in availabilities_to_book:
            if not accepted_payments:
                break
                
            customer = random.choice(customer_users)
            payment = accepted_payments.pop()
            
            self.cursor.execute("""
                INSERT INTO privatecourseorder (customer_id, payment_id)
                VALUES (%s, %s) RETURNING private_course_order_id
            """, (customer['id'], payment['id']))
            
            order_id = self.cursor.fetchone()[0]
            
            self.cursor.execute("""
                INSERT INTO privatecourseorderdetail (private_course_order_id, coach_availability_id)
                VALUES (%s, %s)
            """, (order_id, availability['id']))
            
            self.private_course_orders.append({
                'id': order_id,
                'availability_id': availability['id']
            })
        
        self.connection.commit()
        print(f"  Berhasil membuat {len(self.private_course_orders)} pesanan privatecourseorder dan privatecourseorderdetail")
    
    def seed_vouchers(self):
        """Seeding tabel vouchers"""
        print("Melakukan seeding tabel voucher...")
        
        config = SEEDING_CONFIG['vouchers']
        customer_users = [u for u in self.users if u['type'] == 'customer']
        
        for customer in customer_users:
            voucher_count = random.randint(1, config['vouchers_per_customer'])
            
            for _ in range(voucher_count):
                payment = random.choice(self.payments)
                discount = random.choice(config['predefined_discounts'])
                
                expired_at = datetime.now() + timedelta(days=random.randint(1, 90))
                
                used = random.random() < config['used_percentage']
                
                self.cursor.execute("""
                    INSERT INTO vouchers (payment_id, customer_id, discount, expired_at, used)
                    VALUES (%s, %s, %s, %s, %s)
                """, (payment['id'], customer['id'], discount, expired_at, used))
        
        self.connection.commit()
        
        self.cursor.execute("SELECT COUNT(*) FROM vouchers")
        voucher_count = self.cursor.fetchone()[0]
        print(f"  Berhasil membuat {voucher_count} vouchers")

    def run_seeding(self):
        """Menjalankan proses seeding"""
        try:
            self.connect_database()
            print("Memulai proses seeding database...")
            
            self.clear_all_data()
            self.seed_users()
            self.seed_coaches()
            self.seed_fields()
            self.seed_coach_availability()
            self.seed_field_bookings()
            self.seed_payments()
            self.seed_group_courses()
            self.seed_group_course_orders()
            self.seed_private_course_orders()
            self.seed_vouchers()
            
            print("\nSeeding database berhasil diselesaikan!")
            
        except Exception as e:
            print(f"\nError selama proses seeding: {e}")
            if self.connection:
                self.connection.rollback()
        finally:
            self.close_connection()

if __name__ == "__main__":
    
    seeder = DatabaseSeeder()
    seeder.run_seeding()
